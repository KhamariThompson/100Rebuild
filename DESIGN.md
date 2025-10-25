# 🎨 Subscription System Design Document

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                          App Layer                          │
│  (App.swift, Views using EnvironmentObject)                │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                    Service Layer (SSOT)                     │
│                                                             │
│  ┌─────────────────────────────────────────────┐           │
│  │          SubscriptionStore                  │           │
│  │  @Published var state: SubscriptionState    │           │
│  │  func load(), purchase(), restore()         │           │
│  └─────────────────┬───────────────────────────┘           │
│                    │                                         │
│  ┌─────────────────▼───────────────────────────┐           │
│  │         FiveMinuteWindow                    │           │
│  │  var isActive: Bool                         │           │
│  │  var timeRemaining: TimeInterval            │           │
│  └─────────────────────────────────────────────┘           │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                      Data Layer                             │
│                                                             │
│  ┌─────────────────────────────────────────────┐           │
│  │       SubscriptionRepository (Protocol)     │           │
│  └─────────────────┬───────────────────────────┘           │
│                    │                                         │
│  ┌─────────────────▼───────────────────────────┐           │
│  │   RevenueCatSubscriptionRepository          │           │
│  │  - Maps RC → SubscriptionStatus             │           │
│  │  - Checks intro eligibility                 │           │
│  │  - Fetches product info from StoreKit       │           │
│  │  - Checks grandfathered status (Firestore)  │           │
│  └─────────────────┬───────────────────────────┘           │
└────────────────────┼────────────────────────────────────────┘
                     │
          ┌──────────┼──────────┐
          ▼          ▼           ▼
    ┌─────────┐  ┌─────────┐  ┌──────────┐
    │RevenueCat│  │StoreKit │  │Firestore │
    │   API    │  │   API   │  │   API    │
    └──────────┘  └──────────┘  └──────────┘
```

---

## Domain Models

### SubscriptionPlan
**Purpose:** Enum defining the ONLY two subscription plans in the app

**States:**
- `monthly` → `com.KhamariThompson.100Days.monthlyv2`
- `annual` → `com.KhamariThompson.100Days.annualv1`

**Properties:**
- `productId: String` - ASC product identifier
- `displayName: String` - "Monthly" or "Annual"
- `displayPrice: String` - Fallback price
- `introPrice: String?` - Only annual has intro price
- `highlightBadge: String?` - Only annual has "Best value"

### SubscriptionStatus
**Purpose:** Represents the current subscription state

**States:**
- `notPurchased` - No active subscription
- `active(plan, renewalDate)` - Active subscription with plan and renewal
- `grandfathered` - Permanent Pro access (no billing)
- `expired(lastPlan, expiredAt)` - Subscription ended

**Derived Properties:**
- `isPro: Bool` - Convenience for Pro access check
- `currentPlan: SubscriptionPlan?` - Active or last plan
- `renewalDate: Date?` - Next billing date
- `isGrandfathered: Bool` - Permanent access check

### SubscriptionState
**Purpose:** Complete UI state combining status + flags

**Properties:**
- `status: SubscriptionStatus` - Current status
- `isPro: Bool` - Whether user has Pro access
- `currentPlan: SubscriptionPlan?` - Current/last plan
- `renewalDate: Date?` - Next renewal
- `isGrandfathered: Bool` - Permanent access
- `isPaywallRequired: Bool` - Should show paywall

---

## State Machine

```
[New User]
    │
    ▼
┌─────────────────┐
│  notPurchased   │ ◄─┐
│  isPro = false  │   │
│  paywall = true │   │
└────────┬────────┘   │
         │            │
         │ Purchase   │
         ▼            │
┌─────────────────┐   │
│     active      │   │
│  isPro = true   │   │
│  paywall = false│   │
└────────┬────────┘   │
         │            │
         │ Expires    │
         ▼            │
┌─────────────────┐   │
│    expired      │ ──┘
│  isPro = false  │
│  paywall = true │
└─────────────────┘

[Grandfathered User]
    │
    ▼
┌─────────────────┐
│ grandfathered   │
│  isPro = true   │ ◄──── Permanent State
│  paywall = false│
└─────────────────┘
```

---

## Paywall Variants

### Variant 1: Intro Offer (5-Minute Window)

**When Shown:**
- User just completed funnel
- `FiveMinuteWindow.isActive == true`
- `isIntroEligible(for: .annual) == true`

**Display:**
- Annual plan shows: **"$19.99 for first year"**
- Then: "$29.99/year"
- Monthly shows: "$14.99/month"

**UI:**
```
┌────────────────────────────────────┐
│         Unlock Pro                 │
│                                    │
│ ○ Annual      [Best value]         │
│   $19.99 for first year            │
│   Then $29.99/year                 │
│                                    │
│ ○ Monthly                          │
│   $14.99/month                     │
└────────────────────────────────────┘
```

### Variant 2: Standard Pricing (After Window)

**When Shown:**
- `FiveMinuteWindow.isActive == false` OR
- User not intro-eligible

**Display:**
- Annual plan shows: **"$29.99/year"**
- Monthly shows: "$14.99/month"

**UI:**
```
┌────────────────────────────────────┐
│         Unlock Pro                 │
│                                    │
│ ● Annual      [Best value]         │
│   $29.99/year                      │
│                                    │
│ ○ Monthly                          │
│   $14.99/month                     │
└────────────────────────────────────┘
```

---

## Design Tokens

### Typography
- `title`: DS.Typo.titleXL (Paywall header)
- `headline`: DS.Typo.headline (Plan names, buttons)
- `body`: DS.Typo.body (Descriptions, prices)
- `caption`: DS.Typo.caption1 (Legal text, "Then..." text)

### Colors
- `accent`: DS.Colors.accent (Selection indicator, badges, CTA)
- `surface`: DS.Colors.surface (Card backgrounds)
- `onSurface`: DS.Colors.onSurface (Primary text)
- `onSurfaceSecondary`: DS.Colors.onSurfaceSecondary (Secondary text)
- `border`: DS.Colors.border (Unselected card border)

### Spacing
- `xl`: DS.Spacing.xl (Between sections)
- `lg`: DS.Spacing.lg (Section padding)
- `md`: DS.Spacing.md (Card padding, inter-element spacing)
- `sm`: DS.Spacing.sm (Icon-text spacing)
- `xs`: DS.Spacing.xs (Badge padding)
- `cardCornerRadius`: DS.Spacing.cardCornerRadius (Card rounding)

### Icons
- Selection: `checkmark.circle.fill` (selected), `circle` (unselected)
- Benefits: `checkmark.circle.fill`, `chart.xyaxis.line`, `photo.stack`, `calendar.badge.clock`, `lock.shield.fill`

---

## User Flows

### Flow 1: New User → Purchase

```
User launches app
    │
    ▼
Not authenticated → [Sign In/Up Flow]
    │
    ▼
Authenticated but not Pro
    │
    ▼
Complete funnel (8 questions)
    │
    ▼
FiveMinuteWindow.start() ──────┐
    │                          │
    ▼                          │
Show PaywallView               │
    │                          │
    ├─ Annual selected         │ ← 5 min window active
    │  Shows $19.99            │
    │                          │
    ├─ User purchases          │
    │      │                   │
    │      ▼                   │
    │  isPro = true            │
    │  Hide paywall            │
    │  Show MainAppView        │
    │                          │
    └─ Window expires ─────────┘
       Shows $29.99
```

### Flow 2: Grandfathered User

```
User launches app
    │
    ▼
Authenticated
    │
    ▼
Load subscription status
    │
    ▼
Check Firestore: isGrandfathered = true
    │
    ▼
Set state = .grandfathered
    │
    ▼
isPro = true
    │
    ▼
Show MainAppView (no paywall)
```

### Flow 3: Restore Purchases

```
User on new device
    │
    ▼
Launch app → Sign In
    │
    ▼
Not Pro initially
    │
    ▼
Show PaywallView
    │
    ▼
Tap "Restore Purchases"
    │
    ▼
Query RevenueCat for receipts
    │
    ├─ Found active subscription
    │  └─> isPro = true, hide paywall
    │
    └─ No subscription found
       └─> Show error, keep paywall visible
```

---

## Intro Offer Logic

### Eligibility Rules

```swift
func shouldShowIntroOffer(for plan: SubscriptionPlan) async -> Bool {
    // Rule 1: Only annual has intro offer
    guard plan == .annual else { return false }

    // Rule 2: Five-minute window must be active
    guard let window = store.getFiveMinuteWindow(),
          window.isActive else { return false }

    // Rule 3: User must be intro-eligible from RC
    let isEligible = await store.isIntroEligible(for: .annual)
    guard isEligible else { return false }

    return true
}
```

### Display Logic

```swift
// In PaywallView
if showIntroOffer, let introPrice = productInfo?.introOfferPrice {
    // Show intro price
    Text(introPrice)  // "$19.99 for first year"
        .font(DS.Typo.body)
        .foregroundStyle(DS.Colors.accent)

    Text("Then \(productInfo?.displayPrice ?? plan.displayPrice)")
        .font(DS.Typo.caption1)
        .foregroundStyle(DS.Colors.onSurfaceSecondary)
} else {
    // Show standard price
    Text(productInfo?.displayPrice ?? plan.displayPrice)
        .font(DS.Typo.body)
        .foregroundStyle(DS.Colors.onSurface)
}
```

---

## Analytics Events

### Required Events

```swift
// Paywall
"paywall_viewed" - { source, hasIntroOffer }
"plan_selected" - { plan }
"purchase_initiated" - { plan, price }
"purchase_success" - { plan, price, transaction_id }
"purchase_failed" - { plan, error }
"purchase_cancelled" - { plan }
"restore_initiated"
"restore_success" - { plan }
"restore_failed" - { error }
"paywall_dismissed" - { purchased }

// Five-minute window
"intro_window_started" - { timestamp }
"intro_window_expired" - { duration }
```

### Implementation

```swift
protocol SubscriptionAnalytics {
    func trackPaywallViewed(source: String, hasIntroOffer: Bool)
    func trackPlanSelected(_ plan: SubscriptionPlan)
    func trackPurchaseInitiated(_ plan: SubscriptionPlan, price: String)
    func trackPurchaseSuccess(_ plan: SubscriptionPlan, price: String, transactionId: String)
    func trackPurchaseFailed(_ plan: SubscriptionPlan, error: Error)
    func trackPurchaseCancelled(_ plan: SubscriptionPlan)
    func trackRestoreInitiated()
    func trackRestoreSuccess(_ plan: SubscriptionPlan)
    func trackRestoreFailed(error: Error)
    func trackPaywallDismissed(purchased: Bool)
}
```

---

## Error Handling

### Purchase Errors

```swift
enum SubscriptionError: LocalizedError {
    case noOfferingAvailable
    case packageNotFound
    case purchaseCancelled
    case purchaseFailed(underlying: Error)
    case restoreFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .noOfferingAvailable:
            return "Subscriptions are temporarily unavailable"
        case .packageNotFound:
            return "This subscription plan is not available"
        case .purchaseCancelled:
            return "Purchase was cancelled"
        case .purchaseFailed(let error):
            return "Purchase failed: \(error.localizedDescription)"
        case .restoreFailed(let error):
            return "Restore failed: \(error.localizedDescription)"
        }
    }
}
```

### UI Error Display

```swift
// In PaywallView
if let error = store.error {
    Text(error.localizedDescription)
        .font(DS.Typo.caption1)
        .foregroundStyle(DS.Colors.error)
        .padding(DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Spacing.cardCornerRadius)
                .fill(DS.Colors.error.opacity(0.1))
        )
}
```

---

## Testing Scenarios

### Unit Tests
1. Grandfathered user → always Pro
2. Active subscription → correct plan & renewal
3. Expired subscription → not Pro
4. Intro eligible + active window → show intro price
5. Intro eligible + expired window → show standard price
6. Not intro eligible → show standard price

### UI Tests
1. Launch as new user → paywall shows
2. Purchase annual within window → see $19.99
3. Purchase annual after window → see $29.99
4. Purchase succeeds → paywall dismisses, MainAppView shows
5. Restore with active subscription → becomes Pro
6. Restore without subscription → error shown

---

This design ensures honest, clear pricing with no deceptive tactics. The intro offer is genuinely limited by time and eligibility!
