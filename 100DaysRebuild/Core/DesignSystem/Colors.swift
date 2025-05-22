import SwiftUI

/// Core Design System Colors
/// Use through AppColors namespace for consistent styling
public enum AppColors {
    // MARK: - Primary Semantic Colors
    
    /// Main background color for screens
    public static let background = Color("Background")
    /// Surface color for cards and containers
    public static let surface = Color("Surface")
    /// Primary brand color - neutral color from the landing page
    public static let primary = Color("ProjectPrimary")
    /// Secondary brand color - neutral color from the landing page
    public static let secondary = Color("ProjectSecondary")
    /// Accent color for highlights and CTAs - more subtle neutral from landing page
    public static let accent = Color("ProjectAccent")
    /// Text color for primary text
    public static let text = Color("Text")
    /// Text color for secondary or less important text
    public static let subtext = Color("Subtext")
    /// Border color for dividers and separators
    public static let border = Color("Border")
    /// Shadow color for elevation effects
    public static let shadow = Color("Shadow")
    
    // MARK: - Status Colors
    
    /// Success color for positive feedback
    public static let success = Color("Success")
    /// Error color for negative feedback
    public static let error = Color("Error")
    
    // MARK: - Gradient Colors
    
    /// Start color for gradients
    public static let gradientStart = Color("GradientStart")
    /// End color for gradients
    public static let gradientEnd = Color("GradientEnd")
    
    // MARK: - Gradient Presets
    
    /// Primary gradient used throughout the app
    public static let primaryGradient = LinearGradient(
        gradient: Gradient(colors: [gradientStart, gradientEnd]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// Subtle gradient for backgrounds
    public static let subtleGradient = LinearGradient(
        gradient: Gradient(colors: [
            background,
            gradientStart.opacity(0.05)
        ]),
        startPoint: .top,
        endPoint: .bottom
    )
    
    /// Accent gradient for buttons and highlights
    public static let accentGradient = LinearGradient(
        gradient: Gradient(colors: [accent, accent.opacity(0.8)]),
        startPoint: .top,
        endPoint: .bottom
    )
    
    // MARK: - Theme Extension
    
    /// Access colors through Color.theme namespace
    public static func setupTheme() {
        Color.theme = ColorTheme()
    }
}

/// Provides a namespace for colors through Color.theme
public struct ColorTheme {
    public let background = AppColors.background
    public let surface = AppColors.surface
    public let primary = AppColors.primary
    public let secondary = AppColors.secondary
    public let accent = AppColors.accent
    public let text = AppColors.text
    public let subtext = AppColors.subtext
    public let border = AppColors.border
    public let shadow = AppColors.shadow
    public let success = AppColors.success
    public let error = AppColors.error
    public let gradientStart = AppColors.gradientStart
    public let gradientEnd = AppColors.gradientEnd
    public let primaryGradient = AppColors.primaryGradient
    public let subtleGradient = AppColors.subtleGradient
    public let accentGradient = AppColors.accentGradient
}

/// Extension to allow access through Color.theme
public extension Color {
    static var theme: ColorTheme = ColorTheme()
}

// MARK: - Color Assets
// This was causing a redeclaration error - removed duplicate theme property
public extension Color {
    // static let theme = AppColors.self - removing duplicate declaration
}

// MARK: - Gradient Extensions
public extension LinearGradient {
    /// Primary gradient for backgrounds and buttons - updated to match landing page
    static let primary = LinearGradient(
        gradient: Gradient(colors: [AppColors.gradientStart, AppColors.gradientEnd]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// Accent gradient for highlights and CTAs - updated to match landing page
    static let accent = LinearGradient(
        gradient: Gradient(colors: [AppColors.accent, AppColors.accent.opacity(0.8)]),
        startPoint: .top,
        endPoint: .bottom
    )
    
    /// Primary button gradient - updated to match landing page
    static let primaryButton = LinearGradient(
        gradient: Gradient(colors: [AppColors.accent, AppColors.accent.opacity(0.9)]),
        startPoint: .leading,
        endPoint: .trailing
    )
    
    /// Creates a theme-aware gradient (different colors for light/dark mode)
    /// - Parameters:
    ///   - lightColors: Array of colors for light mode
    ///   - darkColors: Array of colors for dark mode
    ///   - startPoint: Gradient start point
    ///   - endPoint: Gradient end point
    /// - Returns: A theme-aware LinearGradient
    static func themeAware(
        lightColors: [Color],
        darkColors: [Color],
        startPoint: UnitPoint = .topLeading,
        endPoint: UnitPoint = .bottomTrailing
    ) -> LinearGradient {
        @Environment(\.colorScheme) var scheme
        let colors = scheme == .dark ? darkColors : lightColors
        
        return LinearGradient(
            gradient: Gradient(colors: colors),
            startPoint: startPoint,
            endPoint: endPoint
        )
    }
    
    /// Modern chrome-like gradient - added to match landing page
    static let chrome = LinearGradient(
        gradient: Gradient(colors: [
            Color.white.opacity(0.9),
            Color.gray.opacity(0.2),
            Color.white.opacity(0.7)
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// Dark mode chrome-like gradient
    static let darkChrome = LinearGradient(
        gradient: Gradient(colors: [
            Color.black.opacity(0.7),
            Color.gray.opacity(0.3),
            Color.black.opacity(0.8)
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// Theme-aware chrome gradient
    static var themeChrome: LinearGradient {
        @Environment(\.colorScheme) var scheme
        return scheme == .dark ? darkChrome : chrome
    }
}
