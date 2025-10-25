import Foundation

/// SSOT for entitlements - we only have ONE entitlement
enum Entitlement: String, CaseIterable {
    case pro

    /// The EXACT entitlement identifier in RevenueCat
    var identifier: String {
        return rawValue
    }
}
