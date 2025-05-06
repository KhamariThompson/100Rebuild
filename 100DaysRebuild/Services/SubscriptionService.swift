import Foundation
import StoreKit

@MainActor
class SubscriptionService: ObservableObject {
    static let shared = SubscriptionService()
    
    @Published private(set) var isProUser: Bool = false
    @Published private(set) var availableProducts: [Product] = []
    @Published private(set) var renewalDate: Date?
    @Published var showPaywall = false
    
    private init() {
        Task {
            await loadProducts()
            await updateSubscriptionStatus()
        }
    }
    
    private func loadProducts() async {
        do {
            let productIDs = ["com.100days.monthly"]
            availableProducts = try await Product.products(for: productIDs)
        } catch {
            print("Failed to load products: \(error)")
        }
    }
    
    private func updateSubscriptionStatus() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                isProUser = true
                renewalDate = transaction.expirationDate
                return
            }
        }
        isProUser = false
        renewalDate = nil
    }
    
    func purchaseSubscription(plan: SubscriptionPlan) async throws {
        let productID = "com.100days.monthly"
        
        guard let product = availableProducts.first(where: { $0.id == productID }) else {
            throw SubscriptionError.purchaseFailed
        }
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await updateSubscriptionStatus()
                }
            case .userCancelled:
                throw SubscriptionError.purchaseFailed
            case .pending:
                print("Purchase pending")
            @unknown default:
                throw SubscriptionError.unknown
            }
        } catch {
            throw SubscriptionError.purchaseFailed
        }
    }
    
    func presentSubscriptionSheet() {
        showPaywall = true
    }
} 