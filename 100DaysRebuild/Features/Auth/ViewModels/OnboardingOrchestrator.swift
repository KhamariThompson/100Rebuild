import SwiftUI
import Combine

/// Orchestrates the complete onboarding flow for new users
///
/// Flow:
/// 1. User signs in/up
/// 2. Migration check (legacy vs new)
/// 3. If new: Funnel (8 questions) → Founder's Paywall
/// 4. If legacy: Show grace period banner → Main app
/// 5. Everyone gets full app access (no more free tier)
@MainActor
class OnboardingOrchestrator: ObservableObject {
    static let shared = OnboardingOrchestrator()

    @Published var currentStep: OnboardingStep = .loading
    @Published var migrationInfo: MigrationInfo?
    @Published var showGracePeriodBanner: Bool = false

    private var cancellables = Set<AnyCancellable>()

    private let migrationManager = MigrationManager.shared
    private let analyticsService = AnalyticsService.shared

    // MARK: - Onboarding Steps

    enum OnboardingStep: Equatable {
        case loading
        case migration
        case funnel
        case paywall
        case completed
        case error(Error)

        static func == (lhs: OnboardingStep, rhs: OnboardingStep) -> Bool {
            switch (lhs, rhs) {
            case (.loading, .loading),
                 (.migration, .migration),
                 (.funnel, .funnel),
                 (.paywall, .paywall),
                 (.completed, .completed):
                return true
            case (.error(let lhsError), .error(let rhsError)):
                return lhsError.localizedDescription == rhsError.localizedDescription
            default:
                return false
            }
        }
    }

    // MARK: - Public Methods

    /// Start onboarding for authenticated user
    func startOnboarding(for userId: String) async {
        currentStep = .migration

        await analyticsService.trackEvent("onboarding_started", properties: ["user_id": userId])

        do {
            // Perform migration check
            try await migrationManager.checkAndMigrate(for: userId)

            // Get migration info
            let info = try await migrationManager.getMigrationInfo(for: userId)

            self.migrationInfo = info
            self.determineNextStep(info: info)
        } catch {
            self.currentStep = .error(error)

            await analyticsService.trackEvent("onboarding_error", properties: [
                "error": error.localizedDescription
            ])
        }
    }

    /// Complete funnel and move to paywall
    func completeFunnel() {
        Task {
            await analyticsService.trackEvent("onboarding_funnel_completed")
        }

        withAnimation {
            currentStep = .paywall
        }
    }

    /// Complete paywall (subscription purchased)
    func completePaywall() {
        Task {
            await analyticsService.trackEvent("onboarding_paywall_completed")
        }

        withAnimation {
            currentStep = .completed
        }
    }

    /// Skip to main app (for legacy users)
    func skipToMainApp() {
        Task {
            await analyticsService.trackEvent("onboarding_skipped_legacy")
        }

        withAnimation {
            currentStep = .completed
        }
    }

    /// Reset onboarding (for testing)
    func reset() {
        currentStep = .loading
        migrationInfo = nil
        showGracePeriodBanner = false
    }

    // MARK: - Private Methods

    private func determineNextStep(info: MigrationInfo) {
        switch info.userType {
        case .legacyFree:
            // Legacy user with active grace period - skip to app with banner
            showGracePeriodBanner = true
            currentStep = .completed

            Task {
                await analyticsService.trackEvent("onboarding_legacy_user", properties: [
                    "days_remaining": info.daysRemaining
                ])
            }

        case .newUser:
            // New user - start funnel
            currentStep = .funnel

            Task {
                await analyticsService.trackEvent("onboarding_new_user")
            }

        case .legacyExpired:
            // Legacy grace period expired - show paywall
            currentStep = .paywall

            Task {
                await analyticsService.trackEvent("onboarding_legacy_expired")
            }
        }
    }

    /// Check if user should see grace period reminder
    func shouldShowGracePeriodReminder() -> Bool {
        guard let info = migrationInfo,
              info.isLegacyUser,
              info.daysRemaining > 0,
              info.daysRemaining <= 30 else {
            return false
        }
        return true
    }

    /// Get grace period message for banner
    func gracePeriodMessage() -> String {
        guard let info = migrationInfo else {
            return ""
        }

        let days = info.daysRemaining

        if days <= 7 {
            return "⚠️ Your free Pro access ends in \(days) days"
        } else if days <= 14 {
            return "Your free Pro access ends in \(days) days"
        } else {
            return "You have \(days) days of free Pro access remaining"
        }
    }
}

// MARK: - Onboarding Flow View

/// Main orchestrator view that shows the correct screen based on onboarding step
struct OnboardingFlowOrchestrator: View {
    @StateObject private var orchestrator = OnboardingOrchestrator.shared
    @EnvironmentObject var userSession: UserSession

    var onComplete: () -> Void

    var body: some View {
        ZStack {
            switch orchestrator.currentStep {
            case .loading:
                loadingView

            case .migration:
                loadingView
                    .onAppear {
                        Task {
                            if let userId = userSession.currentUser?.uid {
                                await orchestrator.startOnboarding(for: userId)
                            }
                        }
                    }

            case .funnel:
                ImprovedFunnelView {
                    orchestrator.completeFunnel()
                }
                .transition(.move(edge: .trailing))

            case .paywall:
                // Show founders offer if 5-minute window is active, otherwise regular paywall
                Group {
                    if let window = SubscriptionStore.shared.getFiveMinuteWindow(), window.isActive {
                        FoundersOfferView()
                            .onDisappear {
                                orchestrator.completePaywall()
                            }
                    } else {
                        PaywallView()
                            .onDisappear {
                                orchestrator.completePaywall()
                            }
                    }
                }
                .transition(.move(edge: .trailing))

            case .completed:
                // Show completion animation then dismiss
                completionView
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            onComplete()
                        }
                    }

            case .error(let error):
                errorView(error)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: orchestrator.currentStep)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        ZStack {
            DS.Colors.background.ignoresSafeArea()

            VStack(spacing: DS.Spacing.lg) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(DS.Colors.accent)

                Text("Setting up your account...")
                    .font(AppTypography.body())
                    .foregroundStyle(DS.Colors.onSurfaceSecondary)
            }
        }
    }

    // MARK: - Completion View

    private var completionView: some View {
        ZStack {
            DS.Colors.background.ignoresSafeArea()

            VStack(spacing: DS.Spacing.lg) {
                // Success checkmark
                ZStack {
                    Circle()
                        .fill(DS.Colors.success.opacity(0.2))
                        .frame(width: 100, height: 100)

                    Image(systemName: "checkmark")
                        .font(AppTypography.display(.bold))
                        .foregroundStyle(DS.Colors.success)
                }

                Text("You're all set!")
                    .font(AppTypography.title1())
                    .foregroundStyle(DS.Colors.onSurface)

                Text("Let's start building your streak")
                    .font(AppTypography.body())
                    .foregroundStyle(DS.Colors.onSurfaceSecondary)
            }
        }
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Error View

    @ViewBuilder
    private func errorView(_ error: Error) -> some View {
        ZStack {
            DS.Colors.background.ignoresSafeArea()

            VStack(spacing: DS.Spacing.lg) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(AppTypography.font(size: 50, weight: .bold))
                    .foregroundStyle(DS.Colors.error)

                Text("Something went wrong")
                    .font(AppTypography.title1())
                    .foregroundStyle(DS.Colors.onSurface)

                Text(error.localizedDescription)
                    .font(AppTypography.body())
                    .foregroundStyle(DS.Colors.onSurfaceSecondary)
                    .multilineTextAlignment(.center)

                Button(action: {
                    Task {
                        if let userId = userSession.currentUser?.uid {
                            await orchestrator.startOnboarding(for: userId)
                        }
                    }
                }) {
                    Text("Try Again")
                        .font(AppTypography.body(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(DS.Spacing.md)
                        .background(DS.Colors.accent)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Spacing.cardCornerRadius))
                }
                .padding(.horizontal, DS.Spacing.xl)
            }
            .padding(.horizontal, DS.Spacing.xl)
        }
    }
}

// MARK: - Grace Period Banner

/// Banner shown to legacy users reminding them of grace period
struct GracePeriodBannerView: View {
    @StateObject private var orchestrator = OnboardingOrchestrator.shared
    @State private var showBanner = false

    var body: some View {
        VStack(spacing: 0) {
            if showBanner && orchestrator.shouldShowGracePeriodReminder() {
                banner
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                showBanner = true
            }
        }
    }

    private var banner: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(DS.Colors.accent)

            Text(orchestrator.gracePeriodMessage())
                .font(AppTypography.subhead())
                .foregroundStyle(DS.Colors.onSurface)

            Spacer()

            Button(action: {
                withAnimation {
                    showBanner = false
                }
            }) {
                Image(systemName: "xmark")
                    .foregroundStyle(DS.Colors.onSurfaceSecondary)
                    .font(AppTypography.caption1(.bold))
            }
        }
        .padding(DS.Spacing.md)
        .background(
            Rectangle()
                .fill(DS.Colors.accent.opacity(0.15))
        )
    }
}

// MARK: - Preview

struct OnboardingFlowOrchestrator_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingFlowOrchestrator {
            print("Onboarding completed")
        }
        .environmentObject(UserSession.shared)
        .environmentObject(AnalyticsService.shared)
        .environmentObject(SubscriptionStore.shared)
        .environmentObject(EntitlementsAdapter.shared)
    }
}
