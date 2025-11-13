import Foundation
import SwiftUI
import Combine

/// Thin adapter that wraps SubscriptionStore for legacy compatibility
/// Mirrors SubscriptionStore state without business logic overrides
@MainActor
final class EntitlementsAdapter: ObservableObject {
    @Published private(set) var isPro: Bool = false
    @Published private(set) var isLoading: Bool = false
    /// Published combined pro access flag - mirrors store state
    @Published private(set) var hasProAccess: Bool = false

    private let store: SubscriptionStore
    private let migrationManager = MigrationManager.shared
    private var cancellables = Set<AnyCancellable>()

    init(store: SubscriptionStore) {
        self.store = store

        // Mirror SubscriptionStore isPro state (SSOT)
        store.$state
            .map { $0.isPro }  // Read actual Pro status from store
            .assign(to: &$isPro)

        // Mirror combined Pro access from store
        store.$state
            .map { $0.isPro }  // Read actual Pro status from store
            .receive(on: DispatchQueue.main)
            .assign(to: &$hasProAccess)

        store.$isLoading
            .assign(to: &$isLoading)
    }

    /// Effective Pro status - reads from SSOT
    var effectiveIsProUser: Bool {
        // Read from single source of truth
        return store.isPro
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
