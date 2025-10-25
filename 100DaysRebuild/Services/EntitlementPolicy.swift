import Foundation

/// Simple entitlement policy wrapper to provide a single SSOT for entitlement checks.
/// Proxies to `SubscriptionService` so callers can uniformly check entitlements.
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
            return SubscriptionService.shared.isProUser
        }
    }
}
