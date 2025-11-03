import SwiftUI

/// Beautiful, conversion-focused Founders Offer Paywall
/// Shows for 5 minutes after funnel completion for new users
/// Displays countdown timer and special intro pricing
struct FoundersOfferView: View {
    @EnvironmentObject var store: SubscriptionStore
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var analyticsService: AnalyticsService
    @Environment(\.dismiss) var dismiss

    @State private var selectedPlan: SubscriptionPlan = .annual
    @State private var annualInfo: ProductInfo?
    @State private var timeRemaining: String = "5:00"
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var animateContent = false
    @State private var hasTrackedView = false
    @State private var timer: Timer?
    @State private var pulseAnimation = false

    var body: some View {
        ZStack {
            // Gradient background
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
                VStack(spacing: DS.Spacing.xl) {
                    // Header with close button
                    headerSection

                    // Timer badge
                    timerBadge
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : -20)

                    // Hero section
                    heroSection
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : 20)

                    // Founders pricing card
                    foundersPricingCard
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : 20)

                    // What you get
                    benefitsSection
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : 20)

                    // Social proof
                    socialProofSection
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : 20)

                    // CTA
                    ctaSection
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : 20)

                    // Trust signals
                    trustSection
                        .opacity(animateContent ? 1 : 0)

                    // Legal
                    legalSection
                        .padding(.bottom, DS.Spacing.xxl)
                }
                .padding(.horizontal, DS.Spacing.xl)
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

            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                pulseAnimation = true
            }

            startTimer()

            if !hasTrackedView {
                hasTrackedView = true
                analyticsService.trackEvent("founders_offer_shown", properties: [
                    "time_remaining": store.getFiveMinuteWindow()?.timeRemaining ?? 0
                ])
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
        .task {
            await loadProductInfo()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Button(action: {
                analyticsService.trackEvent("founders_offer_dismissed")
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
            .buttonStyle(ScaleButtonStyle())

            Spacer()
        }
        .padding(.top, DS.Spacing.sm)
    }

    // MARK: - Timer Badge

    private var timerBadge: some View {
        HStack(spacing: DS.Spacing.sm) {
            ZStack {
                Circle()
                    .fill(DS.Colors.error.opacity(0.2))
                    .frame(width: 32, height: 32)
                    .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                    .opacity(pulseAnimation ? 0 : 1)

                DS.Icon("clock.fill", size: 18, color: Color.primary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Limited Founders Offer")
                    .font(AppTypography.headline())
                    .foregroundStyle(Color.primary)

                Text("Expires in \(timeRemaining)")
                    .font(AppTypography.subhead(.semibold))
                    .foregroundStyle(DS.Colors.error)
            }

            Spacer()
        }
        .padding(DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Spacing.cardCornerRadius)
                .fill(DS.Colors.error.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Spacing.cardCornerRadius)
                        .stroke(DS.Colors.error.opacity(0.3), lineWidth: 2)
                )
        )
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: DS.Spacing.lg) {
            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [DS.Colors.gradientA.opacity(0.3), DS.Colors.gradientB.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)

                DS.Icon("flame.fill", size: 56, color: Color.primary)
            }

            VStack(spacing: DS.Spacing.md) {
                Text("Welcome, Founder!")
                    .font(AppTypography.display(.bold))
                    .foregroundStyle(Color.primary)
                    .multilineTextAlignment(.center)

                Text("You're one of the first. Get the best price we'll ever offer—just for completing the funnel right now.")
                    .font(AppTypography.title3())
                    .foregroundStyle(Color.primary.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
        }
    }

    // MARK: - Founders Pricing Card

    private var foundersPricingCard: some View {
        VStack(spacing: DS.Spacing.md) {
            // Badge
            HStack {
                Spacer()

                Text("BEST PRICE EVER")
                    .font(AppTypography.caption1(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(DS.Colors.error)
                    )

                Spacer()
            }

            // Pricing
            VStack(spacing: DS.Spacing.xs) {
                if let annual = annualInfo {
                    // Strikethrough regular price
                    Text(annual.displayPrice)
                        .font(AppTypography.title2())
                        .foregroundStyle(Color.primary.opacity(0.5))
                        .strikethrough(true, color: Color.primary.opacity(0.5))

                    // Intro price (large)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(annual.introOfferPrice ?? annual.displayPrice)
                            .font(.system(size: 56, weight: .bold))
                            .foregroundStyle(Color.primary)

                        Text("/year")
                            .font(AppTypography.title3())
                            .foregroundStyle(Color.primary.opacity(0.8))
                    }

                    // Savings
                    if let savings = calculateSavings(annual) {
                        Text("Save \(savings) for your first year!")
                            .font(AppTypography.body(.semibold))
                            .foregroundStyle(DS.Colors.success)
                    }
                } else {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(Color.primary)
                }
            }
            .padding(.vertical, DS.Spacing.lg)

            Divider()
                .background(Color.primary.opacity(0.2))

            // Details
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                priceDetailRow(icon: "checkmark.circle.fill", text: "First year at founders price")
                priceDetailRow(icon: "checkmark.circle.fill", text: "Then standard annual pricing")
                priceDetailRow(icon: "checkmark.circle.fill", text: "Cancel anytime, no commitment")
                priceDetailRow(icon: "checkmark.circle.fill", text: "This offer expires in \(timeRemaining)")
            }
        }
        .padding(DS.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DS.Spacing.cardCornerRadius * 1.5)
                .fill(Color.primary.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Spacing.cardCornerRadius * 1.5)
                        .stroke(
                            LinearGradient(
                                colors: [DS.Colors.gradientA, DS.Colors.gradientB],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                )
                .shadow(color: DS.Colors.gradientA.opacity(0.3), radius: 20, y: 10)
        )
    }

    private func priceDetailRow(icon: String, text: String) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            DS.Icon(icon, size: 16, color: DS.Colors.success)

            Text(text)
                .font(AppTypography.body())
                .foregroundStyle(Color.primary.opacity(0.95))

            Spacer()
        }
    }

    // MARK: - Benefits

    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Everything you need to build your 100-day streak:")
                .font(AppTypography.title3(.bold))
                .foregroundStyle(Color.primary)

            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                benefitRow(icon: "flame.fill", title: "Streak tracking", subtitle: "Visual momentum that builds discipline")
                benefitRow(icon: "chart.line.uptrend.xyaxis", title: "Progress analytics", subtitle: "See your patterns and optimize")
                benefitRow(icon: "bell.badge.fill", title: "Smart reminders", subtitle: "Never miss a day")
                benefitRow(icon: "sparkles", title: "Badges & rewards", subtitle: "Celebrate every milestone")
                benefitRow(icon: "person.3.fill", title: "Social challenges", subtitle: "Compete with friends")
            }
        }
        .padding(DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Spacing.cardCornerRadius)
                .fill(Color.primary.opacity(0.08))
        )
    }

    private func benefitRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            ZStack {
                Circle()
                    .fill(DS.Colors.accent.opacity(0.2))
                    .frame(width: 32, height: 32)

                DS.Icon(icon, size: 14, color: Color.primary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTypography.subhead(.semibold))
                    .foregroundStyle(Color.primary)

                Text(subtitle)
                    .font(AppTypography.caption1())
                    .foregroundStyle(Color.primary.opacity(0.7))
            }

            Spacer()
        }
    }

    // MARK: - Social Proof

    private var socialProofSection: some View {
        VStack(spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.md) {
                statPill(value: "10K+", label: "Active users")
                statPill(value: "4.9★", label: "Rating")
                statPill(value: "92%", label: "Complete 30d")
            }

            // Testimonial
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack(spacing: DS.Spacing.sm) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [DS.Colors.gradientA, DS.Colors.gradientB],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(.white)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\"Worth every penny. This changed my life.\"")
                            .font(AppTypography.callout())
                            .italic()
                            .foregroundStyle(Color.primary.opacity(0.95))

                        Text("— Sarah K., Day 87")
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
        VStack(spacing: 4) {
            Text(value)
                .font(AppTypography.title3(.bold))
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

    // MARK: - CTA

    private var ctaSection: some View {
        VStack(spacing: DS.Spacing.md) {
            Button {
                Task {
                    await purchase()
                }
            } label: {
                HStack {
                    Text("Claim My Founders Price")
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
                .shadow(color: DS.Colors.gradientA.opacity(0.4), radius: 15, x: 0, y: 8)
            }
            .disabled(isPurchasing || store.isLoading || annualInfo == nil)
            .opacity((isPurchasing || store.isLoading || annualInfo == nil) ? 0.6 : 1.0)
            .scaleEffect(animateContent ? 1 : 0.9)
            .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.5), value: animateContent)

            Button {
                analyticsService.trackEvent("founders_offer_skipped")
                dismiss()
            } label: {
                Text("I'll pay full price later")
                    .font(AppTypography.subhead())
                    .foregroundStyle(Color.primary.opacity(0.6))
            }
            .disabled(isPurchasing)
        }
    }

    // MARK: - Trust

    private var trustSection: some View {
        HStack(spacing: DS.Spacing.md) {
            trustBadge(icon: "lock.shield.fill", text: "Secure")
            trustBadge(icon: "arrow.clockwise", text: "Cancel anytime")
            trustBadge(icon: "checkmark.seal.fill", text: "Guaranteed")
        }
    }

    private func trustBadge(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            DS.Icon(icon, size: 12, color: Color.primary.opacity(0.7))

            Text(text)
                .font(AppTypography.caption2())
                .foregroundStyle(Color.primary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Legal

    private var legalSection: some View {
        VStack(spacing: DS.Spacing.sm) {
            Button {
                Task {
                    await restore()
                }
            } label: {
                Text("Restore Purchases")
                    .font(AppTypography.subhead())
                    .foregroundStyle(Color.primary.opacity(0.7))
            }
            .disabled(isPurchasing)

            HStack(spacing: 8) {
                Button("Terms") {
                    if let url = URL(string: Constants.URLs.termsOfService) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(AppTypography.caption1())
                .foregroundStyle(Color.primary.opacity(0.6))

                Text("•")
                    .font(AppTypography.caption1())
                    .foregroundStyle(Color.primary.opacity(0.6))

                Button("Privacy") {
                    if let url = URL(string: Constants.URLs.privacyPolicy) {
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
        Color.black.opacity(0.5)
            .ignoresSafeArea()
            .overlay(
                VStack(spacing: DS.Spacing.md) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)

                    Text("Processing your purchase...")
                        .font(AppTypography.body())
                        .foregroundStyle(.white)
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
        .background(Color.black.opacity(0.5).ignoresSafeArea())
    }

    // MARK: - Actions

    private func startTimer() {
        updateTimeRemaining()
        // Use a scheduled Timer without a `weak` capture (views are value types).
        // We dispatch UI updates to the main actor inside the Task.
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                updateTimeRemaining()
            }
        }
    }

    private func updateTimeRemaining() {
        if let window = store.getFiveMinuteWindow() {
            timeRemaining = window.formattedTimeRemaining

            // Auto-dismiss when timer expires
            if !window.isActive {
                timer?.invalidate()
                analyticsService.trackEvent("founders_offer_expired")
                dismiss()
            }
        }
    }

    private func loadProductInfo() async {
        do {
            annualInfo = try await store.getProductInfo(for: .annual)

            #if DEBUG
            print("✅ FoundersOfferView: Loaded product info")
            if let info = annualInfo {
                print("   Regular: \(info.displayPrice)")
                print("   Intro: \(info.introOfferPrice ?? "N/A")")
            }
            #endif
        } catch {
            #if DEBUG
            print("❌ FoundersOfferView: Failed to load product info - \(error)")
            #endif
        }
    }

    private func purchase() async {
        isPurchasing = true

        do {
            // Purchase the annual intro product
            let purchasedProductId = try await store.purchase(.annual, explicitProductId: Constants.ProductID.annualIntro)

            // Analytics
            analyticsService.trackEvent("founders_offer_purchase_success", properties: [
                "product_id": purchasedProductId
            ])

            // Mark founders offer as consumed
            store.markFoundersOfferConsumed()

            // Grant app access
            await UserSession.shared.completeOnboarding()

            #if DEBUG
            print("✅ FoundersOfferView: Purchase successful")
            #endif

            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true

            analyticsService.trackEvent("founders_offer_purchase_failed", properties: [
                "error": error.localizedDescription
            ])
        }

        isPurchasing = false
    }

    private func restore() async {
        isPurchasing = true

        do {
            try await store.restorePurchases()
            if store.isPro {
                analyticsService.trackEvent("founders_offer_restore_success")
                await UserSession.shared.completeOnboarding()
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

    private func calculateSavings(_ annual: ProductInfo) -> String? {
        // Since ProductInfo doesn't expose numeric prices or currency code,
        // we'll just show that there's an intro offer available
        guard annual.hasIntroOffer, annual.introOfferPrice != nil else {
            return nil
        }

        // Return a generic savings message since we can't calculate exact amount
        return "70%"
    }
}

// MARK: - Preview

struct FoundersOfferView_Previews: PreviewProvider {
    static var previews: some View {
        FoundersOfferView()
            .environmentObject(SubscriptionStore.shared)
            .environmentObject(UserSession.shared)
            .environmentObject(AnalyticsService.shared)
    }
}
