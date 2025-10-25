import Foundation
import RevenueCat
import StoreKit
import Combine
import SwiftUI

// MARK: - Entitlements Service
//
// CHANGED: New single source of truth for subscriptions
// - RevenueCat integration with correct product IDs
// - StoreKit 2 fallback for reliability
// - Hard paywall enforcement
// - Automatic entitlement refresh

/// Single source of truth for subscription entitlements
/// Handles both RevenueCat and StoreKit 2 fallback
@MainActor
class Entitlements: NSObject, ObservableObject {
    static let shared = Entitlements()

    // MARK: - Published Properties

    @Published private(set) var isProUser: Bool = false {
        didSet {
            print("📊 Entitlements: isProUser changed to \(isProUser)")
        }
    }
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var customerInfo: CustomerInfo?
    @Published private(set) var offerings: Offerings?
    @Published private(set) var error: Error?

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private let revenueCatApiKey = "appl_BmXAuCdWBmPoVBAOgxODhJddUvc"

    // Migration manager for legacy user access
    private let migrationManager = MigrationManager.shared

    // Product IDs
    private let monthlyProductId = "com.KhamariThompson.100Days.monthlyv2"
    private let annualProductId = "com.KhamariThompson.100Days.annualv1"

    // Storage keys for persistence
    private enum StorageKeys {
        static let hasCompletedPurchase = "HasCompletedPurchase"
    }

    // DEBUG: Force Pro for testing (remove in production)
    #if DEBUG
    private let forceProForTesting = true
    #else
    private let forceProForTesting = false
    #endif

    /// Computed property that returns Pro status with debug override
    /// This now includes:
    /// 1. Active RevenueCat subscription
    /// 2. Legacy user grace period access
    /// 3. Persisted Pro status from previous purchase
    var effectiveIsProUser: Bool {
        return forceProForTesting || isProUser || hasPersistedProStatus || migrationManager.isInLegacyGracePeriod()
    }

    /// Check if user has persisted Pro status from previous purchase
    private var hasPersistedProStatus: Bool {
        return UserDefaults.standard.bool(forKey: StorageKeys.hasCompletedPurchase)
    }

    // MARK: - Initialization

    private override init() {
        super.init()
        loadPersistedProStatus()
        configureRevenueCat()
        setupSubscriptions()
        setupForegroundRefresh()
    }
    
    // MARK: - Foreground Refresh
    
    /// Set up foreground refresh to update entitlements when app returns to foreground
    private func setupForegroundRefresh() {
        // Use NotificationCenter to listen for app entering foreground
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Refresh entitlements when app comes to foreground
            Task { [weak self] in
                await self?.refreshEntitlements()
            }
        }
    }
    
    // MARK: - Configuration
    
    private func configureRevenueCat() {
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: revenueCatApiKey)
        
        // Observe purchases updates
        Purchases.shared.delegate = self
    }
    
    private func setupSubscriptions() {
        // Listen for app state changes to refresh entitlements
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                Task {
                    await self?.refreshEntitlements()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// Refresh entitlements from RevenueCat
    func refreshEntitlements() async {
        isLoading = true

        do {
            let customerInfo = try await Purchases.shared.customerInfo()

            await MainActor.run {
                self.customerInfo = customerInfo
                self.isProUser = customerInfo.entitlements["pro"]?.isActive == true
                self.isLoading = false

                print("📊 Entitlements refreshed - Pro: \(self.isProUser)")
            }
        } catch {
            await MainActor.run {
                self.error = error
                self.isLoading = false

                // Fallback to StoreKit 2 if RevenueCat fails
                Task {
                    await self.checkStoreKitEntitlements()
                }
            }
        }
    }

    /// Set user attributes in RevenueCat for analytics and cohort tracking
    func setUserAttributes(userId: String, cohort: String, funnelCompletedAt: Date?, firstPaywallAt: Date?) {
        // Set user ID
        Purchases.shared.logIn(userId) { _, _, _ in
            // User logged in to RevenueCat
        }

        // Set cohort attribute
        Purchases.shared.attribution.setAttributes(["cohort": cohort])

        // Set funnel completed timestamp if available
        if let funnelCompleted = funnelCompletedAt {
            let formatter = ISO8601DateFormatter()
            Purchases.shared.attribution.setAttributes(["funnel_completed_at": formatter.string(from: funnelCompleted)])
        }

        // Set first paywall timestamp if available
        if let firstPaywall = firstPaywallAt {
            let formatter = ISO8601DateFormatter()
            Purchases.shared.attribution.setAttributes(["first_paywall_at": formatter.string(from: firstPaywall)])
        }

        print("📊 RevenueCat attributes set - cohort: \(cohort)")
    }
    
    /// Purchase a product using RevenueCat
    func purchaseProduct(_ productId: String) async throws {
        isLoading = true
        
        do {
            // Get available packages
            let offerings = try await Purchases.shared.offerings()
            
            guard let package = findPackage(for: productId, in: offerings) else {
                throw EntitlementError.productNotFound
            }
            
            let (_, customerInfo, _) = try await Purchases.shared.purchase(package: package)
            
            await MainActor.run {
                self.customerInfo = customerInfo
                self.isProUser = customerInfo.entitlements["pro"]?.isActive == true
                self.isLoading = false
            }
            
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
            
            // Fallback to StoreKit 2
            try await purchaseWithStoreKit(productId)
        }
    }
    
    /// Restore purchases
    func restorePurchases() async throws {
        isLoading = true
        
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            
            await MainActor.run {
                self.customerInfo = customerInfo
                self.isProUser = customerInfo.entitlements["pro"]?.isActive == true
                self.isLoading = false
            }
            
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
            
            // Fallback to StoreKit 2
            try await restoreWithStoreKit()
        }
    }
    
    /// Get available offerings
    func loadOfferings() async {
        do {
            let offerings = try await Purchases.shared.offerings()
            
            await MainActor.run {
                self.offerings = offerings
            }
        } catch {
            await MainActor.run {
                self.error = error
            }
        }
    }
    
    // MARK: - StoreKit 2 Fallback
    
    private func checkStoreKitEntitlements() async {
        do {
            // Check for current entitlements
            for await result in Transaction.currentEntitlements {
                if case .verified(let transaction) = result {
                    if transaction.productID == monthlyProductId || transaction.productID == annualProductId {
                        await MainActor.run {
                            self.isProUser = true
                        }
                        return
                    }
                }
            }
            
            await MainActor.run {
                self.isProUser = false
            }
        } catch {
            print("❌ StoreKit entitlement check failed: \(error)")
        }
    }
    
    private func purchaseWithStoreKit(_ productId: String) async throws {
        let products = try await Product.products(for: [productId])
        
        guard let product = products.first else {
            throw EntitlementError.productNotFound
        }
        
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            switch verification {
            case .verified(let transaction):
                // Transaction verified - grant entitlement
                await MainActor.run {
                    self.isProUser = true
                    self.isLoading = false
                }
                
                // Finish the transaction
                await transaction.finish()
                
            case .unverified:
                throw EntitlementError.transactionUnverified
            }
            
        case .userCancelled:
            await MainActor.run {
                self.isLoading = false
            }
            throw EntitlementError.userCancelled
            
        case .pending:
            await MainActor.run {
                self.isLoading = false
            }
            throw EntitlementError.transactionPending
            
        @unknown default:
            throw EntitlementError.unknownError
        }
    }
    
    private func restoreWithStoreKit() async throws {
        try await AppStore.sync()
        await checkStoreKitEntitlements()
    }
    
    // MARK: - Helper Methods

    private func findPackage(for productId: String, in offerings: Offerings) -> Package? {
        for offering in offerings.all.values {
            for package in offering.availablePackages {
                if package.storeProduct.productIdentifier == productId {
                    return package
                }
            }
        }
        return nil
    }

    /// Load persisted Pro status from UserDefaults
    private func loadPersistedProStatus() {
        if UserDefaults.standard.bool(forKey: StorageKeys.hasCompletedPurchase) {
            isProUser = true
            print("📊 Entitlements: Loaded persisted Pro status from UserDefaults")
        }
    }

    /// Mark purchase as complete and persist to UserDefaults
    func markPurchaseComplete() {
        UserDefaults.standard.set(true, forKey: StorageKeys.hasCompletedPurchase)
        isProUser = true
        print("📊 Entitlements: Purchase marked complete and persisted")
    }
}

// MARK: - PurchasesDelegate

extension Entitlements: PurchasesDelegate {
    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            self.customerInfo = customerInfo
            self.isProUser = customerInfo.entitlements["pro"]?.isActive == true
            
            print("📊 RevenueCat update - Pro: \(self.isProUser)")
        }
    }
}

// MARK: - Entitlement Errors

enum EntitlementError: LocalizedError, Equatable {
    case productNotFound
    case transactionUnverified
    case userCancelled
    case transactionPending
    case unknownError
    
    var errorDescription: String? {
        switch self {
        case .productNotFound:
            return "Product not found"
        case .transactionUnverified:
            return "Transaction could not be verified"
        case .userCancelled:
            return "Purchase was cancelled"
        case .transactionPending:
            return "Transaction is pending approval"
        case .unknownError:
            return "An unknown error occurred"
        }
    }
}

// MARK: - View Extensions

extension View {
    /// Modifier to gate content behind Pro subscription
    func requiresPro() -> some View {
        self.modifier(ProRequiredModifier())
    }
}

struct ProRequiredModifier: ViewModifier {
    @StateObject private var entitlements = Entitlements.shared
    @State private var showPaywall = false

    func body(content: Content) -> some View {
        if entitlements.effectiveIsProUser {
            content
        } else {
            content
                .blur(radius: 5)
                .overlay(
                    Button("Upgrade to Pro") {
                        showPaywall = true
                    }
                    .buttonStyle(AppPrimaryButtonStyle())
                )
                .fullScreenCover(isPresented: $showPaywall) {
                    PaywallView()
                        .onDisappear {
                            showPaywall = false
                        }
                }
        }
    }
}
