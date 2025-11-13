import Firebase
import Combine
import Network
import FirebaseFirestore
import Foundation

@MainActor
public class FirebaseAvailabilityService {
    public static let shared = FirebaseAvailabilityService()
    
    private let isAvailableSubject = CurrentValueSubject<Bool, Never>(false)
    public var isAvailable: AnyPublisher<Bool, Never> {
        isAvailableSubject.eraseToAnyPublisher()
    }
    
    private var isInitialized: Bool {
        // Check if Firebase is configured without triggering warnings
        // This won't log warnings since it's checking the optional
        return FirebaseApp.app() != nil
    }
    
    // Add a flag to track Firestore connectivity status
    private var isFirestoreConnected = false
    
    private let networkMonitor = NetworkMonitor.shared
    nonisolated(unsafe) private var initTimer: Timer?
    nonisolated(unsafe) private var networkStatusObserver: NSObjectProtocol?
    private var initRetryCount = 0
    private let maxRetries = 5

    // Add Firestore reconnection timer
    nonisolated(unsafe) private var firestoreReconnectTimer: Timer?
    nonisolated(unsafe) private var firestoreConnectivityListeners: [ListenerRegistration] = []
    
    private init() {
        // PRODUCTION FIX: Don't check Firebase status immediately in init
        // This prevents "Firebase not configured" warnings on app launch
        // The monitoring will start and detect when Firebase becomes available
        isAvailableSubject.send(false)

        // Delay initial checks slightly to allow Firebase to configure first
        Task { @MainActor in
            // Small delay to ensure Firebase has time to configure
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

            // Start monitoring
            self.monitorAvailability()

            // Setup network status observer
            self.setupNetworkObserver()

            // Setup Firestore connectivity monitoring if Firebase is ready
            if self.isInitialized {
                self.setupFirestoreConnectivityMonitoring()
            }
        }
    }
    
    deinit {
        if let observer = networkStatusObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        initTimer?.invalidate()
        firestoreReconnectTimer?.invalidate()
        
        // Clean up Firestore listeners
        for listener in firestoreConnectivityListeners {
            listener.remove()
        }
    }
    
    private func setupNetworkObserver() {
        // Listen for network status changes
        networkStatusObserver = NotificationCenter.default.addObserver(
            forName: NetworkMonitor.networkStatusChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            guard let userInfo = notification.userInfo,
                  let isConnected = userInfo["isConnected"] as? Bool else { return }

            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if isConnected {
                    // Reset retry count and attempt to initialize on the MainActor
                    self.initRetryCount = 0
                    self.ensureFirebaseIsInitialized()

                    // Also reset Firestore connectivity if initialized
                    if self.isInitialized {
                        self.setupFirestoreConnectivityMonitoring()
                    }
                } else {
                    #if DEBUG
                    if self.isInitialized {
                        print("Network disconnected but Firebase initialized - offline mode available")
                    } else {
                        print("Network disconnected and Firebase not initialized - waiting for connection")
                    }
                    #endif
                }
            }
        }
    }
    
    // Add method to monitor Firestore connectivity
    private func setupFirestoreConnectivityMonitoring() {
        // Clean up any existing listeners
        for listener in firestoreConnectivityListeners {
            listener.remove()
        }
        firestoreConnectivityListeners.removeAll()
        
        guard isInitialized && networkMonitor.isConnected else { return }
        
        // Use a special collection for connectivity testing
        let db = Firestore.firestore()
        
        // Set up a listener to monitor connectivity status changes
        let metadataListener = db.collection("_connectivity").addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }

            if let error = error {
                if error.localizedDescription.contains("firestore.googleapis.com") ||
                   error.localizedDescription.contains("lookup error") ||
                   error.localizedDescription.contains("Domain name not found") {
                    #if DEBUG
                    print("⚠️ Firestore DNS resolution error detected, attempting recovery...")
                    #endif
                    Task { @MainActor [weak self] in
                        self?.attemptFirestoreDNSRecovery()
                        self?.isFirestoreConnected = false
                    }
                } else {
                    #if DEBUG
                    print("⚠️ Firestore error: \(error.localizedDescription)")
                    #endif
                    Task { @MainActor [weak self] in
                        self?.isFirestoreConnected = false
                    }
                }
            } else {
                #if DEBUG
                print("✅ Firestore connection established")
                #endif
                Task { @MainActor [weak self] in
                    self?.isFirestoreConnected = true
                }
            }
        }
        
        firestoreConnectivityListeners.append(metadataListener)
    }
    
    // Add method to handle DNS resolution issues
    private func attemptFirestoreDNSRecovery() {
        // Cancel any existing reconnect timer
        firestoreReconnectTimer?.invalidate()
        
        // Create a new timer that attempts to reconnect
        firestoreReconnectTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if self.networkMonitor.isConnected {
                    #if DEBUG
                    print("Attempting to reconnect to Firestore...")
                    #endif

                    // Force a clean reconnect by recreating Firestore instances
                    let db = Firestore.firestore()

                    // Use a simple read operation to test connectivity
                    db.collection("users").limit(to: 1).getDocuments { [weak self] snapshot, error in
                        guard let self = self else { return }
                        if error == nil {
                            #if DEBUG
                            print("✅ Successfully reconnected to Firestore")
                            #endif
                            Task { @MainActor [weak self] in
                                guard let self = self else { return }
                                self.isFirestoreConnected = true
                                self.firestoreReconnectTimer?.invalidate()
                                self.firestoreReconnectTimer = nil

                                // Reset the connectivity monitoring
                                self.setupFirestoreConnectivityMonitoring()
                            }
                        } else {
                            #if DEBUG
                            print("⚠️ Still unable to connect to Firestore: \(error?.localizedDescription ?? "unknown error")")
                            #endif
                        }
                    }
                } else {
                    #if DEBUG
                    print("Network still unavailable, waiting for connectivity")
                    #endif
                }
            }
        }
    }
    
    private func ensureFirebaseIsInitialized() {
        // If Firebase is already initialized, update state
        if isInitialized {
            isAvailableSubject.send(true)
            return
        }
        
        // Check if Firebase has already been configured
        if FirebaseApp.app() != nil {
            #if DEBUG
            print("Firebase already configured")
            #endif
            isAvailableSubject.send(true)
            return
        }

        // This is just for exceptional cases where Firebase wasn't configured in AppDelegate
        if FirebaseApp.app() == nil {
            #if DEBUG
            print("⚠️ WARNING: Firebase not configured in AppDelegate. This should never happen in production.")
            print("Deferring to AppDelegate for proper Firebase initialization")
            #endif
            
            // Instead of configuring Firebase here, notify app state coordinator or post a notification
            // that Firebase needs to be initialized, but let AppDelegate handle it
            
            // Do NOT call FirebaseApp.configure() here
            
            // Just mark as not available instead of trying to initialize
            isAvailableSubject.send(false)
        }
    }
    
    private func handleInitFailure() {
        initRetryCount += 1
        if initRetryCount <= maxRetries {
            #if DEBUG
            print("Firebase initialization failed, retrying (\(initRetryCount)/\(maxRetries))...")
            #endif
            Task { @MainActor in
                // PRODUCTION: Retry immediately, no exponential backoff delays
                self.ensureFirebaseIsInitialized()
            }
        } else {
            #if DEBUG
            print("⚠️ Firebase initialization failed after \(maxRetries) attempts")
            #endif
        }
    }
    
    func monitorAvailability() {
        // Clear any existing timer
        initTimer?.invalidate()
        
        // Check every 1 second until Firebase is available
        initTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let isCurrentlyAvailable = self.isInitialized
                if isCurrentlyAvailable {
                    self.isAvailableSubject.send(true)
                    self.initTimer?.invalidate()
                    self.initTimer = nil
                }
            }
        }
    }
    
    public func waitForFirebase() async -> Bool {
        // PRODUCTION: Non-blocking check - return immediately
        // UI should not wait for Firebase; services handle offline mode gracefully
        if isInitialized { return true }

        // If not initialized but network is available, try to initialize (non-blocking)
        if networkMonitor.isConnected && !isInitialized {
            ensureFirebaseIsInitialized()
        }

        // Return current state immediately - don't block UI
        return isInitialized
    }
    
    // New public method to get Firestore connectivity status
    public var isFirestoreAvailable: Bool {
        return isInitialized && isFirestoreConnected
    }
} 