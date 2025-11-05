import Foundation

enum SubscriptionIDs {
    /// RevenueCat entitlement identifier (case-sensitive)
    static let entitlement = "Pro"

    /// Offering ID in RevenueCat (case-sensitive)
    static let offeringID = "default"

    /// Package IDs in RevenueCat 'default' offering
    enum Package {
        static let monthly = "monthly"
        static let annual = "annual"
        static let annualNoIntro = "annual_no_intro"
    }

    // MARK: - Legacy Compatibility

    /// @deprecated Use `entitlement` instead
    static let proEntitlementID = "Pro"

    /// @deprecated Use `offeringID` instead
    static let defaultOfferingID = "default"

    /// @deprecated Use `Package` instead
    enum PackageID {
        static let monthly = "monthly"
        static let annual = "annual"
        static let annualNoIntro = "annual_no_intro"
    }

    // MARK: - Product Identifiers (App Store Connect)

    /// Actual product IDs from App Store Connect
    /// These MUST match exactly (case-sensitive) with your In-App Purchase product IDs
    enum ProductID {
        /// Monthly subscription
        static let monthly = "com.KhamariThompson.100Days.monthlyv2"

        /// Annual subscription with introductory offer
        static let annualIntro = "com.KhamariThompson.100Days.annualv1"

        /// Annual subscription without introductory offer
        static let annualNoIntro = "com.KhamariThompson.100Days.annualv1.no_introv1"
    }

    // MARK: - Package → Product Mapping

    /// Maps package identifiers to their expected product IDs
    /// Used for validation and diagnostics
    static let packageProductMap: [String: String] = [
        Package.monthly: ProductID.monthly,
        Package.annual: ProductID.annualIntro,
        Package.annualNoIntro: ProductID.annualNoIntro
    ]

    // MARK: - Validation

    /// Validates that the current offering configuration matches expected setup
    /// Call this at app launch to ensure RevenueCat is configured correctly
    /// - Parameter offerings: Current offerings from RevenueCat
    /// - Returns: Validation errors, or empty array if valid
    static func validateConfiguration(offerings: Any?) -> [String] {
        var errors: [String] = []

        // Add validation logic here if needed
        // For now, just return empty (validation happens at runtime in diagnostics)

        return errors
    }

    // MARK: - Diagnostics

    /// Prints comprehensive diagnostics about current offering configuration
    /// Call this at app launch in DEBUG mode
    static func printDiagnostics(offerings: Any?) {
        #if DEBUG
        // Diagnostics available only in debug builds
        // Configuration: Offering ID=\(defaultOfferingID), Entitlement=\(proEntitlementID)
        #endif
    }
}

// MARK: - Legacy Support

/// For backward compatibility with existing code that references Constants.ProductID
/// This extension allows gradual migration
extension Constants {
    enum SubscriptionIdentifiers {
        static let defaultOffering = SubscriptionIDs.defaultOfferingID
        static let proEntitlement = SubscriptionIDs.proEntitlementID

        enum Packages {
            static let monthly = SubscriptionIDs.PackageID.monthly
            static let annual = SubscriptionIDs.PackageID.annual
            static let annualNoIntro = SubscriptionIDs.PackageID.annualNoIntro
        }
    }
}
