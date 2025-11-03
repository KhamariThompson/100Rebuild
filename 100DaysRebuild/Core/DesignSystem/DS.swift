import SwiftUI

/// DS - Design System namespace
/// Provides a unified interface to all design system tokens and components
/// Maps existing AppTypography, AppSpacing, and Color.theme to a clean DS.* namespace
public enum DS {

    // MARK: - Spacing

    /// Standard spacing values from AppSpacing
    public enum Spacing {
        public static let xxs: CGFloat = AppSpacing.xxs        // 4pt
        public static let xs: CGFloat = AppSpacing.xs          // 8pt
        public static let sm: CGFloat = AppSpacing.s           // 12pt
        public static let md: CGFloat = AppSpacing.m           // 16pt
        public static let lg: CGFloat = AppSpacing.l           // 20pt
        public static let xl: CGFloat = AppSpacing.xl          // 28pt
        public static let xxl: CGFloat = AppSpacing.xxl        // 40pt

        // Component-specific
        public static let cardPadding = AppSpacing.cardPadding
        public static let cardCornerRadius = AppSpacing.cardCornerRadius
        public static let sectionSpacing = AppSpacing.sectionSpacing
        public static let itemSpacing = AppSpacing.itemSpacing
        public static let screenHorizontal = AppSpacing.screenHorizontalPadding
    }

    // MARK: - Typography

    /// @deprecated Use AppTypography directly instead of DS.Typo
    /// DS.Typo is a legacy wrapper that will be removed in a future version.
    /// Migration: DS.Typo.body → AppTypography.body()
    @available(*, deprecated, message: "Use AppTypography directly. DS.Typo will be removed in a future version.")
    public enum Typo {
        // Display sizes
        public static let titleXL = AppTypography.largeTitle(.bold)      // 32pt bold
        public static let titleL = AppTypography.title1(.semibold)        // 28pt semibold
        public static let title2 = AppTypography.title2(.semibold)        // 22pt semibold
        public static let title3 = AppTypography.title3(.semibold)        // 20pt semibold

        // Body sizes
        public static let headline = AppTypography.headline(.semibold)    // 17pt semibold
        public static let body = AppTypography.body(.regular)             // 16pt regular
        public static let bodyMedium = AppTypography.body(.medium)        // 16pt medium
        public static let callout = AppTypography.callout(.regular)       // 15pt regular

        // Small sizes
        public static let subhead = AppTypography.subhead(.regular)       // 14pt regular
        public static let footnote = AppTypography.footnote(.regular)     // 13pt regular
        public static let caption1 = AppTypography.caption1(.regular)     // 12pt regular
        public static let caption2 = AppTypography.caption2(.regular)     // 11pt regular
        public static let overline = AppTypography.caption1(.semibold)    // 12pt semibold (for labels)

        // MARK: - Compatibility Aliases (for migration)

        /// Display size (largest - alias for titleXL)
        public static var displayS: Font {
            titleXL
        }
    }

    // MARK: - Colors

    /// Semantic colors from Color.theme
    public enum Colors {
        // Base colors
        public static let background = Color.theme.background
        public static let surface = Color.theme.surface
        public static let onSurface = Color.theme.text
        public static let onSurfaceSecondary = Color.theme.subtext

        // Brand colors
        public static let primary = Color.theme.primary
        public static let secondary = Color.theme.secondary
        public static let accent = Color.theme.accent
        public static let accentAlt = Color.theme.secondary

        // Status colors
        public static let success = Color.theme.success
        public static let error = Color.theme.error
        public static let warning = Color.orange // Adding warning color

        // Gradients
        public static let gradientA = Color.theme.gradientStart
        public static let gradientB = Color.theme.gradientEnd

        // Border & Shadow
        public static let border = Color.theme.border
        public static let shadow = Color.theme.shadow

        // MARK: - Compatibility Aliases (for migration)

        /// Secondary surface color (lighter variant)
        public static var surfaceSecondary: Color {
            surface.opacity(0.5)
        }

        /// Tertiary text color (lighter variant)
        public static var onSurfaceTertiary: Color {
            onSurfaceSecondary.opacity(0.6)
        }
    }

    // MARK: - Card Component

    /// Reusable card component with consistent styling
    public struct Card<Content: View>: View {
        let content: Content
        let padding: CGFloat
        let cornerRadius: CGFloat
        let shadowRadius: CGFloat

        public init(
            padding: CGFloat = DS.Spacing.md,
            cornerRadius: CGFloat = DS.Spacing.cardCornerRadius,
            shadowRadius: CGFloat = 6,
            @ViewBuilder content: () -> Content
        ) {
            self.content = content()
            self.padding = padding
            self.cornerRadius = cornerRadius
            self.shadowRadius = shadowRadius
        }

        public var body: some View {
            content
                .padding(padding)
                .background(DS.Colors.surface)
                .cornerRadius(cornerRadius)
                .shadow(color: DS.Colors.shadow.opacity(0.1), radius: shadowRadius, x: 0, y: 3)
        }
    }

    // MARK: - Badge Component

    /// Small badge/label component
    public struct Badge: View {
        let text: String
        let icon: String?

        public init(_ text: String, icon: String? = nil) {
            self.text = text
            self.icon = icon
        }

        public var body: some View {
            Label {
                Text(text)
                    .font(AppTypography.caption1())
            } icon: {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(AppTypography.caption2())
                }
            }
            .foregroundStyle(DS.Colors.onSurfaceSecondary)
        }
    }

    // MARK: - Icon Component

    /// Standard icon component with consistent sizing
    public struct Icon: View {
        let name: String
        let size: CGFloat
        let color: Color

        public init(_ name: String, size: CGFloat = 20, color: Color = DS.Colors.accent) {
            self.name = name
            self.size = size
            self.color = color
        }

        public var body: some View {
            Image(systemName: name)
                .font(AppTypography.font(size: size, weight: .regular))
                .foregroundStyle(color)
        }
    }

    // MARK: - Button Style Variants

    public enum ButtonStyleVariant {
        case primary
        case secondary
        case tertiary
    }
}

// MARK: - Button Style Extension

extension Button {
    /// Apply DS button style variant
    @MainActor
    public func ds(_ variant: DS.ButtonStyleVariant) -> some View {
        switch variant {
        case .primary:
            return AnyView(self.buttonStyle(AppPrimaryButtonStyle()))
        case .secondary:
            return AnyView(self.buttonStyle(AppSecondaryButtonStyle()))
        case .tertiary:
            return AnyView(self.buttonStyle(AppTextButtonStyle()))
        }
    }
}
