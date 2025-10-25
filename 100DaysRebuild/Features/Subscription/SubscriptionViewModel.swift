import Foundation
import Combine
import StoreKit
import SwiftUI
import FirebaseAuth
import RevenueCat

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

    // private let subscriptionService = SubscriptionService.shared
    // TODO: Inject SubscriptionStore instead
    private let subscriptionStore = SubscriptionStore.shared
    
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
            try await subscriptionStore.purchase(plan)
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

                // User identification is now handled automatically by SubscriptionStore
                // No need to manually re-identify
            } else {
                print("🔐 SubscriptionViewModel: Warning: Attempting restore without logged in user")
            }

            // Properly use the restore purchases method instead of triggering a purchase
            try await subscriptionStore.restorePurchases()

            // Check if Pro status was successfully restored via EntitlementsAdapter
            let hasProAccess = await EntitlementsAdapter.shared.hasProAccess
            if !hasProAccess {
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
                case .restoreFailed(let underlying):
                    // Check the underlying error for specific cases
                    let description = underlying.localizedDescription
                    if description.contains("Account mismatch") {
                        errorMessage = "This subscription belongs to a different account. Please sign in with the account that made the purchase."
                    } else if description.contains("not signed in") || description.contains("User not signed in") {
                        errorMessage = "You need to be signed in to restore purchases."
                    } else if description.contains("App Store") {
                        errorMessage = "Please sign in to your Apple ID in the device settings to restore purchases."
                    } else {
                        errorMessage = "Failed to restore purchases: \(description)"
                    }
                case .noOfferingAvailable:
                    errorMessage = "No subscription offerings available. Please try again later."
                case .packageNotFound:
                    errorMessage = "Subscription package not found. Please try again."
                case .purchaseCancelled:
                    errorMessage = "Purchase was cancelled."
                case .purchaseFailed(let underlying):
                    errorMessage = "Failed to restore purchases: \(underlying.localizedDescription)"
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
            
            // Migration is now handled by SubscriptionStore
            // TODO: Update migration logic to use new architecture
            print("🔐 SubscriptionViewModel: Migration not yet implemented in new architecture")
            migrationResult = "Migration feature coming soon"
            migrationCompleted = true
        } catch {
            print("🔐 SubscriptionViewModel: Migration error: \(error.localizedDescription)")
            errorMessage = "Failed to migrate subscription: \(error.localizedDescription)"
            showError = true
        }
    }
} 