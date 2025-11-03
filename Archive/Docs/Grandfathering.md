# Legacy User Grandfathering Guide

## Overview

This document describes the grandfathering system for legacy 100Days users. As part of the migration to the new subscription funnel model, users who registered before **November 1, 2025** receive **1 year of free Pro access** from their account creation date.

---

## Who Is Grandfathered?

### Eligibility Criteria

A user is grandfathered if and only if:
```swift
accountCreatedAt < November 1, 2025 00:00:00
```

**Legacy Cutoff Date**: November 1, 2025 at midnight UTC

### Implementation

The cutoff date is defined in `MigrationManager.swift:29-39`:

```swift
private let legacyCutoffDate: Date = {
    var components = DateComponents()
    components.year = 2025
    components.month = 11
    components.day = 1
    components.hour = 0
    components.minute = 0
    return Calendar.current.date(from: components) ?? Date()
}()
```

**User Type Determination** (`MigrationManager.swift:87-114`):
- Fetches user's `createdAt` timestamp from Firestore `/users/{userId}` document
- Compares `registrationDate` with `legacyCutoffDate`
- Returns `.legacyFree` if `registrationDate < legacyCutoffDate`
- Returns `.newUser` if `registrationDate >= legacyCutoffDate`
- Returns `.legacyExpired` if grace period has ended

---

## Duration

### Grace Period Calculation

Legacy users receive **exactly 1 year of free Pro access from their account creation date**, not from when the migration runs or when they first log in.

**Formula**:
```swift
gracePeriodEnd = accountCreatedAt + 1 year
```

**Example**:
- User registered: August 15, 2025
- Grace period ends: August 15, 2026
- If user logs in on October 27, 2025, they see: "You have 292 days of free Pro access remaining"

### Implementation

Implemented in `MigrationManager.swift:151-178` (`migrateLegacyUser` method):

```swift
// Fetch registration date from Firestore
let userDoc = try await db.collection("users").document(userId).getDocument()
guard let data = userDoc.data(),
      let createdAtTimestamp = data["createdAt"] as? Timestamp else {
    throw NSError(...)
}

let registrationDate = createdAtTimestamp.dateValue()

// Calculate grace period: 1 year from REGISTRATION date
let gracePeriodEnd = Calendar.current.date(
    byAdding: .year,
    value: 1,
    to: registrationDate
) ?? registrationDate
```

### Storage

Grace period is stored in:
1. **UserDefaults** (client-side cache): `legacy_user_grace_period_end`
2. **Firestore** (server-side source of truth): `/users/{userId}/legacyGracePeriodEnd`

---

## Routing Behavior

### Legacy Users (In Grace Period)

When a legacy user signs in and their grace period is active:

1. **Migration runs** (`MigrationManager.checkAndMigrate`)
2. **User type determined**: `.legacyFree`
3. **Grace period calculated** from Firestore `createdAt`
4. **Firestore updated**:
   ```json
   {
     "isLegacyUser": true,
     "legacyGracePeriodEnd": <Timestamp>,
     "subscriptionStatus": "legacy_free",
     "subscriptionTier": "pro",
     "migratedAt": <Timestamp>,
     "migrationVersion": "v2_funnel"
   }
   ```
5. **Routing**: Direct to `MainAppView` (NO funnel, NO paywall)
6. **UI**: Shows grace period banner at top of Main screen:
   > "You have 292 days of free Pro access as a valued early user!"

### New Users (After Cutoff)

When a user created on or after November 1, 2025 signs in:

1. **User type determined**: `.newUser`
2. **Firestore updated**:
   ```json
   {
     "isLegacyUser": false,
     "needsFunnelOnboarding": true,
     "subscriptionStatus": "trial_pending",
     "subscriptionTier": "none",
     "migratedAt": <Timestamp>,
     "migrationVersion": "v2_funnel"
   }
   ```
3. **Routing**: `ImprovedFunnelView` → `PaywallView` → `MainAppView` (after purchase)

### Legacy Users (Expired Grace Period)

When a legacy user's grace period has expired:

1. **User type determined**: `.legacyExpired`
2. **Firestore updated**:
   ```json
   {
     "isLegacyUser": true,
     "legacyGracePeriodExpired": true,
     "subscriptionStatus": "expired",
     "subscriptionTier": "none",
     "migratedAt": <Timestamp>
   }
   ```
3. **Routing**: Shows `CommitNowView` → `PaywallView`
4. **Access**: Normal subscription flow applies

---

## effectiveIsProUser Computation

The `effectiveIsProUser` property determines whether a user has Pro access.

### Logic Flow

```swift
func effectiveIsProUser() -> Bool {
    // 1. Check if in legacy grace period
    if MigrationManager.shared.isInLegacyGracePeriod() {
        return true
    }

    // 2. Check RevenueCat subscription status
    if subscriptionStore.hasActiveSubscription {
        return true
    }

    // 3. No active access
    return false
}
```

### Implementation Location

- **Primary**: `Services/UserSession.swift` (computed property on UserSession)
- **Secondary**: `MigrationManager.swift:117-122` (grace period check)

### Grace Period Check

```swift
func isInLegacyGracePeriod() -> Bool {
    guard let gracePeriodEnd = legacyUserGracePeriodEnd
        ?? userDefaults.object(forKey: Keys.legacyUserGracePeriod) as? Date
    else {
        return false
    }
    return gracePeriodEnd > Date()
}
```

---

## QA Verification Steps

### Test Scenario 1: Legacy User (Active Grace Period)
**Setup**: Create test user with `createdAt = 2025-08-01`

**Steps**:
1. Sign in with test account
2. Migration should identify user as `.legacyFree`
3. Verify routing goes directly to Main (no funnel)
4. Check banner shows correct days remaining
5. Verify `effectiveIsProUser == true`
6. Confirm Pro features are accessible

**Expected**:
- Banner: "You have X days of free Pro access as a valued early user!"
- Days remaining ≈ 292 (as of 2025-10-27)

---

### Test Scenario 2: Legacy User (Near Expiration)
**Setup**: Create test user with `createdAt = 2024-10-15`

**Steps**:
1. Time travel to 2025-10-26 (11 months 11 days after registration)
2. Sign in with test account
3. Verify grace period is active (< 1 year)
4. Check days remaining ≈ 20 days

**Expected**:
- Direct to Main
- Banner shows accurate countdown
- Pro access active

---

### Test Scenario 3: Legacy User (Just Before Cutoff)
**Setup**: Create test user with `createdAt = 2024-10-15`

**Steps**:
1. Time travel to 2025-11-10 (1 year 26 days after registration)
2. Sign in with test account
3. Verify grace period is still active (cutoff is Nov 1, 2025, not expiration date)
4. Note: Grace period ends 2025-10-15 (1 year from creation)

**Expected**:
- Direct to Main if before 2025-10-15
- Expired flow if after 2025-10-15

---

### Test Scenario 4: Expired Legacy User
**Setup**: Create test user with `createdAt = 2023-10-20`

**Steps**:
1. Time travel to 2025-11-10 (>2 years after registration)
2. Sign in with test account
3. Migration identifies as `.legacyExpired`
4. Verify user sees paywall

**Expected**:
- Routing: `CommitNowView` → `PaywallView`
- No Pro access without subscription
- `effectiveIsProUser == false`

---

### Test Scenario 5: New User (After Cutoff)
**Setup**: Create test user with `createdAt >= 2025-11-01`

**Steps**:
1. Create fresh account on or after Nov 1, 2025
2. Sign in
3. Migration identifies as `.newUser`
4. Verify user goes through funnel

**Expected**:
- Routing: `WelcomeView` → `ImprovedFunnelView` → `PaywallView` → `MainAppView`
- No legacy banner
- Must purchase to access Pro features

---

## Migration Process

### First-Time Migration

When a user signs in for the first time after the migration is deployed:

1. `UserSession.authenticate()` calls `MigrationManager.checkAndMigrate(for: userId)`
2. Migration checks `UserDefaults.bool(forKey: "user_has_migrated_v2")`
3. If not migrated:
   - Fetch user document from Firestore
   - Determine user type based on `createdAt`
   - Perform appropriate migration (legacy/new/expired)
   - Set `user_has_migrated_v2 = true`
   - Set `migration_completed_date = Date()`

### Repeat Login

On subsequent logins:
- Migration status check returns early (already migrated)
- Grace period loaded from UserDefaults cache
- Firestore data already set during first migration

---

## Force Re-migration (Testing/Debug)

For testing purposes, use `MigrationManager.forceMigration()`:

```swift
MigrationManager.shared.forceMigration()
```

This clears:
- `user_has_migrated_v2` flag
- `legacy_user_grace_period_end` date
- `migration_completed_date` timestamp

**⚠️ WARNING**: Only use in development/testing. Do not expose to production users.

---

## Firestore Schema

### Users Collection: `/users/{userId}`

**Legacy User Document**:
```json
{
  "uid": "abc123",
  "email": "user@example.com",
  "createdAt": { "_seconds": 1691193600, "_nanoseconds": 0 },
  "isLegacyUser": true,
  "legacyGracePeriodEnd": { "_seconds": 1722729600, "_nanoseconds": 0 },
  "subscriptionStatus": "legacy_free",
  "subscriptionTier": "pro",
  "migratedAt": { "_seconds": 1730059680, "_nanoseconds": 0 },
  "migrationVersion": "v2_funnel"
}
```

**New User Document**:
```json
{
  "uid": "xyz789",
  "email": "newuser@example.com",
  "createdAt": { "_seconds": 1730419200, "_nanoseconds": 0 },
  "isLegacyUser": false,
  "needsFunnelOnboarding": true,
  "subscriptionStatus": "trial_pending",
  "subscriptionTier": "none",
  "migratedAt": { "_seconds": 1730419200, "_nanoseconds": 0 },
  "migrationVersion": "v2_funnel"
}
```

---

## Analytics Events

Track these events for monitoring:

1. **Migration Completed**
   - Event: `user_migrated`
   - Properties: `{ userType, gracePeriodEnd, migrationVersion }`

2. **Legacy Grace Period Remaining**
   - Event: `legacy_grace_viewed`
   - Properties: `{ daysRemaining, gracePeriodEnd }`

3. **Legacy Grace Period Expired**
   - Event: `legacy_grace_expired`
   - Properties: `{ registrationDate, expirationDate }`

4. **Funnel Bypass (Legacy)**
   - Event: `funnel_bypassed_legacy`
   - Properties: `{ daysRemaining }`

---

## Troubleshooting

### User Not Recognized as Legacy

**Symptoms**: User created before Nov 1, 2025 sees funnel

**Debug Steps**:
1. Check Firestore `/users/{userId}/createdAt` timestamp
2. Verify `legacyCutoffDate` in MigrationManager.swift:33-35
3. Check migration logs for user type determination
4. Confirm migration has run (`user_has_migrated_v2 = true`)

**Common Causes**:
- `createdAt` field missing in Firestore
- `createdAt` stored as String instead of Timestamp
- Cutoff date incorrectly configured

---

### Grace Period Incorrect

**Symptoms**: Days remaining doesn't match expected calculation

**Debug Steps**:
1. Check `legacyGracePeriodEnd` in Firestore
2. Verify `legacyGracePeriodEnd` in UserDefaults
3. Recalculate: `createdAt + 1 year`
4. Check device time/timezone

**Common Causes**:
- Grace period calculated from wrong date (was fixed in this PR)
- Timezone mismatch
- Cache out of sync with Firestore

---

## Code References

| Component | File | Lines |
|-----------|------|-------|
| Legacy cutoff date | `Services/MigrationManager.swift` | 29-39 |
| User type determination | `Services/MigrationManager.swift` | 87-114 |
| Grace period calculation | `Services/MigrationManager.swift` | 151-178 |
| Grace period check | `Services/MigrationManager.swift` | 117-122 |
| Migration info display | `Services/MigrationManager.swift` | 241-251 |
| Main routing logic | `Features/MainApp/Views/MainAppView.swift` | 1-100 |

---

## Summary

- **Grandfathered**: Users with `accountCreatedAt < 2025-11-01`
- **Duration**: 1 year from account creation date
- **Routing**: Direct to Main, bypass funnel/paywall
- **Access**: `effectiveIsProUser = true` during grace period
- **Expiration**: Normal subscription flow after grace period ends
- **Calculation**: Based on Firestore `createdAt` timestamp, not migration date

---

**Document Version**: 1.0
**Last Updated**: 2025-10-27
**Implemented In**: Migration v2_funnel
**Status**: ✅ Active
