# Routing Fix Plan - Minimal Changes

**Goal:** Ensure post-cutoff users always flow `SignUp → Onboarding → Paywall → App(if Pro)`, never `SignUp → Paywall`. Respect grandfathered users.

**Date:** 2025-11-12
**Status:** Phase B - Planning

---

## Critical Issues to Fix

From `ROUTE_AUDIT.json`:

1. **Time-based `isNewSignup` gate** (AppRouter.swift:125-129)
   - After 10 minutes from signup, post-cutoff users route to Paywall, skipping Funnel
   - Fails across reinstalls, device changes, delayed launches

2. **UserDefaults-based `hasCompletedFunnel`** (UserSessionExtensions.swift:26-28)
   - Device-local storage lost on reinstall/device change
   - Not synced across devices
   - Firestore write is fire-and-forget (no guarantee)

3. **Semantic confusion: `hasCompletedOnboarding` vs `hasCompletedFunnel`**
   - Two overlapping flags with unclear purpose
   - `hasCompletedOnboarding` is never set by funnel completion

---

## Proposed Routing Rules (Target State)

### Rule 1: Grandfathered Users (created before 2025-11-01 UTC, within 1yr)
```
if isGrandfathered AND isPro:
    → MainPro (free year access)
```
- Funnel is **optional** (can skip)
- App access granted immediately

### Rule 2: Post-Cutoff Users (created on/after 2025-11-01 UTC)

#### Rule 2a: Funnel Not Completed
```
if !isGrandfathered AND !funnelCompleted:
    → Funnel (mandatory)
```
- **MUST** complete funnel before seeing paywall
- No time-based gates
- No bypasses

#### Rule 2b: Funnel Completed, No Pro
```
if !isGrandfathered AND funnelCompleted AND !isPro:
    → Paywall (block access)
```
- Show Paywall (or FoundersOfferView if 5-min window active)
- Block app access until subscription purchased

#### Rule 2c: Funnel Completed, Has Pro
```
if !isGrandfathered AND funnelCompleted AND isPro:
    → MainPro (purchased access)
```
- Grant app access after purchase

### Rule 3: Offline Handling
```
if offline AND !funnelCompleted:
    → Funnel (allow offline completion, sync later)

if offline AND funnelCompleted AND !isPro:
    → Paywall (show message: "Connect to internet to subscribe")
```

---

## Minimal Changes Required

### Change 1: Remove `isNewSignup` Time-Based Gate

**File:** `AppRouter.swift`
**Lines:** 125-129

**Current Code:**
```swift
let isNewSignup: Bool = {
    guard let acctAt = accountCreatedAt else { return false }
    let elapsed = now.timeIntervalSince(acctAt)
    return elapsed < Constants.Onboarding.newSignupGracePeriod
}()
```

**Proposed Change:**
```swift
// REMOVED: Time-based isNewSignup gate
// Routing now relies solely on server-backed funnelCompleted flag
```

**Rationale:**
- Time-based checks fail across sessions/reinstalls/devices
- `funnelCompleted` (server-backed) is authoritative

---

### Change 2: Migrate `hasCompletedFunnel` to Firestore SSOT

**File:** `UserSessionExtensions.swift`
**Lines:** 26-28

**Current Code:**
```swift
var hasCompletedFunnel: Bool {
    return onboardingCompletedAt != nil  // UserDefaults
}
```

**Proposed Change:**
```swift
var hasCompletedFunnel: Bool {
    // NEW: Firestore is SSOT, UserDefaults is cache
    // Check cache first for performance
    if let cached = UserDefaults.standard.object(forKey: "onboardingCompletedAt") as? Date {
        return true
    }
    // Fallback: This will be loaded from Firestore during loadUserProfile()
    return false
}
```

**File:** `UserSession.swift` (loadUserProfile)
**Lines:** 326-337

**Add After Line 337:**
```swift
// NEW: Load funnelCompleted from Firestore (SSOT)
if let funnelCompleted = data["funnelCompleted"] as? Bool, funnelCompleted {
    let completedAt = (data["onboardingCompletedAt"] as? Timestamp)?.dateValue() ?? Date()
    // Sync to UserDefaults cache
    UserDefaults.standard.set(completedAt, forKey: StorageKeys.onboardingCompletedAt)
    #if DEBUG
    print("UserSession: Loaded funnelCompleted=true from Firestore, cached to UserDefaults")
    #endif
}
```

**File:** `UserSessionExtensions.swift` (completeFunnel)
**Lines:** 34-63

**Change Line 46-50:**
```swift
// OLD:
try await Firestore.firestore().collection("users").document(userId).updateData([
    "onboardingCompletedAt": now,
    "funnelCompleted": true
    // NOTE: hasCompletedOnboarding is NOT set here
])

// NEW: Use merge to create document if missing
try await Firestore.firestore().collection("users").document(userId).setData([
    "onboardingCompletedAt": now,
    "funnelCompleted": true
    // NOTE: hasCompletedOnboarding is NOT set here
], merge: true)
```

**Rationale:**
- Firestore becomes SSOT (survives reinstalls/device changes)
- UserDefaults is cache for performance
- Firestore write uses `setData(merge:)` to handle missing documents

---

### Change 3: Update Routing Logic in `AppRouter.swift`

**File:** `AppRouter.swift`
**Lines:** 131-150

**Current Code:**
```swift
// Step 6: Make routing decision
let route: Route
if effectiveIsProUser {
    route = .mainPro
} else if isNewSignup && !hasCompletedFunnel {
    // PRIORITY: New user who hasn't completed funnel - show funnel first
    route = .funnel
} else if completedOnboarding {
    route = .paywall
} else if hasCompletedFunnel {
    // User completed funnel but hasn't made payment decision yet - show paywall with Founder's Offer
    route = .paywall
} else {
    // Fallback: No Pro access and no funnel completion - show paywall
    route = .paywall
}
```

**Proposed Change:**
```swift
// Step 6: Make routing decision (SIMPLIFIED)
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
```

**Rationale:**
- Removes time-based `isNewSignup` gate
- Removes `completedOnboarding` check (unused/unclear semantics)
- Simplifies to 3 cases: (1) Has Pro → App, (2) No Funnel → Funnel, (3) Else → Paywall
- Enforces: Post-cutoff users MUST complete funnel before seeing paywall

---

### Change 4: Ensure `completeFunnel()` Persists to Firestore Reliably

**File:** `UserSessionExtensions.swift`
**Lines:** 34-63

**Current Code:**
```swift
func completeFunnel() {
    let now = Date()
    UserDefaults.standard.set(now, forKey: StorageKeys.onboardingCompletedAt)

    if let userId = currentUser?.uid {
        Task {
            do {
                try await Firestore.firestore().collection("users").document(userId).updateData([
                    "onboardingCompletedAt": now,
                    "funnelCompleted": true
                ])
                print("✅ UserSession: Funnel completion saved to Firestore")
            } catch {
                print("❌ UserSession: Failed to save funnel completion - \(error.localizedDescription)")
            }
        }
    }

    syncFunnelAttributesToRevenueCat()
}
```

**Proposed Change:**
```swift
func completeFunnel() async {  // Make async
    let now = Date()

    // Step 1: Write to Firestore FIRST (SSOT)
    if let userId = currentUser?.uid {
        do {
            try await Firestore.firestore().collection("users").document(userId).setData([
                "onboardingCompletedAt": now,
                "funnelCompleted": true
            ], merge: true)

            print("✅ UserSession: Funnel completion saved to Firestore")

            // Step 2: Cache to UserDefaults AFTER Firestore succeeds
            UserDefaults.standard.set(now, forKey: StorageKeys.onboardingCompletedAt)

        } catch {
            print("❌ UserSession: Failed to save funnel completion - \(error.localizedDescription)")
            // DO NOT cache to UserDefaults if Firestore write fails
            throw error  // Propagate error to caller
        }
    }

    // Step 3: Sync to RevenueCat
    syncFunnelAttributesToRevenueCat()
}
```

**File:** `ImprovedFunnelView.swift`
**Lines:** 745-774

**Change Line 746:**
```swift
// OLD:
private func completeFunnel() {
    userSession.completeFunnel()
    // ...
}

// NEW:
private func completeFunnel() {
    Task {
        do {
            try await userSession.completeFunnel()  // Now async
            // Continue with existing logic...
        } catch {
            print("❌ ImprovedFunnelView: Failed to complete funnel - \(error.localizedDescription)")
            // Show error to user
            return
        }
    }
    // ...
}
```

**Rationale:**
- Firestore write is awaited (not fire-and-forget)
- UserDefaults cached AFTER Firestore succeeds (cache consistency)
- Errors propagated to UI (user feedback)

---

### Change 5: Remove/Deprecate `hasCompletedOnboarding` (Optional)

**Rationale:**
- Never set by funnel completion
- Unclear purpose (semantic overlap with `hasCompletedFunnel`)
- Unused in routing logic

**Option A: Remove Entirely**
- Delete `UserSession.hasCompletedOnboarding` property
- Delete `completeOnboarding()` method
- Clean up Firestore schema (remove `hasCompletedOnboarding` field)

**Option B: Clarify Semantics**
- Keep `hasCompletedOnboarding` for future use (e.g., tutorial completion)
- Document: `hasCompletedFunnel` = completed onboarding questions
- Document: `hasCompletedOnboarding` = completed app tutorial (separate from funnel)

**Recommendation:** Option B (keep for future, clarify semantics)

---

## Offline Handling Improvements

### Current Behavior
- Offline users timeout → route to Paywall → stuck (can't purchase)

### Proposed Behavior

**File:** `AppRouter.swift`
**Add After Line 106:**

```swift
// Step 2.5: Handle offline scenario gracefully
if !entitlementsLoaded && !NetworkMonitor.shared.isConnected {
    // Offline: Allow funnel completion, block paywall
    if !hasCompletedFunnel {
        // User can complete funnel offline, will sync when online
        return .funnel
    } else if !effectiveIsProUser {
        // User completed funnel but is offline - show paywall with offline message
        // Paywall will display "Connect to internet to subscribe"
        return .paywall
    }
    // Continue to normal routing for Pro users
}
```

**Rationale:**
- Funnel can be completed offline (Firestore write queued)
- Paywall shown for offline non-Pro users (with informative message)
- Pro users unaffected (cached entitlements)

---

## Constants Cleanup

### Remove Unused Constants

**File:** `Constants.swift`
**Lines:** 127-128

**Current Code:**
```swift
static let newSignupGracePeriod: TimeInterval = 10 * 60 // 10 minutes
```

**Proposed Change:**
```swift
// REMOVED: newSignupGracePeriod (time-based gate eliminated)
```

**File:** `Constants.swift`
**Lines:** 120

**Current Code:**
```swift
static let grandfatherDuration: TimeInterval = 365 * 24 * 60 * 60 // 1 year in seconds (kept for backwards compatibility)
```

**Proposed Change:**
```swift
// DEPRECATED: Use SubscriptionPolicy.grandfatherDurationYears instead
// This constant is kept for backwards compatibility only
static let grandfatherDuration: TimeInterval = 365 * 24 * 60 * 60 // 1 year in seconds
```

---

## Testing Strategy

### Unit Tests (New)

**File:** `100DaysRebuildTests/RoutingTests.swift` (currently disabled)

Enable and add tests for:

1. **Grandfathered user routes to MainPro**
   - accountCreatedAt < cutoff, within 1yr → .mainPro

2. **Post-cutoff user without funnel routes to Funnel**
   - accountCreatedAt >= cutoff, funnelCompleted=false → .funnel

3. **Post-cutoff user with funnel, no Pro routes to Paywall**
   - accountCreatedAt >= cutoff, funnelCompleted=true, isPro=false → .paywall

4. **Post-cutoff user with funnel and Pro routes to MainPro**
   - accountCreatedAt >= cutoff, funnelCompleted=true, isPro=true → .mainPro

5. **Offline user without funnel routes to Funnel**
   - networkAvailable=false, funnelCompleted=false → .funnel

6. **Offline user with funnel, no Pro routes to Paywall**
   - networkAvailable=false, funnelCompleted=true, isPro=false → .paywall

### Manual Tests (From MANUAL_TEST_GUIDE.md)

1. **New post-cutoff user (fresh device)**
   - Expected: SignUp → Funnel → Paywall

2. **New post-cutoff user (24h later)**
   - Expected: Login → Funnel (if not completed) OR Paywall (if completed)

3. **New post-cutoff user (reinstall)**
   - Expected: Login → Funnel (if Firestore shows funnelCompleted=false) OR Paywall (if true)

4. **Grandfathered user (within free year)**
   - Expected: Login → MainPro (skip Paywall)

5. **Offline first run**
   - Expected: SignUp → Funnel (allow offline) → Paywall (when online)

---

## Migration Plan

### Pre-Deployment

1. **Data Migration Script** (Optional)
   - Backfill `funnelCompleted` from UserDefaults for existing users
   - Query all users with `hasCompletedOnboarding=true` → set `funnelCompleted=true`

2. **Feature Flag** (Optional)
   - Add `newRoutingEnabled` flag in Constants.swift
   - Default to `true` in Release, toggle in DEBUG for testing

### Deployment

1. **Deploy Firestore schema changes** (additive, backwards compatible)
   - No breaking changes (uses `setData(merge:)`)

2. **Deploy app update** with routing changes

3. **Monitor logs** for routing errors
   - Track `hasCompletedFunnel` cache misses
   - Track Firestore write failures

### Rollback Plan

1. **Revert to time-based routing** via feature flag
2. **Re-enable `isNewSignup` gate** in AppRouter.swift
3. **Deploy hotfix** if critical issues

---

## Summary of Changes

### Files Modified

1. **AppRouter.swift** (Lines 125-150)
   - Remove `isNewSignup` time-based gate
   - Simplify routing logic to 3 cases
   - Add offline handling

2. **UserSessionExtensions.swift** (Lines 26-63)
   - Make `completeFunnel()` async
   - Firestore write → await → cache to UserDefaults
   - Propagate errors to caller

3. **UserSession.swift** (Lines 326-337)
   - Load `funnelCompleted` from Firestore
   - Sync to UserDefaults cache

4. **ImprovedFunnelView.swift** (Lines 745-774)
   - Make `completeFunnel()` call async
   - Handle errors (show user feedback)

5. **Constants.swift** (Lines 120, 127-128)
   - Deprecate `grandfatherDuration`
   - Remove `newSignupGracePeriod`

### Files Created

1. **100DaysRebuildTests/RoutingTests.swift** (re-enable)
   - Add unit tests for routing scenarios

### Files Unchanged

1. **SubscriptionStore.swift** - No changes (isPro logic correct)
2. **SubscriptionPolicy.swift** - No changes (grandfather logic correct)
3. **App.swift** - No changes (routing call correct)

---

## Risk Assessment

### Low Risk Changes

- Remove `isNewSignup` gate (improves reliability)
- Firestore SSOT for `funnelCompleted` (syncs across devices)
- Simplify routing logic (reduces bugs)

### Medium Risk Changes

- Make `completeFunnel()` async (requires caller updates)
- Offline handling (needs testing)

### High Risk Changes

- None (all changes are additive/backwards compatible)

### Mitigation

- Thorough testing (unit + manual)
- Gradual rollout (monitor logs)
- Feature flag for rollback
- Data migration (optional backfill)

---

## Success Criteria

✅ **Routing Compliance:**
- Post-cutoff users: Always SignUp → Funnel → Paywall (never skip Funnel)
- Grandfathered users: Always SignUp → MainPro (optional Funnel)
- Offline users: Can complete Funnel, see Paywall with message

✅ **Persistence:**
- `funnelCompleted` survives reinstalls (Firestore SSOT)
- `funnelCompleted` syncs across devices
- No UserDefaults-only flags

✅ **Tests:**
- All routing tests pass (unit + manual)
- No critical regressions

✅ **Logs:**
- No Firestore write failures
- No routing errors in production

---

## Next Steps (Phase C)

1. Apply minimal diffs to files listed above
2. Re-enable and run `RoutingTests.swift`
3. Test routing scenarios (new/grandfathered/offline)
4. Generate `READINESS.json` with final verdict

---

**Plan Status:** Ready for Phase C (Patch Application)
**Approval:** Pending user confirmation
