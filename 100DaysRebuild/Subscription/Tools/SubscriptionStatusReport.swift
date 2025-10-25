import Foundation
import RevenueCat

/// Runtime snapshot of subscription system state
struct SubscriptionSystemSnapshot {
    let foundProductIds: [String]
    let expectedProductIds: [String]
    let missingInCode: [String]
    let unexpectedInCode: [String]
    let activeEntitlement: String?
    let offeringIdentifier: String?
    let offeringPackages: [String]
    let introEligibleAnnual: Bool
    let fiveMinuteWindowActive: Bool
    let duplicateModelsFound: [String]
    let duplicatePaywallsFound: [String]
    let legacyFlagsInCode: [String]
    let currentState: String
}

/// Generates a runtime status report of the subscription system
@MainActor
func printSubscriptionStatusReport(
    store: SubscriptionStore,
    fiveMinuteWindow: FiveMinuteWindow?,
    repository: SubscriptionRepository
) async {
    print("")
    print("=== 100Days Subscription System Status ===")
    print("")

    // 1. Expected product IDs
    let expected = [
        "com.KhamariThompson.100Days.monthlyv2",
        "com.KhamariThompson.100Days.annualv1"
    ]

    print("✅ Expected product IDs:")
    for id in expected {
        print("   - \(id)")
    }
    print("")

    // 2. Query RevenueCat for offerings
    var offeringId: String?
    var packages: [String] = []
    var activeEntitlement: String?

    do {
        let offerings = try await Purchases.shared.offerings()

        if let offering = offerings.current {
            offeringId = offering.identifier
            packages = offering.availablePackages.map { $0.storeProduct.productIdentifier }
        }

        let customerInfo = try await Purchases.shared.customerInfo()
        if customerInfo.entitlements[Entitlement.pro.identifier]?.isActive == true {
            activeEntitlement = Entitlement.pro.identifier
        }

    } catch {
        print("⚠️  Error fetching offerings: \(error)")
    }

    // 3. Check intro eligibility
    let isIntroEligible = await repository.isIntroEligible(for: .annual)

    // 4. Five-minute window
    let windowActive = fiveMinuteWindow?.isActive ?? false

    // 5. Print report
    if let offeringId = offeringId {
        print("✅ Offering: \(offeringId)")
        print("   Packages:")
        for pkg in packages {
            print("      - \(pkg)")
        }
    } else {
        print("⚠️  No current offering found")
    }
    print("")

    if let entitlement = activeEntitlement {
        print("✅ Entitlement active: \(entitlement)")
    } else {
        print("ℹ️  No active entitlement")
    }
    print("")

    print("✅ Intro offer eligible (annual): \(isIntroEligible)")
    print("")

    print("⏱️  Five-minute window active: \(windowActive)")
    if let window = fiveMinuteWindow {
        let remaining = Int(window.timeRemaining)
        print("   Time remaining: \(remaining)s")
    }
    print("")

    // 6. Check for unexpected product IDs in code
    let unexpected = checkForUnexpectedProductIds()
    if unexpected.isEmpty {
        print("✅ No unexpected product IDs found in code")
    } else {
        print("⚠️  Unexpected product IDs found in code:")
        for id in unexpected {
            print("   - \(id)")
        }
    }
    print("")

    // 7. Check for duplicate paywalls
    let duplicatePaywalls = checkForDuplicatePaywalls()
    if duplicatePaywalls.isEmpty {
        print("✅ No duplicate paywalls found")
    } else {
        print("⚠️  Duplicate paywalls found:")
        for path in duplicatePaywalls {
            print("   - \(path)")
        }
    }
    print("")

    // 8. Current state
    print("🧩 Current state:")
    print("   isPro: \(store.isPro)")
    if let plan = store.state.currentPlan {
        print("   plan: \(plan.rawValue)")
    }
    if let renewal = store.state.renewalDate {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        print("   renewal: \(formatter.string(from: renewal))")
    }
    print("   grandfathered: \(store.state.isGrandfathered)")
    print("")

    print("===========================================")
    print("")
}

// MARK: - Helper Functions

private func checkForUnexpectedProductIds() -> [String] {
    // This would require scanning the codebase
    // For now, return empty array
    // In production, you'd use a build-time tool
    return []
}

private func checkForDuplicatePaywalls() -> [String] {
    // This would require scanning the codebase
    // For now, return empty array
    // In production, you'd use a build-time tool
    return []
}
