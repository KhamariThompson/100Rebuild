import Foundation
import Combine
import StoreKit
import SwiftUI
import FirebaseAuth
import RevenueCat

enum SubscriptionPlan: String {
    case monthly = "com.KhamariThompson.100Days.monthlyv2"
    
    var productId: String {
        return self.rawValue
    }
}

@MainActor
class SubscriptionViewModel: ObservableObject {
    @Published private(set) var features: [ProFeature] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?
    @Published var showError = false
    @Published var errorMessage = ""
    
    // Add properties for migration
    @Published var migrationInProgress = false
    @Published var migrationCompleted = false
    @Published var migrationResult = ""
    
    private let subscriptionService = SubscriptionService.shared
    
    init() {
        loadFeatures()
    }
    
    private func loadFeatures() {
        features = [
            ProFeature(
                icon: "🚀",
                title: "Unlimited Challenges",
                description: "Create and join as many challenges as you want",
                section: .unlockPotential
            ),
            ProFeature(
                icon: "📊",
                title: "Advanced Analytics",
                description: "Track your progress with detailed statistics",
                section: .levelUp
            ),
            ProFeature(
                icon: "🎯",
                title: "Custom Goals",
                description: "Set personalized goals and milestones",
                section: .levelUp
            ),
            ProFeature(
                icon: "👥",
                title: "Community Features",
                description: "Connect with other users and share progress",
                section: .stayMotivated
            ),
            ProFeature(
                icon: "🔔",
                title: "Smart Reminders",
                description: "Get personalized notifications to stay on track",
                section: .stayMotivated
            )
        ]
    }
    
    func purchase(plan: SubscriptionPlan = .monthly) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await subscriptionService.purchaseSubscription(plan: plan)
        } catch {
            errorMessage = "Failed to purchase subscription: \(error.localizedDescription)"
            showError = true
        }
    }
    
    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            print("🔐 SubscriptionViewModel: Starting purchase restore")
            
            // Verify user authentication status
            if let currentUser = Auth.auth().currentUser {
                print("🔐 SubscriptionViewModel: Restoring as Firebase user: \(currentUser.uid)")
                print("🔐 SubscriptionViewModel: Current RevenueCat AppUserID: \(Purchases.shared.appUserID)")
                
                // Verify the user is properly identified with RevenueCat
                if Purchases.shared.appUserID != currentUser.uid {
                    print("🔐 SubscriptionViewModel: User ID mismatch. Re-identifying user before restore.")
                    await subscriptionService.identifyCurrentUser()
                }
            } else {
                print("🔐 SubscriptionViewModel: Warning: Attempting restore without logged in user")
            }
            
            // Properly use the restore purchases method instead of triggering a purchase
            try await subscriptionService.restorePurchases()
            
            // Check if Pro status was successfully restored
            if !subscriptionService.isProUser {
                print("🔐 SubscriptionViewModel: Restore completed but no Pro subscription found")
                errorMessage = "No previous purchases found to restore"
                showError = true
            } else {
                print("🔐 SubscriptionViewModel: Successfully restored Pro subscription")
            }
        } catch {
            let nsError = error as NSError
            print("🔐 SubscriptionViewModel: Restore failed with error domain: \(nsError.domain), code: \(nsError.code)")
            print("🔐 SubscriptionViewModel: Error description: \(error.localizedDescription)")
            
            // Check for common error conditions and provide better error messages
            if let subscriptionError = error as? SubscriptionError {
                switch subscriptionError {
                case .accountMismatch:
                    errorMessage = "This subscription belongs to a different account. Please sign in with the account that made the purchase."
                case .userNotSignedIn:
                    errorMessage = "You need to be signed in to restore purchases."
                case .notSignedIntoAppStore:
                    errorMessage = "Please sign in to your Apple ID in the device settings to restore purchases."
                default:
                    errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
                }
            } else {
                errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
            }
            showError = true
            
            // Check for receipt-related issues
            if let receiptURL = Bundle.main.appStoreReceiptURL {
                print("🔐 SubscriptionViewModel: Receipt URL: \(receiptURL.path)")
                print("🔐 SubscriptionViewModel: Receipt exists: \(FileManager.default.fileExists(atPath: receiptURL.path))")
            } else {
                print("🔐 SubscriptionViewModel: No receipt URL found!")
            }
        }
    }
    
    /// Attempt to migrate a subscription from an anonymous user to the current identified user
    func migrateAnonymousSubscription() async {
        guard Auth.auth().currentUser != nil else {
            errorMessage = "You need to be signed in to migrate a subscription"
            showError = true
            return
        }
        
        print("🔐 SubscriptionViewModel: Starting subscription migration")
        migrationInProgress = true
        defer { migrationInProgress = false }
        
        do {
            // Check if the current Firebase UID matches the RevenueCat ID
            if Auth.auth().currentUser?.uid == Purchases.shared.appUserID {
                migrationResult = "User already properly identified with RevenueCat"
                migrationCompleted = true
                return
            }
            
            let migrationOccurred = await subscriptionService.migrateAnonymousSubscription()
            
            if migrationOccurred {
                print("🔐 SubscriptionViewModel: Successfully migrated subscription")
                migrationResult = "Successfully transferred subscription to your account!"
                migrationCompleted = true
                
                // Verify Pro status after migration
                if subscriptionService.isProUser {
                    print("🔐 SubscriptionViewModel: User now has Pro status after migration")
                } else {
                    print("🔐 SubscriptionViewModel: User still doesn't have Pro status after migration")
                    
                    // Try syncing purchases again
                    do {
                        print("🔐 SubscriptionViewModel: Force syncing purchases after migration")
                        try await Purchases.shared.syncPurchases()
                        await subscriptionService.updateSubscriptionStatus()
                    } catch {
                        print("🔐 SubscriptionViewModel: Sync error: \(error.localizedDescription)")
                    }
                }
            } else {
                print("🔐 SubscriptionViewModel: No subscription to migrate")
                migrationResult = "No anonymous subscription found to migrate"
                migrationCompleted = true
            }
        } catch {
            print("🔐 SubscriptionViewModel: Migration error: \(error.localizedDescription)")
            errorMessage = "Failed to migrate subscription: \(error.localizedDescription)"
            showError = true
        }
    }
} 