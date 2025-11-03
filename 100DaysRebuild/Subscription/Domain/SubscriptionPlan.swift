import Foundation

/// SSOT for subscription plans - these are the ONLY two plans in the app
enum SubscriptionPlan: String, CaseIterable, Codable {
    case monthly
    case annual

    /// The EXACT product ID from App Store Connect
    /// Note: For .annual, this returns the intro product by default.
    /// The PaywallViewModel will determine whether to use annualIntro or annualNoIntro
    /// based on founders gate state (window, eligibility, campaign date, consumption).
    var productId: String {
        switch self {
        case .monthly:
            return Constants.ProductID.monthly
        case .annual:
            return Constants.ProductID.annualIntro  // Default; overridden by selection logic
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
    /// ⚠️ WARNING: These are US prices only. StoreKit provides localized pricing for actual purchases.
    /// These fallbacks should match the base prices configured in App Store Connect.
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
