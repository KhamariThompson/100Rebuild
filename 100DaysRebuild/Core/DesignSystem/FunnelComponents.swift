import SwiftUI

// MARK: - Funnel Hero Header

/// Hero header for funnel screens with gradient background
public struct FunnelHeroHeader: View {
    let title: String
    let subtitle: String
    @Environment(\.colorScheme) private var colorScheme

    public init(title: String, subtitle: String) {
        self.title = title
        self.subtitle = subtitle
    }

    public var body: some View {
        VStack(spacing: 16) {
            // Enhanced title with consistent typography
            Text(title)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(DS.Colors.accent)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .accessibilityLabel(title)
                .accessibilityAddTraits(.isHeader)

            Text(subtitle)
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(DS.Colors.onSurface.opacity(0.75))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, DS.Spacing.xl)
        .padding(.horizontal, 24)
    }
}

// MARK: - Benefit Model

/// Represents a single benefit/feature
public struct Benefit: Identifiable {
    public let id = UUID()
    public let icon: String
    public let title: String
    public let caption: String

    public init(icon: String, title: String, caption: String) {
        self.icon = icon
        self.title = title
        self.caption = caption
    }
}

// MARK: - Benefits Grid

/// Grid display of benefits with icons and descriptions
public struct BenefitsGrid: View {
    let benefits: [Benefit]
    @State private var hasAppeared = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    public init(benefits: [Benefit]) {
        self.benefits = benefits
    }

    private var columns: [GridItem] {
        let columnCount = horizontalSizeClass == .regular ? 3 : 2
        return Array(repeating: GridItem(.flexible(), spacing: DS.Spacing.md), count: columnCount)
    }

    public var body: some View {
        LazyVGrid(columns: columns, spacing: DS.Spacing.md) {
            ForEach(Array(benefits.enumerated()), id: \.element.id) { index, benefit in
                benefitCard(benefit)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 12)
                    .animation(
                        .easeOut(duration: 0.35)
                            .delay(Double(index) * 0.04),
                        value: hasAppeared
                    )
            }
        }
        .padding(.horizontal, DS.Spacing.xl)
        .onAppear {
            hasAppeared = true
        }
    }

    @ViewBuilder
    private func benefitCard(_ benefit: Benefit) -> some View {
        DS.Card(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                // Icon with gradient background
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [DS.Colors.accent.opacity(0.15), DS.Colors.accent.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)

                    DS.Icon(benefit.icon, size: 20, color: DS.Colors.accent)
                }

                // Text content with enhanced typography
                VStack(alignment: .leading, spacing: 6) {
                    Text(benefit.title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(DS.Colors.onSurface)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(benefit.caption)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(DS.Colors.onSurfaceSecondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minHeight: 120)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(benefit.title). \(benefit.caption)")
    }
}

// MARK: - Funnel Progress Bar

/// Progress indicator showing current step
public struct FunnelProgressBar: View {
    let current: Int
    let total: Int
    @Environment(\.colorScheme) private var colorScheme

    public init(current: Int, total: Int) {
        self.current = current
        self.total = total
    }

    private var progress: CGFloat {
        guard total > 0 else { return 0 }
        return CGFloat(current) / CGFloat(total)
    }

    public var body: some View {
        VStack(spacing: 12) {
            // Progress percentage and step text
            HStack {
                Text("Step \(current) of \(total)")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(DS.Colors.onSurfaceSecondary)

                Spacer()

                Text("\(Int(progress * 100))%")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(DS.Colors.accent)
            }
            .padding(.horizontal, 24)

            // Enhanced progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track with gradient
                    Capsule()
                        .fill(DS.Colors.onSurface.opacity(0.08))

                    // Progress fill with gradient and glow
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [DS.Colors.accent, DS.Colors.accent.opacity(0.85)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, progress * geometry.size.width))
                        .shadow(color: DS.Colors.accent.opacity(0.3), radius: 4, x: 0, y: 2)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: current)
                }
            }
            .frame(height: 10)
            .padding(.horizontal, 24)
        }
        .accessibilityLabel("Step \(current) of \(total)")
        .accessibilityValue("\(Int(progress * 100)) percent complete")
    }
}

// MARK: - CTA Stack

/// Primary and optional secondary action buttons
public struct CTAStack: View {
    let primaryTitle: String
    let primaryAction: () -> Void
    var secondaryTitle: String?
    var secondaryAction: (() -> Void)?

    public init(
        primaryTitle: String,
        primaryAction: @escaping () -> Void,
        secondaryTitle: String? = nil,
        secondaryAction: (() -> Void)? = nil
    ) {
        self.primaryTitle = primaryTitle
        self.primaryAction = primaryAction
        self.secondaryTitle = secondaryTitle
        self.secondaryAction = secondaryAction
    }

    public var body: some View {
        VStack(spacing: 12) {
            // Enhanced primary button
            Button(action: primaryAction) {
                Text(primaryTitle)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        ZStack {
                            LinearGradient(
                                colors: [DS.Colors.accent, DS.Colors.accent.opacity(0.85)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )

                            // Subtle shine effect
                            LinearGradient(
                                colors: [Color.white.opacity(0.15), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: DS.Colors.accent.opacity(0.4), radius: 12, x: 0, y: 6)
                    .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
            }
            .accessibilityHint("Primary action")

            // Optional enhanced secondary button
            if let secondaryTitle = secondaryTitle,
               let secondaryAction = secondaryAction {
                Button(action: secondaryAction) {
                    Text(secondaryTitle)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(DS.Colors.accent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(DS.Colors.accent.opacity(0.3), lineWidth: 1.5)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(DS.Colors.accent.opacity(0.06))
                                )
                        )
                }
                .accessibilityHint("Secondary action")
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }
}

// MARK: - Trust Section

/// Trust indicators (privacy, no ads, etc.)
public struct TrustSection: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    public init() {}

    public var body: some View {
        if horizontalSizeClass == .compact {
            VStack(spacing: DS.Spacing.xs) {
                trustBadge(icon: "lock.shield", text: "Privacy-first")
                trustBadge(icon: "nosign", text: "No ads")
                trustBadge(icon: "checkmark.seal", text: "Cancel anytime")
            }
        } else {
            HStack(spacing: DS.Spacing.lg) {
                trustBadge(icon: "lock.shield", text: "Privacy-first")
                trustBadge(icon: "nosign", text: "No ads")
                trustBadge(icon: "checkmark.seal", text: "Cancel anytime")
            }
        }
    }

    @ViewBuilder
    private func trustBadge(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(AppTypography.footnote())
            .foregroundStyle(DS.Colors.onSurfaceSecondary)
            .padding(.horizontal, DS.Spacing.xl)
    }
}

// MARK: - Meta Footnote

/// Small legal/informational text at bottom
public struct MetaFootnote: View {
    let text: String

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .font(AppTypography.footnote())
            .foregroundStyle(DS.Colors.onSurfaceSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.bottom, DS.Spacing.xl)
    }
}

// MARK: - Success Confetti Overlay (Optional)

/// Subtle celebratory animation on completion
public struct SuccessConfettiOverlay: View {
    @State private var isAnimating = false

    public init() {}

    public var body: some View {
        ZStack {
            ForEach(0..<12, id: \.self) { index in
                Circle()
                    .fill(randomColor())
                    .frame(width: 8, height: 8)
                    .offset(
                        x: isAnimating ? randomOffset() : 0,
                        y: isAnimating ? randomOffset() : 0
                    )
                    .opacity(isAnimating ? 0 : 1)
                    .animation(
                        .easeOut(duration: 1.2)
                            .delay(Double(index) * 0.05),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }

    private func randomColor() -> Color {
        [DS.Colors.accent, DS.Colors.success, DS.Colors.primary, DS.Colors.secondary].randomElement() ?? DS.Colors.accent
    }

    private func randomOffset() -> CGFloat {
        CGFloat.random(in: -100...100)
    }
}

// MARK: - Quick Action Card

/// Card for post-funnel quick actions
public struct QuickActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    public init(icon: String, title: String, subtitle: String, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            DS.Card(padding: DS.Spacing.md) {
                HStack(spacing: DS.Spacing.md) {
                    // Icon
                    DS.Icon(icon, size: 28, color: DS.Colors.accent)

                    // Content
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(AppTypography.headline())
                            .foregroundStyle(DS.Colors.onSurface)

                        Text(subtitle)
                            .font(AppTypography.subhead())
                            .foregroundStyle(DS.Colors.onSurfaceSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Chevron
                    Image(systemName: "chevron.right")
                        .font(AppTypography.subhead(.semibold))
                        .foregroundStyle(DS.Colors.onSurfaceSecondary)
                }
            }
        }
        .buttonStyle(AppScaleButtonStyle())
        .accessibilityLabel("\(title). \(subtitle)")
        .accessibilityHint("Tap to \(title.lowercased())")
    }
}
