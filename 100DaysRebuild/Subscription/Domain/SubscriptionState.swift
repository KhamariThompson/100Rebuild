import Foundation

/// SSOT for the complete subscription state - this is what the UI observes
struct SubscriptionState: Equatable {
    var status: SubscriptionStatus
    var isPro: Bool
    var currentPlan: SubscriptionPlan?
    var renewalDate: Date?
    var isGrandfathered: Bool
    var isPaywallRequired: Bool

    init(status: SubscriptionStatus, isPaywallRequired: Bool = false) {
        self.status = status
        self.isPro = status.isPro
        self.currentPlan = status.currentPlan
        self.renewalDate = status.renewalDate
        self.isGrandfathered = status.isGrandfathered
        self.isPaywallRequired = isPaywallRequired
    }

    /// Default state for a new user
    static var `default`: SubscriptionState {
        return SubscriptionState(
            status: .notPurchased,
            isPaywallRequired: true
        )
    }

    /// State for a grandfathered user
    static var grandfathered: SubscriptionState {
        return SubscriptionState(
            status: .grandfathered,
            isPaywallRequired: false
        )
    }
}
