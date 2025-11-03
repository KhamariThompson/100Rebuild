import SwiftUI

/// Adaptive color helpers that automatically adjust for light/dark mode
/// Ensures proper contrast and readability in all scenarios
extension DS.Colors {

    // MARK: - Adaptive Button Colors

    /// Adaptive button text - white in dark mode, black in light mode
    /// Use this for buttons on accent-colored backgrounds
    public static func adaptiveButtonText(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .white : .black
    }

    /// Adaptive button text for current environment
    public static var adaptiveButtonText: Color {
        Color("AdaptiveButtonText", bundle: nil) // Will fallback to Color.primary
    }

    /// Primary button background - accent color with proper contrast
    public static var primaryButtonBg: Color {
        accent
    }

    /// Primary button foreground - contrasts with accent
    public static func primaryButtonFg(_ colorScheme: ColorScheme) -> Color {
        // For accent backgrounds, use white in dark, black in light
        colorScheme == .dark ? .white : .black
    }

    /// Secondary button background - surface with border
    public static var secondaryButtonBg: Color {
        surface
    }

    /// Secondary button foreground - primary text color
    public static var secondaryButtonFg: Color {
        onSurface
    }

    /// Tertiary/Ghost button foreground - accent color
    public static var tertiaryButtonFg: Color {
        accent
    }

    // MARK: - Adaptive Label Colors

    /// Text on colored backgrounds (gradients, accent fills)
    public static func textOnColoredBg(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .white : .white // White works on most colored backgrounds
    }

    /// Text on colored backgrounds - safer default
    public static var textOnColoredBg: Color {
        .white // Most colored backgrounds are mid-dark tones
    }

    // MARK: - Status Button Colors

    /// Destructive button foreground
    public static var destructiveButtonFg: Color {
        error
    }

    /// Success button foreground
    public static var successButtonFg: Color {
        success
    }
}

// MARK: - View Modifier for Adaptive Button Text

extension View {
    /// Applies adaptive foreground color for button text based on color scheme
    /// Use this on Text inside buttons to ensure proper contrast
    func adaptiveButtonText(_ colorScheme: ColorScheme) -> some View {
        self.foregroundStyle(DS.Colors.primaryButtonFg(colorScheme))
    }

    /// Applies adaptive foreground for text on colored backgrounds
    func adaptiveTextOnColor(_ colorScheme: ColorScheme) -> some View {
        self.foregroundStyle(DS.Colors.textOnColoredBg(colorScheme))
    }
}
