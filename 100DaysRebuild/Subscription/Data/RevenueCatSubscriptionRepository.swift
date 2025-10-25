import Foundation
import RevenueCat
import StoreKit
import FirebaseFirestore

/// RevenueCat implementation of SubscriptionRepository
final class RevenueCatSubscriptionRepository: SubscriptionRepository {
    private let firestore = Firestore.firestore()

    // MARK: - Load Status

    func loadStatus() async throws -> SubscriptionStatus {
        let customerInfo = try await Purchases.shared.customerInfo()
        return mapCustomerInfoToStatus(customerInfo)
    }

    // MARK: - Purchase

    func purchase(_ plan: SubscriptionPlan) async throws -> SubscriptionStatus {
        print("🔐 RC: Starting purchase for \(plan.productId)")

        // Get offerings
        let offerings = try await Purchases.shared.offerings()

        guard let offering = offerings.current else {
            print("❌ RC: No current offering available")
            throw SubscriptionError.noOfferingAvailable
        }

        // Find the package for this plan
        guard let package = offering.availablePackages.first(where: {
            $0.storeProduct.productIdentifier == plan.productId
        }) else {
            print("❌ RC: Package not found for \(plan.productId)")
            throw SubscriptionError.packageNotFound
        }

        // Purchase
        let result = try await Purchases.shared.purchase(package: package)
        print("✅ RC: Purchase successful")

        // Map result to status
        return mapCustomerInfoToStatus(result.customerInfo)
    }

    // MARK: - Restore

    func restorePurchases() async throws -> SubscriptionStatus {
        print("🔐 RC: Restoring purchases")
        let customerInfo = try await Purchases.shared.restorePurchases()
        return mapCustomerInfoToStatus(customerInfo)
    }

    // MARK: - Refresh

    func refreshEntitlements() async throws -> SubscriptionStatus {
        let customerInfo = try await Purchases.shared.customerInfo()
        return mapCustomerInfoToStatus(customerInfo)
    }

    // MARK: - Intro Eligibility

    func isIntroEligible(for plan: SubscriptionPlan) async -> Bool {
        do {
            let offerings = try await Purchases.shared.offerings()

            guard let offering = offerings.current else {
                print("⚠️ RC: No offering for intro eligibility check")
                return false
            }

            // Find package for this plan
            guard let package = offering.availablePackages.first(where: {
                $0.storeProduct.productIdentifier == plan.productId
            }) else {
                print("⚠️ RC: Package not found for intro eligibility check")
                return false
            }

            // Check StoreKit product for intro offer
            let product = package.storeProduct

            // For StoreKit 2
            if #available(iOS 15.0, *) {
                // Check if product has intro offer and user is eligible
                // Access the underlying SK2 Product
                let hasIntroOffer = product.sk2Product?.subscription?.introductoryOffer != nil

                if hasIntroOffer {
                    // Get customer info to check eligibility
                    let customerInfo = try await Purchases.shared.customerInfo()

                    // User is eligible if they don't have an active entitlement
                    // and haven't previously purchased this product
                    let hasActiveEntitlement = customerInfo.entitlements[Entitlement.pro.identifier]?.isActive == true
                    let hasPreviouslyPurchased = customerInfo.allPurchasedProductIdentifiers.contains(plan.productId)

                    let isEligible = !hasActiveEntitlement && !hasPreviouslyPurchased

                    print("🔐 RC: Intro eligibility for \(plan.productId): \(isEligible)")
                    return isEligible
                }
            }

            return false
        } catch {
            print("❌ RC: Error checking intro eligibility: \(error)")
            return false
        }
    }

    // MARK: - Product Info

    func getProductInfo(for plan: SubscriptionPlan) async throws -> ProductInfo {
        let offerings = try await Purchases.shared.offerings()

        guard let offering = offerings.current else {
            throw SubscriptionError.noOfferingAvailable
        }

        guard let package = offering.availablePackages.first(where: {
            $0.storeProduct.productIdentifier == plan.productId
        }) else {
            throw SubscriptionError.packageNotFound
        }

        let product = package.storeProduct

        var introOfferPrice: String?
        var introOfferPeriod: String?
        var hasIntroOffer = false

        // Extract intro offer info for StoreKit 2
        if #available(iOS 15.0, *) {
            // Access the underlying SK2 Product
            if let sk2Product = product.sk2Product,
               let introOffer = sk2Product.subscription?.introductoryOffer {
                hasIntroOffer = true
                introOfferPrice = introOffer.displayPrice
                introOfferPeriod = formatSK2Period(introOffer.period)
            }
        }

        return ProductInfo(
            productId: product.productIdentifier,
            displayPrice: product.localizedPriceString,
            localizedDescription: product.localizedDescription,
            hasIntroOffer: hasIntroOffer,
            introOfferPrice: introOfferPrice,
            introOfferPeriod: introOfferPeriod
        )
    }

    // MARK: - Observe Updates

    func observeEntitlementUpdates() -> AsyncStream<SubscriptionStatus> {
        return AsyncStream { continuation in
            // Set up RC delegate to observe updates
            // Note: This would require RC delegate setup
            // For now, return empty stream
            continuation.finish()
        }
    }

    // MARK: - Grandfathered Status

    func checkGrandfatheredStatus(userId: String) async throws -> Bool {
        let userDoc = try await firestore.collection("users").document(userId).getDocument()

        guard let data = userDoc.data() else {
            return false
        }

        return data["isGrandfathered"] as? Bool ?? false
    }

    // MARK: - Private Helpers

    private func mapCustomerInfoToStatus(_ customerInfo: CustomerInfo) -> SubscriptionStatus {
        // Check for pro entitlement
        guard let entitlement = customerInfo.entitlements[Entitlement.pro.identifier] else {
            return .notPurchased
        }

        // Check if active
        guard entitlement.isActive else {
            // Find last plan from purchase history
            let lastPlan = findLastPlanFromPurchaseHistory(customerInfo)
            return .expired(lastPlan: lastPlan, expiredAt: entitlement.expirationDate)
        }

        // Active - find which plan
        let plan = findActivePlan(customerInfo)
        return .active(plan: plan ?? .annual, renewalDate: entitlement.expirationDate)
    }

    private func findActivePlan(_ customerInfo: CustomerInfo) -> SubscriptionPlan? {
        for plan in SubscriptionPlan.allCases {
            if customerInfo.activeSubscriptions.contains(plan.productId) {
                return plan
            }
        }
        return nil
    }

    private func findLastPlanFromPurchaseHistory(_ customerInfo: CustomerInfo) -> SubscriptionPlan? {
        for plan in SubscriptionPlan.allCases {
            if customerInfo.allPurchasedProductIdentifiers.contains(plan.productId) {
                return plan
            }
        }
        return nil
    }

    private func formatPeriod(_ period: SubscriptionPeriod) -> String {
        let value = period.value
        let unit: String

        switch period.unit {
        case .day:
            unit = value == 1 ? "day" : "days"
        case .week:
            unit = value == 1 ? "week" : "weeks"
        case .month:
            unit = value == 1 ? "month" : "months"
        case .year:
            unit = value == 1 ? "year" : "years"
        @unknown default:
            unit = "period"
        }

        return "\(value) \(unit)"
    }

    @available(iOS 15.0, *)
    private func formatSK2Period(_ period: Product.SubscriptionPeriod) -> String {
        let value = period.value
        let unit: String

        switch period.unit {
        case .day:
            unit = value == 1 ? "day" : "days"
        case .week:
            unit = value == 1 ? "week" : "weeks"
        case .month:
            unit = value == 1 ? "month" : "months"
        case .year:
            unit = value == 1 ? "year" : "years"
        @unknown default:
            unit = "period"
        }

        return "\(value) \(unit)"
    }
}

// MARK: - Errors

enum SubscriptionError: LocalizedError {
    case noOfferingAvailable
    case packageNotFound
    case purchaseCancelled
    case purchaseFailed(underlying: Error)
    case restoreFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .noOfferingAvailable:
            return "No subscription offerings available"
        case .packageNotFound:
            return "Subscription package not found"
        case .purchaseCancelled:
            return "Purchase was cancelled"
        case .purchaseFailed(let error):
            return "Purchase failed: \(error.localizedDescription)"
        case .restoreFailed(let error):
            return "Restore failed: \(error.localizedDescription)"
        }
    }
}
