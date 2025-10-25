import Foundation

/// SSOT for subscription plans - these are the ONLY two plans in the app
enum SubscriptionPlan: String, CaseIterable, Codable {
    case monthly
    case annual

    /// The EXACT product ID from App Store Connect
    var productId: String {
        switch self {
        case .monthly:
            return "com.KhamariThompson.100Days.monthlyv2"
        case .annual:
            return "com.KhamariThompson.100Days.annualv1"
        }
    }

    /// Display name for UI
    var displayName: String {
        switch self {
        case .monthly:
            return "Monthly"
        case .annual:
            return "Annual"
        }
    }

    /// Standard display price (fallback if StoreKit fails)
    var displayPrice: String {
        switch self {
        case .monthly:
            return "$14.99/month"
        case .annual:
            return "$29.99/year"
        }
    }

    /// Intro offer price (only shown when eligible)
    var introPrice: String? {
        switch self {
        case .monthly:
            return nil
        case .annual:
            return "$19.99 for first year"
        }
    }

    /// Badge to highlight this plan
    var highlightBadge: String? {
        switch self {
        case .monthly:
            return nil
        case .annual:
            return "Best value"
        }
    }

    /// Billing period for display
    var billingPeriod: String {
        switch self {
        case .monthly:
            return "month"
        case .annual:
            return "year"
        }
    }
}
