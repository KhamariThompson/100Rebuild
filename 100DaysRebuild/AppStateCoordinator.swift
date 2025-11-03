import SwiftUI
import Combine

// Enum for app state
enum AppState: Equatable {
    case initializing
    case ready
    case offline
    case error(String)
    
    // Implement Equatable
    static func == (lhs: AppState, rhs: AppState) -> Bool {
        switch (lhs, rhs) {
        case (.initializing, .initializing): return true
        case (.ready, .ready): return true
        case (.offline, .offline): return true
        case (.error(let lhsMsg), .error(let rhsMsg)): return lhsMsg == rhsMsg
        default: return false
        }
    }
}

// Central coordinator for app state
@MainActor
class AppStateCoordinator: ObservableObject {
    static let shared = AppStateCoordinator()
    
    @Published private(set) var appState: AppState = .initializing
    private var cancellables = Set<AnyCancellable>()
    
    // Hold weak references to avoid retain cycles
    private weak var firebaseService: FirebaseAvailabilityService?
    private weak var networkMonitor: NetworkMonitor?
    
    private init() {
        // Delay setup to reduce initialization pressure. Use a Task on the main actor
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            self?.setupObservers()
        }
    }
    
    deinit {
        // Cleanup happens automatically when the object is deallocated
        // Cannot access main actor-isolated properties from deinit
        print("✅ AppStateCoordinator released")
    }
    
    private func setupObservers() {
        // Monitor Firebase availability with weak references
        firebaseService = FirebaseAvailabilityService.shared
        firebaseService?.isAvailable
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAvailable in
                if isAvailable {
                    self?.appState = .ready
                }
            }
            .store(in: &cancellables)
        
        // Monitor network connectivity with weak references
        networkMonitor = NetworkMonitor.shared
        networkMonitor?.connectionState
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                guard let self = self else { return }
                
                if !isConnected && self.appState == .ready {
                    self.appState = .offline
                } else if isConnected && self.appState == .offline {
                    self.appState = .ready
                    Task { [weak self] in
                        await self?.refreshAllData()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // Refresh all core data in the app to ensure consistency
    @MainActor
    private func refreshAllData() async {
        print("AppStateCoordinator: Refreshing all data after network restored")
        
        // Post a notification to let all parts of the app know data has been refreshed
        NotificationCenter.default.post(name: .appDataRefreshed, object: nil)
    }
    
    // Report a system-wide error
    func reportError(_ message: String) {
        appState = .error(message)
    }
    
    func attemptRecovery() {
        Task { @MainActor in
            appState = .initializing
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
            setupObservers()
        }
    }
}

// Add a notification for when app data is refreshed
extension Notification.Name {
    static let appDataRefreshed = Notification.Name("appDataRefreshed")
} 