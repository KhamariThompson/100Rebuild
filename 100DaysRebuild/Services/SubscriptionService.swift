import Foundation
import RevenueCat
import Combine

enum SubscriptionError: Error {
    case purchaseFailed
    case restoreFailed
    case unknown
}

@MainActor
class SubscriptionService: ObservableObject {
    static let shared = SubscriptionService()
    
    @Published private(set) var isSubscribed = false
    @Published private(set) var isLoading = false
    @Published private(set) var error: SubscriptionError?
    
    private init() {
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: Configuration.revenueCatAPIKey)
    }
    
    func login(userId: String) async {
        do {
            try await Purchases.shared.logIn(userId)
            await checkSubscriptionStatus()
        } catch {
            print("Error logging in to RevenueCat: \(error)")
        }
    }
    
    func purchase() async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let offerings = try await Purchases.shared.offerings()
            guard let offering = offerings.current else {
                throw SubscriptionError.unknown
            }
            
            let result = try await Purchases.shared.purchase(package: offering.availablePackages[0])
            isSubscribed = result.customerInfo.entitlements["pro"]?.isActive == true
        } catch {
            self.error = .purchaseFailed
            throw error
        }
    }
    
    func restorePurchases() async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            isSubscribed = customerInfo.entitlements["pro"]?.isActive == true
        } catch {
            self.error = .restoreFailed
            throw error
        }
    }
    
    private func checkSubscriptionStatus() async {
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            isSubscribed = customerInfo.entitlements["pro"]?.isActive == true
        } catch {
            print("Error checking subscription status: \(error)")
        }
    }
} 