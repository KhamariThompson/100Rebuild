import SwiftUI

/// Core Design System Colors
/// Use through AppColors namespace for consistent styling
public enum AppColors {
    // MARK: - Primary Semantic Colors
    
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
    
    // MARK: - Additional Semantic Colors
    
    /// Gradient start color for backgrounds and elements
    public static let gradientStart = Color("GradientStart")
    /// Gradient end color for backgrounds and elements
    public static let gradientEnd = Color("GradientEnd")
    /// Subtle border color for cards and inputs
    public static let border = Color("Border")
    /// Shadow color for elevated elements
    public static let shadow = Color("Shadow")
    /// Tab bar inactive items - ensures visibility in both light/dark modes
    public static let tabInactive = Color("ProjectAccent").opacity(0.5)
    
    // MARK: - Extended Semantic Colors
    
    /// Color for destructive actions
    public static let destructive = Color("Error")
    /// Color for warning states
    public static let warning = Color("Warning")
    /// Color for informational states
    public static let info = Color("Info")
    /// Subtle background for disabled elements
    public static let disabledBackground = Color("DisabledBackground")
    /// Text color for disabled elements
    public static let disabledText = Color("DisabledText")
    /// Overlay color for modal backgrounds
    public static let modalOverlay = Color.black.opacity(0.4)
    /// Muted background for secondary content
    public static let secondaryBackground = Color("SecondaryBackground")
    
    // MARK: - Component-Specific Colors
    
    /// Background for input fields
    public static let inputBackground = Color("Surface")
    /// Border for input fields
    public static let inputBorder = Color("Border")
    /// Background for primary buttons
    public static let buttonBackground = Color("ProjectAccent")
    /// Text color for primary buttons
    public static let buttonText = Color.white
    /// Background for secondary buttons
    public static let secondaryButtonBackground = Color("SecondaryBackground")
    /// Text color for secondary buttons
    public static let secondaryButtonText = Color("Text")
    
    // MARK: - Fallback Colors
    
    // These are used if the asset catalog colors aren't loaded properly
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
    public static let fallbackTabInactive = Color.gray.opacity(0.7)
    public static let fallbackWarning = Color.yellow
    public static let fallbackInfo = Color.blue
    public static let fallbackDisabledBackground = Color.gray.opacity(0.2)
    public static let fallbackDisabledText = Color.gray
    public static let fallbackSecondaryBackground = Color(.tertiarySystemBackground)
    
    // MARK: - Theme-Specific Color Helpers
    
    /// Get the appropriate color based on the current color scheme
    /// - Parameters:
    ///   - light: Color to use in light mode
    ///   - dark: Color to use in dark mode
    ///   - colorScheme: Current color scheme (optional)
    /// - Returns: Color appropriate for the current theme
    public static func forTheme(light: Color, dark: Color, colorScheme: ColorScheme? = nil) -> Color {
        if let scheme = colorScheme {
            return scheme == .dark ? dark : light
        } else {
            @Environment(\.colorScheme) var currentScheme
            return currentScheme == .dark ? dark : light
        }
    }
    
    /// Get an opacity appropriate for the current theme
    /// - Parameters:
    ///   - light: Opacity to use in light mode
    ///   - dark: Opacity to use in dark mode
    ///   - colorScheme: Current color scheme (optional)
    /// - Returns: Opacity appropriate for the current theme
    public static func opacityForTheme(light: Double, dark: Double, colorScheme: ColorScheme? = nil) -> Double {
        if let scheme = colorScheme {
            return scheme == .dark ? dark : light
        } else {
            @Environment(\.colorScheme) var currentScheme
            return currentScheme == .dark ? dark : light
        }
    }
    
    /// Get shadow radius appropriate for the current theme
    /// - Parameters:
    ///   - light: Radius for light mode
    ///   - dark: Radius for dark mode
    ///   - colorScheme: Current color scheme (optional)
    /// - Returns: Shadow radius for the current theme
    public static func shadowRadiusForTheme(light: CGFloat, dark: CGFloat, colorScheme: ColorScheme? = nil) -> CGFloat {
        if let scheme = colorScheme {
            return scheme == .dark ? dark : light
        } else {
            @Environment(\.colorScheme) var currentScheme
            return currentScheme == .dark ? dark : light
        }
    }
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
    
    /// Primary button gradient
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
}
