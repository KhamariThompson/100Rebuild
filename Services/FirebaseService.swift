import Firebase
import Network

class FirebaseService {
    static let shared = FirebaseService()
    
    private var auth: Auth?
    private var firestore: Firestore?
    private var storage: Storage?
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "FirebaseService.NetworkMonitor")
    private var isNetworkAvailable = true
    private var isReconnecting = false
    
    private var pendingOperations: [() async throws -> Void] = []
    private var firestoreListeners: [ListenerRegistration] = []
    
    private init() {
        // Firebase configuration will be initialized in AppDelegate
        setupNetworkMonitoring()
        
        // Setup notification observer for network status changes from AppDelegate
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNetworkStatusChange),
            name: NSNotification.Name("NetworkStatusChanged"),
            object: nil
        )
    }
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            let isConnected = path.status == .satisfied
            
            DispatchQueue.main.async {
                self?.handleNetworkChange(isConnected: isConnected)
            }
        }
        networkMonitor.start(queue: networkQueue)
    }
    
    private func handleNetworkChange(isConnected: Bool) {
        let wasOffline = !isNetworkAvailable
        isNetworkAvailable = isConnected
        
        if wasOffline && isConnected && !isReconnecting {
            print("DEBUG: Network reconnected in FirebaseService")
            isReconnecting = true
            
            // Execute pending operations when network is back
            Task {
                await executePendingOperations()
                isReconnecting = false
            }
        } else if !isConnected {
            print("DEBUG: Network disconnected in FirebaseService")
        }
    }
    
    @objc private func handleNetworkStatusChange(notification: Notification) {
        if let userInfo = notification.userInfo,
           let isConnected = userInfo["isConnected"] as? Bool {
            handleNetworkChange(isConnected: isConnected)
        }
    }
    
    private func executePendingOperations() async {
        print("DEBUG: Executing \(pendingOperations.count) pending operations")
        let operations = pendingOperations
        pendingOperations.removeAll()
        
        var successCount = 0
        var failureCount = 0
        
        for operation in operations {
            do {
                try await operation()
                successCount += 1
            } catch {
                failureCount += 1
                print("DEBUG: Failed to execute pending operation: \(error.localizedDescription)")
            }
        }
        
        print("DEBUG: Completed pending operations - Success: \(successCount), Failed: \(failureCount)")
    }
    
    deinit {
        networkMonitor.cancel()
        NotificationCenter.default.removeObserver(self)
        
        // Clean up any active Firestore listeners
        for listener in firestoreListeners {
            listener.remove()
        }
    }
    
    func configure() {
        // Check if Firebase is already configured 
        if FirebaseApp.app() != nil {
            print("DEBUG: Using existing Firebase configuration in FirebaseService")
            
            // Make sure services are initialized
            initializeServices()
        } else {
            print("ERROR: Firebase not configured. It should be initialized in AppDelegate.")
            // Don't try to configure Firebase here - that should only happen in AppDelegate
        }
    }
    
    func configureIfNeeded() {
        if FirebaseApp.app() == nil {
            print("ERROR: Firebase not configured, should be initialized in AppDelegate")
            return
        } else {
            print("DEBUG: Firebase already configured, initializing services")
            
            // Ensure all services are initialized
            initializeServices()
        }
    }
    
    // Helper method to initialize services
    private func initializeServices() {
        if auth == nil {
            auth = Auth.auth()
            print("DEBUG: Auth service initialized")
        }
        
        if firestore == nil {
            firestore = Firestore.firestore()
            print("DEBUG: Firestore service initialized")
        }
        
        if storage == nil {
            storage = Storage.storage()
            print("DEBUG: Storage service initialized")
        }
    }
    
    // Rest of the service methods remain unchanged
} 