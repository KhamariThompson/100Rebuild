import SwiftUI
import Combine

/// Theme options supported by the app
public enum AppThemeMode: String, CaseIterable, Identifiable {
    case light = "light"
    case dark = "dark"
    case system = "system"
    
    public var id: String { rawValue }
    
    /// User-friendly display name for this theme
    public var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "System"
        }
    }
    
    /// System icon name for this theme
    public var iconName: String {
        switch self {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .system: return "circle.lefthalf.filled"
        }
    }
    
    /// Convert to SwiftUI ColorScheme when needed
    public func toColorScheme(defaultScheme: ColorScheme = .light) -> ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil // Let the system decide
        }
    }
}

/// Notification name published when the theme changes
extension Notification.Name {
    public static let appThemeDidChange = Notification.Name("appThemeDidChange")
}

/// Central manager for handling application theme
public class ThemeManager: ObservableObject {
    // Singleton instance
    public static let shared = ThemeManager()
    
    // Current theme mode
    @Published public private(set) var currentTheme: AppThemeMode {
        didSet {
            if oldValue != currentTheme {
                saveTheme()
                NotificationCenter.default.post(name: .appThemeDidChange, object: currentTheme.rawValue)
            }
        }
    }
    
    // Key for storing theme preference
    private let themeStorageKey = "AppTheme"
    
    private init() {
        // Load saved theme or use system default
        if let savedTheme = UserDefaults.standard.string(forKey: themeStorageKey),
           let themeMode = AppThemeMode(rawValue: savedTheme) {
            self.currentTheme = themeMode
        } else {
            self.currentTheme = .system
        }
    }
    
    /// Change the app theme
    /// - Parameter theme: The new theme to apply
    public func setTheme(_ theme: AppThemeMode) {
        guard theme != currentTheme else { return }
        
        // Use main actor to ensure UI updates are thread-safe
        DispatchQueue.main.async {
            self.currentTheme = theme
            // Post theme change notification
            NotificationCenter.default.post(name: .appThemeDidChange, object: theme.rawValue)
        }
    }
    
    /// Toggle between light and dark modes (skipping system)
    public func toggleLightDarkMode() {
        switch currentTheme {
        case .light:
            setTheme(.dark)
        case .dark, .system:
            setTheme(.light)
        }
    }
    
    /// Save the current theme to user defaults
    private func saveTheme() {
        UserDefaults.standard.set(currentTheme.rawValue, forKey: themeStorageKey)
    }
    
    /// Get the SwiftUI ColorScheme based on current theme
    /// - Parameter defaultScheme: Default scheme if using system setting
    /// - Returns: ColorScheme to use for preferredColorScheme modifier
    public func effectiveColorScheme(defaultScheme: ColorScheme = .light) -> ColorScheme? {
        return currentTheme.toColorScheme(defaultScheme: defaultScheme)
    }
}

// MARK: - SwiftUI Environment Extensions

/// Environment key for ThemeManager
private struct ThemeManagerKey: EnvironmentKey {
    static let defaultValue = ThemeManager.shared
}

extension EnvironmentValues {
    public var themeManager: ThemeManager {
        get { self[ThemeManagerKey.self] }
        set { self[ThemeManagerKey.self] = newValue }
    }
}

// MARK: - View Extensions for Theming
extension View {
    /// Apply the application theme from ThemeManager to this view hierarchy
    public func withAppTheme() -> some View {
        self.modifier(AppThemeModifier())
    }
    
    /// Sheet presentation that inherits the app theme
    public func presentationWithAppTheme<Item, Content>(
        item: Binding<Item?>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View where Item: Identifiable, Content: View {
        self.sheet(item: item, onDismiss: onDismiss) { item in
            content(item)
                .withAppTheme()
        }
    }
    
    /// Sheet presentation that inherits the app theme
    public func sheetWithAppTheme<Content>(
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View where Content: View {
        self.sheet(isPresented: isPresented, onDismiss: onDismiss) {
            content()
                .withAppTheme()
        }
    }
    
    /// Full screen cover that inherits the app theme
    public func fullScreenCoverWithAppTheme<Content>(
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View where Content: View {
        self.fullScreenCover(isPresented: isPresented, onDismiss: onDismiss) {
            content()
                .withAppTheme()
        }
    }
    
    /// Alert that uses theme-aware colors
    public func themeAwareAlert(
        title: String,
        isPresented: Binding<Bool>,
        actions: @escaping () -> some View,
        message: @escaping () -> some View
    ) -> some View {
        self.alert(
            title,
            isPresented: isPresented,
            actions: actions,
            message: message
        )
    }
}

/// Modifier that applies the app theme from ThemeManager
struct AppThemeModifier: ViewModifier {
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var lastTheme: AppThemeMode? = nil
    
    func body(content: Content) -> some View {
        content
            .preferredColorScheme(themeManager.effectiveColorScheme())
            .environment(\.colorScheme, themeManager.effectiveColorScheme() ?? .light)
            .onAppear {
                // Store the initial theme to avoid animation when view first appears
                if lastTheme == nil {
                    lastTheme = themeManager.currentTheme
                }
            }
            .onChange(of: themeManager.currentTheme) { oldValue, newValue in
                // Only apply animation if this isn't the first appearance
                if lastTheme != nil && oldValue != newValue {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        lastTheme = newValue
                    }
                } else {
                    lastTheme = newValue
                }
            }
    }
} 