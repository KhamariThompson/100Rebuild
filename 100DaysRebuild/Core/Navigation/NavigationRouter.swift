import SwiftUI
import Combine

/// Central router for navigating between app screens with controlled transitions
class NavigationRouter: ObservableObject {
    @Published var selectedTab: Int = 0
    @Published var tabIsChanging: Bool = false
    @Published var isShowingNewChallengeSheet: Bool = false
    
    // Used to prevent rapid tab changes that can cause flickering
    private var changeTabDebouncer: AnyCancellable?
    private var lastTabChangeTime: Date = Date()
    private let minimumTabChangeInterval: TimeInterval = 0.3
    
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Change tab without animation
            self.selectedTab = tab
            
            // After tab change, fade in new tab
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.easeIn(duration: 0.15)) {
                    self.tabIsChanging = false
                }
            }
        }
    }
    
    /// Show the new challenge sheet
    func showNewChallengeSheet() {
        // First navigate to the challenges tab
        changeTab(to: 0)
        
        // Then after a small delay, set the flag to show the new challenge sheet
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
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