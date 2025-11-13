import Foundation

/// Simple entitlement policy wrapper to provide a single SSOT for entitlement checks.
/// Proxies to `SubscriptionStore` (the authoritative subscription SSOT).
@MainActor
final class EntitlementPolicy {
    static let shared = EntitlementPolicy()

    private init() {}

    enum Entitlement {
        case pro
    }

    func isEntitled(_ entitlement: Entitlement) -> Bool {
        switch entitlement {
        case .pro:
            return SubscriptionStore.shared.isPro
        }
    }
}
