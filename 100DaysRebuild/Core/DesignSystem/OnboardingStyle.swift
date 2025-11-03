import SwiftUI

/// OnboardingStyle - Unified design tokens for onboarding and funnel screens
/// Ensures consistent gradients, typography, spacing, and button hierarchy across:
/// - WelcomeView
/// - ReadyToCommitView
/// - Funnel/Paywall flows
public enum OnboardingStyle {

    // MARK: - Gradients

    public enum Gradient {
        /// Primary brand gradient for hero cards and CTAs
        public static let primary = LinearGradient(
            gradient: SwiftUI.Gradient(colors: [
                DS.Colors.gradientA,
                DS.Colors.gradientA.opacity(0.85),
                DS.Colors.gradientB
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// Surface gradient for page backgrounds
        public static let surface = LinearGradient(
            gradient: SwiftUI.Gradient(colors: [
                DS.Colors.background,
                DS.Colors.background.opacity(0.95),
                DS.Colors.surface.opacity(0.3)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )

        /// Subtle card background gradient
        public static let card = LinearGradient(
            gradient: SwiftUI.Gradient(colors: [
                DS.Colors.surface.opacity(0.8),
                DS.Colors.surface
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Spacing

    public enum Spacing {
        /// Horizontal page padding
        public static let pagePadding: CGFloat = 20

        /// Spacing between sections
        public static let section: CGFloat = 16

        /// Large spacing (between major blocks)
        public static let large: CGFloat = 24

        /// Extra large spacing (page vertical padding)
        public static let xLarge: CGFloat = 32

        /// Hero card internal padding
        public static let heroCardPadding: CGFloat = 24
    }

    // MARK: - Typography Helpers

    public enum Typography {
        /// Main page title
        public static let title = AppTypography.largeTitle(.bold)

        /// Subtitle / description text
        public static let subtitle = AppTypography.title1(.semibold)

        /// Body text
        public static let body = AppTypography.body(.regular)

        /// CTA button text
        public static let cta = AppTypography.headline(.semibold)

        /// Small footnote text
        public static let footnote = AppTypography.footnote(.regular)

        /// Feature row title (medium weight)
        public static func featureTitle(_ text: String) -> some View {
            Text(text)
                .font(AppTypography.headline())
                .foregroundStyle(DS.Colors.onSurface)
        }

        /// Feature row subtitle
        public static func featureSubtitle(_ text: String) -> some View {
            Text(text)
                .font(AppTypography.footnote())
                .foregroundStyle(DS.Colors.onSurfaceSecondary)
        }
    }

    // MARK: - Button Components

    public enum Buttons {
        /// Primary CTA button
        public static func primary(_ title: String, action: @escaping () -> Void) -> some View {
            Button(action: action) {
                Text(title)
                    .font(AppTypography.headline())
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .foregroundColor(.white)
            }
            .background(DS.Colors.accent)
            .cornerRadius(14)
            .shadow(color: DS.Colors.shadow.opacity(0.3), radius: 8, x: 0, y: 4)
        }

        /// Secondary button (outlined style)
        public static func secondary(_ title: String, action: @escaping () -> Void) -> some View {
            Button(action: action) {
                Text(title)
                    .font(AppTypography.headline())
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .foregroundColor(DS.Colors.onSurface)
            }
            .background(DS.Colors.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(DS.Colors.border, lineWidth: 1.5)
            )
            .cornerRadius(14)
        }

        /// Tertiary text-only button
        public static func tertiary(_ title: String, action: @escaping () -> Void) -> some View {
            Button(action: action) {
                Text(title)
                    .font(AppTypography.callout())
                    .fontWeight(.medium)
                    .foregroundColor(DS.Colors.accent)
            }
        }
    }

    // MARK: - Layout Components

    /// Full-screen page background
    public static func pageBackground() -> some View {
        OnboardingStyle.Gradient.surface
            .ignoresSafeArea()
    }

    /// Hero card with gradient background
    public static func heroCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.section, content: content)
            .padding(Spacing.heroCardPadding)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Gradient.primary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: DS.Colors.shadow.opacity(0.2), radius: 12, x: 0, y: 6)
    }

    /// Standard content card
    public static func contentCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.section, content: content)
            .padding(Spacing.section)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Gradient.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(DS.Colors.border.opacity(0.3), lineWidth: 1)
            )
    }
}
