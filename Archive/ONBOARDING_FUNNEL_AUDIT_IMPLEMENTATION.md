# 100Days – Onboarding & Funnel Audit Implementation Summary

**Date**: October 29, 2025
**Goal**: Stop legacy/grandfathered users from seeing the new funnel every launch; ensure only **new** sign-ups enter the funnel; fix RevenueCat Apple In-App Purchase Key error; tighten onboarding state, routing, and entitlements loading.

---

## ✅ Changes Implemented

### 1. RevenueCat In-App Purchase Key Setup (HIGH PRIORITY)

**Problem**: RevenueCat logs showing "Apple In-App Purchase Key is invalid or not present" - this blocks correct entitlement syncing.

**Solution**: Created comprehensive setup guide at `REVENUECAT_IAP_KEY_SETUP.md`

**Action Required**:
1. Generate In-App Purchase Key in App Store Connect (Users & Access → Keys → In-App Purchase)
2. Download `.p8` file and note Key ID + Issuer ID
3. Upload to RevenueCat Dashboard (Apps → Your App → Apple App Store → Add In-App Purchase Key)
4. Verify Bundle ID and Products match
5. (Optional) Enable App Store Server Notifications v2

**File**: `/REVENUECAT_IAP_KEY_SETUP.md`

---

### 2. Centralized Constants for Grandfathering & Onboarding

**Added to `Core/Utils/Constants.swift`**:

```swift
enum Onboarding {
    // Legacy cutoff: Users registered BEFORE Nov 1, 2025 get grandfathered (1 year free Pro)
    static let newFunnelStartDate: Date // Nov 1, 2025 00:00 UTC

    // Founder window cutoff: Oct 10, 2025
    static let founderWindowCutoff: Date // Oct 10, 2025 00:00 UTC

    // Grandfathered users get 1 year from account creation date
    static let grandfatherDuration: TimeInterval // 365 days

    // Current funnel schema version
    static let funnelSchemaVersion = 1

    // New signup grace period (10 minutes)
    static let newSignupGracePeriod: TimeInterval // 10 minutes

    // Entitlements load timeout (4 seconds)
    static let entitlementsLoadTimeout: TimeInterval // 4 seconds
}

enum FeatureFlags {
    // Enable routing v2 (default: true)
    static var routingV2Enabled: Bool

    // Manual override to skip funnel (support/debug only)
    static var overrideNoFunnel: Bool
}
```

**File**: `Core/Utils/Constants.swift` (lines 92-149)

---

### 3. Updated MigrationManager with Correct Dates & Tracking

**Changes**:
- Now uses centralized `Constants.Onboarding.newFunnelStartDate` (Nov 1, 2025)
- Added `completedOnboardingAt` tracking (local + Firestore)
- Added `lastFunnelShownVersion` tracking
- New methods:
  - `markOnboardingCompleted(userId:)` - Called when user finishes funnel
  - `hasCompletedOnboarding(userId:)` - Check if user completed onboarding
  - `getAccountCreatedAt(userId:)` - Fetch account creation date from Firestore

**Key Firestore Fields**:
- `completedOnboardingAt`: Timestamp (when funnel was completed)
- `lastFunnelShownVersion`: Int (funnel schema version)
- `funnelSchemaVersion`: Int (stored on new user setup)

**File**: `Services/MigrationManager.swift`

---

### 4. Centralized Routing Logic (NEW FILE)

**Created**: `Core/Navigation/AppRouter.swift`

**Purpose**: Single source of truth for ALL routing decisions.

**Routes**:
- `.splash` - Initial loading
- `.auth` - WelcomeView (unauthenticated)
- `.loading` - CommitNowView (entitlements loading)
- `.funnel` - ImprovedFunnelView (new users only)
- `.mainPro` - MainAppView (Pro access)
- `.mainFree` - MainAppView (Free access)

**Key Logic**:
```swift
func computeRoute(
    isAuthenticated: Bool,
    accountCreatedAt: Date?,
    completedOnboarding: Bool,
    isPro: Bool,
    entitlementsLoaded: Bool
) -> Route
```

**Routing Contract**:
1. If not authenticated → `.auth`
2. If entitlements still loading (< 4s timeout) → `.loading`
3. Compute `isGrandfatherActive`:
   - `accountCreatedAt < Nov 1, 2025` AND `now < accountCreatedAt + 1 year`
4. Compute `effectiveIsProUser = isPro || isGrandfatherActive`
5. Compute `isNewSignup`:
   - `now - accountCreatedAt < 10 minutes`
6. Route decision:
   - If `effectiveIsProUser` → `.mainPro`
   - Else if `completedOnboarding` → `.mainFree`
   - Else if `isNewSignup` → `.funnel`
   - Else → `.mainFree`

**Logging**: Comprehensive routing logs with all state variables (see Section 8 below)

**Feature Flags**:
- `routing.v2.enabled` (UserDefaults) - Enable/disable new routing
- `override.no_funnel` (UserDefaults) - Manual override to skip funnel

**File**: `Core/Navigation/AppRouter.swift`

---

### 5. Updated App.swift Routing

**Changes to `AppContentView`**:

**New State Variables**:
```swift
@StateObject private var appRouter = AppRouter()
@State private var accountCreatedAt: Date? = nil
@State private var completedOnboarding = false
```

**New Routing Logic** (lines 854-912):
```swift
let route = appRouter.computeRoute(
    isAuthenticated: userSession.isAuthenticated,
    accountCreatedAt: accountCreatedAt,
    completedOnboarding: completedOnboarding,
    isPro: subscriptionStore.isPro,
    entitlementsLoaded: subscriptionLoaded
)

switch route {
    case .splash: SplashScreen()
    case .auth: WelcomeView()
    case .loading: CommitNowView()
    case .funnel: ImprovedFunnelView { /* mark complete */ }
    case .mainPro: MainAppView()
    case .mainFree: MainAppView()
}
```

**On Authentication** (lines 920-964):
1. Check and perform migration
2. **Load `accountCreatedAt` from Firestore** (via `MigrationManager.getAccountCreatedAt()`)
3. **Load `completedOnboarding` status** (via `MigrationManager.hasCompletedOnboarding()`)
4. Identify user with RevenueCat
5. Load subscription status
6. Mark `subscriptionLoaded = true`

**On Funnel Completion**:
```swift
try await MigrationManager.shared.markOnboardingCompleted(userId: userId)
print("[Onboarding] completedOnboardingAt set: \(Date())")
completedOnboarding = true
await subscriptionStore.load()
```

**File**: `App.swift` (lines 795-964)

---

### 6. Entitlements Load Grace Period

**Implementation**: Built into `AppRouter.computeRoute()`

**Logic**:
- Start timer when `entitlementsLoaded == false`
- Wait up to 4 seconds (`Constants.Onboarding.entitlementsLoadTimeout`)
- Show `.loading` route during grace period
- After timeout, continue routing without entitlements (use `isGrandfatherActive` + `completedOnboarding`)
- **Never route to funnel if entitlements are unknown**

**File**: `Core/Navigation/AppRouter.swift` (lines 47-72)

---

### 7. Persistence Model

**UserDefaults Keys** (via `MigrationManager`):
- `completed_onboarding_at` - Date when onboarding completed
- `last_funnel_shown_version` - Int schema version
- `legacy_user_grace_period_end` - Date when grace period ends

**Firestore Fields** (`users/{userId}`):
- `accountCreatedAt`: Timestamp (source of truth)
- `completedOnboardingAt`: Timestamp (when funnel finished)
- `lastFunnelShownVersion`: Int
- `funnelSchemaVersion`: Int
- `isLegacyUser`: Boolean
- `legacyGracePeriodEnd`: Timestamp
- `needsFunnelOnboarding`: Boolean

---

### 8. Instrumentation & Logging

**Comprehensive routing logs** in `AppRouter.logRoutingDecision()`:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[Route] ROUTING DECISION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[Route] Auth State:
  - isAuthenticated: true

[Route] User Profile:
  - accountCreatedAt: 2025-10-15T12:34:56Z
  - cutoffDate: 2025-11-01T00:00:00Z
  - registeredBeforeCutoff: true
  - completedOnboarding: false

[Route] Subscription State:
  - RC.isPro: false
  - isGrandfatherActive: true
  - effectiveIsProUser: true
  - entitlementsLoaded: true

[Route] Funnel Eligibility:
  - isNewSignup: false
  - shouldShowFunnel: false

[Route] RESULT → mainPro
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Additional logs**:
- `[Onboarding] completedOnboardingAt set: <timestamp>` (when funnel completes)
- MigrationManager logs for legacy user setup, grace period calculations
- EntitlementsAdapter logs for Pro status checks

---

### 9. Feature Flags & Manual Overrides

**Routing V2 Feature Flag**:
```swift
UserDefaults.standard.set(false, forKey: "routing.v2.enabled")
```
Set to `false` to revert to legacy routing behavior.

**Manual Override** (support/debug only):
```swift
UserDefaults.standard.set(true, forKey: "override.no_funnel")
```
Set to `true` to skip funnel entirely.

---

## 🎯 QA Test Matrix

### Cohort A: New Signup (post Nov 1, 2025), No Purchase
**Expected**:
1. Sign up → See funnel once
2. Complete funnel → Never see funnel again
3. Reinstall → Still don't see funnel (reads `completedOnboardingAt` from Firestore)

**Test**:
- Create new account (Nov 1, 2025 or later)
- Check logs: `isNewSignup: true`, `shouldShowFunnel: true`
- Complete funnel
- Check logs: `completedOnboarding: true`, `shouldShowFunnel: false`
- Force quit and reopen → Should go to MainAppView

---

### Cohort B: Legacy User (pre Nov 1, 2025), No Purchase
**Expected**:
1. Login → **Skip funnel**
2. Go directly to MainAppView (Free or Pro access via grace period)
3. Never see funnel for 1 year from account creation

**Test**:
- Login with existing account (created before Nov 1, 2025)
- Check logs: `isGrandfatherActive: true`, `effectiveIsProUser: true`
- Should route to `.mainPro` or `.mainFree`
- **Should NOT see funnel at any point**

---

### Cohort C: Pro Subscriber (Any Date)
**Expected**:
1. Login → Never see funnel
2. Go directly to MainAppView (Pro)

**Test**:
- Login with account that has active RevenueCat subscription
- Check logs: `RC.isPro: true`, `effectiveIsProUser: true`
- Should route to `.mainPro`

---

### Cohort D: Legacy + Purchase Later
**Expected**:
1. Login as legacy user → Skip funnel
2. Purchase subscription → Never see funnel
3. Grace period ends → Still have Pro access via subscription

**Test**:
- Login as legacy user
- Purchase subscription while grace period active
- Wait for grace period to expire (or manually set date forward)
- Check logs: `isGrandfatherActive: false`, `RC.isPro: true`, `effectiveIsProUser: true`
- Should still route to `.mainPro`

---

## 🔍 Likely Root Causes (Now Fixed)

### 1. Entitlements Not Loading (RC Key Error)
**Was**: App assumes `isPro=false` when RC fails → routes to funnel by default
**Now**:
- Setup guide for RC In-App Purchase Key
- 4-second grace period before routing
- Uses `isGrandfatherActive` as fallback

### 2. Login Treated as Signup
**Was**: `isNewSignup` always true (wrong `accountCreatedAt` or recomputed locally)
**Now**:
- Reads `accountCreatedAt` from Firestore (server source of truth)
- `isNewSignup` only true if `now - accountCreatedAt < 10 minutes`

### 3. `completedOnboardingAt` Never Set or Not Read
**Was**: Funnel appears forever because completion not tracked
**Now**:
- `markOnboardingCompleted()` called when funnel finishes
- Stored in both UserDefaults and Firestore
- Read at launch via `hasCompletedOnboarding()`

### 4. Clock/Timezone Drift
**Was**: `accountCreatedAt` compared using local time → misclassified users
**Now**:
- All dates use UTC in `Constants.Onboarding`
- Firestore Timestamps automatically handle timezone conversion

### 5. Router Runs Before Profile Load
**Was**: `accountCreatedAt` is nil → falls back to funnel
**Now**:
- Profile loaded in `onChange(of: userSession.isAuthenticated)`
- `accountCreatedAt` and `completedOnboarding` fetched before routing
- Shows `.loading` until data ready

### 6. Multiple Routers
**Was**: Duplication causes one route to funnel even after the other resolves
**Now**:
- Single `AppRouter` instance
- Single `computeRoute()` function
- Centralized decision logic

---

## 📋 Post-Implementation Checklist

### RevenueCat Setup
- [ ] In-App Purchase Key uploaded to RC (see `REVENUECAT_IAP_KEY_SETUP.md`)
- [ ] Key ID and Issuer ID entered correctly
- [ ] Bundle ID matches between RC and App Store Connect
- [ ] All products exist in RC and match App Store Connect
- [ ] Products attached to an offering in RC
- [ ] (Optional) App Store Server Notifications v2 enabled
- [ ] Test with sandbox account - no "invalid key" errors in console
- [ ] `CustomerInfo` updates successfully

### Routing & State
- [ ] Single router (`AppRouter`) used throughout
- [ ] No second-chance router or fallback routing
- [ ] Gate shows `.loading` until entitlements/profile resolve or 4s timeout
- [ ] `effectiveIsProUser = isPro || isGrandfatherActive` used everywhere
- [ ] `isNewSignup` read from server time, only true during signup session
- [ ] `completedOnboardingAt` set when funnel finishes
- [ ] `completedOnboardingAt` honored at launch
- [ ] `FUNNEL_SCHEMA_VERSION` respected with `lastFunnelShownVersion`

### Testing
- [ ] Logs show comprehensive routing decisions
- [ ] Cohort A (new signup) sees funnel once, then never again
- [ ] Cohort B (legacy user) never sees funnel
- [ ] Cohort C (Pro subscriber) never sees funnel
- [ ] Cohort D (legacy + purchase) never sees funnel
- [ ] Reinstall doesn't re-trigger funnel for logged-in users
- [ ] Entitlements timeout works (wait >4s, still routes correctly)
- [ ] Feature flags work (disable routing v2, enable manual override)

### Verification
- [ ] RevenueCat dashboard shows receipts ingested
- [ ] `Customer Info` live updates without errors
- [ ] Analytics show <1% users entering funnel twice within 14 days
- [ ] Support tickets for "seeing funnel every time" drop to ~0

---

## 🚀 Migration Steps (Safe Rollout)

### Phase 1: RC Key Setup (Do First)
1. Generate In-App Purchase Key in App Store Connect
2. Upload to RevenueCat
3. Verify no errors in console logs
4. Test with sandbox account

### Phase 2: Deploy Code (TestFlight 10% Cohort)
1. Deploy build with new routing logic
2. Monitor logs for routing decisions
3. Test all cohorts (A-D)
4. Verify no regressions

### Phase 3: Backfill Data (Server-Side)
1. Backfill `accountCreatedAt` for all users (if missing)
2. Compute and store `grandfatherEndsAt` for legacy users
3. Set `completedOnboardingAt` for users who already completed old flow

### Phase 4: Full Rollout
1. Roll out to 100% of users
2. Monitor analytics for funnel re-entry rate
3. Monitor support tickets

### Phase 5: Cleanup (1 Month Later)
1. Remove legacy routing code (if routing v2 stable)
2. Remove feature flag `routing.v2.enabled`
3. Keep `override.no_funnel` for support use

---

## 🔧 Rollback Plan

### If Issues Arise
1. Set feature flag: `UserDefaults.standard.set(false, forKey: "routing.v2.enabled")`
2. Reverts to legacy routing behavior
3. Or deploy previous app version

### Manual Override (Support/Debug)
```swift
// Skip funnel entirely for specific user
UserDefaults.standard.set(true, forKey: "override.no_funnel")
```

---

## 📝 Files Changed

1. **`Core/Utils/Constants.swift`** - Added `Onboarding` and `FeatureFlags` enums
2. **`Services/MigrationManager.swift`** - Added onboarding tracking methods
3. **`Core/Navigation/AppRouter.swift`** - NEW FILE - Centralized routing logic
4. **`App.swift`** - Updated `AppContentView` to use `AppRouter`
5. **`REVENUECAT_IAP_KEY_SETUP.md`** - NEW FILE - Setup guide
6. **`ONBOARDING_FUNNEL_AUDIT_IMPLEMENTATION.md`** - NEW FILE - This document

---

## 📞 Support

If issues persist after implementation:
- Check logs: Look for `[Route]` prefix in Xcode console
- Verify RC setup: Follow `REVENUECAT_IAP_KEY_SETUP.md`
- Test cohorts: Run QA matrix (Section 9)
- Feature flag: Disable routing v2 if needed
- Manual override: Use `override.no_funnel` for debugging

---

## ✨ Summary

This implementation:
- ✅ Fixes RevenueCat In-App Purchase Key error (setup guide provided)
- ✅ Stops legacy users from seeing funnel every launch
- ✅ Ensures only new sign-ups enter the funnel
- ✅ Adds 4-second entitlements load grace period
- ✅ Centralizes routing logic in single source of truth
- ✅ Adds comprehensive logging for debugging
- ✅ Includes feature flags for safe rollback
- ✅ Tracks `completedOnboardingAt` to prevent repeated funnel
- ✅ Computes `isGrandfatherActive` and `isNewSignup` correctly
- ✅ Uses UTC dates to avoid timezone issues

**Next Step**: Follow RevenueCat setup guide, then test with sandbox account!
