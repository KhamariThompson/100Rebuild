# 🔄 Subscription System Migration Guide

## Overview

This document describes the migration from the old fragmented subscription system to the new Single Source of Truth (SSOT) subscription system.

---

## 🗑️ Removed Keys & Models

### Deleted Files
- ❌ `Services/SubscriptionService.swift` (old implementation)
- ❌ `Services/Entitlements.swift` (duplicate state)
- ❌ `Features/Auth/Views/FoundersOfferPaywall.swift` (duplicate paywall)
- ❌ `Features/Auth/Views/EnhancedPaywallView.swift` (duplicate paywall)
- ❌ `Features/Auth/Views/PaywallView.swift` (old paywall)
- ❌ `Features/Pro/ProGateView.swift` (duplicate gate)
- ❌ `Core/UI/ProGatedViewModifier.swift` (duplicate modifier)
- ❌ `Core/UI/ProLockedView.swift` (duplicate lock view)

### Removed UserDefaults Keys
- ❌ `hasCompletedPurchase` (replaced by RC entitlement check)
- ❌ `cachedProStatus` (replaced by SubscriptionState)
- ❌ `cachedExpirationDate` (replaced by SubscriptionState.renewalDate)
- ❌ `offeringsRetryCount` (no longer needed)
- ❌ `subscriptionLastVerified` (RC handles this)
- ❌ `founders_offer_start_time` (replaced by five_minute_window)
- ❌ `founders_offer_expired` (replaced by FiveMinuteWindow.isActive)

### Removed Product IDs
- ❌ `com.100days.founders.annual` (never created in ASC)
- ❌ `com.100days.annual` (never created in ASC)
- ❌ `com.100days.monthly` (never created in ASC)

### Removed Models/Enums
```swift
// ❌ DELETED
enum SubscriptionPlan {
    case foundersAnnual
    case standardAnnual
    case monthly
}

// ❌ DELETED
enum SubscriptionError { ... }

// ❌ DELETED
struct MigrationInfo { ... }

// ❌ DELETED
class MigrationManager { ... }
```

### Removed Properties
```swift
// ❌ DELETED from various classes
@Published var isProUser: Bool
@Published var hasSubscription: Bool
@Published var subscriptionLevel: String
@Published var paywallUnlocked: Bool
@Published var effectiveIsProUser: Bool
```

---

## ✅ New Keys & Models

### New Product IDs (TRUTH)
- ✅ `com.KhamariThompson.100Days.monthlyv2` - $14.99/month
- ✅ `com.KhamariThompson.100Days.annualv1` - $29.99/year (with $19.99 intro offer)

### New UserDefaults Keys
- ✅ `five_minute_window` - FiveMinuteWindow JSON (started after funnel completion)

### New Models (SSOT)
```swift
// ✅ NEW - Single source of truth
enum SubscriptionPlan: String, CaseIterable {
    case monthly = "com.KhamariThompson.100Days.monthlyv2"
    case annual = "com.KhamariThompson.100Days.annualv1"
}

enum Entitlement: String {
    case pro
}

enum SubscriptionStatus {
    case notPurchased
    case active(plan: SubscriptionPlan, renewalDate: Date?)
    case grandfathered
    case expired(lastPlan: SubscriptionPlan?, expiredAt: Date?)
}

struct SubscriptionState {
    var status: SubscriptionStatus
    var isPro: Bool
    var currentPlan: SubscriptionPlan?
    var renewalDate: Date?
    var isGrandfathered: Bool
    var isPaywallRequired: Bool
}
```

### New Properties
```swift
// ✅ NEW - Single property for Pro status
@ObservedObject var store: SubscriptionStore

// Access via:
store.isPro
store.state.currentPlan
store.state.renewalDate
```

---

## 👥 Grandfathering Rules

### Who is Grandfathered?

Users are grandfathered if they have `isGrandfathered: true` in Firestore `users/{uid}` document.

**How to Set:**
```swift
// In Firestore console or admin script:
db.collection("users").document(userId).updateData([
    "isGrandfathered": true
])
```

**Effect:**
- `store.isPro` returns `true` permanently
- No paywall shown
- No expiration
- No recurring billing

### How to Check
```swift
let isGrandfathered = try await repository.checkGrandfatheredStatus(userId: userId)
if isGrandfathered {
    state = .grandfathered
}
```

### Migration Script for Existing Users

If you want to grandfather existing Pro users:

```swift
// Run this ONCE to grandfather all current Pro subscribers
func grandfatherExistingProUsers() async {
    let db = Firestore.firestore()

    // Get all users with active Pro entitlement from RC
    let offerings = try await Purchases.shared.offerings()
    // ... query RC for active Pro users

    // For each active Pro user:
    for userId in activeProUserIds {
        try await db.collection("users").document(userId).updateData([
            "isGrandfathered": true,
            "grandfatheredAt": FieldValue.serverTimestamp(),
            "grandfatheredReason": "migration_2025"
        ])
    }
}
```

---

## 🔄 Code Migration Examples

### Before (OLD)
```swift
// OLD - Multiple sources of truth
if entitlements.effectiveIsProUser {
    // Show feature
}

if subscriptionService.isProUser || migrationManager.isInLegacyGracePeriod() {
    // Show feature
}

if hasActiveSubscription {
    // Show feature
}
```

### After (NEW)
```swift
// NEW - Single source of truth
if store.isPro {
    // Show feature
}

// Or use helper
if requirePro(store) {
    // Show feature
}
```

### View Modifiers

**Before:**
```swift
// OLD
SomeView()
    .proGated()

SomeView()
    .requiresPro()

SomeView()
    .proBlurredPreview(message: "...")
```

**After:**
```swift
// NEW - Just check the store directly
if store.isPro {
    SomeView()
} else {
    // Show lock or navigate to paywall
    Button("Unlock Pro") {
        showPaywall = true
    }
}
```

### Paywall Display

**Before:**
```swift
// OLD - Multiple paywalls
.sheet(isPresented: $showPaywall) {
    if isFoundersOffer {
        FoundersOfferPaywall()
    } else {
        EnhancedPaywallView()
    }
}
```

**After:**
```swift
// NEW - Single paywall
.fullScreenCover(isPresented: $showPaywall) {
    PaywallView()
        .environmentObject(store)
}
```

---

## 📝 Firestore Schema Changes

### Users Collection

**Before:**
```javascript
{
  "users": {
    "<userId>": {
      "isLegacyUser": true/false,           // ❌ REMOVED
      "legacyGracePeriodEnd": Timestamp,    // ❌ REMOVED
      "subscriptionStatus": "...",          // ❌ REMOVED
      "subscriptionTier": "...",            // ❌ REMOVED
      "migratedAt": Timestamp,              // ❌ REMOVED
      "migrationVersion": "...",            // ❌ REMOVED
      "needsFunnelOnboarding": true/false   // ❌ REMOVED
    }
  }
}
```

**After:**
```javascript
{
  "users": {
    "<userId>": {
      // ✅ NEW - Only need this for grandfathering
      "isGrandfathered": true/false,
      "grandfatheredAt": Timestamp,
      "grandfatheredReason": "migration_2025" | "founder" | "lifetime_deal"
    }
  }
}
```

**Reason:** RevenueCat is now the ONLY source of truth for subscription status. Firestore only stores grandfathering override.

---

## 🧪 Testing Migration

### 1. Test New User Flow
```swift
// New user should:
// 1. Not be Pro initially
// 2. See paywall
// 3. After purchase, become Pro
// 4. NOT see intro offer after 5-minute window
```

### 2. Test Grandfathered User
```swift
// Grandfathered user should:
// 1. Always be Pro
// 2. Never see paywall
// 3. No expiration
```

### 3. Test Existing Subscriber
```swift
// Existing subscriber should:
// 1. Have `isPro = true`
// 2. Show correct plan (monthly or annual)
// 3. Show renewal date
// 4. NOT see paywall
```

### 4. Test Intro Offer Eligibility
```swift
// New user within 5-minute window should:
// 1. See "$19.99 for first year" on annual plan
// 2. After 5 minutes, see "$29.99/year"
// 3. After purchase, intro offer not shown again
```

---

## ⚠️ Breaking Changes

### API Changes
```swift
// ❌ OLD API - NO LONGER EXISTS
subscriptionService.isProUser
entitlements.effectiveIsProUser
migrationManager.isInLegacyGracePeriod()

// ✅ NEW API - USE THIS
store.isPro
store.state.currentPlan
store.state.renewalDate
```

### Environment Objects
```swift
// ❌ OLD - DELETE THESE
.environmentObject(subscriptionService)
.environmentObject(entitlements)

// ✅ NEW - USE THIS
.environmentObject(store) // SubscriptionStore
```

---

## 📅 Migration Timeline

1. **Phase 1** (Week 1): Create new Subscription module
2. **Phase 2** (Week 1): Update App.swift to use SubscriptionStore
3. **Phase 3** (Week 2): Update all feature gates to use `store.isPro`
4. **Phase 4** (Week 2): Delete old files
5. **Phase 5** (Week 2): Test thoroughly
6. **Phase 6** (Week 3): Deploy to TestFlight
7. **Phase 7** (Week 3): Monitor & fix bugs
8. **Phase 8** (Week 4): Production release

---

## 🆘 Troubleshooting

### "User shows as not Pro but has active subscription"
**Solution:** Check if grandfathered flag is set in Firestore. If not, RC entitlement should be active.

### "Intro offer shows after 5-minute window"
**Solution:** Check `FiveMinuteWindow.isActive`. Clear `five_minute_window` from UserDefaults to test.

### "Multiple paywalls still showing"
**Solution:** Search codebase for duplicate paywall files and delete them. Only `PaywallView.swift` should exist.

### "Old product IDs found in code"
**Solution:** Run CI guardrail script to find and replace them.

---

This migration ensures a clean, single source of truth for subscriptions. No fragmentation, no duplicate state!
