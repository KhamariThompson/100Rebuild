import Foundation
import SwiftUI
import FirebaseAuth
import RevenueCat

/// SSOT ObservableObject for subscription state
/// This is the ONLY place the UI should read subscription information from
@MainActor
final class SubscriptionStore: ObservableObject {
    @Published private(set) var state: SubscriptionState = .default
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var error: Error?

    private let repository: SubscriptionRepository
    private var fiveMinuteWindow: FiveMinuteWindow?

    init(repository: SubscriptionRepository) {
        self.repository = repository
    }

    // MARK: - Public API

    /// Whether user has Pro access
    var isPro: Bool {
        state.isPro
    }

    /// Load subscription status from repository
    func load() async {
        isLoading = true
        error = nil

        do {
            // Check grandfathered status first
            if let userId = Auth.auth().currentUser?.uid {
                let isGrandfathered = try await repository.checkGrandfatheredStatus(userId: userId)

                if isGrandfathered {
                    state = .grandfathered
                    isLoading = false
                    print("✅ SubscriptionStore: User is grandfathered")
                    return
                }
            }

            // Load normal status from RevenueCat
            let status = try await repository.loadStatus()
            updateState(with: status)
            print("✅ SubscriptionStore: Loaded status - isPro: \(state.isPro)")
        } catch {
            self.error = error
            print("❌ SubscriptionStore: Failed to load - \(error)")
        }

        isLoading = false
    }

    /// Purchase a subscription plan
    func purchase(_ plan: SubscriptionPlan) async throws {
        isLoading = true
        error = nil

        print("🔐 SubscriptionStore: Purchasing \(plan.rawValue)")

        do {
            let status = try await repository.purchase(plan)
            updateState(with: status)
            print("✅ SubscriptionStore: Purchase successful")
        } catch {
            self.error = error
            isLoading = false
            print("❌ SubscriptionStore: Purchase failed - \(error)")
            throw error
        }

        isLoading = false
    }

    /// Restore previous purchases
    func restorePurchases() async throws {
        isLoading = true
        error = nil

        print("🔐 SubscriptionStore: Restoring purchases")

        do {
            let status = try await repository.restorePurchases()
            updateState(with: status)
            print("✅ SubscriptionStore: Restore successful")
        } catch {
            self.error = error
            isLoading = false
            print("❌ SubscriptionStore: Restore failed - \(error)")
            throw error
        }

        isLoading = false
    }

    /// Refresh entitlements from server
    func refreshEntitlements() async {
        do {
            let status = try await repository.refreshEntitlements()
            updateState(with: status)
            print("✅ SubscriptionStore: Refreshed entitlements")
        } catch {
            print("⚠️ SubscriptionStore: Failed to refresh - \(error)")
        }
    }

    /// Check if user is eligible for intro offer
    func isIntroEligible(for plan: SubscriptionPlan) async -> Bool {
        return await repository.isIntroEligible(for: plan)
    }

    /// Identify the current user with RevenueCat and refresh status.
    func identifyUser(_ userId: String) async {
        // Avoid unnecessary identify calls
        if Purchases.shared.appUserID == userId {
            return
        }

        do {
            print("🔐 SubscriptionStore: Identifying RevenueCat user: \(userId)")
            // Use logIn to identify the user and potentially migrate anonymous purchases
            let loginResult = try await Purchases.shared.logIn(userId)
            // Optionally log transfer info
            #if DEBUG
            print("🔐 SubscriptionStore: RevenueCat login created: \(loginResult.created)")
            print("🔐 SubscriptionStore: RevenueCat originalAppUserId: \(loginResult.customerInfo.originalAppUserId)")
            #endif
            // Refresh state after identification
            await load()
        } catch {
            print("⚠️ SubscriptionStore: Failed to identify user with RevenueCat - \(error)")
        }
    }

    /// Get product info from StoreKit
    func getProductInfo(for plan: SubscriptionPlan) async throws -> ProductInfo {
        return try await repository.getProductInfo(for: plan)
    }

    // MARK: - Five-Minute Window

    /// Start the 5-minute welcome offer window
    func startFiveMinuteWindow() {
        fiveMinuteWindow = .start()
        saveFiveMinuteWindow()
        print("⏱️  SubscriptionStore: Started 5-minute window")
    }

    /// Get the current five-minute window (loads from UserDefaults if not in memory)
    func getFiveMinuteWindow() -> FiveMinuteWindow? {
        if fiveMinuteWindow == nil {
            loadFiveMinuteWindow()
        }
        return fiveMinuteWindow
    }

    /// Clear the five-minute window
    func clearFiveMinuteWindow() {
        fiveMinuteWindow = nil
        UserDefaults.standard.removeObject(forKey: "five_minute_window")
        print("🗑️  SubscriptionStore: Cleared 5-minute window")
    }

    // MARK: - Private

    private func updateState(with status: SubscriptionStatus) {
        let isPaywallRequired = !status.isPro
        state = SubscriptionState(status: status, isPaywallRequired: isPaywallRequired)
    }

    private func saveFiveMinuteWindow() {
        if let window = fiveMinuteWindow,
           let data = try? JSONEncoder().encode(window) {
            UserDefaults.standard.set(data, forKey: "five_minute_window")
        }
    }

    private func loadFiveMinuteWindow() {
        if let data = UserDefaults.standard.data(forKey: "five_minute_window"),
           let window = try? JSONDecoder().decode(FiveMinuteWindow.self, from: data) {
            // Only load if still active, otherwise clear it
            if window.isActive {
                fiveMinuteWindow = window
                print("⏱️  SubscriptionStore: Loaded active 5-minute window")
            } else {
                clearFiveMinuteWindow()
            }
        }
    }

    // MARK: - Reset

    /// Reset the store to default state. Used on sign-out to clear subscription state.
    func reset() async {
        // Clear runtime state
        isLoading = false
        error = nil
        state = .default
        // Clear persisted five-minute window
        clearFiveMinuteWindow()
    }
}

// MARK: - Shared singleton

@MainActor
extension SubscriptionStore {
    /// Backwards-compatible shared instance. Uses the RevenueCat implementation by default.
    static let shared: SubscriptionStore = {
        let store = SubscriptionStore(repository: RevenueCatSubscriptionRepository())
        // Kick off an initial load in the background
        Task {
            await store.load()
        }
        return store
    }()
}

// MARK: - Helper

/// Check if user requires Pro access
@MainActor
func requirePro(_ store: SubscriptionStore) -> Bool {
    return store.isPro
}
