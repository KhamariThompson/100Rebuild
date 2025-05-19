import Foundation
import Network
import Combine
import SystemConfiguration
import CoreServices
import FirebaseCore
import FirebaseFirestore

public class NetworkMonitor {
    public static let shared = NetworkMonitor()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    private let connectionStateSubject = CurrentValueSubject<Bool, Never>(false)
    public var connectionState: AnyPublisher<Bool, Never> {
        connectionStateSubject.eraseToAnyPublisher()
    }
    
    public var isConnected: Bool {
        connectionStateSubject.value
    }
    
    // Add DNS resolution status
    private var hasDNSResolutionIssues = false
    private var dnsCheckTimer: Timer?
    
    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let isConnected = path.status == .satisfied
            
            DispatchQueue.main.async {
                self?.connectionStateSubject.send(isConnected)
                
                // Add more detailed connectivity info
                var connectivityInfo: [String: Any] = [
                    "isConnected": isConnected,
                    "interfaceType": self?.getInterfaceTypeString(path) ?? "unknown"
                ]
                
                // If connected, check DNS resolution
                if isConnected {
                    self?.checkDNSResolution { hasDNSIssue in
                        connectivityInfo["hasDNSIssues"] = hasDNSIssue
                        
                        // Post notification with detailed info
                        NotificationCenter.default.post(
                            name: NetworkMonitor.networkStatusChanged,
                            object: nil,
                            userInfo: connectivityInfo
                        )
                        
                        print("Network status changed: \(isConnected ? "Connected" : "Disconnected") - Interface: \(connectivityInfo["interfaceType"] as? String ?? "unknown") - DNS Issues: \(hasDNSIssue)")
                    }
                } else {
                    // Not connected, no need to check DNS
                    NotificationCenter.default.post(
                        name: NetworkMonitor.networkStatusChanged,
                        object: nil,
                        userInfo: connectivityInfo
                    )
                    
                    print("Network status changed: Disconnected")
                }
            }
        }
        
        monitor.start(queue: queue)
        
        // Initial check
        DispatchQueue.main.async { [weak self] in
            self?.checkNetworkStatus()
            
            // Set up periodic network checks
            self?.startPeriodicNetworkChecks()
        }
    }
    
    deinit {
        monitor.cancel()
        dnsCheckTimer?.invalidate()
    }
    
    // Add a method to get interface type
    private func getInterfaceTypeString(_ path: NWPath) -> String {
        if path.usesInterfaceType(.wifi) {
            return "WiFi"
        } else if path.usesInterfaceType(.cellular) {
            return "Cellular"
        } else if path.usesInterfaceType(.wiredEthernet) {
            return "Ethernet"
        } else if path.usesInterfaceType(.loopback) {
            return "Loopback"
        } else {
            return "Other"
        }
    }
    
    // Add a method to check DNS resolution
    private func checkDNSResolution(completion: @escaping (Bool) -> Void) {
        // Check Firebase domain DNS resolution
        let host = "firestore.googleapis.com"
        
        let hostRef = CFHostCreateWithName(nil, host as CFString).takeRetainedValue()
        CFHostStartInfoResolution(hostRef, .addresses, nil)
        
        var resolved = DarwinBoolean(false)
        if let addresses = CFHostGetAddressing(hostRef, &resolved)?.takeUnretainedValue() as NSArray?,
           resolved.boolValue && addresses.count > 0 {
            // DNS resolution succeeded
            self.hasDNSResolutionIssues = false
            completion(false)
        } else {
            // DNS resolution failed
            self.hasDNSResolutionIssues = true
            completion(true)
            
            // Log DNS resolution error
            print("⚠️ DNS resolution failed for \(host) - This may cause Firebase connectivity issues")
        }
    }
    
    // Add method to check network status
    private func checkNetworkStatus() {
        let reachability = SCNetworkReachabilityCreateWithName(nil, "firestore.googleapis.com")
        
        var flags = SCNetworkReachabilityFlags()
        if let reachability = reachability,
           SCNetworkReachabilityGetFlags(reachability, &flags) {
            
            let isReachable = flags.contains(.reachable)
            let needsConnection = flags.contains(.connectionRequired)
            let isConnected = isReachable && !needsConnection
            
            connectionStateSubject.send(isConnected)
            
            // Notify about status
            NotificationCenter.default.post(
                name: NetworkMonitor.networkStatusChanged,
                object: nil,
                userInfo: ["isConnected": isConnected]
            )
        }
    }
    
    // Start periodic network checks to ensure status is accurate
    private func startPeriodicNetworkChecks() {
        dnsCheckTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.checkNetworkStatus()
            
            // If connected, check Firestore connectivity by making a test request
            if self?.isConnected == true {
                self?.checkFirestoreConnectivity()
            }
        }
    }
    
    // Check Firestore connectivity
    private func checkFirestoreConnectivity() {
        guard FirebaseApp.app() != nil else { return }
        
        // Don't directly access Firestore here, as it might cause initialization conflicts
        // Instead, post a notification that will be handled by FirebaseAvailabilityService
        NotificationCenter.default.post(
            name: NetworkMonitor.firestoreConnectivityCheckRequested,
            object: nil
        )
    }
    
    // Public method to force a network status check
    public func forceNetworkCheck() {
        checkNetworkStatus()
    }
    
    // Define the notification names as static properties
    public static let networkStatusChanged = Notification.Name("networkStatusChanged")
    public static let firestoreConnectivityChanged = Notification.Name("firestoreConnectivityChanged")
    public static let firestoreConnectivityCheckRequested = Notification.Name("firestoreConnectivityCheckRequested")
} 