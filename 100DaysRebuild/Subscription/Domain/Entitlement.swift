import Foundation

/// SSOT for entitlements - we only have ONE entitlement
enum Entitlement: String, CaseIterable {
    case pro = "Pro"  // Capital P to match RevenueCat configuration

    /// The EXACT entitlement identifier in RevenueCat (case-sensitive)
    var identifier: String {
        return rawValue
    }
}
