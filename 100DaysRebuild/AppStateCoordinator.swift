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
class AppStateCoordinator: ObservableObject {
    static let shared = AppStateCoordinator()
    
    @Published private(set) var appState: AppState = .initializing
    private var cancellables = Set<AnyCancellable>()
    
    // Key services that need to be synchronized
    private let challengeStore = ChallengeStore.shared
    private let userStatsService = UserStatsService.shared
    
    private init() {
        setupObservers()
    }
    
    private func setupObservers() {
        // Monitor Firebase availability
        let firebaseService = FirebaseAvailabilityService.shared
        firebaseService.isAvailable
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] isAvailable in
                if isAvailable {
                    self?.appState = .ready
                }
            }
            .store(in: &cancellables)
        
        // Monitor network connectivity
        let networkMonitor = NetworkMonitor.shared
        networkMonitor.connectionState
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] (isConnected: Bool) in
                guard let self = self else { return }
                
                if !isConnected && self.appState == .ready {
                    self.appState = .offline
                } else if isConnected && self.appState == .offline {
                    self.appState = .ready
                    
                    // Refresh critical data when coming back online
                    Task {
                        await self.refreshAllData()
                    }
                }
            }
            .store(in: &cancellables)
        
        // Start initial state check
        Task {
            let firebaseReady = await FirebaseAvailabilityService.shared.waitForFirebase()
            if firebaseReady {
                await MainActor.run {
                    let networkMonitor = NetworkMonitor.shared
                    self.appState = networkMonitor.isConnected ? .ready : .offline
                }
            } else {
                await MainActor.run {
                    self.appState = .error("Firebase initialization failed")
                }
            }
        }
    }
    
    // Refresh all core data in the app to ensure consistency
    @MainActor
    private func refreshAllData() async {
        print("AppStateCoordinator: Refreshing all data after network restored")
        
        // Refresh challenges first (source of truth)
        await challengeStore.refreshChallenges()
        
        // Then update user stats which depend on challenge data
        await userStatsService.refreshUserStats()
        
        // Post a notification to let all parts of the app know data has been refreshed
        NotificationCenter.default.post(name: .appDataRefreshed, object: nil)
    }
    
    // Report a system-wide error
    func reportError(_ message: String) {
        appState = .error(message)
    }
    
    // Attempt to recover from error state
    func attemptRecovery() {
        let networkMonitor = NetworkMonitor.shared
        appState = networkMonitor.isConnected ? .ready : .offline
        
        // If we've recovered and are online, refresh data
        if appState == .ready {
            Task {
                await refreshAllData()
            }
        }
    }
}

// Add a notification for when app data is refreshed
extension Notification.Name {
    static let appDataRefreshed = Notification.Name("appDataRefreshed")
} 