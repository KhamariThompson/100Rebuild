import Foundation
import Network
import Combine

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
    
    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let isConnected = path.status == .satisfied
            DispatchQueue.main.async {
                self?.connectionStateSubject.send(isConnected)
                NotificationCenter.default.post(
                    name: NetworkMonitor.networkStatusChanged,
                    object: nil,
                    userInfo: ["isConnected": isConnected]
                )
                print("Network status changed: \(isConnected ? "Connected" : "Disconnected")")
            }
        }
        
        monitor.start(queue: queue)
    }
    
    deinit {
        monitor.cancel()
    }
    
    // Define the notification name as a static property
    public static let networkStatusChanged = Notification.Name("networkStatusChanged")
} 