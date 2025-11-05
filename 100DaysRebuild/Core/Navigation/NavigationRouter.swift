import SwiftUI
import Combine

/// Central router for navigating between app screens with controlled transitions
@MainActor
class NavigationRouter: ObservableObject {
    @Published var selectedTab: Int = 0
    @Published var tabIsChanging: Bool = false
    @Published var isShowingNewChallengeSheet: Bool = false
    
    // Used to prevent rapid tab changes that can cause flickering
    nonisolated(unsafe) private var changeTabDebouncer: AnyCancellable?
    private var lastTabChangeTime: Date = Date()
    private let minimumTabChangeInterval: TimeInterval = 0.3
    
    /// Reset the navigation state to its initial values
    func reset() {
        selectedTab = 0
        tabIsChanging = false
        isShowingNewChallengeSheet = false
        changeTabDebouncer?.cancel()
        lastTabChangeTime = Date()
    }
    
    /// Change tab with controlled animation and debouncing
    func changeTab(to tab: Int) {
        guard selectedTab != tab else { return }
        
        // Don't allow changing tabs during an active transition
        if tabIsChanging {
            return
        }
        
        // Debounce rapid tab changes
        let currentTime = Date()
        if currentTime.timeIntervalSince(lastTabChangeTime) < minimumTabChangeInterval {
            return
        }
        
        // Immediately set changing state
        tabIsChanging = true
        lastTabChangeTime = currentTime
        
        // Cancel any existing debouncer
        changeTabDebouncer?.cancel()
        
        // First fade out current tab
        withAnimation(.easeOut(duration: 0.1)) {
            // Keep tab unchanged but set to changing state to trigger opacity animation
        }

        // After brief fade out, change tab
        let tabToSelect = tab
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            guard let self = self else { return }
            // Change tab without animation
            self.selectedTab = tabToSelect

            // After tab change, fade in new tab
            try? await Task.sleep(nanoseconds: 50_000_000) // 0.05s
            withAnimation(.easeIn(duration: 0.15)) {
                self.tabIsChanging = false
            }
        }
    }
    
    /// Show the new challenge sheet
    func showNewChallengeSheet() {
        // First navigate to the challenges tab
        changeTab(to: 0)

        // Then after a small delay, set the flag to show the new challenge sheet
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
            guard let self = self else { return }
            withAnimation {
                self.isShowingNewChallengeSheet = true
            }
        }
    }
    
    deinit {
        changeTabDebouncer?.cancel()
        print("✅ NavigationRouter released")
    }
} 