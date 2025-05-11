import SwiftUI

/// Core Design System Colors
/// Use through AppColors namespace for consistent styling
public enum AppColors {
    /// Main background color for screens
    public static let background = Color("Background")
    /// Surface color for cards and containers
    public static let surface = Color("Surface")
    /// Primary brand color
    public static let primary = Color("ProjectPrimary")
    /// Secondary brand color
    public static let secondary = Color("ProjectSecondary")
    /// Accent color for highlights and CTAs
    public static let accent = Color("ProjectAccent")
    /// Main text color
    public static let text = Color("Text")
    /// Secondary text color for labels and captions
    public static let subtext = Color("Subtext")
    /// Error state color
    public static let error = Color("Error")
    /// Success state color
    public static let success = Color("Success")
    
    // Fallback colors in case assets aren't loaded properly
    public static let fallbackAccent = Color.blue
    public static let fallbackText = Color.primary
    public static let fallbackSubtext = Color.secondary
    public static let fallbackBackground = Color(.systemBackground)
    public static let fallbackSurface = Color(.secondarySystemBackground)
    public static let fallbackError = Color.red
    public static let fallbackSuccess = Color.green
}

// MARK: - Color Assets
public extension Color {
    static let theme = AppColors.self
} // Border color missing in AppColors - add it now
extension AppColors {
    /// Border color for fields and containers
    public static let border = Color.gray.opacity(0.3)
}
