import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import RevenueCat

/// SSOT ObservableObject for subscription state
/// This is the ONLY place the UI should read subscription information from
@MainActor
final class SubscriptionStore: NSObject, ObservableObject, PurchasesDelegate {
    @Published private(set) var state: SubscriptionState = .default
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var error: Error?

    nonisolated private let repository: SubscriptionRepository
    private var foundersWindow: FoundersWindowState?

    // MARK: - Grandfather Pro State
    private var customerInfo: CustomerInfo?
    private var profile: ProfileData?

    // Persistence keys
    private let foundersWindowKey = "founders_window_state_v1"

    nonisolated init(repository: SubscriptionRepository) {
        self.repository = repository
        super.init()

        #if DEBUG
        print("🔐 SubscriptionStore.init id=\(ObjectIdentifier(self))")
        #endif

        // Set delegate on MainActor to avoid dispatch queue assertion
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            Purchases.shared.delegate = self
        }
    }

    // MARK: - PurchasesDelegate

    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            // Update customer info and recompute state
            setCustomerInfo(customerInfo)
        }
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
            // Get customer info from RevenueCat
            let info = try await Purchases.shared.customerInfo()
            setCustomerInfo(info)

            // Note: Profile (accountCreatedAt) is set by UserSession.loadUserProfile()
            // This keeps the data flow simple and avoids duplicate Firestore reads
        } catch {
            self.error = error
        }

        isLoading = false
    }

    /// Purchase a subscription plan with optional explicit product ID
    /// - Parameters:
    ///   - plan: The plan to purchase
    ///   - explicitProductId: Optional product ID override (for annual intro vs no-intro selection)
    /// - Returns: The purchased product ID
    @discardableResult
    func purchase(_ plan: SubscriptionPlan, explicitProductId: String? = nil) async throws -> String {
        isLoading = true
        error = nil

        let targetProduct = explicitProductId ?? plan.productId

        do {
            let (status, purchasedProductId) = try await repository.purchase(plan, explicitProductId: explicitProductId)
            // Get fresh customer info after purchase
            let info = try await Purchases.shared.customerInfo()
            setCustomerInfo(info)
            isLoading = false
            return purchasedProductId
        } catch {
            self.error = error
            isLoading = false
            throw error
        }
    }

    /// Restore previous purchases
    func restorePurchases() async throws {
        isLoading = true
        error = nil

        do {
            let status = try await repository.restorePurchases()
            // Get fresh customer info after restore
            let info = try await Purchases.shared.customerInfo()
            setCustomerInfo(info)
        } catch {
            self.error = error
            isLoading = false
            throw error
        }

        isLoading = false
    }

    /// Refresh entitlements from server
    func refreshEntitlements() async {
        do {
            let status = try await repository.refreshEntitlements()
            // Get fresh customer info after refresh
            let info = try await Purchases.shared.customerInfo()
            setCustomerInfo(info)
        } catch {
            // Silent fail for refresh
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
            // Use logIn to identify the user and potentially migrate anonymous purchases
            let loginResult = try await Purchases.shared.logIn(userId)
            // Refresh state after identification
            await load()
        } catch {
            // Silent fail
        }
    }

    /// Get product info from StoreKit
    func getProductInfo(for plan: SubscriptionPlan) async throws -> ProductInfo {
        return try await repository.getProductInfo(for: plan)
    }

    // MARK: - Founders Window

    /// Start the 5-minute founders window (only once per user, only for NEW non-legacy users)
    func startFiveMinuteWindow() {
        // Check if window was already started before
        loadFoundersWindow()

        if let existing = foundersWindow, existing.startedAt != nil {
            return
        }

        // First time - create window
        foundersWindow = .start()
        saveFoundersWindow()
    }

    /// Get the current founders window (loads from UserDefaults if not in memory)
    func getFiveMinuteWindow() -> FoundersWindowState? {
        if foundersWindow == nil {
            loadFoundersWindow()
        }
        return foundersWindow
    }

    /// Mark that the user has consumed the founders intro offer
    /// This persists to BOTH local UserDefaults AND Firestore for reinstall protection
    func markFoundersOfferConsumed() async {
        loadFoundersWindow()

        // Update local state
        if var window = foundersWindow {
            window.foundersOfferConsumed = true
            foundersWindow = window
            saveFoundersWindow()
        } else {
            // Create a consumed state even if window never started
            foundersWindow = FoundersWindowState(version: 1, startedAt: nil, foundersOfferConsumed: true)
            saveFoundersWindow()
        }

        // Persist to Firestore for server-backed enforcement
        await persistFoundersOfferConsumption()
    }

    /// Persist Founder's Offer consumption to Firestore
    /// This prevents reinstall exploits by storing server-side record
    private func persistFoundersOfferConsumption() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("⚠️ SubscriptionStore: Cannot persist founders offer - no user logged in")
            return
        }

        do {
            let db = Firestore.firestore()
            try await db.collection("users").document(userId).updateData([
                "foundersOfferConsumedAt": Timestamp(date: Date())
            ])
            print("✅ SubscriptionStore: Persisted founders offer consumption to Firestore")
        } catch {
            print("❌ SubscriptionStore: Failed to persist founders offer consumption: \(error.localizedDescription)")
            // Non-fatal - local state still updated
        }
    }

    /// Check if user has already consumed the Founder's Offer (server-backed check)
    /// Returns true if consumed, false if not, nil if unable to fetch (offline/error)
    func hasConsumedFoundersOfferServer() async -> Bool? {
        guard let userId = Auth.auth().currentUser?.uid else {
            return nil
        }

        do {
            let db = Firestore.firestore()
            let doc = try await db.collection("users").document(userId).getDocument()

            // Check server record
            if let consumedAt = doc.data()?["foundersOfferConsumedAt"] as? Timestamp {
                print("✅ SubscriptionStore: Server shows founders offer consumed at \(consumedAt.dateValue())")
                return true
            }

            // Also check declined flag (if implemented)
            if let declinedAt = doc.data()?["foundersOfferDeclinedAt"] as? Timestamp {
                print("✅ SubscriptionStore: Server shows founders offer declined at \(declinedAt.dateValue())")
                return true  // Declined counts as consumed (no re-offer)
            }

            print("✅ SubscriptionStore: Server shows no founders offer consumption")
            return false
        } catch {
            print("⚠️ SubscriptionStore: Unable to fetch founders offer status from server: \(error.localizedDescription)")
            return nil  // Unable to determine - caller should handle conservatively
        }
    }

    /// Clear the founders window
    func clearFiveMinuteWindow() {
        foundersWindow = nil
        UserDefaults.standard.removeObject(forKey: foundersWindowKey)
        // Also remove legacy key for backwards compatibility
        UserDefaults.standard.removeObject(forKey: "five_minute_window")
    }

    // MARK: - Private

    private func updateState(with status: SubscriptionStatus) {
        let isPaywallRequired = !status.isPro
        state = SubscriptionState(status: status, isPaywallRequired: isPaywallRequired)
    }

    private func saveFoundersWindow() {
        if let window = foundersWindow,
           let data = try? JSONEncoder().encode(window) {
            UserDefaults.standard.set(data, forKey: foundersWindowKey)
        }
    }

    private func loadFoundersWindow() {
        // Try new versioned key first
        if let data = UserDefaults.standard.data(forKey: foundersWindowKey),
           let window = try? JSONDecoder().decode(FoundersWindowState.self, from: data) {
            foundersWindow = window
            return
        }

        // Fallback: try legacy key for migration
        if let data = UserDefaults.standard.data(forKey: "five_minute_window") {
            // Try to decode as old FiveMinuteWindow struct (just had `start: Date`)
            if let legacyDecoded = try? JSONDecoder().decode(LegacyWindow.self, from: data) {
                // Migrate to new structure
                foundersWindow = FoundersWindowState(
                    version: 1,
                    startedAt: legacyDecoded.start,
                    foundersOfferConsumed: false
                )
                saveFoundersWindow()
                // Remove legacy key
                UserDefaults.standard.removeObject(forKey: "five_minute_window")
            }
        }
    }

    /// Legacy window structure for migration
    private struct LegacyWindow: Codable {
        let start: Date
    }

    // MARK: - Reset

    /// Reset the store to default state. Used on sign-out to clear subscription state.
    func reset() async {
        #if DEBUG
        print("🔐 SubscriptionStore.reset - Clearing all state")
        #endif
        // Clear runtime state
        isLoading = false
        error = nil
        state = .default
        // Clear persisted five-minute window
        clearFiveMinuteWindow()
        // Clear grandfather state
        customerInfo = nil
        profile = nil
        // Force recompute to ensure clean state
        recomputeState()
    }

    // MARK: - Grandfather Pro Logic

    /// Simple profile data structure for grandfather checks
    struct ProfileData {
        let accountCreatedAt: Date?
    }

    /// Update customer info and recompute state
    func setCustomerInfo(_ info: CustomerInfo) {
        #if DEBUG
        print("🔐 SubscriptionStore.setCustomerInfo id=\(ObjectIdentifier(self))")
        #endif
        self.customerInfo = info
        recomputeState()
    }

    /// Update profile and recompute state
    func setProfile(_ profileData: ProfileData) {
        #if DEBUG
        print("🔐 SubscriptionStore.setProfile id=\(ObjectIdentifier(self))")
        #endif
        self.profile = profileData
        recomputeState()
    }

    /// Recompute subscription state by merging RevenueCat Pro + Grandfather Pro
    private func recomputeState() {
        // Check RC entitlement using exact case from SubscriptionIDs
        let rcHasPro: Bool = {
            guard let info = customerInfo else { return false }
            if let ent = info.entitlements[SubscriptionIDs.entitlement] {
                return ent.isActive
            }
            return false
        }()

        // Check grandfather status
        let grandfather: Bool = {
            guard let created = profile?.accountCreatedAt else { return false }
            return SubscriptionPolicy.isGrandfathered(accountCreatedAt: created)
        }()

        // Update state fields
        state.rcIsPro = rcHasPro
        state.isGrandfatherActive = grandfather
        state.isPro = rcHasPro || grandfather  // EFFECTIVE PRO
        state.isGrandfathered = grandfather
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
