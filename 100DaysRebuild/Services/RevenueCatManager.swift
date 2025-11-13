import Foundation
import RevenueCat
import FirebaseAuth

/// Centralized manager for RevenueCat (Purchases) configuration.
/// Use `configureIfNeeded()` as the single entry point to ensure Purchases
/// is configured exactly once and before any code accesses `Purchases.shared`.
final class RevenueCatManager {
    nonisolated(unsafe) private static var configured = false

    static var isConfigured: Bool {
        return configured
    }

    @MainActor
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

        // IMPORTANT: Set up the log handler BEFORE calling Purchases.configure()
        // This prevents crashes when RevenueCat tries to log during initialization
        Purchases.logHandler = { @Sendable level, message in
            // Filter out the offerings not configured errors that are expected during development
            if message.contains("There are no products registered in the RevenueCat dashboard for your offerings") {
                // Just log that we're using fallback pricing mechanism
                #if DEBUG
                print("No products registered in RevenueCat dashboard, using fallback pricing mechanism")
                #endif
                return
            }

            // Log other messages as usual, but only errors in production
            #if DEBUG
            if level == .debug {
                print("RC: ℹ️ \(message)")
            } else if level == .info {
                print("RC: ℹ️ \(message)")
            } else if level == .warn {
                print("RC: ⚠️ \(message)")
            } else if level == .error {
                print("RC: ❌ \(message)")
            }
            #else
            // In production, only log errors but without sensitive information
            if level == .error {
                print("RC: Error occurred in RevenueCat SDK")
            }
            #endif
        }

        // Get and validate API key
        let apiKey = Constants.RevenueCat.apiKey

        #if !DEBUG
        // Production builds: verify API key is set and is production key
        if apiKey.isEmpty {
            fatalError("❌ FATAL: RevenueCat API key not set in Info.plist for Release build")
        }
        // Production keys start with "appl_" for iOS
        if !apiKey.hasPrefix("appl_") {
            print("⚠️ WARNING: RevenueCat API key may not be a production key (expected prefix: appl_)")
        }
        print("✅ RevenueCat: Using production API key in Release build")
        #else
        if apiKey.isEmpty {
            print("⚠️ WARNING: RevenueCat API key not set in Info.plist")
        }
        #endif

        Purchases.configure(
            with: Configuration.Builder(withAPIKey: apiKey)
                .with(appUserID: currentUserId)
                .with(purchasesAreCompletedBy: .revenueCat, storeKitVersion: .storeKit2)
                .with(userDefaults: UserDefaults.standard)
                .with(usesStoreKit2IfAvailable: true)
                .build()
        )

        // Set delegate directly - we're already on main thread
        // SubscriptionStore is the SSOT and implements PurchasesDelegate
        Purchases.shared.delegate = SubscriptionStore.shared

        configured = true
    }

    /// Explicitly set the Purchases delegate if needed later.
    @MainActor
    static func setDelegate(_ delegate: PurchasesDelegate?) {
        Purchases.shared.delegate = delegate
    }
}
