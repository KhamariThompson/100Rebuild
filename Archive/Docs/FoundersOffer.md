# Founders Offer - Product IDs & Selection Logic

## Product IDs (Single Source of Truth)

All product IDs are defined in `Constants.swift → ProductID`:

```swift
enum ProductID {
    static let monthly       = "com.KhamariThompson.100Days.monthlyv2"
    static let annualIntro   = "com.KhamariThompson.100Days.annualv1"
    static let annualNoIntro = "com.KhamariThompson.100Days.annualv1.no_intro1"
}
```

### Product Descriptions:

- **Monthly** (`monthlyv2`): $14.99/month, no intro offer
- **Annual WITH intro** (`annualv1`): First year $19.99, renews at $29.99/year
- **Annual NO intro** (`annualv1.no_intro1`): $29.99/year, no intro offer

## Selection Logic

### Founders Gate State

The system uses a **FoundersGateState** struct to determine which annual product to show:

```swift
struct FoundersGateState {
    let windowActive: Bool        // 5-minute window is active
    let introEligible: Bool       // RC/SK2 says user is eligible
    let foundersConsumed: Bool    // User already used intro offer
    let campaignLive: Bool        // Date >= Nov 1, 2025
}
```

### Decision Tree

```
IF (windowActive && introEligible && !foundersConsumed && campaignLive):
    → Show/purchase annualv1 (intro)
ELSE:
    → Show/purchase annualv1.no_intro1 (no intro)
```

### Campaign Start Date

- **Launch**: November 1, 2025
- **Before Nov 1**: Intro product is NOT available (users see annualv1.no_intro1)
- **After Nov 1**: Intro product available IF other conditions met

```swift
enum FoundersCampaign {
    static let startDate: Date // Nov 1, 2025
    static var isLive: Bool { Date() >= startDate }
}
```

## Five-Minute Window

### When it Starts

- Only for **NEW users** (not legacy/grace users)
- Triggered when user completes `ImprovedFunnelView`
- Starts on `subscriptionStore.startFiveMinuteWindow()`
- Persisted to UserDefaults as `FoundersWindowState`

### What it Tracks

```swift
struct FoundersWindowState {
    let version: Int = 1
    var startedAt: Date?
    var foundersOfferConsumed: Bool
    var isActive: Bool // true if < 5 min elapsed
}
```

### Consumption Tracking

- `foundersOfferConsumed` flips to `true` ONLY after successful purchase of `annualv1` (intro product)
- Prevents user from seeing intro offer multiple times
- Persists across app restarts

## RevenueCat Offerings

### Preferred Setup (Two Offerings)

If your RC dashboard supports it, create:

1. **founders_offer** → contains `annualv1` + `monthlyv2`
2. **default** → contains `annualv1.no_intro1` + `monthlyv2`

### Fallback (Single Offering)

If only one offering exists, the app scans all packages by `productIdentifier` match at runtime.

## Renewal Behavior

- **After first year**: Apple handles renewal automatically
- **Intro users**: $19.99 first year → $29.99/year thereafter
- **No-intro users**: $29.99/year from start
- No code changes needed for renewals (App Store manages this)

## QA Test Matrix

### Scenario 1: Pre-Campaign (Before Nov 1, 2025)

| Condition | Expected Product | Notes |
|-----------|-----------------|-------|
| New user, window active, intro eligible | **annualv1.no_intro1** | Campaign not live yet |
| New user, window expired | **annualv1.no_intro1** | Window expired |

### Scenario 2: Post-Campaign (After Nov 1, 2025)

| Window | Intro Eligible | Consumed | Expected Product | Notes |
|--------|---------------|----------|------------------|-------|
| Active | Yes | No | **annualv1** (intro) | ✅ Founders offer |
| Active | Yes | Yes | **annualv1.no_intro1** | Already used |
| Active | No | No | **annualv1.no_intro1** | Not eligible |
| Expired | Yes | No | **annualv1.no_intro1** | Window closed |

### Scenario 3: Legacy Users

| Condition | Expected Behavior | Notes |
|-----------|------------------|-------|
| Legacy with grace | Skip funnel → MainAppView | No window starts |
| Legacy grace expired | Must subscribe (see above rules) | Window never started for legacy |

## Verification Steps

### 1. Check `foundersOfferConsumed` Flag

```swift
// In Xcode debug console after purchase:
po UserDefaults.standard.data(forKey: "founders_window_state_v1")

// Should show foundersOfferConsumed = true if intro was purchased
```

### 2. Analytics Events

**paywall_shown:**
```json
{
  "offering": "current",
  "product_id_shown": "com.KhamariThompson.100Days.annualv1" or "...annualv1.no_intro1",
  "window_active": true/false,
  "intro_eligible": true/false,
  "founders_consumed": true/false,
  "campaign_live": true/false
}
```

**purchase_success:**
```json
{
  "product_id": "com.KhamariThompson.100Days.annualv1",
  "was_intro": true
}
```

### 3. Test Date Override (for Pre-Launch Testing)

To test before Nov 1, 2025, temporarily modify `FoundersCampaign.startDate` in Constants.swift:

```swift
// FOR TESTING ONLY - remove before production
static let startDate: Date = Date()  // Campaign always live
```

### 4. Reset Window for Testing

```swift
// In debug console:
UserDefaults.standard.removeObject(forKey: "founders_window_state_v1")
// Then restart app and go through funnel
```

## Dashboard Configuration (RevenueCat)

If using two offerings:

1. **Create Entitlement**: "pro" (already exists)
2. **Create Offerings**:
   - **founders_offer** (identifier: `founders_offer`)
     - Annual Package → `annualv1`
     - Monthly Package → `monthlyv2`
   - **default** (identifier: `default`)
     - Annual Package → `annualv1.no_intro1`
     - Monthly Package → `monthlyv2`
3. **Set Current Offering**: During campaign window, set `founders_offer` as current. After campaign, switch to `default`.

### If Single Offering Only

- Create one offering with all 3 products
- App will select by product ID at runtime

## Common Issues

### Issue: Intro not showing even though eligible

**Check:**
- Date >= Nov 1, 2025? (`FoundersCampaign.isLive`)
- Window active? (< 5 min since start)
- Not consumed? (`foundersOfferConsumed == false`)
- RC says eligible? (`isIntroEligible == true`)

### Issue: User sees intro twice

**Fix:** Ensure `store.markFoundersOfferConsumed()` is called after successful intro purchase (already implemented in PaywallView.swift:584)

### Issue: Product not found error

**Check:**
- All 3 product IDs created in App Store Connect
- Products linked to "pro" entitlement in RC dashboard
- App Store Connect products approved (not "Waiting for Review")

## Files Modified

- `Constants.swift` - Product IDs + Campaign date
- `FiveMinuteWindow.swift` - FoundersWindowState struct
- `SubscriptionStore.swift` - Consumption tracking
- `SubscriptionRepository.swift` - Purchase signature
- `RevenueCatSubscriptionRepository.swift` - Package selection logic
- `PaywallView.swift` - FoundersGateState + analytics
- `SubscriptionPlan.swift` - Use Constants.ProductID

## Support

For issues or questions:
- Check console logs for `🔐 RC:` and `⏱️ SubscriptionStore:` prefixes
- Verify RC dashboard configuration
- Test with sandbox Apple ID
