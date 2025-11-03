import Foundation
import RevenueCat
import FirebaseAuth

/// Centralized manager for RevenueCat (Purchases) configuration.
/// Use `configureIfNeeded()` as the single entry point to ensure Purchases
/// is configured exactly once and before any code accesses `Purchases.shared`.
@MainActor
final class RevenueCatManager {
    private static var configured = false

    static var isConfigured: Bool {
        return configured
    }

    static func configureIfNeeded() {
        guard !configured else {
            return
        }

        let currentUserId = Auth.auth().currentUser?.uid

        #if DEBUG
        Purchases.logLevel = .debug
        #else
        Purchases.logLevel = .error
        #endif

        Purchases.configure(
            with: Configuration.Builder(withAPIKey: Constants.RevenueCat.apiKey)
                .with(appUserID: currentUserId)
                .with(purchasesAreCompletedBy: .revenueCat, storeKitVersion: .storeKit2)
                .with(userDefaults: UserDefaults.standard)
                .with(usesStoreKit2IfAvailable: true)
                .build()
        )

        // Default delegate - SubscriptionService conforms to PurchasesDelegate
        Purchases.shared.delegate = SubscriptionService.shared

        configured = true
    }

    /// Explicitly set the Purchases delegate if needed later.
    static func setDelegate(_ delegate: PurchasesDelegate?) {
        Purchases.shared.delegate = delegate
    }
}
