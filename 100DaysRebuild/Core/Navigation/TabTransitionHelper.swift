import SwiftUI
import Combine

/// A modifier that handles transitions between tabs in a TabView
/// to prevent flash of content during transitions
struct TabTransitionModifier: ViewModifier {
    @ObservedObject var router: NavigationRouter
    
    func body(content: Content) -> some View {
        content
            .opacity(router.tabIsChanging ? 0 : 1) // Fade out content during tab changes
            .animation(.easeInOut(duration: 0.15), value: router.tabIsChanging)
    }
}

extension View {
    /// Apply the tab transition modifier to a view
    /// - Parameter router: The NavigationRouter instance
    /// - Returns: The modified view with smooth tab transition handling
    func withTabTransition(router: NavigationRouter) -> some View {
        self.modifier(TabTransitionModifier(router: router))
    }
} 