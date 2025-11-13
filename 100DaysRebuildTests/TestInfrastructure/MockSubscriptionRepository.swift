import Foundation
import RevenueCat
@testable import _00DaysRebuild

/// Mock subscription repository for deterministic testing
/// Allows complete control over subscription state and network behavior
actor MockSubscriptionRepository: SubscriptionRepository {
    // Configurable state
    private var mockStatus: SubscriptionStatus = .notPurchased
    private var mockHasIntroEligibility: Bool = true
    private var mockOfferings: [String: MockProductInfo] = [:]
    private var mockNetworkError: Error?
    private var mockIsOffline: Bool = false
    private var mockPurchaseResult: (SubscriptionStatus, String)?
    private var mockGrandfatheredUserId: String?

    // Call tracking
    private(set) var purchaseCalls: [(plan: SubscriptionPlan, productId: String?)] = []
    private(set) var restoreCalls: Int = 0
    private(set) var refreshCalls: Int = 0

    init() {}

    // MARK: - Configuration Methods

    func setStatus(_ status: SubscriptionStatus) {
        mockStatus = status
    }

    func setIntroEligibility(_ eligible: Bool) {
        mockHasIntroEligibility = eligible
    }

    func setOffering(productId: String, price: String, hasIntro: Bool, introPrice: String? = nil) {
        mockOfferings[productId] = MockProductInfo(
            productId: productId,
            displayPrice: price,
            hasIntroOffer: hasIntro,
            introOfferPrice: introPrice
        )
    }

    func setNetworkError(_ error: Error?) {
        mockNetworkError = error
    }

    func setOffline(_ offline: Bool) {
        mockIsOffline = offline
    }

    func setPurchaseResult(status: SubscriptionStatus, productId: String) {
        mockPurchaseResult = (status, productId)
    }

    func setGrandfatheredUserId(_ userId: String?) {
        mockGrandfatheredUserId = userId
    }

    func reset() {
        mockStatus = .notPurchased
        mockHasIntroEligibility = true
        mockOfferings = [:]
        mockNetworkError = nil
        mockIsOffline = false
        mockPurchaseResult = nil
        mockGrandfatheredUserId = nil
        purchaseCalls = []
        restoreCalls = 0
        refreshCalls = 0
    }

    // MARK: - SubscriptionRepository Implementation

    func loadStatus() async throws -> SubscriptionStatus {
        try await throwIfError()
        return mockStatus
    }

    func purchase(_ plan: SubscriptionPlan, explicitProductId: String?) async throws -> (SubscriptionStatus, String) {
        try await throwIfError()

        let productId = explicitProductId ?? plan.productId
        purchaseCalls.append((plan: plan, productId: explicitProductId))

        if let result = mockPurchaseResult {
            mockStatus = result.0
            return result
        }

        // Default: successful purchase
        let newStatus = SubscriptionStatus.active(plan: plan, renewalDate: Date().addingTimeInterval(30 * 24 * 60 * 60))
        mockStatus = newStatus
        return (newStatus, productId)
    }

    func restorePurchases() async throws -> SubscriptionStatus {
        try await throwIfError()
        restoreCalls += 1
        return mockStatus
    }

    func refreshEntitlements() async throws -> SubscriptionStatus {
        try await throwIfError()
        refreshCalls += 1
        return mockStatus
    }

    func isIntroEligible(for plan: SubscriptionPlan) async -> Bool {
        return mockHasIntroEligibility
    }

    func getProductInfo(for plan: SubscriptionPlan) async throws -> ProductInfo {
        try await throwIfError()

        let productId = plan.productId
        if let mock = mockOfferings[productId] {
            return ProductInfo(
                productId: mock.productId,
                displayPrice: mock.displayPrice,
                localizedDescription: "Mock Product",
                hasIntroOffer: mock.hasIntroOffer,
                introOfferPrice: mock.introOfferPrice,
                introOfferPeriod: mock.hasIntroOffer ? "1 month" : nil
            )
        }

        // Default fallback
        return ProductInfo(
            productId: productId,
            displayPrice: "$4.99",
            localizedDescription: "Mock Product",
            hasIntroOffer: mockHasIntroEligibility,
            introOfferPrice: mockHasIntroEligibility ? "$0.99" : nil,
            introOfferPeriod: mockHasIntroEligibility ? "1 month" : nil
        )
    }

    func observeEntitlementUpdates() -> AsyncStream<SubscriptionStatus> {
        return AsyncStream { continuation in
            continuation.yield(mockStatus)
            continuation.finish()
        }
    }

    func checkGrandfatheredStatus(userId: String) async throws -> Bool {
        try await throwIfError()
        return userId == mockGrandfatheredUserId
    }

    // MARK: - Private Helpers

    private func throwIfError() async throws {
        if mockIsOffline {
            throw MockError.offline
        }
        if let error = mockNetworkError {
            throw error
        }
    }
}

// MARK: - Mock Data Structures

struct MockProductInfo {
    let productId: String
    let displayPrice: String
    let hasIntroOffer: Bool
    let introOfferPrice: String?
}

enum MockError: LocalizedError {
    case offline
    case networkFailure
    case rcMismatch
    case emptyOfferings

    var errorDescription: String? {
        switch self {
        case .offline:
            return "Device is offline"
        case .networkFailure:
            return "Network request failed"
        case .rcMismatch:
            return "RevenueCat configuration mismatch"
        case .emptyOfferings:
            return "No offerings available"
        }
    }
}
