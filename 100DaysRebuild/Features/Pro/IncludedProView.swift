import SwiftUI

// MARK: - Included Pro View
//
// Post-funnel success screen showing Pro benefits and quick actions
// - Mirrors funnel visual design with FunnelHeroHeader
// - Shows "What you just got" benefits
// - Provides quick action cards for immediate next steps
// - Uses DS design system components throughout
// - Accessibility-first with proper labels and hints

/// Post-funnel screen showing Pro benefits and next steps
struct IncludedProView: View {
    @EnvironmentObject var analyticsService: AnalyticsService
    @EnvironmentObject var userSession: UserSession
    @State private var hasAppeared = false
    @State private var showConfetti = false

    var onDone: () -> Void

    init(onDone: @escaping () -> Void) {
        self.onDone = onDone
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    // Success hero
                    successHero
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : -12)
                        .animation(.easeOut(duration: 0.35), value: hasAppeared)

                    // What's included card
                    whatsIncludedCard
                        .padding(.horizontal, DS.Spacing.xl)
                        .padding(.top, DS.Spacing.lg)
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 12)
                        .animation(.easeOut(duration: 0.35).delay(0.1), value: hasAppeared)

                    // Quick actions section
                    quickActionsSection
                        .padding(.top, DS.Spacing.md)

                    // Primary CTA
                    CTAStack(
                        primaryTitle: "Let's go",
                        primaryAction: handleLetGo
                    )
                    .padding(.top, DS.Spacing.xl)
                }
                .padding(.bottom, DS.Spacing.xxl)
            }
            .background(DS.Colors.background.ignoresSafeArea())

            // Optional confetti overlay
            if showConfetti {
                SuccessConfettiOverlay()
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            analyticsService.trackEvent("pro_included_shown")

            withAnimation(.easeOut(duration: 0.35)) {
                hasAppeared = true
            }

            // Show confetti briefly
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                showConfetti = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                showConfetti = false
            }
        }
    }

    // MARK: - Success Hero

    private var successHero: some View {
        VStack(spacing: DS.Spacing.md) {
            // Success icon
            ZStack {
                Circle()
                    .fill(DS.Colors.success.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(DS.Colors.success)
            }
            .accessibilityLabel("Success")

            // Hero header
            FunnelHeroHeader(
                title: "Pro Included",
                subtitle: "Everything is unlocked. Let's build your streak."
            )
        }
    }

    // MARK: - What's Included Card

    private var whatsIncludedCard: some View {
        DS.Card(padding: DS.Spacing.lg) {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                // Section header
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "gift.fill")
                        .foregroundStyle(DS.Colors.accent)
                    Text("What's included")
                        .font(DS.Typo.title3)
                        .foregroundStyle(DS.Colors.onSurface)
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)

                Divider()
                    .padding(.vertical, DS.Spacing.xxs)

                // Benefits list
                benefitRow(icon: "nosign", text: "No ads, ever")
                benefitRow(icon: "checkmark.seal.fill", text: "All features unlocked")
                benefitRow(icon: "bolt.fill", text: "Priority updates")
                benefitRow(icon: "lock.shield.fill", text: "Privacy-first design")
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func benefitRow(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(DS.Typo.body)
            .foregroundStyle(DS.Colors.onSurface)
            .accessibilityLabel(text)
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Next steps")
                .font(DS.Typo.title3)
                .foregroundStyle(DS.Colors.onSurface)
                .padding(.horizontal, DS.Spacing.xl)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: DS.Spacing.sm) {
                QuickActionCard(
                    icon: "plus.circle.fill",
                    title: "Create your first challenge",
                    subtitle: "Start small. Consistency compounds."
                ) {
                    handleCreateChallenge()
                }

                QuickActionCard(
                    icon: "bell.badge.fill",
                    title: "Enable reminders",
                    subtitle: "Daily nudges keep streaks alive."
                ) {
                    handleEnableReminders()
                }

                QuickActionCard(
                    icon: "square.grid.2x2.fill",
                    title: "Pin the widget",
                    subtitle: "See progress at a glance."
                ) {
                    handlePinWidget()
                }
            }
            .padding(.horizontal, DS.Spacing.xl)
        }
        .opacity(hasAppeared ? 1 : 0)
        .animation(.easeOut(duration: 0.35).delay(0.2), value: hasAppeared)
    }

    // MARK: - Actions

    private func handleLetGo() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        analyticsService.trackEvent("pro_included_lets_go")
        onDone()
    }

    private func handleCreateChallenge() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        analyticsService.trackEvent("pro_included_create_challenge")

        // Navigate to create challenge
        // This would be handled by the parent view or router
        onDone()
    }

    private func handleEnableReminders() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        analyticsService.trackEvent("pro_included_enable_reminders")

        // Request notification permissions
        Task {
            await requestNotificationPermissions()
        }
    }

    private func handlePinWidget() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        analyticsService.trackEvent("pro_included_pin_widget")

        // Show widget instructions
        // This would typically open a modal or navigate to widget settings
        showWidgetInstructions()
    }

    private func requestNotificationPermissions() async {
        let center = UNUserNotificationCenter.current()
        do {
            try await center.requestAuthorization(options: [.alert, .badge, .sound])
            analyticsService.trackEvent("notifications_enabled")
        } catch {
            print("Error requesting notification permissions: \(error)")
        }
    }

    private func showWidgetInstructions() {
        // This would show a modal with widget setup instructions
        // For now, just track the event
        analyticsService.trackEvent("widget_instructions_shown")
    }
}

// MARK: - Preview

struct IncludedProView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Light mode
            IncludedProView {
                print("Done tapped")
            }
            .environmentObject(AnalyticsService.shared)
            .environmentObject(UserSession.shared)
            .preferredColorScheme(.light)

            // Dark mode
            IncludedProView {
                print("Done tapped")
            }
            .environmentObject(AnalyticsService.shared)
            .environmentObject(UserSession.shared)
            .preferredColorScheme(.dark)
        }
    }
}
