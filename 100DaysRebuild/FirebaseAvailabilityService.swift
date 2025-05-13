import Firebase
import Combine
import Network

public class FirebaseAvailabilityService {
    public static let shared = FirebaseAvailabilityService()
    
    private let isAvailableSubject = CurrentValueSubject<Bool, Never>(false)
    public var isAvailable: AnyPublisher<Bool, Never> {
        isAvailableSubject.eraseToAnyPublisher()
    }
    
    private var isInitialized: Bool {
        FirebaseApp.app() != nil && UserDefaults.standard.bool(forKey: "firebase_initialized")
    }
    
    private let networkMonitor = NetworkMonitor.shared
    private var initTimer: Timer?
    private var networkStatusObserver: NSObjectProtocol?
    private var initRetryCount = 0
    private let maxRetries = 5
    
    private init() {
        // Check initial state
        isAvailableSubject.send(isInitialized)
        
        // Start monitoring
        monitorAvailability()
        
        // Setup network status observer
        setupNetworkObserver()
    }
    
    deinit {
        if let observer = networkStatusObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        initTimer?.invalidate()
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
    
    private func ensureFirebaseIsInitialized() {
        // If Firebase is already initialized, update state
        if isInitialized {
            isAvailableSubject.send(true)
            return
        }
        
        // Otherwise, try to initialize Firebase
        if FirebaseApp.app() == nil {
            // Use a simple initialization block without try/catch since FirebaseApp.configure() doesn't throw
            FirebaseApp.configure()
            
            // Configure Firestore for offline persistence
            let db = Firestore.firestore()
            let settings = db.settings
            
            // Set up persistent cache for offline mode
            let cacheSettings = PersistentCacheSettings(sizeBytes: NSNumber(value: FirestoreCacheSizeUnlimited))
            settings.cacheSettings = cacheSettings
            
            db.settings = settings
            
            UserDefaults.standard.set(true, forKey: "firebase_initialized")
            isAvailableSubject.send(true)
            print("Firebase initialized on-demand in FirebaseAvailabilityService")
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
        let timeout: TimeInterval = 10.0 // Increased timeout
        
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
} 