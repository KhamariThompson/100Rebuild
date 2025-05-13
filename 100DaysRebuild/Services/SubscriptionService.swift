import Foundation
import StoreKit
import RevenueCat
import FirebaseAuth

@MainActor
class SubscriptionService: ObservableObject {
    static let shared = SubscriptionService()
    
    @Published private(set) var isProUser: Bool = false
    @Published private(set) var availableProducts: [Product] = []
    @Published private(set) var renewalDate: Date?
    @Published var showPaywall = false
    @Published var errorLoadingOfferings = false
    @Published var offeringsLoaded = false
    
    // RevenueCat API key
    private var apiKey: String {
        // Production SDK API key (not secret key)
        return "appl_BmXAuCdWBmPoVBAOgxODhJddUvc"
    }
    
    // Product identifiers
    private let monthlyProductID = "com.KhamariThompson.100Days.monthly"
    
    private init() {
        // Initialize RevenueCat
        setupRevenueCat()
        
        Task {
            await loadProducts()
            await updateSubscriptionStatus()
            // Add early check for offerings configuration
            let _ = await checkOfferingsConfiguration()
        }
        
        // Listen for StoreKit transactions
        listenForTransactions()
        
        // Listen for auth changes to identify user in RevenueCat
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAuthStateChanged),
            name: NSNotification.Name("AuthStateChanged"),
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleAuthStateChanged() {
        Task {
            await identifyUser()
            await updateSubscriptionStatus()
        }
    }
    
    private func setupRevenueCat() {
        // Configure RevenueCat with API key
        Purchases.configure(withAPIKey: apiKey)
        
        // Enable debug logs to help troubleshoot
        #if DEBUG
        Purchases.logLevel = .debug
        #else
        Purchases.logLevel = .error
        #endif
        
        // Ensure entitlements are configured correctly
        print("RevenueCat configured with key: \(apiKey)")
        print("Expected product ID: \(monthlyProductID)")
        print("Expected entitlement: pro")
        
        // Identify the current user if available
        Task {
            await identifyUser()
        }
    }
    
    private func identifyUser() async {
        if let currentUser = Auth.auth().currentUser {
            do {
                // Use Firebase UID as RevenueCat user identifier
                let loginResult = try await Purchases.shared.logIn(currentUser.uid)
                print("User identified with RevenueCat: \(currentUser.uid)")
                
                // Update pro status based on latest customer info
                let activeEntitlements = loginResult.customerInfo.entitlements.active
                self.isProUser = activeEntitlements["pro"]?.isActive ?? false
                self.renewalDate = activeEntitlements["pro"]?.expirationDate
            } catch {
                print("Failed to identify user with RevenueCat: \(error.localizedDescription)")
            }
        } else {
            // When user logs out, reset to anonymous identifier
            do {
                // Check if current user is anonymous before calling logOut
                if Auth.auth().currentUser?.isAnonymous == true {
                    print("Current user is anonymous, not calling RevenueCat logOut")
                    return
                }
                
                // This resets to an anonymous user ID
                let customerInfo = try await Purchases.shared.logOut()
                print("Reset to anonymous user in RevenueCat")
                
                // Update pro status based on latest customer info
                let activeEntitlements = customerInfo.entitlements.active
                self.isProUser = activeEntitlements["pro"]?.isActive ?? false
                self.renewalDate = activeEntitlements["pro"]?.expirationDate
            } catch {
                print("Failed to reset RevenueCat user: \(error.localizedDescription)")
            }
        }
    }
    
    private func listenForTransactions() {
        // Listen for StoreKit transaction updates
        Task {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    // Always finish the transaction after handling
                    await transaction.finish()
                    
                    // Update subscription status
                    await updateSubscriptionStatus()
                }
            }
        }
    }
    
    private func loadProducts() async {
        do {
            let productIDs = [monthlyProductID]
            print("Loading StoreKit products: \(productIDs)")
            availableProducts = try await Product.products(for: productIDs)
            print("Loaded \(availableProducts.count) products from StoreKit")
            
            // Log available products for debug
            for product in availableProducts {
                print("StoreKit Product: \(product.id) - \(product.displayName)")
            }
        } catch {
            print("Failed to load products: \(error.localizedDescription)")
        }
    }
    
    private func updateSubscriptionStatus() async {
        // Check RevenueCat subscription status first
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            
            // Check if "pro" entitlement is active
            let isPro = customerInfo.entitlements["pro"]?.isActive ?? false
            let expirationDate = customerInfo.entitlements["pro"]?.expirationDate
            
            await MainActor.run {
                self.isProUser = isPro
                self.renewalDate = expirationDate
            }
            
            // Log entitlements for debugging
            for (entitlementId, entitlement) in customerInfo.entitlements.active {
                print("Active entitlement: \(entitlementId), expires: \(String(describing: entitlement.expirationDate))")
            }
            
            // If we found an active subscription in RevenueCat, we're done
            if isPro {
                return
            }
        } catch {
            print("Failed to check RevenueCat subscription: \(error.localizedDescription)")
        }
        
        // Fallback to StoreKit 2 if RevenueCat check failed
        let detachedTask = Task.detached {
            for await result in Transaction.currentEntitlements {
                if case .verified(let transaction) = result {
                    Task { @MainActor in
                        self.isProUser = true
                        self.renewalDate = transaction.expirationDate
                    }
                    return
                }
            }
            
            Task { @MainActor in
                // If StoreKit and RevenueCat both show no subscription, update state to non-pro
                self.isProUser = false
                self.renewalDate = nil
            }
        }
        
        // Add a timeout to prevent hanging
        await withTimeout(seconds: 5) {
            await detachedTask.value
        }
    }
    
    // Helper to add timeout to async operations
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async -> T) async {
        // Create a task group for running the operation with a timeout
        await withTaskGroup(of: Void.self) { group in
            // Task for the actual operation
            group.addTask {
                let _ = await operation()
            }
            
            // Task for the timeout
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                // When timeout occurs, we'll just exit this task
            }
            
            // Wait for first task to complete, then cancel everything else
            await group.next()
            group.cancelAll()
        }
    }
    
    func purchaseSubscription(plan: SubscriptionPlan) async throws {
        let productID = plan.rawValue
        print("Attempting to purchase product: \(productID)")
        
        // Try RevenueCat first
        do {
            let offerings = try await Purchases.shared.offerings()
            print("Successfully retrieved RevenueCat offerings")
            
            if let offering = offerings.current {
                print("Current offering: \(offering.identifier)")
                print("Available packages: \(offering.availablePackages.map { $0.identifier })")
                
                if let package = offering.availablePackages.first(where: { $0.storeProduct.productIdentifier == productID }) {
                    print("Found matching package: \(package.identifier) with product ID: \(package.storeProduct.productIdentifier)")
                    
                    let result = try await Purchases.shared.purchase(package: package)
                    print("Purchase successful - entitlements: \(result.customerInfo.entitlements.active.keys.joined(separator: ", "))")
                    
                    // Update pro status from result
                    await MainActor.run {
                        let activeEntitlements = result.customerInfo.entitlements.active
                        self.isProUser = activeEntitlements["pro"]?.isActive ?? false
                        self.renewalDate = activeEntitlements["pro"]?.expirationDate
                    }
                    
                    // Purchase succeeded
                    return
                } else {
                    print("No matching package found for product ID: \(productID)")
                }
            } else {
                print("No current offering available")
            }
        } catch {
            print("RevenueCat purchase failed: \(error.localizedDescription)")
            // Continue with StoreKit approach as fallback
        }
        
        // Fallback to StoreKit 2
        guard let product = availableProducts.first(where: { $0.id == productID }) else {
            print("Product not found in available products: \(productID)")
            print("Available products: \(availableProducts.map { $0.id })")
            throw SubscriptionError.purchaseFailed
        }
        
        do {
            print("Attempting StoreKit purchase for product: \(product.id)")
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    print("StoreKit purchase successful for: \(product.id)")
                    await transaction.finish()
                    await updateSubscriptionStatus()
                }
            case .userCancelled:
                print("User cancelled purchase")
                throw SubscriptionError.purchaseFailed
            case .pending:
                print("Purchase pending")
            @unknown default:
                print("Unknown purchase result")
                throw SubscriptionError.unknown
            }
        } catch {
            print("Purchase error: \(error.localizedDescription)")
            throw SubscriptionError.purchaseFailed
        }
    }
    
    func restorePurchases() async throws {
        print("Restoring purchases via RevenueCat")
        // Try to restore via RevenueCat
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            print("Restore purchases successful - entitlements: \(customerInfo.entitlements.active.keys.joined(separator: ", "))")
            
            await MainActor.run {
                self.isProUser = customerInfo.entitlements["pro"]?.isActive ?? false
                self.renewalDate = customerInfo.entitlements["pro"]?.expirationDate
            }
        } catch {
            print("Failed to restore purchases with RevenueCat: \(error.localizedDescription)")
            throw SubscriptionError.restoreFailed
        }
    }
    
    func presentSubscriptionSheet() {
        showPaywall = true
    }
    
    // For refreshing the subscription status
    func refreshSubscriptionStatus() async {
        await updateSubscriptionStatus()
    }
    
    // Check if offerings are available and properly configured
    func checkOfferingsConfiguration() async -> Bool {
        do {
            print("Checking RevenueCat offerings configuration...")
            let offerings = try await Purchases.shared.offerings()
            
            if let current = offerings.current {
                print("Current offering available: \(current.identifier)")
                print("Packages in offering: \(current.availablePackages.map { $0.identifier })")
                
                let hasMonthlyPackage = current.availablePackages.contains { 
                    $0.storeProduct.productIdentifier == monthlyProductID 
                }
                
                if hasMonthlyPackage {
                    print("Monthly package found with correct product ID")
                    await MainActor.run {
                        self.offeringsLoaded = true
                        self.errorLoadingOfferings = false
                    }
                    return true
                } else {
                    print("Monthly package not found or has incorrect product ID")
                    print("Expected product ID: \(monthlyProductID)")
                    print("Available product IDs: \(current.availablePackages.map { $0.storeProduct.productIdentifier })")
                    
                    await MainActor.run {
                        self.offeringsLoaded = false
                        self.errorLoadingOfferings = true
                    }
                    return false
                }
            } else {
                print("No current offering available")
                await MainActor.run {
                    self.offeringsLoaded = false
                    self.errorLoadingOfferings = true
                }
                return false
            }
        } catch {
            print("Error checking offerings: \(error.localizedDescription)")
            await MainActor.run {
                self.offeringsLoaded = false
                self.errorLoadingOfferings = true
            }
            return false
        }
    }
} 