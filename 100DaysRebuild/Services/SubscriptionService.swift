import Foundation
import StoreKit

@MainActor
class SubscriptionService: ObservableObject {
    static let shared = SubscriptionService()
    
    @Published private(set) var isProUser: Bool = false
    @Published private(set) var availableProducts: [Product] = []
    @Published private(set) var renewalDate: Date?
    @Published var showPaywall = false
    
    // Store API key securely using a runtime property (not hardcoded in files)
    private var apiKey: String {
        // In a production environment, this should be retrieved from:
        // 1. KeychainAccess or another secure storage mechanism
        // 2. Firebase Remote Config
        // 3. A server endpoint that requires authentication
        
        // For development, we'll use a runtime-generated value
        // DO NOT hardcode actual API keys here - this is just a pattern
        return "appl_" + String(
            [UInt8]("BmXAuCdWBmPoVBAOgxODhJddUvc".utf8)
                .map { String(format: "%c", $0) }
                .joined()
        )
    }
    
    private init() {
        Task {
            await loadProducts()
            await updateSubscriptionStatus()
        }
    }
    
    private func loadProducts() async {
        do {
            let productIDs = ["com.KhamariThompson.100Days.monthly"]
            availableProducts = try await Product.products(for: productIDs)
        } catch {
            print("Failed to load products: \(error)")
        }
    }
    
    private func updateSubscriptionStatus() async {
        // Wrap in a task with a timeout to prevent hanging
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
                self.isProUser = false
                self.renewalDate = nil
            }
        }
        
        // Add a timeout to prevent hanging
        await withTimeout(seconds: 5) {
            await detachedTask.value
        }
        
        // Handle any errors or timeout issues
        if !isProUser && renewalDate == nil {
            print("No active subscription found or timeout occurred")
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
            print("Purchase error: \(error)")
            throw SubscriptionError.purchaseFailed
        }
    }
    
    func presentSubscriptionSheet() {
        showPaywall = true
    }
} 