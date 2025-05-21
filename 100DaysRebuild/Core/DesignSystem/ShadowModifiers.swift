import SwiftUI

/// Shadow style definitions used across the app
public enum ShadowStyle {
    /// Subtle shadow for subtle elevation of UI elements
    case subtle
    /// Standard shadow for cards and containers
    case standard
    /// Elevated shadow for floating elements
    case elevated
    /// Strong shadow for modal dialogs and popovers
    case strong
    /// Custom shadow with specific parameters
    case custom(radius: CGFloat, y: CGFloat, opacity: Double)
    
    /// Shadow radius based on the style
    public func radius(_ colorScheme: ColorScheme? = nil) -> CGFloat {
        switch self {
        case .subtle:
            return AppColors.shadowRadiusForTheme(light: 3, dark: 5, colorScheme: colorScheme)
        case .standard:
            return AppColors.shadowRadiusForTheme(light: 6, dark: 8, colorScheme: colorScheme)
        case .elevated:
            return AppColors.shadowRadiusForTheme(light: 8, dark: 12, colorScheme: colorScheme)
        case .strong:
            return AppColors.shadowRadiusForTheme(light: 12, dark: 16, colorScheme: colorScheme)
        case .custom(let radius, _, _):
            return radius
        }
    }
    
    /// Shadow y-offset based on the style
    public func yOffset(_ colorScheme: ColorScheme? = nil) -> CGFloat {
        switch self {
        case .subtle:
            return AppColors.shadowRadiusForTheme(light: 1, dark: 2, colorScheme: colorScheme)
        case .standard:
            return AppColors.shadowRadiusForTheme(light: 2, dark: 3, colorScheme: colorScheme)
        case .elevated:
            return AppColors.shadowRadiusForTheme(light: 4, dark: 5, colorScheme: colorScheme)
        case .strong:
            return AppColors.shadowRadiusForTheme(light: 6, dark: 8, colorScheme: colorScheme)
        case .custom(_, let y, _):
            return y
        }
    }
    
    /// Shadow opacity based on the style
    public func opacity(_ colorScheme: ColorScheme? = nil) -> Double {
        switch self {
        case .subtle:
            return AppColors.opacityForTheme(light: 0.03, dark: 0.08, colorScheme: colorScheme)
        case .standard:
            return AppColors.opacityForTheme(light: 0.06, dark: 0.12, colorScheme: colorScheme)
        case .elevated:
            return AppColors.opacityForTheme(light: 0.08, dark: 0.16, colorScheme: colorScheme)
        case .strong:
            return AppColors.opacityForTheme(light: 0.12, dark: 0.22, colorScheme: colorScheme)
        case .custom(_, _, let opacity):
            return opacity
        }
    }
}

/// View modifier for applying theme-aware shadows
struct ThemeAwareShadowModifier: ViewModifier {
    let style: ShadowStyle
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .shadow(
                color: Color.theme.shadow.opacity(style.opacity(colorScheme)),
                radius: style.radius(colorScheme),
                x: 0,
                y: style.yOffset(colorScheme)
            )
    }
}

// Extension to apply theme-aware shadows to SwiftUI views
public extension View {
    /// Apply a theme-aware shadow with predefined style
    func themeShadow(_ style: ShadowStyle = .standard) -> some View {
        self.modifier(ThemeAwareShadowModifier(style: style))
    }
    
    /// Apply a card shadow - commonly used for card containers
    func cardShadow() -> some View {
        self.themeShadow(.standard)
    }
    
    /// Apply a button shadow - commonly used for buttons
    func buttonShadow() -> some View {
        self.themeShadow(.subtle)
    }
    
    /// Apply a modal shadow - commonly used for modals and sheets
    func modalShadow() -> some View {
        self.themeShadow(.strong)
    }
} 