import SwiftUI

/// Core Design System Colors
/// Use through AppColors namespace for consistent styling
public enum AppColors {
    /// Main background color for screens
    public static let background = Color("Background")
    /// Surface color for cards and containers
    public static let surface = Color("Surface")
    /// Primary brand color
    public static let primary = Color("Primary")
    /// Secondary brand color
    public static let secondary = Color("Secondary")
    /// Accent color for highlights and CTAs
    public static let accent = Color("Accent")
    /// Main text color
    public static let text = Color("Text")
    /// Secondary text color for labels and captions
    public static let subtext = Color("Subtext")
    /// Error state color
    public static let error = Color("Error")
    /// Success state color
    public static let success = Color("Success")
}

// MARK: - Color Assets
public extension Color {
    static let theme = AppColors.self
} 