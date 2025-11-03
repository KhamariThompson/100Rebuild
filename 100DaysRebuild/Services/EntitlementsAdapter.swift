import Foundation
import SwiftUI
import Combine

/// Thin adapter that wraps SubscriptionStore for legacy compatibility
/// This provides a migration path from the old Entitlements system to SubscriptionStore
@MainActor
final class EntitlementsAdapter: ObservableObject {
    @Published private(set) var isPro: Bool = false
    @Published private(set) var isLoading: Bool = false
    /// Published combined pro access flag that includes migration/grace period logic.
    @Published private(set) var hasProAccess: Bool = false

    private let store: SubscriptionStore
    private let migrationManager = MigrationManager.shared
    private var cancellables = Set<AnyCancellable>()

    init(store: SubscriptionStore) {
        self.store = store

        // Observe store state changes
        store.$state
            .map { $0.isPro }
            .assign(to: &$isPro)

        // Update combined hasProAccess whenever store state changes.
        store.$state
            .map { [migrationManager] state in
                // Effective pro includes store's isPro OR legacy grace period
                return state.isPro || migrationManager.isInLegacyGracePeriod()
            }
            .receive(on: DispatchQueue.main)
            .assign(to: &$hasProAccess)

        store.$isLoading
            .assign(to: &$isLoading)
    }

    /// Effective Pro status including legacy grace period
    var effectiveIsProUser: Bool {
        // Keep compatibility: reflect the latest published combined value
        let result = hasProAccess
        print("🔐 EntitlementsAdapter.effectiveIsProUser check:")
        print("   - RevenueCat isPro: \(isPro)")
        print("   - Legacy grace period: \(migrationManager.isInLegacyGracePeriod())")
        print("   - RESULT (hasProAccess): \(result)")
        return result
    }

    /// Refresh subscription status
    func refreshStatus() async {
        await store.load()
    }

    /// Check Pro status synchronously (for immediate UI needs)
    func checkProStatus() -> Bool {
        return effectiveIsProUser
    }
}

// MARK: - Shared singleton

@MainActor
extension EntitlementsAdapter {
    /// Backwards-compatible shared instance that wraps the shared SubscriptionStore.
    static let shared: EntitlementsAdapter = {
        let adapter = EntitlementsAdapter(store: SubscriptionStore.shared)
        return adapter
    }()
}
