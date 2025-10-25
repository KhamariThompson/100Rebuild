import Foundation

/// SSOT for subscription status
enum SubscriptionStatus: Equatable {
    case notPurchased
    case active(plan: SubscriptionPlan, renewalDate: Date?)
    case grandfathered
    case expired(lastPlan: SubscriptionPlan?, expiredAt: Date?)

    /// Convenience check if user has Pro access
    var isPro: Bool {
        switch self {
        case .notPurchased, .expired:
            return false
        case .active, .grandfathered:
            return true
        }
    }

    /// Get the current plan if active
    var currentPlan: SubscriptionPlan? {
        switch self {
        case .active(let plan, _):
            return plan
        case .expired(let lastPlan, _):
            return lastPlan
        case .notPurchased, .grandfathered:
            return nil
        }
    }

    /// Get renewal date if active
    var renewalDate: Date? {
        switch self {
        case .active(_, let renewalDate):
            return renewalDate
        default:
            return nil
        }
    }

    /// Get expiration date if expired
    var expiredAt: Date? {
        switch self {
        case .expired(_, let expiredAt):
            return expiredAt
        default:
            return nil
        }
    }

    /// Check if grandfathered
    var isGrandfathered: Bool {
        if case .grandfathered = self {
            return true
        }
        return false
    }

    static func == (lhs: SubscriptionStatus, rhs: SubscriptionStatus) -> Bool {
        switch (lhs, rhs) {
        case (.notPurchased, .notPurchased):
            return true
        case (.active(let lplan, let ldate), .active(let rplan, let rdate)):
            return lplan == rplan && ldate == rdate
        case (.grandfathered, .grandfathered):
            return true
        case (.expired(let lplan, let ldate), .expired(let rplan, let rdate)):
            return lplan == rplan && ldate == rdate
        default:
            return false
        }
    }
}
