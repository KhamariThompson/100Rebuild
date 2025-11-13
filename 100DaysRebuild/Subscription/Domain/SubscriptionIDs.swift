import Foundation
import RevenueCat

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
    @MainActor
    static func validateConfiguration(offerings: Offerings?) async -> [String] {
        var errors: [String] = []

        guard let offerings = offerings else {
            errors.append("No offerings available from RevenueCat")
            return errors
        }

        // 1. Check default offering exists
        guard let defaultOffering = offerings.offering(identifier: offeringID) else {
            errors.append("Required offering '\(offeringID)' not found in RevenueCat")
            return errors
        }

        print("✅ RC Validation: Found offering '\(offeringID)'")

        // 2. Validate expected packages exist
        let expectedPackages = [Package.monthly, Package.annual, Package.annualNoIntro]
        for packageId in expectedPackages {
            if let package = defaultOffering.package(identifier: packageId) {
                // Package found - validate product ID matches
                let expectedProductId = packageProductMap[packageId]
                let actualProductId = package.storeProduct.productIdentifier

                if let expected = expectedProductId, expected != actualProductId {
                    errors.append("Package '\(packageId)' has product ID '\(actualProductId)' but expected '\(expected)'")
                } else {
                    print("✅ RC Validation: Package '\(packageId)' → '\(actualProductId)'")
                }
            } else {
                errors.append("Required package '\(packageId)' not found in offering '\(offeringID)'")
            }
        }

        // 3. Validate entitlement exists in customer info
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            let hasProEntitlement = customerInfo.entitlements.all.keys.contains(entitlement)

            if !hasProEntitlement {
                // Not an error if user hasn't subscribed yet, just log
                print("ℹ️ RC Validation: Entitlement '\(entitlement)' not in customer info (user may not have subscribed)")
            } else {
                print("✅ RC Validation: Entitlement '\(entitlement)' found")
            }
        } catch {
            print("⚠️ RC Validation: Unable to check entitlements: \(error.localizedDescription)")
        }

        return errors
    }

    /// Perform runtime validation and log results
    /// Non-fatal - logs errors but doesn't crash
    @MainActor
    static func performRuntimeValidation() async {
        do {
            let offerings = try await Purchases.shared.offerings()
            let errors = await validateConfiguration(offerings: offerings)

            if errors.isEmpty {
                print("✅ RC Validation: All checks passed")
            } else {
                print("❌ RC Validation: Found \(errors.count) error(s):")
                for error in errors {
                    print("   - \(error)")
                }
                // Log to analytics/crash reporting in production
                #if !DEBUG
                // TODO: Send validation errors to analytics
                #endif
            }
        } catch {
            print("❌ RC Validation: Failed to fetch offerings: \(error.localizedDescription)")
        }
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
