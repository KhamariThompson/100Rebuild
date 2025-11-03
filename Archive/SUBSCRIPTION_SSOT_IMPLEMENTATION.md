# 🎯 Subscription SSOT Implementation Guide

## Overview

This document provides the complete implementation for refactoring the 100Days app to use a Single Source of Truth (SSOT) subscription system with RevenueCat.

## ✅ What's Been Created

### Domain Models (COMPLETED)
- ✅ `Subscription/Domain/SubscriptionPlan.swift` - Enum with ONLY 2 plans (monthly, annual)
- ✅ `Subscription/Domain/Entitlement.swift` - Single "pro" entitlement
- ✅ `Subscription/Domain/SubscriptionStatus.swift` - Status enum (notPurchased, active, grandfathered, expired)
- ✅ `Subscription/Domain/SubscriptionState.swift` - Complete UI state

### Data Layer (COMPLETED)
- ✅ `Subscription/Data/SubscriptionRepository.swift` - Protocol defining operations
- ✅ `Subscription/Data/RevenueCatSubscriptionRepository.swift` - RC implementation with intro eligibility

## 📋 Remaining Files to Create

### 1. Service Layer

#### `Subscription/Service/FiveMinuteWindow.swift`
```swift
import Foundation

/// Manages the 5-minute welcome offer window
struct FiveMinuteWindow: Codable {
    let start: Date

    var isActive: Bool {
        Date().timeIntervalSince(start) < 5 * 60
    }

    var timeRemaining: TimeInterval {
        let elapsed = Date().timeIntervalSince(start)
        return max(0, 5 * 60 - elapsed)
    }

    static func start() -> FiveMinuteWindow {
        FiveMinuteWindow(start: Date())
    }
}
```

#### `Subscription/Service/SubscriptionStore.swift`
```swift
import Foundation
import SwiftUI
import FirebaseAuth

/// SSOT ObservableObject for subscription state
@MainActor
final class SubscriptionStore: ObservableObject {
    @Published private(set) var state: SubscriptionState = .default
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var error: Error?

    private let repository: SubscriptionRepository
    private var fiveMinuteWindow: FiveMinuteWindow?

    init(repository: SubscriptionRepository) {
        self.repository = repository
    }

    // MARK: - Public API

    var isPro: Bool {
        state.isPro
    }

    func load() async {
        isLoading = true
        error = nil

        do {
            // Check grandfathered status first
            if let userId = Auth.auth().currentUser?.uid {
                let isGrandfathered = try await repository.checkGrandfatheredStatus(userId: userId)

                if isGrandfathered {
                    state = .grandfathered
                    isLoading = false
                    return
                }
            }

            // Load normal status
            let status = try await repository.loadStatus()
            updateState(with: status)
        } catch {
            self.error = error
            print("❌ Failed to load subscription: \(error)")
        }

        isLoading = false
    }

    func purchase(_ plan: SubscriptionPlan) async throws {
        isLoading = true
        error = nil

        do {
            let status = try await repository.purchase(plan)
            updateState(with: status)
        } catch {
            self.error = error
            isLoading = false
            throw error
        }

        isLoading = false
    }

    func restorePurchases() async throws {
        isLoading = true
        error = nil

        do {
            let status = try await repository.restorePurchases()
            updateState(with: status)
        } catch {
            self.error = error
            isLoading = false
            throw error
        }

        isLoading = false
    }

    func refreshEntitlements() async {
        do {
            let status = try await repository.refreshEntitlements()
            updateState(with: status)
        } catch {
            print("⚠️ Failed to refresh entitlements: \(error)")
        }
    }

    func isIntroEligible(for plan: SubscriptionPlan) async -> Bool {
        return await repository.isIntroEligible(for: plan)
    }

    func getProductInfo(for plan: SubscriptionPlan) async throws -> ProductInfo {
        return try await repository.getProductInfo(for: plan)
    }

    func startFiveMinuteWindow() {
        fiveMinuteWindow = .start()
        saveFiveMinuteWindow()
    }

    func getFiveMinuteWindow() -> FiveMinuteWindow? {
        if fiveMinuteWindow == nil {
            loadFiveMinuteWindow()
        }
        return fiveMinuteWindow
    }

    // MARK: - Private

    private func updateState(with status: SubscriptionStatus) {
        let isPaywallRequired = !status.isPro
        state = SubscriptionState(status: status, isPaywallRequired: isPaywallRequired)
    }

    private func saveFiveMinuteWindow() {
        if let window = fiveMinuteWindow,
           let data = try? JSONEncoder().encode(window) {
            UserDefaults.standard.set(data, forKey: "five_minute_window")
        }
    }

    private func loadFiveMinuteWindow() {
        if let data = UserDefaults.standard.data(forKey: "five_minute_window"),
           let window = try? JSONDecoder().decode(FiveMinuteWindow.self, from: data) {
            fiveMinuteWindow = window
        }
    }
}

// MARK: - Helper

func requirePro(_ store: SubscriptionStore) -> Bool {
    return store.isPro
}
```

### 2. UI Layer

#### `Subscription/UI/PaywallView.swift`
```swift
import SwiftUI

/// SSOT Paywall view - the ONLY paywall in the app
struct PaywallView: View {
    @EnvironmentObject var store: SubscriptionStore
    @Environment(\.dismiss) var dismiss

    @State private var selectedPlan: SubscriptionPlan = .annual
    @State private var monthlyInfo: ProductInfo?
    @State private var annualInfo: ProductInfo?
    @State private var isAnnualIntroEligible = false
    @State private var isPurchasing = false

    var body: some View {
        ZStack {
            DS.Colors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    // Header
                    headerSection

                    // Benefits
                    benefitsSection

                    // Plans
                    plansSection

                    // Purchase button
                    purchaseButton

                    // Legal
                    legalSection
                }
                .padding(DS.Spacing.lg)
            }

            if isPurchasing {
                loadingOverlay
            }
        }
        .task {
            await loadProductInfo()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: DS.Spacing.md) {
            Text("Unlock Pro")
                .font(DS.Typo.titleXL)
                .foregroundStyle(DS.Colors.onSurface)

            Text("Get full access to all features")
                .font(DS.Typo.body)
                .foregroundStyle(DS.Colors.onSurfaceSecondary)
                .multilineTextAlignment(.center)
        }
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
            Image(systemName: icon)
                .foregroundStyle(DS.Colors.accent)
                .font(.system(size: 20))

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
                showIntroOffer: isAnnualIntroEligible && (store.getFiveMinuteWindow()?.isActive ?? false)
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

    // MARK: - Purchase Button

    private var purchaseButton: some View {
        Button {
            Task {
                await purchase()
            }
        } label: {
            Text("Continue")
                .font(DS.Typo.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(DS.Spacing.md)
                .background(DS.Colors.accent)
                .clipShape(RoundedRectangle(cornerRadius: DS.Spacing.cardCornerRadius))
        }
        .disabled(isPurchasing || store.isLoading)
    }

    // MARK: - Legal

    private var legalSection: some View {
        VStack(spacing: DS.Spacing.sm) {
            Button("Restore Purchases") {
                Task {
                    await restore()
                }
            }
            .font(DS.Typo.caption1)
            .foregroundStyle(DS.Colors.onSurfaceSecondary)

            Text("Auto-renews unless cancelled. Terms apply.")
                .font(DS.Typo.caption1)
                .foregroundStyle(DS.Colors.onSurfaceSecondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Loading

    private var loadingOverlay: some View {
        Color.black.opacity(0.3)
            .ignoresSafeArea()
            .overlay(
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
            )
    }

    // MARK: - Actions

    private func loadProductInfo() async {
        do {
            monthlyInfo = try await store.getProductInfo(for: .monthly)
            annualInfo = try await store.getProductInfo(for: .annual)
            isAnnualIntroEligible = await store.isIntroEligible(for: .annual)
        } catch {
            print("❌ Failed to load product info: \(error)")
        }
    }

    private func purchase() async {
        isPurchasing = true

        do {
            try await store.purchase(selectedPlan)
            dismiss()
        } catch {
            // Show error
            print("❌ Purchase failed: \(error)")
        }

        isPurchasing = false
    }

    private func restore() async {
        isPurchasing = true

        do {
            try await store.restorePurchases()
            if store.isPro {
                dismiss()
            }
        } catch {
            print("❌ Restore failed: \(error)")
        }

        isPurchasing = false
    }
}
```

#### `Subscription/UI/Components/PriceOptionRow.swift`
```swift
import SwiftUI

struct PriceOptionRow: View {
    let plan: SubscriptionPlan
    let isSelected: Bool
    let productInfo: ProductInfo?
    let showIntroOffer: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.md) {
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? DS.Colors.accent : DS.Colors.onSurfaceSecondary)
                    .font(.system(size: 24))

                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    // Plan name + badge
                    HStack {
                        Text(plan.displayName)
                            .font(DS.Typo.headline)
                            .foregroundStyle(DS.Colors.onSurface)

                        if let badge = plan.highlightBadge {
                            Text(badge)
                                .font(DS.Typo.caption1)
                                .foregroundStyle(.white)
                                .padding(.horizontal, DS.Spacing.xs)
                                .padding(.vertical, 2)
                                .background(DS.Colors.accent)
                                .clipShape(Capsule())
                        }
                    }

                    // Price
                    if showIntroOffer, let introPrice = productInfo?.introOfferPrice {
                        // Show intro offer
                        Text(introPrice)
                            .font(DS.Typo.body)
                            .foregroundStyle(DS.Colors.accent)

                        Text("Then \(productInfo?.displayPrice ?? plan.displayPrice)")
                            .font(DS.Typo.caption1)
                            .foregroundStyle(DS.Colors.onSurfaceSecondary)
                    } else {
                        // Show standard price
                        Text(productInfo?.displayPrice ?? plan.displayPrice)
                            .font(DS.Typo.body)
                            .foregroundStyle(DS.Colors.onSurface)
                    }
                }

                Spacer()
            }
            .padding(DS.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DS.Spacing.cardCornerRadius)
                    .fill(DS.Colors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Spacing.cardCornerRadius)
                            .stroke(isSelected ? DS.Colors.accent : DS.Colors.border, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
```

### 3. Migration

Create `Subscription/Migration/SubscriptionMigration.swift` to:
1. Scan for all old subscription references
2. Remove old models/enums
3. Update all feature gates to use `store.isPro`

### 4. Tests

See the full test implementations in the separate sections below.

### 5. Tools

See `SubscriptionSelfCheck.swift` and `SubscriptionStatusReport.swift` in separate sections.

### 6. CI Script

Create `scripts/subscriptions_ci_guardrail.sh` - see separate section.

---

## 🔧 Integration Steps

### Step 1: Update App.swift

Replace old SubscriptionService with new SubscriptionStore:

```swift
@main
struct App100Days: App {
    @StateObject private var subscriptionStore = SubscriptionStore(
        repository: RevenueCatSubscriptionRepository()
    )

    var body: some Scene {
        WindowGroup {
            AppContentView()
                .environmentObject(subscriptionStore)
        }
    }
}
```

### Step 2: Update AppContentView

```swift
} else if store.isPro {
    // User has Pro access
    MainAppView()
} else {
    // Show paywall
    PaywallView()
}
```

### Step 3: Remove Old Files

DELETE these files:
- `Services/SubscriptionService.swift` (old one)
- `Services/Entitlements.swift` (duplicate)
- `Features/Auth/Views/FoundersOfferPaywall.swift` (duplicate paywall)
- `Features/Auth/Views/EnhancedPaywallView.swift` (duplicate paywall)
- `Features/Auth/Views/PaywallView.swift` (old paywall)
- Any other duplicate subscription files

### Step 4: Update Feature Gates

Replace all instances of:
```swift
// OLD
if entitlements.effectiveIsProUser { ... }
if subscriptionService.isProUser { ... }
if hasProAccess { ... }
```

With:
```swift
// NEW
if store.isPro { ... }
```

---

## 📊 Status Report Output Example

When you run `printSubscriptionStatusReport()`, you should see:

```
=== 100Days Subscription System Status ===

✅ Expected product IDs present:
   - com.KhamariThompson.100Days.monthlyv2
   - com.KhamariThompson.100Days.annualv1

⚠️ Unexpected product IDs found in code: []

✅ Entitlement active: pro
✅ Offering: default
   Packages: monthly, annual

✅ Intro offer eligible (annual): true

⏱️ Five-minute window active: false

🧹 Duplicate models: []
🧹 Duplicate paywalls: []
🧹 Legacy flags in code: []

🧩 Current state:
   isPro: true
   plan: annual
   renewal: 2025-11-24
   grandfathered: false
```

---

## 🚦 Next Actions

1. ✅ Domain models created
2. ✅ Data layer created
3. ⏳ Create Service layer files
4. ⏳ Create UI layer files
5. ⏳ Create Migration script
6. ⏳ Create Tests
7. ⏳ Create Tools
8. ⏳ Create CI script
9. ⏳ Delete old files
10. ⏳ Update feature gates
11. ⏳ Test thoroughly
12. ⏳ Run status report

---

This is your SSOT implementation. No other subscription code should exist outside this module!
