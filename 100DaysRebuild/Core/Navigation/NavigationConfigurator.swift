import SwiftUI

/// Helper struct to configure NavigationView styles consistently across the app
struct NavigationConfigurator: ViewModifier {
    func body(content: Content) -> some View {
        // Updated to use modern SwiftUI navigation
        content
    }
}

/// Extension to add navigationStyle modifier to any NavigationView
extension View {
    func configureNavigation() -> some View {
        self.modifier(NavigationConfigurator())
    }
}

/// Fix for layout constraint issues in NavigationView
func setupNavigationBarAppearance() {
    let appearance = UINavigationBarAppearance()
    appearance.configureWithTransparentBackground()
    appearance.backgroundColor = UIColor(Color.theme.background)
    
    // Title and button appearance
    appearance.titleTextAttributes = [.foregroundColor: UIColor(Color.theme.text)]
    appearance.largeTitleTextAttributes = [.foregroundColor: UIColor(Color.theme.text)]
    
    // Apply to all navigation bars
    UINavigationBar.appearance().standardAppearance = appearance
    UINavigationBar.appearance().scrollEdgeAppearance = appearance
    UINavigationBar.appearance().compactAppearance = appearance
    
    // Set tint color for navigation bar items
    UINavigationBar.appearance().tintColor = UIColor(Color.theme.accent)
} 