import SwiftUI

/// SSOT Paywall view - the ONLY paywall in the app
/// Shows monthly and annual plans with honest intro pricing
struct PaywallView: View {
    @EnvironmentObject var store: SubscriptionStore
    @Environment(\.dismiss) var dismiss

    @State private var selectedPlan: SubscriptionPlan = .annual
    @State private var monthlyInfo: ProductInfo?
    @State private var annualInfo: ProductInfo?
    @State private var isAnnualIntroEligible = false
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        ZStack {
            DS.Colors.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: DS.Spacing.xl) {
                    // Header
                    headerSection

                    // Welcome offer banner (if active)
                    if shouldShowIntroBanner {
                        introBanner
                    }

                    // Benefits
                    benefitsSection

                    // Plans
                    plansSection

                    // Purchase button
                    purchaseButton

                    // Legal & restore
                    legalSection
                }
                .padding(DS.Spacing.lg)
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
        .task {
            await loadProductInfo()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: DS.Spacing.md) {
            DS.Icon("crown.fill", size: 48, color: DS.Colors.accent)

            Text("Unlock Pro")
                .font(DS.Typo.titleXL)
                .foregroundStyle(DS.Colors.onSurface)

            Text("Get full access to all features and unlimited usage")
                .font(DS.Typo.body)
                .foregroundStyle(DS.Colors.onSurfaceSecondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Intro Banner

    private var shouldShowIntroBanner: Bool {
        guard isAnnualIntroEligible else { return false }
        guard let window = store.getFiveMinuteWindow() else { return false }
        return window.isActive
    }

    private var introBanner: some View {
        HStack(spacing: DS.Spacing.sm) {
            DS.Icon("sparkles", size: 16, color: DS.Colors.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text("Welcome offer applied")
                    .font(DS.Typo.subhead.weight(.semibold))
                    .foregroundStyle(DS.Colors.accent)

                if let window = store.getFiveMinuteWindow() {
                    Text("Expires in \(window.formattedTimeRemaining)")
                        .font(DS.Typo.caption1)
                        .foregroundStyle(DS.Colors.onSurfaceSecondary)
                }
            }

            Spacer()
        }
        .padding(DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Spacing.cardCornerRadius)
                .fill(DS.Colors.accent.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Spacing.cardCornerRadius)
                        .stroke(DS.Colors.accent.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Benefits

    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            benefitRow(icon: "checkmark.circle.fill", text: "Track unlimited challenges")
            benefitRow(icon: "chart.xyaxis.line", text: "Advanced progress analytics")
            benefitRow(icon: "photo.stack", text: "Unlimited photo uploads")
            benefitRow(icon: "calendar.badge.clock", text: "Complete history access")
            benefitRow(icon: "lock.shield.fill", text: "Premium themes & customization")
        }
        .padding(DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Spacing.cardCornerRadius)
                .fill(DS.Colors.surface)
        )
    }

    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            DS.Icon(icon, size: 20, color: DS.Colors.success)

            Text(text)
                .font(DS.Typo.body)
                .foregroundStyle(DS.Colors.onSurface)

            Spacer()
        }
    }

    // MARK: - Plans

    private var plansSection: some View {
        VStack(spacing: DS.Spacing.md) {
            // Annual plan
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

    private var shouldShowIntroPricing: Bool {
        guard isAnnualIntroEligible else { return false }
        guard let window = store.getFiveMinuteWindow() else { return false }
        return window.isActive
    }

    // MARK: - Purchase Button

    private var purchaseButton: some View {
        Button {
            Task {
                await purchase()
            }
        } label: {
            HStack {
                Text("Continue")
                    .font(DS.Typo.headline)

                if isPurchasing {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.8)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(DS.Spacing.md)
            .background(DS.Colors.accent)
            .clipShape(RoundedRectangle(cornerRadius: DS.Spacing.cardCornerRadius))
        }
        .disabled(isPurchasing || store.isLoading)
        .opacity(isPurchasing || store.isLoading ? 0.6 : 1.0)
        .accessibilityLabel("Continue with \(selectedPlan.displayName) plan")
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
                    .font(DS.Typo.subhead)
                    .foregroundStyle(DS.Colors.onSurfaceSecondary)
            }
            .disabled(isPurchasing)

            VStack(spacing: DS.Spacing.xs) {
                Text("Subscription auto-renews unless cancelled.")
                    .font(DS.Typo.caption1)
                    .foregroundStyle(DS.Colors.onSurfaceTertiary)
                    .multilineTextAlignment(.center)

                HStack(spacing: DS.Spacing.xs) {
                    Button("Terms") {
                        // Open terms
                    }
                    .font(DS.Typo.caption1)
                    .foregroundStyle(DS.Colors.onSurfaceTertiary)

                    Text("•")
                        .font(DS.Typo.caption1)
                        .foregroundStyle(DS.Colors.onSurfaceTertiary)

                    Button("Privacy") {
                        // Open privacy
                    }
                    .font(DS.Typo.caption1)
                    .foregroundStyle(DS.Colors.onSurfaceTertiary)
                }
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
                        .tint(.white)

                    Text("Processing...")
                        .font(DS.Typo.body)
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
                    .font(DS.Typo.body)
                    .foregroundStyle(DS.Colors.onSurface)
                    .multilineTextAlignment(.center)

                Button {
                    showError = false
                } label: {
                    Text("OK")
                        .font(DS.Typo.headline)
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

            print("✅ PaywallView: Loaded product info")
            print("   Intro eligible: \(isAnnualIntroEligible)")
            if let window = store.getFiveMinuteWindow() {
                print("   Window active: \(window.isActive)")
            }
        } catch {
            print("❌ PaywallView: Failed to load product info - \(error)")
        }
    }

    private func purchase() async {
        isPurchasing = true

        do {
            try await store.purchase(selectedPlan)
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
}

// MARK: - Preview

struct PaywallView_Previews: PreviewProvider {
    static var previews: some View {
        PaywallView()
            .environmentObject(SubscriptionStore(repository: RevenueCatSubscriptionRepository()))
    }
}
