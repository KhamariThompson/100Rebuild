import Foundation
import SwiftUI
import FirebaseAuth

/// Centralized routing logic for the app
/// This is the SINGLE SOURCE OF TRUTH for routing decisions
@MainActor
class AppRouter: ObservableObject {

    // MARK: - Route Enum

    enum Route: Equatable {
        case splash
        case auth
        case loading
        case funnel
        case mainPro
        case paywall  // Show paywall for users without Pro who didn't convert
    }

    // MARK: - Entitlements Load State

    enum EntitlementsLoadState {
        case idle
        case loading
        case loaded
        case failed
        case timedOut
    }

    // MARK: - Published State

    @Published var currentRoute: Route = .splash
    @Published var entitlementsState: EntitlementsLoadState = .idle

    private var entitlementsLoadStartTime: Date?

    // MARK: - Dependencies

    private let migrationManager = MigrationManager.shared

    // MARK: - Timer Management

    /// Start the entitlements loading timer (call from Task, not from body)
    func startEntitlementsTimer() {
        if entitlementsLoadStartTime == nil {
            entitlementsLoadStartTime = Date()
            entitlementsState = .loading
        }
    }

    /// Mark entitlements as loaded (call from Task, not from body)
    func markEntitlementsLoaded() {
        entitlementsState = .loaded
        entitlementsLoadStartTime = nil
    }

    /// Mark entitlements as timed out (call from Task, not from body)
    func markEntitlementsTimedOut() {
        entitlementsState = .timedOut
    }

    // MARK: - Route Computation

    /// Compute the appropriate route based on current state
    /// This is the ONLY function that should determine routing
    func computeRoute(
        isAuthenticated: Bool,
        accountCreatedAt: Date?,
        completedOnboarding: Bool,
        hasCompletedFunnel: Bool,
        isPro: Bool,
        entitlementsLoaded: Bool,
        now: Date = Date()
    ) -> Route {

        // Feature flag check - if routing v2 is disabled, fall back to legacy
        guard Constants.FeatureFlags.routingV2Enabled else {
            return computeLegacyRoute(isAuthenticated: isAuthenticated, isPro: isPro, entitlementsLoaded: entitlementsLoaded)
        }

        // Manual override check - support/debug only
        if Constants.FeatureFlags.overrideNoFunnel {
            return isAuthenticated ? (isPro ? .mainPro : .paywall) : .auth
        }

        // Step 1: Auth gate
        guard isAuthenticated else {
            return .auth
        }

        // Step 2: Wait for entitlements if still loading (with timeout)
        // NOTE: State mutations moved to caller to avoid "Publishing changes from within view updates" warning
        if !entitlementsLoaded {
            if let startTime = entitlementsLoadStartTime {
                let elapsed = now.timeIntervalSince(startTime)
                if elapsed > Constants.Onboarding.entitlementsLoadTimeout {
                    // Fall through to continue routing without entitlements
                } else {
                    return .loading
                }
            } else {
                // First time seeing loading state
                return .loading
            }
        }

        // Step 3: Use effective Pro status from SubscriptionStore
        // Note: isPro already includes both RC Pro and Grandfather Pro
        let effectiveIsProUser = isPro

        #if DEBUG
        // For logging, compute grandfather status separately (DEBUG ONLY)
        let isGrandfatherActive: Bool = {
            guard let acctAt = accountCreatedAt else { return false }
            let cutoff = Constants.Onboarding.newFunnelStartDate
            let gracePeriodEnd = acctAt.addingTimeInterval(Constants.Onboarding.grandfatherDuration)
            let active = acctAt < cutoff && now < gracePeriodEnd
            return active
        }()
        // Routing only uses SubscriptionStore.state.isPro; grandfather block above is debug-only
        #endif

        // Step 5: Make routing decision (SIMPLIFIED - removed time-based gates)
        // Users MUST have Pro to access main app (includes RC Pro + Grandfather Pro)
        let route: Route
        if effectiveIsProUser {
            // User has Pro (RC Pro OR Grandfather Pro) - grant app access
            route = .mainPro
        } else if !hasCompletedFunnel {
            // User hasn't completed funnel - MUST complete it first
            // This enforces: SignUp → Funnel (mandatory for all non-Pro users)
            route = .funnel
        } else {
            // User completed funnel but doesn't have Pro - block at paywall
            // This enforces: Funnel → Paywall (block until purchase)
            route = .paywall
        }

        return route
    }

    // MARK: - Legacy Routing (Fallback)

    private func computeLegacyRoute(
        isAuthenticated: Bool,
        isPro: Bool,
        entitlementsLoaded: Bool
    ) -> Route {
        if !isAuthenticated {
            return .auth
        } else if isPro {
            return .mainPro
        } else if !entitlementsLoaded {
            return .loading
        } else {
            // No Pro - show paywall
            return .paywall
        }
    }

    // Logging removed for production
}
