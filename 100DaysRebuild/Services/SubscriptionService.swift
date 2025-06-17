import Foundation
import StoreKit
import RevenueCat
import FirebaseAuth

@MainActor
class SubscriptionService: NSObject, ObservableObject {
    static let shared = SubscriptionService()
    
    @Published private(set) var isProUser: Bool = false
    @Published private(set) var availableProducts: [Product] = []
    @Published private(set) var renewalDate: Date?
    @Published var showPaywall = false
    @Published var errorLoadingOfferings = false
    @Published var offeringsLoaded = false
    @Published var fallbackPricing: String = "$5.99" // Updated fallback price
    
    // Add a property to track the current RevenueCat user ID
    @Published private(set) var currentRevenueCatUID: String = ""
    
    // Flag to disable purchases during App Review
    @Published var isPurchasingEnabled = true
    
    // Cache offerings to avoid multiple requests
    private var cachedOfferings: Offerings?
    private var isLoadingOfferings = false
    private var didAttemptOfferingsLoad = false
    
    // Add retry logic for offerings
    private var offeringsRetryCount = 0
    private let maxOfferingsRetries = 3
    
    // RevenueCat API key
    private var apiKey: String {
        // Production SDK API key (not secret key)
        return "appl_BmXAuCdWBmPoVBAOgxODhJddUvc"
    }
    
    // Product identifiers
    private let monthlyProductID = "com.KhamariThompson.100Days.monthlyv2"
    
    @Published private(set) var offerings: Offerings?
    @Published private(set) var customerInfo: CustomerInfo?
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?
    
    private var products: [Product] = []
    private let productIds = ["com.KhamariThompson.100Days.monthlyv2"]
    
    // Add property to track deleted account cases
    @Published var isDeletedAccountDetected: Bool = false
    @Published var lastRestoreError: SubscriptionError?
    @Published var showRestoreErrorAlert: Bool = false
    
    // Add properties for offline mode and receipt expiration
    @Published private(set) var isOfflineMode: Bool = false
    @Published private(set) var subscriptionExpirationDate: Date?
    @Published private(set) var subscriptionRenewalIssue: Bool = false
    
    // Timer for periodic receipt refresh
    private var receiptRefreshTimer: Timer?
    
    // Class property near the top with other properties
    @Published private var needsForcedPurchaseSync: Bool = false
    
    private override init() {
        // Call super.init() first before using self
        super.init()
        
        // Configure custom error handling
        setupRevenueCatErrorHandling()
        
        // Add observer for deleted account cases
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSubscriptionStatusChange),
            name: NSNotification.Name("SubscriptionStatusChanged"),
            object: nil
        )
        
        // Add observer for app state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        // Add observer for network status changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNetworkStatusChange),
            name: NSNotification.Name("NetworkStatusChanged"),
            object: nil
        )
        
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
        
        // Schedule periodic receipt refresh
        scheduleReceiptRefresh()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        receiptRefreshTimer?.invalidate()
        print("✅ Singleton released: \(Self.self)")
    }
    
    @objc private func handleAuthStateChanged() {
        Task {
            await identifyCurrentUser()
            await updateSubscriptionStatus()
        }
    }
    
    // Add method to set up custom error handling for RevenueCat
    private func setupRevenueCatErrorHandling() {
        #if DEBUG
        print("Configuring RevenueCat error handling...")
        #endif
        
        // This will be called by the RevenueCat SDK after configure
        Purchases.logHandler = { level, message in
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
    }
    
    // Public method to identify the current user with RevenueCat
    func identifyCurrentUser() async {
        if let currentUser = Auth.auth().currentUser {
            do {
                #if DEBUG
                print("🔐 RevenueCat: Identifying user with RevenueCat: \(currentUser.uid)")
                print("🔐 RevenueCat: Previous appUserID: \(Purchases.shared.appUserID)")
                #endif
                
                // IMPORTANT: Before attempting to login, check if we're already logged in
                // with the correct user ID to avoid unnecessary API calls
                if Purchases.shared.appUserID == currentUser.uid {
                    print("🔐 RevenueCat: User already identified with correct UID: \(currentUser.uid)")
                    // Still update subscription status to be safe
                    await updateSubscriptionStatus()
                    return
                }
                
                // First reset Pro status before logging in with a new user
                await MainActor.run {
                    if self.isProUser {
                        print("🔐 RevenueCat: Resetting Pro status before identifying new user")
                        self.isProUser = false
                        self.renewalDate = nil
                        
                        // Clear cached data for security
                        UserDefaults.standard.removeObject(forKey: "cachedProStatus")
                        UserDefaults.standard.removeObject(forKey: "cachedExpirationDate")
                    }
                }
                
                // Use Firebase UID as RevenueCat user identifier
                let loginResult = try await Purchases.shared.logIn(currentUser.uid)
                
                // Store the current RevenueCat user ID
                self.currentRevenueCatUID = currentUser.uid
                
                // Check if a transfer occurred (.created = false means a transfer happened)
                let transferOccurred = !loginResult.created
                if transferOccurred {
                    print("🔐 RevenueCat: ✅ Detected subscription transfer during identification!")
                    print("🔐 RevenueCat: Original AppUserID: \(loginResult.customerInfo.originalAppUserId)")
                    print("🔐 RevenueCat: This indicates a migration from anonymous → identified user")
                    
                    // Post notification about the migration
                    NotificationCenter.default.post(
                        name: NSNotification.Name("SubscriptionMigrationCompleted"),
                        object: nil,
                        userInfo: ["originalAppUserId": loginResult.customerInfo.originalAppUserId]
                    )
                }
                
                #if DEBUG
                print("🔐 RevenueCat: User successfully identified with UID: \(currentUser.uid)")
                print("🔐 RevenueCat: Original AppUserID: \(loginResult.customerInfo.originalAppUserId)")
                print("🔐 RevenueCat: Current AppUserID: \(Purchases.shared.appUserID)")
                print("🔐 RevenueCat: Transfer occurred: \(transferOccurred)")
                #endif
                
                // Explicitly sync purchases with RevenueCat after login to ensure receipt is associated with correct user
                print("🔐 RevenueCat: Explicitly syncing purchases after user identification")
                try await syncPurchasesWithRetry(maxRetries: 3)
                
                // Get updated customer info after sync
                let updatedCustomerInfo = try await Purchases.shared.customerInfo()
                print("🔐 RevenueCat: After sync - entitlements: \(updatedCustomerInfo.entitlements.active.keys.joined(separator: ", "))")
                if !updatedCustomerInfo.activeSubscriptions.isEmpty {
                    print("🔐 RevenueCat: After sync - active subscriptions: \(updatedCustomerInfo.activeSubscriptions.joined(separator: ", "))")
                }
                
                // Verify that the original purchaser matches the current user before granting Pro
                let originalAppUserId = updatedCustomerInfo.originalAppUserId
                let validPurchaser = originalAppUserId.isEmpty || originalAppUserId == currentUser.uid
                
                if !validPurchaser {
                    print("🔐 RevenueCat: ⚠️ Original purchaser (\(originalAppUserId)) doesn't match current user (\(currentUser.uid))")
                    
                    // If there's a mismatch, ensure Pro is disabled
                    await MainActor.run {
                        self.isProUser = false
                        self.renewalDate = nil
                        
                        // Clear cached data for security
                        UserDefaults.standard.removeObject(forKey: "cachedProStatus")
                        UserDefaults.standard.removeObject(forKey: "cachedExpirationDate")
                        
                        // Notify about subscription status change
                        NotificationCenter.default.post(
                            name: NSNotification.Name("SubscriptionStatusChanged"),
                            object: nil,
                            userInfo: ["isProUser": false]
                        )
                    }
                    return
                }
                
                // Update pro status based on latest customer info for this specific user
                let activeEntitlements = updatedCustomerInfo.entitlements.active
                let hasPro = activeEntitlements["Pro"]?.isActive ?? false
                
                #if DEBUG
                print("🔐 RevenueCat: Firebase UID \(currentUser.uid) has Pro entitlement: \(hasPro)")
                // Add debug logs for entitlements
                print("🔐 RevenueCat: Active entitlements: \(activeEntitlements)")
                #endif
                
                // Only update if this user has their own Pro subscription
                self.isProUser = hasPro
                self.renewalDate = activeEntitlements["Pro"]?.expirationDate
                
                // Cache the subscription status for offline use
                UserDefaults.standard.set(hasPro, forKey: "cachedProStatus")
                UserDefaults.standard.set(self.renewalDate, forKey: "cachedExpirationDate")
                
                // Notify the app about the subscription status change
                NotificationCenter.default.post(
                    name: NSNotification.Name("SubscriptionStatusChanged"),
                    object: nil,
                    userInfo: ["isProUser": hasPro]
                )
            } catch {
                #if DEBUG
                print("🔐 RevenueCat: Failed to identify user with RevenueCat: \(error.localizedDescription)")
                #else
                print("🔐 RevenueCat: Failed to identify user with RevenueCat")
                #endif
                
                // On error, ensure we reset Pro status to match the current user's actual entitlements
                await updateSubscriptionStatus()
            }
        } else {
            #if DEBUG
            print("🔐 RevenueCat: No Firebase user to identify with RevenueCat")
            #endif
            await updateSubscriptionStatus(forceReset: true)
        }
    }
    
    private func listenForTransactions() {
        // Listen for StoreKit transaction updates
        Task {
            do {
                for await result in Transaction.updates {
                    if case .verified(let transaction) = result {
                        print("Transaction verified: \(transaction.productID)")
                        // Always finish the transaction after handling
                        await transaction.finish()
                        
                        // Update subscription status
                        await updateSubscriptionStatus()
                    }
                }
            } catch {
                // Handle "No active account" error
                if let nsError = error as? NSError, nsError.domain == "ASDErrorDomain", nsError.code == 509 {
                    print("StoreKit: No active account, ignoring.")
                } else {
                    print("Unhandled transaction error: \(error.localizedDescription)")
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
            } else {
                // Use default fallback pricing since no products are available
                print("No StoreKit product available either, using hardcoded fallback price")
                self.fallbackPricing = "$4.99"
            }
            
            // Log available products for debug
            for product in availableProducts {
                print("StoreKit Product: \(product.id) - \(product.displayName)")
            }
        } catch {
            print("Failed to load products: \(error.localizedDescription)")
            self.fallbackPricing = "$4.99" // Fallback price if products can't be loaded
        }
    }
    
    // Make the method public so it can be called from MainAppViewModel
    func updateSubscriptionStatus(forceReset: Bool = false, forceVerification: Bool = false) async {
        isLoading = true
        error = nil
        
        // Debug receipt environment info
        if let receiptURL = Bundle.main.appStoreReceiptURL {
            let isSandboxReceipt = receiptURL.lastPathComponent == "sandboxReceipt"
            print("🔐 RevenueCat: Using \(isSandboxReceipt ? "SANDBOX" : "PRODUCTION") receipt")
        }
        
        // Get the current Firebase UID for strict validation
        let currentFirebaseUID = Auth.auth().currentUser?.uid
        
        // If no Firebase user or force reset requested, ensure Pro is disabled
        if currentFirebaseUID == nil || forceReset {
            await MainActor.run {
                if self.isProUser {
                    #if DEBUG
                    print("🔐 RevenueCat: Resetting Pro status to false (no Firebase user or force reset)")
                    #endif
                    self.isProUser = false
                    self.renewalDate = nil
                    
                    // Clear cached data for security
                    UserDefaults.standard.removeObject(forKey: "cachedProStatus")
                    UserDefaults.standard.removeObject(forKey: "cachedExpirationDate")
                    
                    // Notify about subscription status change
                    NotificationCenter.default.post(
                        name: NSNotification.Name("SubscriptionStatusChanged"),
                        object: nil,
                        userInfo: ["isProUser": false]
                    )
                }
            }
            
            isLoading = false
            return
        }
        
        // Check for network connectivity
        if NetworkMonitor.shared.isConnected == false {
            #if DEBUG
            print("🔐 RevenueCat: Network offline, using cached subscription status")
            #endif
            
            // Load from cache
            let cachedProStatus = UserDefaults.standard.bool(forKey: "cachedProStatus")
            let cachedExpirationDate = UserDefaults.standard.object(forKey: "cachedExpirationDate") as? Date
            
            await MainActor.run {
                self.isOfflineMode = true
                
                // Check if the cached subscription has expired
                if let expirationDate = cachedExpirationDate, expirationDate < Date(), self.isProUser {
                    #if DEBUG
                    print("🔐 RevenueCat: Cached subscription has expired while offline")
                    #endif
                    self.isProUser = false
                    self.renewalDate = nil
                    
                    // Notify about subscription status change
                    NotificationCenter.default.post(
                        name: NSNotification.Name("SubscriptionStatusChanged"),
                        object: nil,
                        userInfo: ["isProUser": false]
                    )
                }
                // Update if status doesn't match cache
                else if self.isProUser != cachedProStatus {
                    #if DEBUG
                    print("🔐 RevenueCat: Using cached Pro status: \(cachedProStatus)")
                    #endif
                    self.isProUser = cachedProStatus
                    self.renewalDate = cachedExpirationDate
                    
                    // Notify about subscription status change
                    NotificationCenter.default.post(
                        name: NSNotification.Name("SubscriptionStatusChanged"),
                        object: nil,
                        userInfo: ["isProUser": cachedProStatus]
                    )
                }
            }
            
            isLoading = false
            return
        } else {
            // Online mode
            await MainActor.run {
                self.isOfflineMode = false
            }
        }
        
        do {
            // If a forced sync is needed (like after a user switch), do it now
            if needsForcedPurchaseSync || forceVerification {
                print("🔐 RevenueCat: Forced sync requested during subscription status update")
                try await syncPurchasesWithRetry(maxRetries: 3)
                needsForcedPurchaseSync = false // Reset the flag after sync
                
                // If we're doing a force verification, also verify original purchaser ID
                if forceVerification {
                    print("🔐 RevenueCat: Performing force verification of original purchaser")
                    let customerInfo = try await Purchases.shared.customerInfo()
                    
                    // Check for mismatch between original purchaser and current user
                    if !customerInfo.originalAppUserId.isEmpty && 
                       customerInfo.originalAppUserId != currentFirebaseUID {
                        print("🔐 RevenueCat: Original purchaser mismatch detected during force verification")
                        print("🔐 RevenueCat: Original: \(customerInfo.originalAppUserId), Current: \(currentFirebaseUID ?? "none")")
                        
                        // Reset Pro status if there's a mismatch
                        await MainActor.run {
                            if self.isProUser {
                                self.isProUser = false
                                self.renewalDate = nil
                                
                                // Clear cached data
                                UserDefaults.standard.removeObject(forKey: "cachedProStatus")
                                UserDefaults.standard.removeObject(forKey: "cachedExpirationDate")
                                
                                // Notify about subscription status change
                                NotificationCenter.default.post(
                                    name: NSNotification.Name("SubscriptionStatusChanged"),
                                    object: nil,
                                    userInfo: ["isProUser": false]
                                )
                            }
                        }
                        // Skip further processing
                        isLoading = false
                        return
                    }
                }
            }
            
            // First check if the current RevenueCat user ID matches the Firebase UID
            let currentAppUserID = Purchases.shared.appUserID
            print("🔐 RevenueCat: Checking subscription status for Firebase UID: \(currentFirebaseUID ?? "none")")
            print("🔐 RevenueCat: Current AppUserID: \(currentAppUserID)")
            
            // If the IDs don't match, reset Pro status and re-identify user with Firebase UID
            if currentAppUserID != currentFirebaseUID {
                print("🔐 RevenueCat: AppUserID mismatch. Re-identifying user with Firebase UID")
                
                // Reset Pro status immediately when mismatch is detected
                await MainActor.run {
                    if self.isProUser {
                        print("🔐 RevenueCat: Resetting Pro status due to user mismatch")
                        self.isProUser = false
                        self.renewalDate = nil
                        
                        // Clear cached data for security
                        UserDefaults.standard.removeObject(forKey: "cachedProStatus")
                        UserDefaults.standard.removeObject(forKey: "cachedExpirationDate")
                        
                        // Notify about subscription status change
                        NotificationCenter.default.post(
                            name: NSNotification.Name("SubscriptionStatusChanged"),
                            object: nil,
                            userInfo: ["isProUser": false]
                        )
                    }
                }
                
                // Re-identify with the current Firebase UID
                if let uid = currentFirebaseUID {
                    let loginResult = try await Purchases.shared.logIn(uid)
                    print("🔐 RevenueCat: Re-identified user. New AppUserID: \(Purchases.shared.appUserID)")
                    
                    // Update stored RevenueCat user ID
                    self.currentRevenueCatUID = uid
                    
                    // Get customer info from the login result
                    let customerInfo = loginResult.customerInfo
                    self.customerInfo = customerInfo
                    
                    // Validate that the originalAppUserId matches current Firebase UID
                    let originalAppUserId = customerInfo.originalAppUserId
                    print("🔐 RevenueCat: Original AppUserID: \(originalAppUserId)")
                    
                    let validPurchaser = originalAppUserId == uid
                    if !validPurchaser {
                        print("🔐 RevenueCat: ⚠️ Original purchaser (\(originalAppUserId)) doesn't match current user (\(uid))")
                        
                        // If originalAppUserId doesn't match, keep Pro disabled
                        await MainActor.run {
                            self.isProUser = false
                            self.renewalDate = nil
                            
                            // Clear cached data for security
                            UserDefaults.standard.removeObject(forKey: "cachedProStatus")
                            UserDefaults.standard.removeObject(forKey: "cachedExpirationDate")
                        }
                        
                        isLoading = false
                        return
                    }
                    
                    // Check active entitlements for this specific Firebase user
                    let activeEntitlements = customerInfo.entitlements.active
                    let hasPro = activeEntitlements["Pro"]?.isActive ?? false
                    self.renewalDate = activeEntitlements["Pro"]?.expirationDate
                    
                    print("🔐 RevenueCat: Firebase UID \(uid) has Pro entitlement: \(hasPro)")
                    print("🔐 RevenueCat: All entitlements: \(customerInfo.entitlements.all)")
                    
                    // Check for expiration date and potential renewal issues
                    checkSubscriptionExpirationStatus(customerInfo: customerInfo)
                    
                    // Update Pro status only based on this user's entitlements
                    if self.isProUser != hasPro {
                        self.isProUser = hasPro
                        
                        // Cache the subscription status for offline use
                        UserDefaults.standard.set(hasPro, forKey: "cachedProStatus")
                        UserDefaults.standard.set(self.renewalDate, forKey: "cachedExpirationDate")
                        
                        // Notify about subscription status change
                        NotificationCenter.default.post(
                            name: NSNotification.Name("SubscriptionStatusChanged"),
                            object: nil,
                            userInfo: ["isProUser": hasPro]
                        )
                    }
                    
                    isLoading = false
                    return
                }
            }
            
            // If IDs match, check RevenueCat for entitlements for this specific user
            let customerInfo = try await Purchases.shared.customerInfo()
            self.customerInfo = customerInfo
            
            print("🔐 RevenueCat: Customer Info - Original AppUserID: \(customerInfo.originalAppUserId)")
            print("🔐 RevenueCat: Customer Info - Current AppUserID: \(Purchases.shared.appUserID)")
            print("🔐 RevenueCat: Firebase User ID: \(currentFirebaseUID ?? "none")")
            print("🔐 RevenueCat: All entitlements: \(customerInfo.entitlements.all)")
            
            // Only check entitlements if the current RevenueCat user matches the Firebase user
            // AND the original purchaser matches the current Firebase user
            if Purchases.shared.appUserID == currentFirebaseUID && 
               customerInfo.originalAppUserId == currentFirebaseUID {
                
                // Check active entitlements - looking specifically for "Pro" entitlement
                let activeEntitlements = customerInfo.entitlements.active
                let hasPro = activeEntitlements["Pro"]?.isActive ?? false
                self.renewalDate = activeEntitlements["Pro"]?.expirationDate
                
                // Check for expiration date and potential renewal issues
                checkSubscriptionExpirationStatus(customerInfo: customerInfo)
                
                print("🔐 RevenueCat: Firebase UID \(currentFirebaseUID!) has Pro entitlement: \(hasPro)")
                
                // Cache the subscription status for offline use
                UserDefaults.standard.set(hasPro, forKey: "cachedProStatus")
                UserDefaults.standard.set(self.renewalDate, forKey: "cachedExpirationDate")
            
                // Only update published property if there's a change to avoid UI flicker
                if self.isProUser != hasPro {
                    print("🔐 RevenueCat: Updating Pro status for Firebase UID \(currentFirebaseUID!): \(hasPro)")
                    self.isProUser = hasPro
                    
                    // Notify about subscription status change
                    NotificationCenter.default.post(
                        name: NSNotification.Name("SubscriptionStatusChanged"),
                        object: nil,
                        userInfo: ["isProUser": hasPro]
                    )
                }
            } else {
                // If the IDs don't match, or original purchaser doesn't match current user,
                // force the user to non-Pro
                if customerInfo.originalAppUserId != currentFirebaseUID {
                    print("🔐 RevenueCat: Original purchaser (\(customerInfo.originalAppUserId)) doesn't match current user (\(currentFirebaseUID!))")
                } else {
                    print("🔐 RevenueCat: AppUserID mismatch. Current: \(Purchases.shared.appUserID), Firebase: \(currentFirebaseUID!)")
                }
                print("🔐 RevenueCat: Resetting Pro status to false due to user mismatch")
                
                // Reset Pro status
                if self.isProUser {
                    self.isProUser = false
                    self.renewalDate = nil
                    
                    // Clear cached data for security
                    UserDefaults.standard.removeObject(forKey: "cachedProStatus")
                    UserDefaults.standard.removeObject(forKey: "cachedExpirationDate")
                    
                    // Notify about subscription status change
                    NotificationCenter.default.post(
                        name: NSNotification.Name("SubscriptionStatusChanged"),
                        object: nil,
                        userInfo: ["isProUser": false]
                    )
                }
            }
            
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
            print("🔐 RevenueCat: Error updating subscription status: \(error.localizedDescription)")
            
            // On error, try to use cached data if available
            if let cachedProStatus = UserDefaults.standard.object(forKey: "cachedProStatus") as? Bool,
               let cachedExpirationDate = UserDefaults.standard.object(forKey: "cachedExpirationDate") as? Date,
               cachedExpirationDate > Date() { // Make sure it hasn't expired
                print("🔐 RevenueCat: Using cached subscription status due to error: \(cachedProStatus)")
                if self.isProUser != cachedProStatus {
                    self.isProUser = cachedProStatus
                    self.renewalDate = cachedExpirationDate
                    
                    // Notify about subscription status change
                    NotificationCenter.default.post(
                        name: NSNotification.Name("SubscriptionStatusChanged"),
                        object: nil,
                        userInfo: ["isProUser": cachedProStatus]
                    )
                }
            } else {
                // No valid cached data, ensure Pro is disabled on error
                if self.isProUser {
                    self.isProUser = false
                    self.renewalDate = nil
                    
                    // Notify about subscription status change
                    NotificationCenter.default.post(
                        name: NSNotification.Name("SubscriptionStatusChanged"),
                        object: nil,
                        userInfo: ["isProUser": false]
                    )
                }
            }
        }
        
        // Always set loading to false when done
        await MainActor.run {
            isLoading = false
        }
    }
    
    // Check for subscription expiration and renewal issues
    private func checkSubscriptionExpirationStatus(customerInfo: CustomerInfo) {
        // Check for Pro entitlement
        if let proEntitlement = customerInfo.entitlements["Pro"], proEntitlement.isActive {
            // Store the expiration date
            self.subscriptionExpirationDate = proEntitlement.expirationDate
            
            // Check if expiring soon (within 3 days)
            if let expirationDate = proEntitlement.expirationDate, 
               expirationDate < Date().addingTimeInterval(3 * 24 * 60 * 60) {
                print("🔐 RevenueCat: Subscription expires soon: \(expirationDate)")
            }
            
            // Check for billing issues
            if let renewalStatus = proEntitlement.billingIssueDetectedAt,
               renewalStatus > Date().addingTimeInterval(-30 * 24 * 60 * 60) { // Within the last 30 days
                print("🔐 RevenueCat: Billing issue detected at: \(renewalStatus)")
                self.subscriptionRenewalIssue = true
                
                // Notify about renewal issue
                NotificationCenter.default.post(
                    name: NSNotification.Name("SubscriptionRenewalIssue"),
                    object: nil
                )
            } else {
                self.subscriptionRenewalIssue = false
            }
        } else {
            self.subscriptionExpirationDate = nil
            self.subscriptionRenewalIssue = false
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
            
            // Validate offering identifiers against expected values
            let expectedOfferingId = "default_offerings"
            let expectedEntitlementId = "Pro"
            
            // Check if we have the default offering configured
            if let current = offerings.current {
                print("Current offering available: \(current.identifier)")
                print("Packages in offering: \(current.availablePackages.map { $0.identifier })")
                
                // Validate offering ID matches expected
                if current.identifier != expectedOfferingId {
                    print("Warning: Current offering ID (\(current.identifier)) doesn't match expected (\(expectedOfferingId))")
                }
                
                // Check for monthly package
                let hasMonthlyPackage = current.availablePackages.contains { 
                    $0.storeProduct.productIdentifier == monthlyProductID 
                }
                
                if hasMonthlyPackage {
                    print("Monthly package found with correct product ID")
                    
                    // Validate entitlement ID
                    if let customerInfo = try? await Purchases.shared.customerInfo() {
                        print("Checking entitlements: \(customerInfo.entitlements.all)")
                        
                        if !customerInfo.entitlements.all.keys.contains(expectedEntitlementId) {
                            print("Warning: Entitlement ID 'Pro' not found in customer info. Available entitlements: \(customerInfo.entitlements.all.keys.joined(separator: ", "))")
                        // Continue anyway as this might be normal for non-subscribers
                        } else {
                            print("✅ Found expected entitlement: \(expectedEntitlementId)")
                        }
                    }
                    
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
                await retryOfferingsOrLoadFallback()
                return false
            }
        } catch {
            print("Error checking offerings: \(error.localizedDescription)")
            await retryOfferingsOrLoadFallback()
            return false
        }
    }
    
    // New method to retry offerings load or use fallback
    private func retryOfferingsOrLoadFallback() async {
        offeringsRetryCount += 1
        
        if offeringsRetryCount < maxOfferingsRetries {
            print("Retrying offerings load (attempt \(offeringsRetryCount)/\(maxOfferingsRetries))...")
            
            // Wait before retry
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            // Reset state for retry
            isLoadingOfferings = false
            didAttemptOfferingsLoad = false
            
            // Try again
            let _ = await checkOfferingsConfiguration()
        } else {
            // Mark as error to use fallback after max retries
            await MainActor.run {
                self.offeringsLoaded = true
                self.errorLoadingOfferings = true
                self.didAttemptOfferingsLoad = true
                self.isLoadingOfferings = false
            }
            // Use StoreKit fallback pricing
            await loadFallbackPricing()
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
        // Add environment verification at the beginning
        print("🔐 RevenueCat: Verifying environment for purchase")
        let receiptURL = Bundle.main.appStoreReceiptURL
        let isSandboxReceipt = receiptURL?.lastPathComponent == "sandboxReceipt"
        print("🔐 RevenueCat: Using \(isSandboxReceipt ? "SANDBOX" : "PRODUCTION") receipt")
        print("🔐 RevenueCat: Current app bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")")
        
        guard isPurchasingEnabled else {
            // Skip if purchases are disabled for App Review
            return
        }
        
        guard let currentUser = Auth.auth().currentUser else {
            throw SubscriptionError.userNotSignedIn
        }
        
        #if DEBUG
        print("🔐 RevenueCat: Starting purchase for \(plan.productId) - current user: \(currentUser.uid)")
        print("🔐 RevenueCat: Current appUserID: \(Purchases.shared.appUserID)")
        #endif
        
        // If the user isn't properly identified with RevenueCat, identify them first
        if Purchases.shared.appUserID != currentUser.uid {
            do {
                #if DEBUG
                print("🔐 RevenueCat: Re-identifying user before purchase")
                #endif
                
                let loginResult = try await Purchases.shared.logIn(currentUser.uid)
                
                // Check if a transfer occurred during login
                let transferOccurred = !loginResult.created
                if transferOccurred {
                    print("🔐 RevenueCat: ✅ Subscription transferred during pre-purchase identification")
                    print("🔐 RevenueCat: Original AppUserID: \(loginResult.customerInfo.originalAppUserId)")
                    
                    // Force sync purchases after transfer
                    try await Purchases.shared.syncPurchases()
                    print("🔐 RevenueCat: Synced purchases after subscription transfer")
                    
                    // Check if user already has Pro after the transfer
                    let customerInfo = try await Purchases.shared.customerInfo()
                    let hasProAfterTransfer = customerInfo.entitlements["Pro"]?.isActive ?? false
                    
                    if hasProAfterTransfer {
                        print("🔐 RevenueCat: User already has Pro after subscription transfer")
                        
                        // Update subscription status
                        await updateSubscriptionStatus()
                        
                        // If they already have Pro, we don't need to continue with purchase
                        isLoading = false
                        return
                    }
                }
                
                #if DEBUG
                print("🔐 RevenueCat: User successfully identified with UID: \(currentUser.uid)")
                print("🔐 RevenueCat: Original AppUserID: \(loginResult.customerInfo.originalAppUserId)")
                #endif
            } catch {
                #if DEBUG
                print("🔐 RevenueCat: Failed to identify user before purchase: \(error.localizedDescription)")
                #endif
                throw SubscriptionError.purchaseFailed
            }
        }
        
        isLoading = true
        error = nil
        
        let productID = plan.productId
        let timeoutSeconds: TimeInterval = 30 // 30 second timeout
        
        // Create a timeout task that will automatically cancel the purchase after the timeout
        let purchaseTimeout = Task {
            try await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
            print("🔐 RevenueCat: Purchase timed out after \(timeoutSeconds) seconds")
            throw SubscriptionError.timeout
        }
        
        do {
            // First ensure we have offerings available
            if offerings == nil {
                print("🔐 RevenueCat: Loading offerings before purchase")
                offerings = try await Purchases.shared.offerings()
            }
            
            // Check if we have valid offerings
            if let offerings = offerings, let current = offerings.current {
                print("🔐 RevenueCat: Using offerings - current identifier: \(current.identifier)")
                
                // Find the package that matches our product ID
                if let package = current.package(identifier: productID) ?? current.availablePackages.first(where: { $0.storeProduct.productIdentifier == productID }) {
                    print("🔐 RevenueCat: Found matching package for product ID: \(productID)")
                    
                    do {
                        // Attempt the purchase using RevenueCat
                        print("🔐 RevenueCat: Starting purchase with package: \(package.identifier)")
                        let purchaseResult = try await Purchases.shared.purchase(package: package)
                        
                        // Purchase succeeded - cancel the timeout task
                        purchaseTimeout.cancel()
                        
                        // Extract data from the result
                        let customerInfo = purchaseResult.customerInfo
                        
                        print("🔐 RevenueCat: Purchase successful - entitlements: \(customerInfo.entitlements.active.keys.joined(separator: ", "))")
                        
                        // Explicitly sync purchases with RevenueCat to ensure receipt is properly recorded
                        print("🔐 RevenueCat: Explicitly syncing purchases with RevenueCat after successful purchase")
                        try await syncPurchasesWithRetry(maxRetries: 3)
                        
                        // Get updated customer info after sync
                        let updatedCustomerInfo = try await Purchases.shared.customerInfo()
                        print("🔐 RevenueCat: After sync - entitlements: \(updatedCustomerInfo.entitlements.active.keys.joined(separator: ", "))")
                        print("🔐 RevenueCat: After sync - active subscriptions: \(updatedCustomerInfo.activeSubscriptions.joined(separator: ", "))")
                        print("🔐 RevenueCat: After sync - originalAppUserId: \(updatedCustomerInfo.originalAppUserId)")
                        
                        // Update pro status from result
                        await MainActor.run {
                            let activeEntitlements = updatedCustomerInfo.entitlements.active
                            self.isProUser = activeEntitlements["Pro"]?.isActive ?? false
                            self.renewalDate = activeEntitlements["Pro"]?.expirationDate
                            
                            // Cache the subscription status for offline use
                            UserDefaults.standard.set(self.isProUser, forKey: "cachedProStatus")
                            UserDefaults.standard.set(self.renewalDate, forKey: "cachedExpirationDate")
                            
                            // Post notification for subscription change
                            NotificationCenter.default.post(
                                name: NSNotification.Name("SubscriptionStatusChanged"),
                                object: nil,
                                userInfo: ["isProUser": self.isProUser]
                            )
                        }
                        
                        // Purchase succeeded
                        return
                    } catch {
                        // Handle RevenueCat purchase errors
                        purchaseTimeout.cancel()
                        
                        let nsError = error as NSError
                        if nsError.domain == "ASDErrorDomain" && nsError.code == 509 {
                            print("🔐 RevenueCat: User not signed into App Store")
                            throw SubscriptionError.notSignedIntoAppStore
                        } else if error.localizedDescription.contains("cancelled") || error.localizedDescription.contains("canceled") {
                            // Check for cancellation in the error description
                            print("🔐 RevenueCat: User cancelled the purchase")
                            throw SubscriptionError.userCancelled
                        } else if nsError.domain == "RevenueCat.ErrorCode" {
                            // Check RevenueCat error codes
                            let errorCode = nsError.code
                            
                            if errorCode == 7 { // Payment Pending
                                throw SubscriptionError.purchasePending
                            } else if errorCode == 5 { // Receipt Already In Use
                                throw SubscriptionError.receiptInUse
                            } else if errorCode == 6 { // Unknown
                                print("🔐 RevenueCat: Unknown RevenueCat error: \(nsError)")
                                throw SubscriptionError.unknown
                            } else {
                                print("🔐 RevenueCat: Other RevenueCat error: \(nsError)")
                                throw SubscriptionError.purchaseFailed
                            }
                        } else {
                            print("🔐 RevenueCat: Purchase failed with error: \(error.localizedDescription)")
                            throw SubscriptionError.purchaseFailed
                        }
                    }
                } else {
                    purchaseTimeout.cancel()
                    print("🔐 RevenueCat: No matching package found for product ID: \(productID)")
                    throw SubscriptionError.productNotFound
                }
            } else {
                purchaseTimeout.cancel()
                print("🔐 RevenueCat: No offerings available")
                throw SubscriptionError.productNotFound
            }
        } catch {
            // Cancel the timeout task if any other error occurred
            purchaseTimeout.cancel()
            
            // Re-throw appropriate error
            if let subscriptionError = error as? SubscriptionError {
                throw subscriptionError
            } else if error is CancellationError {
                throw SubscriptionError.timeout
            } else {
                throw SubscriptionError.purchaseFailed
            }
        }
    }
    
    // New function to load fallback pricing from StoreKit directly
    private func loadFallbackPricing() async {
        if availableProducts.isEmpty {
            await loadProducts() // Make sure products are loaded
        }
        
        if let monthlyProduct = availableProducts.first(where: { $0.id == monthlyProductID }) {
            // Use StoreKit product price
            self.fallbackPricing = monthlyProduct.displayPrice
        } else {
            // Fallback to updated hardcoded price if no StoreKit product is available
            self.fallbackPricing = "$5.99"
            #if DEBUG
            print("No StoreKit products available, using hardcoded price: \(self.fallbackPricing)")
            #endif
        }
    }
    
    // MARK: - Restore Purchases
    
    /// Restore purchases and sync with RevenueCat
    func restorePurchases() async throws {
        guard isPurchasingEnabled else {
            // Skip if purchases are disabled for App Review
            return
        }
        
        guard let currentUser = Auth.auth().currentUser else {
            throw SubscriptionError.userNotSignedIn
        }
        
        #if DEBUG
        print("🔐 RevenueCat: Starting purchase restore")
        print("🔐 RevenueCat: Firebase UID: \(currentUser.uid)")
        print("🔐 RevenueCat: Current AppUserID: \(Purchases.shared.appUserID)")
        #endif
        
        isLoading = true
        error = nil
        lastRestoreError = nil
        
        // First make sure we have our Firebase user ID synced with RevenueCat
        if Purchases.shared.appUserID != currentUser.uid {
            print("🔐 RevenueCat: AppUserID mismatch during restore. Attempting migration first")
            
            // Try explicit migration before restore
            let migrationOccurred = await migrateAnonymousSubscription()
            print("🔐 RevenueCat: Pre-restore migration result: \(migrationOccurred ? "Transferred subscription" : "No migration needed")")
            
            // If migration didn't work, re-identify user
            if !migrationOccurred {
                print("🔐 RevenueCat: Re-identifying with Firebase UID")
                await identifyCurrentUser()
            }
            
            // If successful migration gave the user Pro, we can skip the restore
            if isProUser {
                print("🔐 RevenueCat: User already has Pro after migration, skipping restore")
                isLoading = false
                return
            }
        }
        
        // Now that we have the correct user ID, try restore
        do {
            #if DEBUG
            print("🔐 RevenueCat: Attempting restore for user \(Purchases.shared.appUserID)")
            #endif
            
            // First, try direct StoreKit restore to see if we have active subscriptions
            // This will help if there are sync issues with RevenueCat
            var hasActiveStoreKitSubscription = false
            print("🔐 RevenueCat: Checking StoreKit for direct receipt evidence")
            
            for await result in Transaction.currentEntitlements {
                if case .verified(let transaction) = result, 
                   ["com.KhamariThompson.100Days.monthlyv2"].contains(transaction.productID),
                   transaction.revocationDate == nil,
                   (transaction.expirationDate == nil || transaction.expirationDate! > Date()) {
                    
                    // Valid subscription found in StoreKit
                    hasActiveStoreKitSubscription = true
                    print("🔐 RevenueCat: StoreKit shows active subscription for product: \(transaction.productID)")
                    
                    // Log details that could help with recovery
                    if let expirationDate = transaction.expirationDate {
                        print("🔐 RevenueCat: Subscription expires on: \(expirationDate)")
                    } else {
                        print("🔐 RevenueCat: Subscription does not expire (lifetime)")
                    }
                    print("🔐 RevenueCat: Original purchase date: \(transaction.originalPurchaseDate)")
                    
                    break
                }
            }
            
            // Now do the RevenueCat restore
            let customerInfo = try await Purchases.shared.restorePurchases()
            print("🔐 RevenueCat: Restore completed successfully - checking entitlements")
            
            // Explicitly sync purchases with RevenueCat after restore
            print("🔐 RevenueCat: Explicitly syncing purchases with RevenueCat after restore")
            try await syncPurchasesWithRetry(maxRetries: 3)
            
            // Get updated customer info after sync
            let updatedCustomerInfo = try await Purchases.shared.customerInfo()
            print("🔐 RevenueCat: After sync - entitlements: \(updatedCustomerInfo.entitlements.active.keys.joined(separator: ", "))")
            print("🔐 RevenueCat: After sync - active subscriptions: \(updatedCustomerInfo.activeSubscriptions.joined(separator: ", "))")
            print("🔐 RevenueCat: After sync - originalAppUserId: \(updatedCustomerInfo.originalAppUserId)")
            
            // Check if RevenueCat has active entitlements
            let hasProEntitlement = updatedCustomerInfo.entitlements["Pro"]?.isActive ?? false
            
            // Check if the original purchaser matches the current user
            let originalAppUserId = updatedCustomerInfo.originalAppUserId
            print("🔐 RevenueCat: Original App User ID: \(originalAppUserId)")
            print("🔐 RevenueCat: Current Firebase UID: \(currentUser.uid)")
            
            let originalPurchaserMatches = originalAppUserId == currentUser.uid
            if !originalPurchaserMatches && hasProEntitlement {
                print("🔐 RevenueCat: ⚠️ Original purchaser (\(originalAppUserId)) doesn't match current user (\(currentUser.uid))")
                print("🔐 RevenueCat: Cannot restore Pro access to a different user account")
                
                // Reset Pro status since this user isn't the original purchaser
                await MainActor.run {
                    self.isProUser = false
                    self.renewalDate = nil
                    
                    // Clear cached data for security
                    UserDefaults.standard.removeObject(forKey: "cachedProStatus")
                    UserDefaults.standard.removeObject(forKey: "cachedExpirationDate")
                    
                    // Notify that we can't restore
                    NotificationCenter.default.post(
                        name: NSNotification.Name("SubscriptionStatusChanged"),
                        object: nil,
                        userInfo: ["isProUser": false]
                    )
                }
                
                throw SubscriptionError.accountMismatch
            }
            
            // If StoreKit shows active but RevenueCat doesn't, we have a sync issue
            if hasActiveStoreKitSubscription && !hasProEntitlement {
                print("🔐 RevenueCat: ⚠️ StoreKit shows active subscription but RevenueCat entitlements don't match")
                print("🔐 RevenueCat: Trying to force sync purchases...")
                
                // Try to force sync purchases with RevenueCat
                try await Purchases.shared.syncPurchases()
                
                // Get updated customer info after sync
                let updatedCustomerInfo = try await Purchases.shared.customerInfo()
                try await handleRestoredCustomerInfo(updatedCustomerInfo)
            } else {
                // Normal restore flow
                try await handleRestoredCustomerInfo(customerInfo)
            }
        } catch {
            await handleRestoreError(error)
            throw error
        }
        
        // Set loading to false whether the operation succeeded or failed
        isLoading = false
    }
    
    /// Reset all state to initial values
    @MainActor
    func reset() {
        print("🔐 RevenueCat: Reset: Starting complete reset of subscription state")
        
        // Reset all published properties
        isProUser = false
        availableProducts = []
        renewalDate = nil
        showPaywall = false
        errorLoadingOfferings = false
        offeringsLoaded = false
        currentRevenueCatUID = ""
        isDeletedAccountDetected = false
        lastRestoreError = nil
        showRestoreErrorAlert = false
        isOfflineMode = false
        subscriptionExpirationDate = nil
        subscriptionRenewalIssue = false
        
        // Reset cached data
        cachedOfferings = nil
        isLoadingOfferings = false
        didAttemptOfferingsLoad = false
        offeringsRetryCount = 0
        
        // Clear ALL cached subscriptions in UserDefaults with namespace isolation
        let userDefaultsKeys = [
            "cachedProStatus",
            "cachedExpirationDate",
            "offeringsRetryCount",
            "lastSubscriptionCheck",
            "hasCompletedSubscriptionMigration",
            "lastUserIdentified",
            "lastRevenueCatSync",
            "subscriptionLastVerified"
        ]
        
        for key in userDefaultsKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        
        // Force an immediate purchase sync on the next user login
        needsForcedPurchaseSync = true
        
        // Notify the app about subscription status change
        NotificationCenter.default.post(
            name: NSNotification.Name("SubscriptionStatusChanged"),
            object: nil,
            userInfo: ["isProUser": false]
        )
        
        print("🔐 RevenueCat: Reset: Subscription service reset complete")
    }
    
    private func handleRestoredCustomerInfo(_ customerInfo: CustomerInfo) async throws {
        print("🔐 RevenueCat: Restore completed - checking account ownership")
        print("🔐 RevenueCat: Original AppUserID: \(customerInfo.originalAppUserId)")
        print("🔐 RevenueCat: Current AppUserID: \(Purchases.shared.appUserID)")
        print("🔐 RevenueCat: All entitlements: \(customerInfo.entitlements.all.keys)")
        print("🔐 RevenueCat: Active entitlements: \(customerInfo.entitlements.active.keys)")
        
        // Get the current Firebase user ID
        let currentFirebaseUID = Auth.auth().currentUser?.uid
        print("🔐 RevenueCat: Current Firebase UID: \(currentFirebaseUID ?? "none")")
        
        // Validate all required conditions for a valid restore:
        // 1. We must have a current Firebase user
        // 2. The original purchaser must match the current Firebase user
        // 3. The RevenueCat appUserID must match the current Firebase user
        
        guard let currentFirebaseUID = currentFirebaseUID else {
            print("🔐 RevenueCat: No Firebase user found during restore")
            throw SubscriptionError.userNotSignedIn
        }
        
        // Make sure the RevenueCat ID matches the Firebase ID
        guard Purchases.shared.appUserID == currentFirebaseUID else {
            print("🔐 RevenueCat: AppUserID mismatch during restore")
            print("🔐 RevenueCat: RevenueCat ID: \(Purchases.shared.appUserID)")
            print("🔐 RevenueCat: Firebase UID: \(currentFirebaseUID)")
            
            await MainActor.run {
                self.isProUser = false
                self.renewalDate = nil
                
                // Clear cached data
                UserDefaults.standard.removeObject(forKey: "cachedProStatus")
                UserDefaults.standard.removeObject(forKey: "cachedExpirationDate")
            }
            
            throw SubscriptionError.accountMismatch
        }
        
        // Check if the restored purchases were originally made by this Firebase user
        if !customerInfo.originalAppUserId.isEmpty && 
           customerInfo.originalAppUserId != currentFirebaseUID {
            // The purchases were originally made by a different account
            print("🔐 RevenueCat: Account mismatch! Original: \(customerInfo.originalAppUserId), Current: \(currentFirebaseUID)")
            
            // Check if there are Pro entitlements to be restored
            let hasProEntitlement = customerInfo.entitlements["Pro"]?.isActive ?? false
            
            if hasProEntitlement {
                print("🔐 RevenueCat: Blocking Pro entitlement restore for different account")
                
                // Check if this might be a case of a deleted Firebase account
                let couldBeDeletedAccount = await handleDeletedAccountRestore()
                
                // Reset Pro status regardless
                await MainActor.run {
                    self.isProUser = false
                    self.renewalDate = nil
                    
                    // Clear cached data
                    UserDefaults.standard.removeObject(forKey: "cachedProStatus")
                    UserDefaults.standard.removeObject(forKey: "cachedExpirationDate")
                    
                    // Set state for specialized UI
                    self.isDeletedAccountDetected = couldBeDeletedAccount
                    
                    // Post notification for subscription change with specialized info
                    NotificationCenter.default.post(
                        name: NSNotification.Name("SubscriptionStatusChanged"),
                        object: nil,
                        userInfo: [
                            "isProUser": false,
                            "isDeletedAccountCase": couldBeDeletedAccount,
                            "originalAppUserID": customerInfo.originalAppUserId
                        ]
                    )
                }
                
                // Throw a specialized error
                throw SubscriptionError.accountMismatch
            } else {
                print("🔐 RevenueCat: No Pro entitlements in restored purchases, no action needed")
            }
        } else {
            // Successful restore for the current user
            print("🔐 RevenueCat: Restore successful for current user - entitlements: \(customerInfo.entitlements.active.keys.joined(separator: ", "))")
            
            // Check if Pro entitlement is active
            let isProActive = customerInfo.entitlements["Pro"]?.isActive ?? false
            let expirationDate = customerInfo.entitlements["Pro"]?.expirationDate
            
            print("🔐 RevenueCat: Pro status after restore: \(isProActive)")
            if let expirationDate = expirationDate {
                print("🔐 RevenueCat: Pro expires on: \(expirationDate)")
            }
            
            await MainActor.run {
                self.isProUser = isProActive
                self.renewalDate = expirationDate
                
                // Cache the subscription status for offline use
                UserDefaults.standard.set(isProActive, forKey: "cachedProStatus")
                UserDefaults.standard.set(expirationDate, forKey: "cachedExpirationDate")
                
                // Post notification for subscription change
                NotificationCenter.default.post(
                    name: NSNotification.Name("SubscriptionStatusChanged"),
                    object: nil,
                    userInfo: ["isProUser": isProActive]
                )
            }
        }
    }
    
    private func handleRestoreError(_ error: Error) {
        print("🔐 RevenueCat: Failed to restore purchases: \(error.localizedDescription)")
        self.lastRestoreError = .restoreFailed
        self.showRestoreErrorAlert = true
    }
    
    func presentSubscriptionSheet() {
        showPaywall = true
    }
    
    // For refreshing the subscription status
    func refreshSubscriptionStatus() async {
        print("Forcing subscription status refresh")
        
        // First try to sync purchases with RevenueCat
        do {
            try await Purchases.shared.syncPurchases()
            print("Successfully synced purchases with RevenueCat")
            
            // Check RevenueCat configuration directly
            await checkRevenueCatConfiguration()
        } catch {
            print("Failed to sync purchases: \(error.localizedDescription)")
        }
        
        // Then update subscription status
        await updateSubscriptionStatus()
    }
    
    // New method to check RevenueCat configuration directly
    private func checkRevenueCatConfiguration() async {
        print("🔐 RevenueCat: Checking configuration directly...")
        
        do {
            // Get customer info to check entitlements configuration
            let customerInfo = try await Purchases.shared.customerInfo()
            
            // Check all entitlements
            print("🔐 RevenueCat: All available entitlements: \(customerInfo.entitlements.all.keys)")
            
            // Check specifically for 'Pro' entitlement (case sensitive)
            let hasProEntitlement = customerInfo.entitlements.all.keys.contains("Pro")
            let hasLowercaseProEntitlement = customerInfo.entitlements.all.keys.contains("pro")
            
            print("🔐 RevenueCat: Has 'Pro' entitlement: \(hasProEntitlement)")
            print("🔐 RevenueCat: Has 'pro' entitlement: \(hasLowercaseProEntitlement)")
            
            // Check active entitlements
            print("🔐 RevenueCat: Active entitlements: \(customerInfo.entitlements.active.keys)")
            
            // Check product IDs in current subscription
            if !customerInfo.activeSubscriptions.isEmpty {
                print("🔐 RevenueCat: Active subscriptions: \(customerInfo.activeSubscriptions)")
            } else {
                print("🔐 RevenueCat: No active subscriptions found")
            }
            
            // Check offerings
            if let offerings = try? await Purchases.shared.offerings() {
                if let current = offerings.current {
                    print("🔐 RevenueCat: Current offering: \(current.identifier)")
                    print("🔐 RevenueCat: Available packages: \(current.availablePackages.map { $0.identifier })")
                    
                    // Check product mappings
                    for package in current.availablePackages {
                        print("🔐 RevenueCat: Package \(package.identifier) - Product ID: \(package.storeProduct.productIdentifier)")
                    }
                } else {
                    print("🔐 RevenueCat: No current offering available")
                }
            }
        } catch {
            print("🔐 RevenueCat: Error checking configuration: \(error.localizedDescription)")
        }
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
    
    @MainActor
    private func loadOfferings() async {
        isLoading = true
        error = nil
        
        do {
            offerings = try await Purchases.shared.offerings()
            print("Successfully loaded offerings")
        } catch {
            self.error = error
            print("Error loading offerings: \(error)")
            
            // Retry logic
            if let retryCount = UserDefaults.standard.object(forKey: "offeringsRetryCount") as? Int,
               retryCount < 3 {
                let newRetryCount = retryCount + 1
                UserDefaults.standard.set(newRetryCount, forKey: "offeringsRetryCount")
                print("Retrying offerings load (attempt \(newRetryCount)/3)...")
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 second delay
                await loadOfferings()
            } else {
                UserDefaults.standard.set(0, forKey: "offeringsRetryCount")
            }
        }
        
        isLoading = false
    }
    
    // Helper method to handle restore attempts from deleted accounts
    func handleDeletedAccountRestore() async -> Bool {
        print("🔐 RevenueCat: Attempting to check if the current device had a previous Pro subscription")
        
        guard let currentFirebaseUID = Auth.auth().currentUser?.uid else {
            print("🔐 RevenueCat: Cannot handle deleted account restore - no Firebase user is logged in")
            return false
        }
        
        // First ensure the user is properly identified with RevenueCat
        if Purchases.shared.appUserID != currentFirebaseUID {
            do {
                let _ = try await Purchases.shared.logIn(currentFirebaseUID)
                print("🔐 RevenueCat: Re-identified user with Firebase UID: \(currentFirebaseUID)")
            } catch {
                print("🔐 RevenueCat: Failed to identify user: \(error.localizedDescription)")
                return false
            }
        }
        
        do {
            // First check StoreKit for active purchases
            var hasActiveStoreKitSubscription = false
            
            print("🔐 RevenueCat: Checking StoreKit for direct receipt evidence")
            for await result in Transaction.currentEntitlements {
                if case .verified(let transaction) = result, 
                   productIds.contains(transaction.productID),
                   transaction.revocationDate == nil,
                   (transaction.expirationDate == nil || transaction.expirationDate! > Date()) {
                    
                    // Valid subscription found in StoreKit
                    hasActiveStoreKitSubscription = true
                    print("🔐 RevenueCat: StoreKit shows active subscription for product: \(transaction.productID)")
                    
                    // Log details that could help with recovery
                    if let expirationDate = transaction.expirationDate {
                        print("🔐 RevenueCat: Subscription expires on: \(expirationDate)")
                    } else {
                        print("🔐 RevenueCat: Subscription does not expire (lifetime)")
                    }
                    print("🔐 RevenueCat: Original purchase date: \(transaction.originalPurchaseDate)")
                    
                    break
                }
            }
            
            if hasActiveStoreKitSubscription {
                print("🔐 RevenueCat: Device has an active StoreKit subscription, but no RevenueCat record matches current user")
                print("🔐 RevenueCat: This could be a case of a deleted Firebase account that had a subscription")
                
                // Option 1: Show a special UI to explain the situation to the user
                // In this implementation, we'll just return true to indicate recovery might be possible
                
                return true
            } else {
                print("🔐 RevenueCat: No active subscription found in StoreKit for this device")
                return false
            }
        } catch {
            print("🔐 RevenueCat: Error checking for deleted account subscription: \(error.localizedDescription)")
            return false
        }
    }
    
    // Helper method to show user-friendly error for restore failures
    func showRestoreErrorMessage(_ error: Error) {
        Task { @MainActor in
            let subscriptionError: SubscriptionError
            
            if let subError = error as? SubscriptionError {
                subscriptionError = subError
            } else {
                // Convert generic errors to our custom error type
                subscriptionError = .restoreFailed
            }
            
            // Store the error for UI display
            self.lastRestoreError = subscriptionError
            
            // Handle deleted account case specially
            if subscriptionError == .accountMismatch && isDeletedAccountDetected {
                print("🔐 RevenueCat: Showing deleted account recovery guidance to user")
                // UI would show specialized messaging here
            }
            
            // Trigger UI alert
            self.showRestoreErrorAlert = true
        }
    }
    
    // Update to receive notification about deleted account detection and validate subscription status changes
    @objc private func handleSubscriptionStatusChange(_ notification: Notification) {
        print("🔐 RevenueCat: Handling subscription status change notification")
        
        if let isDeletedAccountCase = notification.userInfo?["isDeletedAccountCase"] as? Bool, 
           isDeletedAccountCase {
            isDeletedAccountDetected = true
            print("🔐 RevenueCat: Detected deleted account case")
            return
        }
        
        // Get current Firebase UID
        let currentFirebaseUID = Auth.auth().currentUser?.uid
        
        Task {
            // If we don't have a user, reset Pro status
            guard let currentFirebaseUID = currentFirebaseUID else {
                print("🔐 RevenueCat: No Firebase user found during subscription status change")
                await MainActor.run {
                    if self.isProUser {
                        self.isProUser = false
                        self.renewalDate = nil
                        
                        // Clear cached data
                        UserDefaults.standard.removeObject(forKey: "cachedProStatus")
                        UserDefaults.standard.removeObject(forKey: "cachedExpirationDate")
                    }
                }
                return
            }
            
            // Check if RevenueCat ID matches Firebase UID
            if Purchases.shared.appUserID != currentFirebaseUID {
                print("🔐 RevenueCat: AppUserID mismatch during subscription status change")
                print("🔐 RevenueCat: RevenueCat ID: \(Purchases.shared.appUserID)")
                print("🔐 RevenueCat: Firebase UID: \(currentFirebaseUID)")
                
                await MainActor.run {
                    if self.isProUser {
                        self.isProUser = false
                        self.renewalDate = nil
                        
                        // Clear cached data
                        UserDefaults.standard.removeObject(forKey: "cachedProStatus")
                        UserDefaults.standard.removeObject(forKey: "cachedExpirationDate")
                    }
                }
                
                // Re-identify user to fix the mismatch
                await identifyCurrentUser()
                return
            }
            
            // Get customer info to validate original purchaser
            do {
                let customerInfo = try await Purchases.shared.customerInfo()
                
                // Check if the original purchaser matches the current user
                if !customerInfo.originalAppUserId.isEmpty && 
                   customerInfo.originalAppUserId != currentFirebaseUID {
                    
                    print("🔐 RevenueCat: Original purchaser (\(customerInfo.originalAppUserId)) doesn't match current user (\(currentFirebaseUID))")
                    
                    await MainActor.run {
                        if self.isProUser {
                            self.isProUser = false
                            self.renewalDate = nil
                            
                            // Clear cached data
                            UserDefaults.standard.removeObject(forKey: "cachedProStatus")
                            UserDefaults.standard.removeObject(forKey: "cachedExpirationDate")
                            
                            // Notify about subscription status change
                            NotificationCenter.default.post(
                                name: NSNotification.Name("SubscriptionStatusChanged"),
                                object: nil,
                                userInfo: ["isProUser": false]
                            )
                        }
                    }
                    return
                }
                
                // Both RevenueCat ID and original purchaser match - update status
                await updateSubscriptionStatus()
                
            } catch {
                print("🔐 RevenueCat: Error checking customer info during subscription change: \(error.localizedDescription)")
            }
        }
    }
    
    // Handle app becoming active
    @objc private func handleAppDidBecomeActive() {
        print("🔐 RevenueCat: App became active, verifying subscription status")
        Task {
            // First, verify user identity matches
            if let currentFirebaseUID = Auth.auth().currentUser?.uid {
                if Purchases.shared.appUserID != currentFirebaseUID {
                    print("🔐 RevenueCat: User ID mismatch detected on app resume, re-identifying user")
                    await identifyCurrentUser()
                } else {
                    // Even if IDs match, verify the original purchaser ID
                    let customerInfo = try? await Purchases.shared.customerInfo()
                    if let originalAppUserId = customerInfo?.originalAppUserId,
                       !originalAppUserId.isEmpty && originalAppUserId != currentFirebaseUID {
                        print("🔐 RevenueCat: Original purchaser ID mismatch on app resume")
                        // Force Pro status to false if original purchaser doesn't match
                        if self.isProUser {
                            self.isProUser = false
                            self.renewalDate = nil
                            
                            // Clear cached data
                            UserDefaults.standard.removeObject(forKey: "cachedProStatus")
                            UserDefaults.standard.removeObject(forKey: "cachedExpirationDate")
                            
                            // Notify about subscription status change
                            NotificationCenter.default.post(
                                name: NSNotification.Name("SubscriptionStatusChanged"),
                                object: nil,
                                userInfo: ["isProUser": false]
                            )
                        }
                    }
                }
            }
            
            // Then update subscription status
            await updateSubscriptionStatus(forceVerification: true)
            
            // Log environment
            do {
                let customerInfo = try await Purchases.shared.customerInfo()
                print("🔐 RevenueCat: Pro status on resume = \(customerInfo.entitlements["Pro"]?.isActive ?? false)")
            } catch {
                print("🔐 RevenueCat: Failed to get customer info on resume: \(error.localizedDescription)")
            }
        }
    }
    
    // Handle network status changes
    @objc private func handleNetworkStatusChange(_ notification: Notification) {
        if let isConnected = notification.userInfo?["isConnected"] as? Bool {
            if isConnected {
                // We're back online, refresh subscription status
                print("🔐 RevenueCat: Network connection restored, refreshing subscription status")
                isOfflineMode = false
                Task {
                    await updateSubscriptionStatus(forceVerification: true)
                }
            } else {
                // We're offline, enable offline mode
                print("🔐 RevenueCat: Network connection lost, enabling offline mode")
                isOfflineMode = true
            }
        }
    }
    
    // Schedule periodic receipt refresh
    private func scheduleReceiptRefresh() {
        // Cancel any existing timer
        receiptRefreshTimer?.invalidate()
        
        // Create a new timer that refreshes every hour
        receiptRefreshTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            print("🔐 RevenueCat: Performing scheduled receipt refresh")
            Task {
                await self.updateSubscriptionStatus(forceVerification: true)
            }
        }
    }
    
    // MARK: - Debug Methods
    
    /// Check and debug the App Store receipt
    func debugReceiptStatus() async -> Bool {
        print("🔐 RevenueCat: Debugging receipt status")
        
        // Check if receipt exists
        guard let receiptURL = Bundle.main.appStoreReceiptURL else {
            print("🔐 RevenueCat: No receipt URL available")
            return false
        }
        
        let receiptExists = FileManager.default.fileExists(atPath: receiptURL.path)
        print("🔐 RevenueCat: Receipt URL: \(receiptURL.path)")
        print("🔐 RevenueCat: Receipt exists: \(receiptExists)")
        
        if receiptExists {
            // Get receipt file size
            if let attributes = try? FileManager.default.attributesOfItem(atPath: receiptURL.path),
               let fileSize = attributes[.size] as? Int {
                print("🔐 RevenueCat: Receipt file size: \(fileSize) bytes")
                
                // If receipt is too small, it might be invalid
                if fileSize < 1000 {
                    print("🔐 RevenueCat: ⚠️ Receipt file is suspiciously small (\(fileSize) bytes), might be invalid")
                }
            }
            
            // Check if it's a sandbox receipt
            if receiptURL.lastPathComponent == "sandboxReceipt" {
                print("🔐 RevenueCat: ⚠️ Using sandbox receipt")
            } else {
                print("🔐 RevenueCat: Using production receipt")
            }
            
            // Check for receipt validation with RevenueCat
            do {
                print("🔐 RevenueCat: Requesting customer info to validate receipt")
                let customerInfo = try await Purchases.shared.customerInfo()
                
                print("🔐 RevenueCat: Receipt validation succeeded")
                print("🔐 RevenueCat: Original App User ID: \(customerInfo.originalAppUserId)")
                print("🔐 RevenueCat: Current App User ID: \(Purchases.shared.appUserID)")
                print("🔐 RevenueCat: Active entitlements: \(customerInfo.entitlements.active.keys.joined(separator: ", "))")
                print("🔐 RevenueCat: Active subscriptions: \(customerInfo.activeSubscriptions.joined(separator: ", "))")
                
                // Attempt to force sync with RevenueCat
                print("🔐 RevenueCat: Attempting to force sync receipt with RevenueCat")
                try await syncPurchasesWithRetry(maxRetries: 3)
                
                // Check customer info again after sync
                let updatedInfo = try await Purchases.shared.customerInfo()
                print("🔐 RevenueCat: After sync - Active entitlements: \(updatedInfo.entitlements.active.keys.joined(separator: ", "))")
                print("🔐 RevenueCat: After sync - Active subscriptions: \(updatedInfo.activeSubscriptions.joined(separator: ", "))")
                
                // Check if Pro entitlement is active
                let hasProEntitlement = updatedInfo.entitlements["Pro"]?.isActive ?? false
                print("🔐 RevenueCat: Has Pro entitlement: \(hasProEntitlement)")
                
                return hasProEntitlement
            } catch {
                print("🔐 RevenueCat: ❌ Error validating receipt with RevenueCat: \(error.localizedDescription)")
                return false
            }
        } else {
            print("🔐 RevenueCat: ❌ Receipt file does not exist at expected location")
            
            // Try to refresh the receipt
            print("🔐 RevenueCat: Attempting to refresh App Store receipt")
            do {
                let receiptRefreshRequest = SKReceiptRefreshRequest()
                try await receiptRefreshRequest.start()
                print("🔐 RevenueCat: Receipt refresh request completed")
                
                // Check if receipt exists after refresh
                let refreshedReceiptExists = FileManager.default.fileExists(atPath: receiptURL.path)
                print("🔐 RevenueCat: After refresh - Receipt exists: \(refreshedReceiptExists)")
                
                return refreshedReceiptExists
            } catch {
                print("🔐 RevenueCat: ❌ Error refreshing receipt: \(error.localizedDescription)")
                return false
            }
        }
    }
    
    /// Attempt to fix common subscription issues
    func attemptSubscriptionRepair() async -> Bool {
        print("🔐 RevenueCat: Attempting to repair subscription")
        
        // Ensure user is properly identified
        if let currentUser = Auth.auth().currentUser {
            print("🔐 RevenueCat: Current Firebase UID: \(currentUser.uid)")
            print("🔐 RevenueCat: Current RevenueCat ID: \(Purchases.shared.appUserID)")
            
            if Purchases.shared.appUserID != currentUser.uid {
                print("🔐 RevenueCat: Re-identifying user with correct Firebase UID")
                await identifyCurrentUser()
            }
        } else {
            print("🔐 RevenueCat: ❌ No Firebase user available for repair")
            return false
        }
        
        // Step 1: Validate receipt
        let receiptValid = await debugReceiptStatus()
        if !receiptValid {
            print("🔐 RevenueCat: ❌ Receipt validation failed")
        }
        
        // Step 2: Force sync with RevenueCat
        do {
            print("🔐 RevenueCat: Forcing sync with RevenueCat")
            try await syncPurchasesWithRetry(maxRetries: 3)
            print("🔐 RevenueCat: Sync completed")
        } catch {
            print("🔐 RevenueCat: ❌ Sync failed: \(error.localizedDescription)")
        }
        
        // Step 3: Update subscription status
        await updateSubscriptionStatus()
        
        // Check if repair was successful
        let success = self.isProUser
        print("🔐 RevenueCat: Repair attempt completed. Pro status: \(success)")
        return success
    }
    
    /// Migrates a subscription from an anonymous user to an identified user
    /// Call this when a user logs in to ensure their purchases are transferred
    /// Returns true if a transfer occurred, false otherwise
    func migrateAnonymousSubscription() async -> Bool {
        guard let currentUser = Auth.auth().currentUser else {
            print("🔐 RevenueCat: Cannot migrate subscription - No Firebase user is logged in")
            return false
        }

        print("🔐 RevenueCat: Attempting to migrate anonymous subscription to user: \(currentUser.uid)")
        print("🔐 RevenueCat: Current RevenueCat AppUserID: \(Purchases.shared.appUserID)")
        
        // Skip if already properly identified
        if Purchases.shared.appUserID == currentUser.uid {
            print("🔐 RevenueCat: User already identified with correct UID, no migration needed")
            return false
        }
        
        do {
            // Perform login which will trigger migration if needed
            let loginResult = try await Purchases.shared.logIn(currentUser.uid)
            
            // Store the current RevenueCat user ID
            self.currentRevenueCatUID = currentUser.uid
            
            // Check if a transfer occurred (.created = false means a transfer happened)
            let transferOccurred = !loginResult.created
            
            if transferOccurred {
                print("🔐 RevenueCat: ✅ Successfully migrated subscription from anonymous user to \(currentUser.uid)")
                print("🔐 RevenueCat: Original AppUserID: \(loginResult.customerInfo.originalAppUserId)")
                print("🔐 RevenueCat: Current AppUserID: \(Purchases.shared.appUserID)")
                
                // Get all entitlements
                let entitlements = loginResult.customerInfo.entitlements.active
                print("🔐 RevenueCat: Migrated entitlements: \(entitlements.keys.joined(separator: ", "))")
                
                // Force sync purchases after migration
                try await Purchases.shared.syncPurchases()
                print("🔐 RevenueCat: Explicitly synced purchases after migration")
                
                // Update subscription status
                await updateSubscriptionStatus()
                
                // Force sync with RevenueCat to ensure receipt is properly associated
                print("🔐 RevenueCat: Force syncing with RevenueCat after migration")
                try await syncPurchasesWithRetry(maxRetries: 3)
                
                return true
            } else {
                print("🔐 RevenueCat: No subscription transfer needed - this is a new user")
                
                // Still sync purchases to ensure any App Store receipts are properly associated
                try await Purchases.shared.syncPurchases()
                print("🔐 RevenueCat: Synced purchases for new user")
                
                // Update subscription status
                await updateSubscriptionStatus()
                
                return false
            }
        } catch {
            print("🔐 RevenueCat: ❌ Migration failed: \(error.localizedDescription)")
            
            // Still update subscription status to make sure it reflects current state
            await updateSubscriptionStatus()
            
            return false
        }
    }
    
    /// Provides detailed diagnostic information about the subscription state
    /// Useful for support and debugging subscription issues
    func getSubscriptionDiagnostics() async -> [String: Any] {
        var diagnostics: [String: Any] = [:]
        
        // User identification info
        diagnostics["firebaseUID"] = Auth.auth().currentUser?.uid ?? "none"
        diagnostics["currentRevenueCatUserID"] = Purchases.shared.appUserID
        
        // Get customer info
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            diagnostics["originalPurchaserID"] = customerInfo.originalAppUserId
            diagnostics["activeEntitlements"] = Array(customerInfo.entitlements.active.keys)
            diagnostics["activeSubscriptions"] = Array(customerInfo.activeSubscriptions)
            diagnostics["isProUser"] = isProUser
            
            // Receipt validation
            let receiptURL = Bundle.main.appStoreReceiptURL
            diagnostics["receiptExists"] = receiptURL != nil && FileManager.default.fileExists(atPath: receiptURL!.path)
            diagnostics["receiptPath"] = receiptURL?.path ?? "none"
            
            // Add receipt file size if exists
            if let receiptURL = receiptURL, 
               let attributes = try? FileManager.default.attributesOfItem(atPath: receiptURL.path),
               let fileSize = attributes[.size] as? Int {
                diagnostics["receiptFileSize"] = fileSize
            }
            
            // Attempt migration status
            let migrationNeeded = Purchases.shared.appUserID != Auth.auth().currentUser?.uid && 
                                 Auth.auth().currentUser != nil
            diagnostics["migrationNeeded"] = migrationNeeded
            
            // OS and app version info
            diagnostics["osVersion"] = UIDevice.current.systemVersion
            if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                diagnostics["appVersion"] = appVersion
            }
        } catch {
            diagnostics["error"] = error.localizedDescription
        }
        
        return diagnostics
    }
    
    // Add this new method to SubscriptionService.swift:
    private func syncPurchasesWithRetry(maxRetries: Int) async throws {
        var retryCount = 0
        var lastError: Error?
        
        while retryCount < maxRetries {
            do {
                try await Purchases.shared.syncPurchases()
                print("🔐 RevenueCat: Successfully synced purchases with RevenueCat (attempt \(retryCount + 1))")
                return
            } catch {
                lastError = error
                print("🔐 RevenueCat: Failed to sync purchases (attempt \(retryCount + 1)): \(error.localizedDescription)")
                retryCount += 1
                
                if retryCount < maxRetries {
                    // Exponential backoff: 1s, 2s, 4s
                    let delay = TimeInterval(pow(2.0, Double(retryCount - 1)))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        if let lastError = lastError {
            throw lastError
        }
    }
}

// MARK: - PurchasesDelegate
extension SubscriptionService: PurchasesDelegate {
    func purchases(_ purchases: Purchases, receivedUpdatedCustomerInfo customerInfo: CustomerInfo) {
        print("🔐 RevenueCat: Received updated CustomerInfo notification from RevenueCat")
        
        // Verify that the current Firebase user ID matches the RevenueCat ID
        let currentFirebaseUID = Auth.auth().currentUser?.uid
        
        // Create a detached task to handle async operations
        Task.detached {
            await self.handleCustomerInfoUpdate(customerInfo: customerInfo, currentFirebaseUID: currentFirebaseUID)
        }
    }
    
    // New helper method to handle async operations for customer info updates
    private func handleCustomerInfoUpdate(customerInfo: CustomerInfo, currentFirebaseUID: String?) async {
        // Make sure we're on the main thread for any UI updates
        await MainActor.run {
            // Check if we have a current Firebase user
            guard let currentFirebaseUID = currentFirebaseUID else {
                print("🔐 RevenueCat: No Firebase user available, ignoring CustomerInfo update")
                return
            }
            
            // Check if RevenueCat ID matches Firebase UID
            if Purchases.shared.appUserID != currentFirebaseUID {
                print("🔐 RevenueCat: AppUserID mismatch during subscription status change")
                print("🔐 RevenueCat: RevenueCat ID: \(Purchases.shared.appUserID)")
                print("🔐 RevenueCat: Firebase UID: \(currentFirebaseUID)")
                
                if self.isProUser {
                    self.isProUser = false
                    self.renewalDate = nil
                    
                    // Clear cached data
                    UserDefaults.standard.removeObject(forKey: "cachedProStatus")
                    UserDefaults.standard.removeObject(forKey: "cachedExpirationDate")
                }
                
                // Create a new task for the async operation
                Task {
                    // Re-identify user to fix the mismatch
                    await self.identifyCurrentUser()
                }
                return
            }
            
            // Also check if the original purchaser matches the current user
            if !customerInfo.originalAppUserId.isEmpty && 
               customerInfo.originalAppUserId != currentFirebaseUID {
                
                print("🔐 RevenueCat: Original purchaser (\(customerInfo.originalAppUserId)) doesn't match current user (\(currentFirebaseUID))")
                
                if self.isProUser {
                    self.isProUser = false
                    self.renewalDate = nil
                    
                    // Clear cached data
                    UserDefaults.standard.removeObject(forKey: "cachedProStatus")
                    UserDefaults.standard.removeObject(forKey: "cachedExpirationDate")
                    
                    // Notify about subscription status change
                    NotificationCenter.default.post(
                        name: NSNotification.Name("SubscriptionStatusChanged"),
                        object: nil,
                        userInfo: ["isProUser": false]
                    )
                }
                return
            }
            
            // Both RevenueCat ID and original purchaser match - update status
            Task {
                await self.updateSubscriptionStatus(forceVerification: true)
            }
        }
    }
    
    // Log possible refund for analytics
    private func logPossibleRefund() {
        print("🔐 RevenueCat: Possible refund or cancellation detected")
        // Here you could send an analytics event or log to your backend
    }
}

enum StoreError: Error {
    case failedVerification
}

enum SubscriptionError: Error {
    case purchaseFailed
    case notSignedIntoAppStore
    case restoreFailed
    case timeout
    case unknown
    case networkOffline
    case networkError
    case purchasePending
    case receiptInUse
    case productNotFound
    case verificationFailed
    case userCancelled
    case accountMismatch
    case userNotSignedIn
    
    var localizedDescription: String {
        switch self {
        case .purchaseFailed:
            return "The purchase failed to complete."
        case .notSignedIntoAppStore:
            return "You're not signed in to the App Store. Please sign in to your Apple ID."
        case .restoreFailed:
            return "Failed to restore purchases."
        case .timeout:
            return "The operation timed out. Please try again."
        case .unknown:
            return "An unknown error occurred."
        case .networkOffline:
            return "You're offline. Please check your internet connection."
        case .networkError:
            return "A network error occurred. Please try again."
        case .purchasePending:
            return "Your purchase is pending approval."
        case .receiptInUse:
            return "This receipt is already in use with another account."
        case .productNotFound:
            return "The product was not found."
        case .verificationFailed:
            return "Purchase verification failed."
        case .userCancelled:
            return "The purchase was cancelled."
        case .accountMismatch:
            return "This subscription belongs to a different account. Please log in with the original account that purchased Pro."
        case .userNotSignedIn:
            return "You must be signed in to perform this action."
        }
    }
} 
