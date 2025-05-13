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
    
    // Additional semantic colors
    /// Gradient start color for backgrounds and elements
    public static let gradientStart = Color("GradientStart")
    /// Gradient end color for backgrounds and elements
    public static let gradientEnd = Color("GradientEnd")
    /// Subtle border color for cards and inputs
    public static let border = Color("Border")
    /// Shadow color for elevated elements
    public static let shadow = Color("Shadow")
    
    // Fallback colors in case assets aren't loaded properly
    public static let fallbackAccent = Color.blue
    public static let fallbackText = Color.primary
    public static let fallbackSubtext = Color.secondary
    public static let fallbackBackground = Color(.systemBackground)
    public static let fallbackSurface = Color(.secondarySystemBackground)
    public static let fallbackError = Color.red
    public static let fallbackSuccess = Color.green
    public static let fallbackGradientStart = Color.blue.opacity(0.8)
    public static let fallbackGradientEnd = Color.purple.opacity(0.8)
    public static let fallbackBorder = Color.gray.opacity(0.3)
    public static let fallbackShadow = Color.black.opacity(0.2)
}

// MARK: - Color Assets
public extension Color {
    static let theme = AppColors.self
}

// MARK: - Gradient Extensions
public extension LinearGradient {
    /// Primary gradient for backgrounds and buttons
    static let primary = LinearGradient(
        gradient: Gradient(colors: [AppColors.gradientStart, AppColors.gradientEnd]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// Accent gradient for highlights and CTAs
    static let accent = LinearGradient(
        gradient: Gradient(colors: [AppColors.accent, AppColors.accent.opacity(0.8)]),
        startPoint: .top,
        endPoint: .bottom
    )
}
