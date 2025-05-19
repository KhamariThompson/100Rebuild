import Firebase
import Combine
import Network
import FirebaseFirestore
import Foundation

public class FirebaseAvailabilityService {
    public static let shared = FirebaseAvailabilityService()
    
    private let isAvailableSubject = CurrentValueSubject<Bool, Never>(false)
    public var isAvailable: AnyPublisher<Bool, Never> {
        isAvailableSubject.eraseToAnyPublisher()
    }
    
    private var isInitialized: Bool {
        FirebaseApp.app() != nil && UserDefaults.standard.bool(forKey: "firebase_initialized")
    }
    
    // Add a flag to track Firestore connectivity status
    private var isFirestoreConnected = false
    
    private let networkMonitor = NetworkMonitor.shared
    private var initTimer: Timer?
    private var networkStatusObserver: NSObjectProtocol?
    private var initRetryCount = 0
    private let maxRetries = 5
    
    // Add Firestore reconnection timer
    private var firestoreReconnectTimer: Timer?
    private var firestoreConnectivityListeners: [ListenerRegistration] = []
    
    private init() {
        // Check initial state
        isAvailableSubject.send(isInitialized)
        
        // Start monitoring
        monitorAvailability()
        
        // Setup network status observer
        setupNetworkObserver()
        
        // Setup Firestore connectivity monitoring
        setupFirestoreConnectivityMonitoring()
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
            
            if let userInfo = notification.userInfo,
               let isConnected = userInfo["isConnected"] as? Bool {
                if isConnected {
                    // When network becomes available, ensure Firebase is initialized
                    self.initRetryCount = 0 // Reset retry count on new connection
                    self.ensureFirebaseIsInitialized()
                    
                    // Also reset Firestore connectivity
                    if self.isInitialized {
                        self.setupFirestoreConnectivityMonitoring()
                    }
                } else {
                    // Network disconnected but Firebase may still work offline
                    if self.isInitialized {
                        print("Network disconnected but Firebase initialized - offline mode available")
                    } else {
                        print("Network disconnected and Firebase not initialized - waiting for connection")
                    }
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
        let metadataListener = db.collection("_connectivity").addSnapshotListener { snapshot, error in
            if let error = error {
                if error.localizedDescription.contains("firestore.googleapis.com") || 
                   error.localizedDescription.contains("lookup error") ||
                   error.localizedDescription.contains("Domain name not found") {
                    print("⚠️ Firestore DNS resolution error detected, attempting recovery...")
                    self.attemptFirestoreDNSRecovery()
                } else {
                    print("⚠️ Firestore error: \(error.localizedDescription)")
                }
                self.isFirestoreConnected = false
            } else {
                print("✅ Firestore connection established")
                self.isFirestoreConnected = true
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
            
            if self.networkMonitor.isConnected {
                print("Attempting to reconnect to Firestore...")
                
                // Force a clean reconnect by recreating Firestore instances
                let db = Firestore.firestore()
                
                // Use a simple read operation to test connectivity
                db.collection("users").limit(to: 1).getDocuments { snapshot, error in
                    if error == nil {
                        print("✅ Successfully reconnected to Firestore")
                        self.isFirestoreConnected = true
                        timer.invalidate()
                        self.firestoreReconnectTimer = nil
                        
                        // Reset the connectivity monitoring
                        self.setupFirestoreConnectivityMonitoring()
                    } else {
                        print("⚠️ Still unable to connect to Firestore: \(error?.localizedDescription ?? "unknown error")")
                    }
                }
            } else {
                print("Network still unavailable, waiting for connectivity")
            }
        }
    }
    
    private func ensureFirebaseIsInitialized() {
        // If Firebase is already initialized, update state
        if isInitialized {
            isAvailableSubject.send(true)
            return
        }
        
        // Check if Firebase has already been configured in AppDelegate
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate, 
           AppDelegate.firebaseConfigured {
            print("Firebase already configured in AppDelegate, setting initialized flag")
            UserDefaults.standard.set(true, forKey: "firebase_initialized")
            isAvailableSubject.send(true)
            return
        }
        
        // This is just for exceptional cases where Firebase wasn't configured in AppDelegate
        if FirebaseApp.app() == nil {
            print("⚠️ WARNING: Firebase not configured in AppDelegate. This should never happen in production.")
            print("Deferring to AppDelegate for proper Firebase initialization")
            
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
            print("Firebase initialization failed, retrying (\(initRetryCount)/\(maxRetries))...")
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(initRetryCount)) {
                self.ensureFirebaseIsInitialized()
            }
        } else {
            print("⚠️ Firebase initialization failed after \(maxRetries) attempts")
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
            
            let isCurrentlyAvailable = self.isInitialized
            if isCurrentlyAvailable {
                self.isAvailableSubject.send(true)
                timer.invalidate()
                self.initTimer = nil
            }
        }
    }
    
    public func waitForFirebase() async -> Bool {
        // For async contexts - wait for Firebase to be ready
        if isInitialized { return true }
        
        // If not initialized but network is available, try to initialize
        if networkMonitor.isConnected && !isInitialized {
            ensureFirebaseIsInitialized()
        }
        
        let start = Date()
        let timeout: TimeInterval = 15.0 // Increased timeout further to handle DNS issues
        
        while !isInitialized && Date().timeIntervalSince(start) < timeout {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // Check every second if network is available but Firebase isn't initialized
            if networkMonitor.isConnected && !isInitialized {
                ensureFirebaseIsInitialized()
            }
        }
        
        if isInitialized {
            return true
        } else {
            print("⚠️ Firebase initialization timeout in waitForFirebase()")
            // Final fallback attempt
            if networkMonitor.isConnected {
                print("Final attempt to initialize Firebase")
                ensureFirebaseIsInitialized()
                // Wait a short time for the initialization to complete
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                return isInitialized
            }
            return false
        }
    }
    
    // New public method to get Firestore connectivity status
    public var isFirestoreAvailable: Bool {
        return isInitialized && isFirestoreConnected
    }
} 