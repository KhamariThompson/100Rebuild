import Foundation
import RevenueCat
import StoreKit

/// Protocol defining subscription data operations
protocol SubscriptionRepository {
    /// Load current subscription status
    func loadStatus() async throws -> SubscriptionStatus

    /// Purchase a subscription plan
    func purchase(_ plan: SubscriptionPlan) async throws -> SubscriptionStatus

    /// Restore purchases
    func restorePurchases() async throws -> SubscriptionStatus

    /// Refresh entitlements from server
    func refreshEntitlements() async throws -> SubscriptionStatus

    /// Check if user is eligible for intro offer
    func isIntroEligible(for plan: SubscriptionPlan) async -> Bool

    /// Get product info for a plan (with actual pricing from StoreKit)
    func getProductInfo(for plan: SubscriptionPlan) async throws -> ProductInfo

    /// Observe entitlement updates
    func observeEntitlementUpdates() -> AsyncStream<SubscriptionStatus>

    /// Check if user is grandfathered (from Firestore)
    func checkGrandfatheredStatus(userId: String) async throws -> Bool
}

/// Product information from StoreKit
struct ProductInfo: Equatable {
    let productId: String
    let displayPrice: String
    let localizedDescription: String
    let hasIntroOffer: Bool
    let introOfferPrice: String?
    let introOfferPeriod: String?
}
