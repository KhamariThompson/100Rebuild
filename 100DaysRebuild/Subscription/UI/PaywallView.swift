import SwiftUI

/// Gate state for founders offer selection
struct FoundersGateState {
    let windowActive: Bool
    let introEligible: Bool
    let foundersConsumed: Bool
    let campaignLive: Bool

    /// Determine if user should see annual intro product
    var shouldShowIntroProduct: Bool {
        windowActive && introEligible && !foundersConsumed && campaignLive
    }
}

/// Extensive, conversion-focused paywall - everyone needs Pro to use the app
/// No feature comparison needed since there's no free tier
struct PaywallView: View {
    @EnvironmentObject var store: SubscriptionStore
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var analyticsService: AnalyticsService
    @Environment(\.dismiss) var dismiss

    @State private var selectedPlan: SubscriptionPlan = .annual
    @State private var monthlyInfo: ProductInfo?
    @State private var annualInfo: ProductInfo?
    @State private var isAnnualIntroEligible = false
    @State private var foundersGate: FoundersGateState?
    @State private var selectedAnnualProductId: String?
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var animateContent = false
    @State private var hasTrackedView = false

    var body: some View {
        ZStack {
            // Background gradient that adapts to light/dark mode
            LinearGradient(
                colors: [
                    DS.Colors.gradientA,
                    DS.Colors.gradientB
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: DS.Spacing.xxl) {
                    // Header with Close and Log out buttons
                    headerSection

                    // Hero section
                    heroSection
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : 20)

                    // Social proof
                    socialProofSection
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : 20)

                    // Transformation promise
                    transformationSection
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : 20)

                    // Pricing
                    pricingSection
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : 20)

                    // CTA
                    ctaSection
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : 20)

                    // Trust signals
                    trustSection
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : 20)

                    // Legal & restore
                    legalSection
                }
                .padding(DS.Spacing.xl)
            }

            // Loading overlay
            if isPurchasing {
                loadingOverlay
            }

            // Error alert
            if showError {
                errorAlert
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                animateContent = true
            }

            // Compute founders gate state with server-backed check
            Task {
                let fw = store.getFiveMinuteWindow()

                // Check server for founder's offer consumption (prevents reinstall exploit)
                let serverConsumed = await store.hasConsumedFoundersOfferServer()

                // Conservative offline rule: if server check fails, don't show offer
                let consumed: Bool
                if let serverConsumed = serverConsumed {
                    consumed = serverConsumed
                } else {
                    // Offline/error: fall back to NOT showing offer (conservative)
                    consumed = true
                    print("⚠️ PaywallView: Unable to verify founders offer server state - defaulting to consumed for safety")
                }

                foundersGate = FoundersGateState(
                    windowActive: fw?.isActive ?? false,
                    introEligible: isAnnualIntroEligible,
                    foundersConsumed: consumed,
                    campaignLive: Constants.FoundersCampaign.isLive
                )

                // Determine which annual product to show based on server-validated state
                selectedAnnualProductId = foundersGate?.shouldShowIntroProduct == true
                    ? Constants.ProductID.annualIntro
                    : Constants.ProductID.annualNoIntro
            }

            // Track paywall view with detailed analytics (only once)
            if !hasTrackedView {
                hasTrackedView = true
                analyticsService.trackEvent("paywall_shown", properties: [
                    "offering": "current",  // TODO: capture actual offering ID if available
                    "product_id_shown": selectedAnnualProductId ?? "unknown",
                    "selected_plan": selectedPlan.rawValue,
                    "window_active": foundersGate?.windowActive ?? false,
                    "intro_eligible": foundersGate?.introEligible ?? false,
                    "founders_consumed": foundersGate?.foundersConsumed ?? false,
                    "campaign_live": foundersGate?.campaignLive ?? false
                ])
            }
        }
        .task {
            await loadProductInfo()
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(alignment: .center, spacing: 0) {
            // Close button (top-left) - clean minimal design
            Button(action: {
                dismiss()
            }) {
                ZStack {
                    Circle()
                        .fill(Color.primary.opacity(0.12))
                        .frame(width: 36, height: 36)

                    Image(systemName: "xmark")
                        .font(AppTypography.subhead(.semibold))
                        .foregroundStyle(Color.primary.opacity(0.95))
                }
            }
            .buttonStyle(PaywallScaleButtonStyle())

            Spacer()

            // Log out button (top-right) - elegant capsule
            Button(action: {
                Task {
                    await handleLogout()
                }
            }) {
                HStack(spacing: 5) {
                    Text("Log out")
                        .font(AppTypography.subhead(.medium))
                    Image(systemName: "arrow.right.circle.fill")
                        .font(AppTypography.subhead())
                }
                .foregroundStyle(Color.primary.opacity(0.95))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.primary.opacity(0.12))
                )
            }
            .buttonStyle(PaywallScaleButtonStyle())
            .disabled(isPurchasing)
            .opacity(isPurchasing ? 0.5 : 1.0)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: DS.Spacing.lg) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.2))
                    .frame(width: 100, height: 100)

                DS.Icon("flame.fill", size: 48, color: Color.primary)
            }

            VStack(spacing: DS.Spacing.md) {
                Text("100 Days Changes Everything")
                    .font(AppTypography.largeTitle(.bold))
                    .foregroundStyle(Color.primary)
                    .multilineTextAlignment(.center)

                Text("This isn't just another habit app.\nIt's a commitment system that actually works.")
                    .font(AppTypography.body())
                    .foregroundStyle(Color.primary.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
        }
    }

    // MARK: - Social Proof

    private var socialProofSection: some View {
        VStack(spacing: DS.Spacing.md) {
            // Stats
            HStack(spacing: DS.Spacing.lg) {
                statPill(value: "10K+", label: "Active users")
                statPill(value: "4.9★", label: "App rating")
                statPill(value: "92%", label: "Finish Day 30")
            }

            // Testimonial with profile picture
            VStack(spacing: DS.Spacing.sm) {
                HStack(alignment: .top, spacing: DS.Spacing.sm) {
                    // Profile picture
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [DS.Colors.gradientA, DS.Colors.gradientB],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.white)
                        )

                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        Text("\"I've tried everything. This is the only thing that stuck. The daily check-in accountability is powerful.\"")
                            .font(AppTypography.callout())
                            .italic()
                            .foregroundStyle(Color.primary.opacity(0.95))
                            .lineSpacing(2)

                        Text("— Marcus T., completed 3 challenges")
                            .font(AppTypography.caption1())
                            .foregroundStyle(Color.primary.opacity(0.7))
                    }
                }
            }
            .padding(DS.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DS.Spacing.cardCornerRadius)
                    .fill(Color.primary.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Spacing.cardCornerRadius)
                            .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }

    private func statPill(value: String, label: String) -> some View {
        VStack(spacing: DS.Spacing.xxs) {
            Text(value)
                .font(AppTypography.title2(.bold))
                .foregroundStyle(Color.primary)

            Text(label)
                .font(AppTypography.caption2())
                .foregroundStyle(Color.primary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DS.Spacing.cardCornerRadius)
                .fill(Color.primary.opacity(0.15))
        )
    }

    // MARK: - Transformation

    private var transformationSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("What you're really getting:")
                .font(AppTypography.title3(.bold))
                .foregroundStyle(Color.primary)

            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                transformationPoint(
                    icon: "checkmark.shield.fill",
                    text: "Proven accountability system"
                )
                transformationPoint(
                    icon: "chart.line.uptrend.xyaxis",
                    text: "Data-driven insights on your patterns"
                )
                transformationPoint(
                    icon: "bell.badge.fill",
                    text: "Smart reminders that actually work"
                )
                transformationPoint(
                    icon: "sparkles",
                    text: "Visual streak system that builds momentum"
                )
                transformationPoint(
                    icon: "heart.fill",
                    text: "Personalized to your commitment"
                )
            }
        }
        .padding(DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Spacing.cardCornerRadius)
                .fill(Color.primary.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Spacing.cardCornerRadius)
                        .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private func transformationPoint(icon: String, text: String) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            DS.Icon(icon, size: 18, color: Color.primary.opacity(0.9))

            Text(text)
                .font(AppTypography.body())
                .foregroundStyle(Color.primary.opacity(0.95))

            Spacer()
        }
    }

    // MARK: - Pricing

    private var pricingSection: some View {
        VStack(spacing: DS.Spacing.sm) {
            // Welcome offer banner
            if shouldShowIntroBanner {
                introBanner
            }

            // Annual plan (recommended)
            PriceOptionRow(
                plan: .annual,
                isSelected: selectedPlan == .annual,
                productInfo: annualInfo,
                showIntroOffer: shouldShowIntroPricing
            ) {
                selectedPlan = .annual
            }

            // Monthly plan
            PriceOptionRow(
                plan: .monthly,
                isSelected: selectedPlan == .monthly,
                productInfo: monthlyInfo,
                showIntroOffer: false
            ) {
                selectedPlan = .monthly
            }
        }
    }

    private var shouldShowIntroBanner: Bool {
        guard isAnnualIntroEligible else { return false }
        guard let window = store.getFiveMinuteWindow() else { return false }
        return window.isActive
    }

    private var shouldShowIntroPricing: Bool {
        foundersGate?.shouldShowIntroProduct ?? false
    }

    private var introBanner: some View {
        HStack(spacing: DS.Spacing.sm) {
            DS.Icon("clock.fill", size: 16, color: Color.primary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Limited welcome offer")
                    .font(AppTypography.subhead(.semibold))
                    .foregroundStyle(Color.primary)

                if let window = store.getFiveMinuteWindow() {
                    Text("Expires in \(window.formattedTimeRemaining)")
                        .font(AppTypography.caption1())
                        .foregroundStyle(Color.primary.opacity(0.8))
                }
            }

            Spacer()
        }
        .padding(DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Spacing.cardCornerRadius)
                .fill(Color.primary.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Spacing.cardCornerRadius)
                        .stroke(Color.primary.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - CTA

    private var ctaSection: some View {
        VStack(spacing: DS.Spacing.md) {
            Button {
                Task {
                    await purchase()
                }
            } label: {
                HStack {
                    Text("Start My 100 Days")
                        .font(AppTypography.headline())
                        .foregroundStyle(.white)

                    if isPurchasing {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(DS.Spacing.md)
                .background(
                    LinearGradient(
                        colors: [DS.Colors.gradientA, DS.Colors.gradientB],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: DS.Spacing.cardCornerRadius))
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
            }
            .disabled(isPurchasing || store.isLoading)
            .opacity(isPurchasing || store.isLoading ? 0.6 : 1.0)
            .scaleEffect(animateContent ? 1 : 0.9)
            .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.5), value: animateContent)

            Text("Subscription auto-renews. Cancel anytime.")
                .font(AppTypography.caption1())
                .foregroundStyle(Color.primary.opacity(0.7))
        }
    }

    // MARK: - Trust

    private var trustSection: some View {
        VStack(spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.md) {
                trustBadge(icon: "lock.shield.fill", text: "Secure payment")
                trustBadge(icon: "arrow.clockwise", text: "Cancel anytime")
                trustBadge(icon: "checkmark.seal.fill", text: "Money-back")
            }
        }
    }

    private func trustBadge(icon: String, text: String) -> some View {
        HStack(spacing: DS.Spacing.xxs) {
            DS.Icon(icon, size: 12, color: Color.primary.opacity(0.7))

            Text(text)
                .font(AppTypography.caption2())
                .foregroundStyle(Color.primary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Legal

    private var legalSection: some View {
        VStack(spacing: DS.Spacing.md) {
            Button {
                Task {
                    await restore()
                }
            } label: {
                Text("Restore Purchases")
                    .font(AppTypography.subhead())
                    .foregroundStyle(Color.primary.opacity(0.8))
            }
            .disabled(isPurchasing)

            HStack(spacing: DS.Spacing.xs) {
                Button("Terms") {
                    if let url = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
                        UIApplication.shared.open(url)
                    }
                }
                .font(AppTypography.caption1())
                .foregroundStyle(Color.primary.opacity(0.6))

                Text("•")
                    .font(AppTypography.caption1())
                    .foregroundStyle(Color.primary.opacity(0.6))

                Button("Privacy") {
                    if let url = URL(string: "https://100days.site/privacy") {
                        UIApplication.shared.open(url)
                    }
                }
                .font(AppTypography.caption1())
                .foregroundStyle(Color.primary.opacity(0.6))
            }
        }
    }

    // MARK: - Loading & Error

    private var loadingOverlay: some View {
        Color.black.opacity(0.4)
            .ignoresSafeArea()
            .overlay(
                VStack(spacing: DS.Spacing.md) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(Color.primary)

                    Text("Processing...")
                        .font(AppTypography.body())
                        .foregroundStyle(Color.primary)
                }
            )
    }

    private var errorAlert: some View {
        VStack(spacing: DS.Spacing.lg) {
            Spacer()

            VStack(spacing: DS.Spacing.md) {
                DS.Icon("exclamationmark.triangle.fill", size: 40, color: DS.Colors.error)

                Text(errorMessage)
                    .font(AppTypography.body())
                    .foregroundStyle(DS.Colors.onSurface)
                    .multilineTextAlignment(.center)

                Button {
                    showError = false
                } label: {
                    Text("OK")
                        .font(AppTypography.headline())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(DS.Spacing.sm)
                        .background(DS.Colors.accent)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Spacing.cardCornerRadius))
                }
            }
            .padding(DS.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DS.Spacing.cardCornerRadius)
                    .fill(DS.Colors.surface)
            )
            .padding(DS.Spacing.xl)

            Spacer()
        }
        .background(Color.black.opacity(0.4).ignoresSafeArea())
    }

    // MARK: - Actions

    private func loadProductInfo() async {
        do {
            monthlyInfo = try await store.getProductInfo(for: .monthly)
            annualInfo = try await store.getProductInfo(for: .annual)
            isAnnualIntroEligible = await store.isIntroEligible(for: .annual)

            #if DEBUG
            print("✅ PaywallView: Loaded product info")
            print("   Intro eligible: \(isAnnualIntroEligible)")
            if let window = store.getFiveMinuteWindow() {
                print("   Window active: \(window.isActive)")
            }
            #endif
        } catch {
            #if DEBUG
            print("❌ PaywallView: Failed to load product info - \(error)")
            #endif
        }
    }

    private func purchase() async {
        isPurchasing = true

        do {
            // Determine which product ID to purchase
            let explicitProductId: String? = selectedPlan == .annual ? selectedAnnualProductId : nil

            // Perform purchase
            let purchasedProductId = try await store.purchase(selectedPlan, explicitProductId: explicitProductId)

            // Analytics: track purchase success
            analyticsService.trackEvent("purchase_success", properties: [
                "product_id": purchasedProductId,
                "was_intro": (purchasedProductId == Constants.ProductID.annualIntro)
            ])

            // Mark founders offer as consumed if they purchased the intro product (persists to server)
            if purchasedProductId == Constants.ProductID.annualIntro {
                await store.markFoundersOfferConsumed()
                print("✅ PaywallView: Marked founders offer as consumed and persisted to server")
            }

            // CRITICAL: Only grant app access after successful Pro purchase
            await UserSession.shared.completeOnboarding()
            #if DEBUG
            print("✅ PaywallView: Purchase successful - granted app access")
            #endif

            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isPurchasing = false
    }

    private func restore() async {
        isPurchasing = true

        do {
            try await store.restorePurchases()
            if store.isPro {
                // Analytics: track restore success
                analyticsService.trackEvent("restore_success", properties: [:])

                // CRITICAL: Grant app access after successful restore
                await UserSession.shared.completeOnboarding()
                #if DEBUG
                print("✅ PaywallView: Restore successful - granted app access")
                #endif

                dismiss()
            } else {
                errorMessage = "No previous purchases found"
                showError = true
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isPurchasing = false
    }

    private func handleLogout() async {
        isPurchasing = true

        // Sign out the user and route back to auth
        await userSession.signOutWithoutThrowing()

        isPurchasing = false
        dismiss()
    }
}

// MARK: - Button Style

struct PaywallScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Preview

struct PaywallView_Previews: PreviewProvider {
    static var previews: some View {
        PaywallView()
            .environmentObject(SubscriptionStore.shared)
    }
}
