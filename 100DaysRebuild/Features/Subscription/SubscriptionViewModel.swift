import Foundation
import Combine

@MainActor
class SubscriptionViewModel: ObservableObject {
    @Published private(set) var features: [ProFeature] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: SubscriptionError?
    
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
    
    func purchase() async {
        do {
            try await subscriptionService.purchase()
        } catch {
            self.error = .purchaseFailed
        }
    }
    
    func restorePurchases() async {
        do {
            try await subscriptionService.restorePurchases()
        } catch {
            self.error = .restoreFailed
        }
    }
    
    func login(userId: String) async {
        await subscriptionService.login(userId: userId)
    }
} 