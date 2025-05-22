import Network
import Foundation
import Combine

public class NetworkMonitor: ObservableObject {
    public static let shared = NetworkMonitor()
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    // Add static notification names
    public static let networkStatusChanged = Notification.Name("NetworkMonitorStatusChanged")
    public static let firestoreConnectivityCheckRequested = Notification.Name("FirestoreConnectivityCheckRequested")
    public static let firestoreConnectivityChanged = Notification.Name("FirestoreConnectivityChanged")
    
    // Add connectionState publisher for Combine support
    public var connectionState: AnyPublisher<Bool, Never> {
        $isConnected.eraseToAnyPublisher()
    }
    
    @Published public private(set) var isConnected = false
    @Published public private(set) var connectionType: ConnectionType = .unknown
    @Published public private(set) var hasDNSIssues = false
    
    public enum ConnectionType {
        case wifi
        case cellular
        case ethernet
        case unknown
    }
    
    private init() {
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let wasConnected = self?.isConnected ?? false
                self?.isConnected = path.status == .satisfied
                self?.connectionType = self?.checkConnectionType(path) ?? .unknown
                self?.hasDNSIssues = path.isDNSIssues
                
                // Post notification when network status changes
                if wasConnected != (path.status == .satisfied) {
                    NotificationCenter.default.post(
                        name: NetworkMonitor.networkStatusChanged,
                        object: nil,
                        userInfo: ["isConnected": path.status == .satisfied]
                    )
                }
                
                print("Network connectivity changed: \(path.status == .satisfied ? "Connected" : "Disconnected")")
                print("Network status changed: \(path.status == .satisfied ? "Connected" : "Disconnected") - Interface: \(self?.connectionType.description ?? "Unknown") - DNS Issues: \(path.isDNSIssues)")
            }
        }
        monitor.start(queue: queue)
    }
    
    private func stopMonitoring() {
        monitor.cancel()
    }
    
    private func checkConnectionType(_ path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .ethernet
        } else {
            return .unknown
        }
    }
}

extension NetworkMonitor.ConnectionType: CustomStringConvertible {
    public var description: String {
        switch self {
        case .wifi: return "WiFi"
        case .cellular: return "Cellular"
        case .ethernet: return "Ethernet"
        case .unknown: return "Unknown"
        }
    }
}

extension NWPath {
    var isDNSIssues: Bool {
        // Since direct comparison with .dns is problematic,
        // we'll use a more reliable heuristic approach
        if status == .satisfied {
            // If the network is satisfied, there's definitely no DNS issue
            return false
        }
        
        // If there are available interfaces but network is unsatisfied,
        // it could be a DNS issue or other connectivity problem
        return availableInterfaces.count > 0
    }
} 