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
    @Published var fallbackPricing: String = "$4.99" // Default fallback price
    
    // Flag to disable purchases during App Review
    // Set to false for release builds when products are in "Waiting for Review" status
    #if DEBUG
    @Published var isPurchasingEnabled = true
    #else
    @Published var isPurchasingEnabled = true // Set to false for App Store submissions until products are approved
    #endif
    
    // Cache offerings to avoid multiple requests
    private var cachedOfferings: Offerings?
    private var isLoadingOfferings = false
    private var didAttemptOfferingsLoad = false
    
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
            // Load StoreKit products first
            await loadProducts()
            
            // Then check subscription status
            await updateSubscriptionStatus()
            
            // Finally check offerings configuration - but only once
            if !didAttemptOfferingsLoad {
                await checkOfferingsConfiguration()
            }
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
        // Only configure if not already configured
        if Purchases.isConfigured {
            print("RevenueCat is already configured, skipping initialization")
            return
        }
        
        // Configure RevenueCat with API key
        Purchases.configure(withAPIKey: apiKey)
        
        // Enable debug logs to help troubleshoot
        #if DEBUG
        Purchases.logLevel = .debug
        #else
        Purchases.logLevel = .error
        #endif
        
        // Setup custom error handling to suppress offerings errors
        Purchases.logHandler = { level, message in
            // Filter out the offerings not configured errors that are expected during development
            if message.contains("There are no products registered in the RevenueCat dashboard for your offerings") {
                // Just ignore these messages completely
                return
            }
            
            // Log other messages as usual
            if level == .debug {
                #if DEBUG
                print("RC: \(message)")
                #endif
            } else if level == .error || level == .info {
                print("RevenueCat Error: \(message)")
            }
        }
        
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
            
            // Load fallback pricing if we have products
            if !availableProducts.isEmpty {
                await loadFallbackPricing()
            }
            
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
    
    // Check if offerings are available and properly configured
    func checkOfferingsConfiguration() async -> Bool {
        // If we already attempted to load offerings, use cached result
        if didAttemptOfferingsLoad {
            return !errorLoadingOfferings
        }
        
        // If we're already loading offerings, wait for it to complete
        if isLoadingOfferings {
            for _ in 0..<10 { // Try up to 10 times with short delay
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
                if didAttemptOfferingsLoad {
                    return !errorLoadingOfferings
                }
            }
        }
        
        // Mark that we're loading offerings
        isLoadingOfferings = true
        
        do {
            print("Checking RevenueCat offerings configuration...")
            
            // Use a timeout to prevent hanging on offering fetch
            let offerings = try await withThrowingTimeout(seconds: 5.0) {
                try await Purchases.shared.offerings()
            }
            
            // Cache the offerings for future use
            self.cachedOfferings = offerings
            
            // Check if we have the default offering configured
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
                        self.didAttemptOfferingsLoad = true
                        self.isLoadingOfferings = false
                    }
                    return true
                } else {
                    print("Monthly package not found or has incorrect product ID")
                    print("Expected product ID: \(monthlyProductID)")
                    print("Available product IDs: \(current.availablePackages.map { $0.storeProduct.productIdentifier })")
                    
                    // Even if package not found, still mark as loaded to avoid multiple errors
                    await MainActor.run {
                        self.offeringsLoaded = true
                        self.errorLoadingOfferings = true // Mark as error to use fallback
                        self.didAttemptOfferingsLoad = true
                        self.isLoadingOfferings = false
                    }
                    // Use StoreKit fallback pricing
                    await loadFallbackPricing()
                    return false
                }
            } else {
                print("No current offering available - using StoreKit fallback")
                // Mark as error to use fallback
                await MainActor.run {
                    self.offeringsLoaded = true
                    self.errorLoadingOfferings = true
                    self.didAttemptOfferingsLoad = true
                    self.isLoadingOfferings = false
                }
                await loadFallbackPricing()
                return false
            }
        } catch {
            print("Error checking offerings: \(error.localizedDescription)")
            // Mark as error to use fallback
            await MainActor.run {
                self.offeringsLoaded = true
                self.errorLoadingOfferings = true
                self.didAttemptOfferingsLoad = true
                self.isLoadingOfferings = false
            }
            await loadFallbackPricing()
            return false
        }
    }
    
    // Get cached offerings or load them if needed
    func getOfferings() async -> Offerings? {
        if let cached = cachedOfferings {
            return cached
        }
        
        // If we haven't loaded offerings yet, try to load them
        if !didAttemptOfferingsLoad {
            await checkOfferingsConfiguration()
        }
        
        return cachedOfferings
    }
    
    func purchaseSubscription(plan: SubscriptionPlan) async throws {
        let productID = plan.rawValue
        print("Attempting to purchase product: \(productID)")
        
        // Try RevenueCat first if we have offerings
        if let offerings = await getOfferings(), let offering = offerings.current {
            print("Using cached RevenueCat offerings")
            
            if let package = offering.availablePackages.first(where: { $0.storeProduct.productIdentifier == productID }) {
                print("Found matching package: \(package.identifier) with product ID: \(package.storeProduct.productIdentifier)")
                
                do {
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
                } catch {
                    print("RevenueCat purchase failed: \(error.localizedDescription)")
                    // Fall through to StoreKit approach as fallback
                }
            } else {
                print("No matching package found for product ID: \(productID)")
                // Fall through to StoreKit approach as fallback
            }
        } else {
            print("No RevenueCat offerings available, using StoreKit directly")
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
    
    // New function to load fallback pricing from StoreKit directly
    private func loadFallbackPricing() async {
        if availableProducts.isEmpty {
            await loadProducts() // Make sure products are loaded
        }
        
        if let product = availableProducts.first(where: { $0.id == monthlyProductID }) {
            // Use the StoreKit price
            await MainActor.run {
                self.fallbackPricing = product.displayPrice
            }
            print("Using StoreKit fallback pricing: \(product.displayPrice)")
        } else {
            // Keep default fallback price
            print("No StoreKit product available either, using hardcoded fallback price")
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
    
    // Helper function to add timeout to RevenueCat operations
    private func withTimeout<T>(seconds: TimeInterval, task: Task<T, Error>) async throws -> T {
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            task.cancel()
            throw SubscriptionError.timeout
        }
        
        do {
            let result = try await task.value
            timeoutTask.cancel()
            return result
        } catch {
            timeoutTask.cancel()
            throw error
        }
    }
    
    // Add a timeout to any throwing async call
    private func withThrowingTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        let task = Task {
            try await operation()
        }
        
        return try await withTimeout(seconds: seconds, task: task)
    }
} 