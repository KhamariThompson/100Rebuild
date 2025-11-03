import SwiftUI
import FirebaseAuth

/// A settings section showing legacy user grace period countdown
/// Displayed only for users who registered before Jan 1, 2026 and are in their 1-year grace period
struct LegacyGraceSection: View {
    @StateObject private var migrationManager = MigrationManager.shared
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @State private var daysRemaining: Int = 0
    @State private var gracePeriodEnd: Date?
    @State private var isInGracePeriod: Bool = false

    var body: some View {
        Group {
            if isInGracePeriod {
                SettingsSection(title: "Legacy Access", icon: "gift.fill") {
                    SettingsCard {
                        VStack(alignment: .leading, spacing: AppSpacing.m) {
                            // Header with crown icon
                            HStack(spacing: AppSpacing.xs) {
                                Image(systemName: "crown.fill")
                                    .font(AppTypography.title2())
                                    .foregroundColor(.yellow)

                                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                                    Text("Thank You, Early Supporter!")
                                        .font(AppTypography.headline())
                                        .foregroundColor(.theme.text)

                                    Text("You're a valued founding member")
                                        .font(AppTypography.caption1())
                                        .foregroundColor(.theme.subtext)
                                }
                            }
                            .padding(.bottom, AppSpacing.xxs)

                            Divider()

                            // Grace period info
                            VStack(alignment: .leading, spacing: AppSpacing.s) {
                                Text("As an early user who joined before our paid launch, you've been granted **1 year of free Pro access** as our way of saying thank you.")
                                    .font(AppTypography.subhead())
                                    .foregroundColor(.theme.text)
                                    .fixedSize(horizontal: false, vertical: true)

                                // Countdown display
                                HStack(spacing: AppSpacing.xs) {
                                    Image(systemName: "clock.fill")
                                        .font(AppTypography.body())
                                        .foregroundColor(.theme.accent)

                                    if daysRemaining > 0 {
                                        Text("**\(daysRemaining) days** remaining")
                                            .font(AppTypography.subhead())
                                            .foregroundColor(.theme.text)
                                    } else {
                                        Text("Grace period ending soon")
                                            .font(AppTypography.subhead())
                                            .foregroundColor(.orange)
                                    }
                                }
                                .padding(.vertical, AppSpacing.xs)
                                .padding(.horizontal, AppSpacing.s)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.theme.accent.opacity(0.1))
                                )

                                if let endDate = gracePeriodEnd {
                                    Text("Your free access ends on **\(endDate.formatted(date: .long, time: .omitted))**")
                                        .font(AppTypography.caption1())
                                        .foregroundColor(.theme.subtext)
                                }
                            }

                            Divider()

                            // What happens next
                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                HStack(spacing: AppSpacing.xxs) {
                                    Image(systemName: "info.circle.fill")
                                        .font(AppTypography.subhead())
                                        .foregroundColor(.theme.accent)

                                    Text("What happens after?")
                                        .font(AppTypography.caption1().bold())
                                        .foregroundColor(.theme.text)
                                }

                                Text("After your grace period ends, you'll need an active Pro subscription to continue using the app. We hope you'll choose to stay with us!")
                                    .font(AppTypography.caption1())
                                    .foregroundColor(.theme.subtext)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.top, AppSpacing.xxs)
                        }
                        .padding(.vertical, AppSpacing.xs)
                    }
                }
            }
        }
        .onAppear {
            loadGracePeriodInfo()
        }
        .onChange(of: subscriptionStore.state) { _ in
            loadGracePeriodInfo()
        }
    }

    private func loadGracePeriodInfo() {
        isInGracePeriod = migrationManager.isInLegacyGracePeriod()
        daysRemaining = migrationManager.daysRemainingInGracePeriod()
        gracePeriodEnd = migrationManager.legacyUserGracePeriodEnd
    }
}

// MARK: - Preview

struct LegacyGraceSection_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Preview with grace period active
            ScrollView {
                LegacyGraceSection()
                    .padding()
            }
            .background(Color.theme.background)
            .previewDisplayName("With Grace Period")

            // Preview in dark mode
            ScrollView {
                LegacyGraceSection()
                    .padding()
            }
            .background(Color.theme.background)
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")
        }
    }
}
