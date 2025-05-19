import Foundation
import Combine
import StoreKit

enum SubscriptionError: Error {
    case purchaseFailed
    case restoreFailed
    case unknown
    case timeout
    case notSignedIntoAppStore
}

enum SubscriptionPlan: String {
    case monthly = "com.KhamariThompson.100Days.monthly"
}

@MainActor
class SubscriptionViewModel: ObservableObject {
    @Published private(set) var features: [ProFeature] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: SubscriptionError?
    @Published var showError = false
    @Published var errorMessage = ""
    
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
        } catch SubscriptionError.notSignedIntoAppStore {
            errorMessage = "You need to be signed into the App Store to make purchases. Please sign in through Settings app."
            showError = true
        } catch {
            errorMessage = "Failed to purchase subscription: \(error.localizedDescription)"
            showError = true
        }
    }
    
    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Properly use the restore purchases method instead of triggering a purchase
            try await subscriptionService.restorePurchases()
            
            // Check if Pro status was successfully restored
            if !subscriptionService.isProUser {
                errorMessage = "No previous purchases found to restore"
                showError = true
            }
        } catch SubscriptionError.notSignedIntoAppStore {
            errorMessage = "You need to be signed into the App Store to restore purchases. Please sign in through Settings app."
            showError = true
        } catch {
            errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
            showError = true
        }
    }
} 