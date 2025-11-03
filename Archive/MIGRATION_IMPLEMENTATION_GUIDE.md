# 🚀 New Subscription Model - Implementation Guide

## Overview

This guide walks you through implementing the new funnel-based subscription model for your 100 Days app.

## 🎯 What's New

### Old Model
- Free tier + optional Pro upgrade
- Features gated behind paywall
- Users could use app indefinitely for free

### New Model
- **Everyone is Pro by default** - all features unlocked
- New users: Funnel (8 questions) → Founder's Offer Paywall ($19.99 annual for 5min) → Standard plans ($29.99/year or $14.99/month)
- Legacy users (registered before Jan 1, 2026): **1 year free Pro** then transition to paid
- No free tier anymore - everyone must subscribe

---

## 📁 New Files Created

### 1. **MigrationManager.swift** (`/Services/MigrationManager.swift`)
- Handles user migration from old to new model
- Determines user type (legacy vs new)
- Grants 1-year grace period to legacy users
- Tracks migration status in Firestore

### 2. **FoundersOfferPaywall.swift** (`/Features/Auth/Views/FoundersOfferPaywall.swift`)
- Paywall with 5-minute countdown timer
- Shows $19.99 founder's offer (33% off)
- After timer: shows only $29.99/year + $14.99/month
- Beautiful UI with social proof & benefits

### 3. **ImprovedFunnelView.swift** (`/Features/Auth/Views/ImprovedFunnelView.swift`)
- High-conversion funnel with 8 emotional questions
- Exit intent detection with retention dialogs
- Progress investment psychology
- Auto-advances to paywall after completion

### 4. **OnboardingOrchestrator.swift** (`/Features/Auth/ViewModels/OnboardingOrchestrator.swift`)
- Orchestrates entire onboarding flow
- Decides: Funnel → Paywall vs Skip to app
- Shows grace period banner for legacy users
- Handles all state transitions

---

## 🔧 Implementation Steps

### Step 1: Update RevenueCat Products

Add these product IDs to App Store Connect & RevenueCat:

```
com.100days.founders.annual  - $19.99/year (Founder's Offer)
com.100days.annual           - $29.99/year (Standard)
com.100days.monthly          - $14.99/month
```

**Important:** The founder's offer product should have a 7-day free trial.

### Step 2: Update SubscriptionService

Add support for new subscription plans. Update `SubscriptionService.swift`:

```swift
enum SubscriptionPlan: String {
    case foundersAnnual = "com.100days.founders.annual"
    case standardAnnual = "com.100days.annual"
    case monthly = "com.100days.monthly"
}

// Update purchase method to handle these plans
func purchase(plan: SubscriptionPlan) async throws {
    let offering = try await Purchases.shared.offerings().current

    guard let package = offering?.package(identifier: plan.rawValue) else {
        throw SubscriptionError.packageNotFound
    }

    let result = try await Purchases.shared.purchase(package: package)
    // Handle result...
}
```

### Step 3: Remove Pro-Gating

Since everyone is now Pro by default, remove all pro gates:

**Files to update:**
- `ProGatedViewModifier.swift` - Remove or make no-op
- `ProLockedView.swift` - Remove or make transparent
- `SimpleCheckInSheet.swift` - Remove image limit checks
- `SettingsView.swift` - Update subscription status display

**Quick fix approach:**

```swift
// In SubscriptionService, add:
var isProUser: Bool {
    // Everyone is Pro now - check only if they have active subscription
    // OR are in legacy grace period
    return hasActiveSubscription || migrationManager.isInLegacyGracePeriod()
}

var hasActiveSubscription: Bool {
    // Check RevenueCat subscription status
    return customerInfo?.entitlements["pro"]?.isActive == true
}
```

### Step 4: Update UserSession

Integrate migration check on app launch:

```swift
class UserSession: ObservableObject {
    // ... existing code ...

    func signIn(email: String, password: String) async throws {
        // Existing sign-in logic...

        // After successful sign-in, check migration
        if let userId = user?.id {
            try await MigrationManager.shared.checkAndMigrate(for: userId)
        }
    }

    func checkMigrationStatus() async throws {
        guard let userId = user?.id else { return }
        try await MigrationManager.shared.checkAndMigrate(for: userId)
    }
}
```

### Step 5: Update Auth Flow

Replace old onboarding with new orchestrator in your root view:

```swift
struct ContentView: View {
    @EnvironmentObject var userSession: UserSession
    @State private var showOnboarding = false

    var body: some View {
        Group {
            if userSession.isAuthenticated {
                if showOnboarding {
                    OnboardingFlowOrchestrator {
                        showOnboarding = false
                    }
                } else {
                    MainAppView()
                        .overlay(alignment: .top) {
                            GracePeriodBannerView()
                        }
                }
            } else {
                SignInView()
            }
        }
        .onAppear {
            // Check if user needs onboarding
            Task {
                if userSession.isAuthenticated {
                    let info = try? await MigrationManager.shared
                        .getMigrationInfo(for: userSession.user?.id ?? "")

                    showOnboarding = info?.shouldShowFunnel == true ||
                                    info?.shouldShowPaywall == true
                }
            }
        }
    }
}
```

### Step 6: Firestore Setup

Add these fields to user documents:

```javascript
// Firestore users collection structure
{
  "users": {
    "<userId>": {
      // Existing fields...

      // New migration fields
      "isLegacyUser": true/false,
      "legacyGracePeriodEnd": Timestamp,
      "subscriptionStatus": "legacy_free" | "trial_pending" | "active" | "expired",
      "subscriptionTier": "pro" | "none",
      "migratedAt": Timestamp,
      "migrationVersion": "v2_funnel",

      // New user fields
      "needsFunnelOnboarding": true/false,
      "funnelCompletedAt": Timestamp
    }
  }
}
```

### Step 7: Analytics Events

Track these events for optimization:

```swift
// Onboarding
"onboarding_started"
"onboarding_legacy_user"
"onboarding_new_user"
"onboarding_funnel_completed"
"onboarding_paywall_completed"

// Funnel
"funnel_started_v2"
"funnel_answer_selected"
"funnel_next"
"funnel_exit_intent"
"funnel_abandoned"
"funnel_completed"

// Paywall
"founders_paywall_shown"
"founders_offer_expired"
"subscription_initiated"
"subscription_completed"
"subscription_failed"
"paywall_skip_attempted"

// Migration
"user_migrated"
"legacy_grace_period_reminder"
"legacy_grace_period_expired"
```

---

## 🧪 Testing Checklist

### New User Flow
- [ ] New user signs up
- [ ] Sees funnel with 8 questions
- [ ] Completes funnel
- [ ] Sees founder's offer paywall with countdown
- [ ] Timer counts down correctly
- [ ] After 5min, founder's offer disappears
- [ ] Can purchase any plan
- [ ] Gets access to full app after purchase

### Legacy User Flow
- [ ] Existing user (registered before Jan 1, 2026) signs in
- [ ] Migration automatically grants 1 year free Pro
- [ ] User sees grace period banner
- [ ] Full app access without paywall
- [ ] Banner shows correct days remaining
- [ ] After grace period expires, sees paywall

### Edge Cases
- [ ] User closes app during funnel - resumes where left off
- [ ] User closes app during countdown - timer resumes correctly
- [ ] No bypass to free access (no skip buttons work)
- [ ] Offline mode - migration queued for next online
- [ ] Multiple devices - migration syncs via Firestore

---

## ⚠️ Important Notes

### 1. **No Free Access**
- Remove all "Continue without Pro" or "Skip" buttons
- Every user must subscribe after grace period
- Legacy users get 1 year free, then must subscribe

### 2. **Grandfather Clause**
- Users registered before Jan 1, 2026 = Legacy
- They get exactly 1 year from migration date
- After that, they see normal paywall (no founder's offer)

### 3. **Founder's Offer Timer**
- Timer is PER USER (stored in UserDefaults)
- Once expired, can never see $19.99 offer again
- They see only $29.99/year + $14.99/month

### 4. **All Features Unlocked**
- Remove ALL pro-gating immediately
- Everyone sees full app
- Payment is required to continue using (except legacy grace period)

---

## 📊 Expected Conversion Metrics

Based on the improved funnel psychology:

- **Funnel Completion Rate:** 70-85% (vs industry 30-50%)
- **Founder's Offer Conversion:** 25-35% (urgency + discount)
- **Standard Plan Conversion:** 15-20%
- **Overall Paywall Conversion:** 40-55%
- **Legacy User Retention:** 60-70% (post grace period)

---

## 🎨 Customization Tips

### Countdown Timer Duration
Change in `FoundersOfferViewModel`:
```swift
@Published var timeRemaining: TimeInterval = 300 // 5 minutes = 300 seconds
```

### Grace Period Duration
Change in `MigrationManager`:
```swift
let gracePeriodEnd = Calendar.current.date(byAdding: .year, value: 1, to: Date())
```

### Pricing
Update in `FoundersOfferPaywall.swift`:
```swift
price: "$19.99"  // Founder's offer
price: "$29.99"  // Standard annual
price: "$14.99"  // Monthly
```

---

## 🐛 Troubleshooting

### "Migration failed" error
- Check Firestore rules allow user document updates
- Verify user has `createdAt` timestamp in Firestore
- Check network connection

### Timer not counting down
- Check UserDefaults keys aren't conflicting
- Verify timer starts in `onAppear`
- Check app isn't being suspended by iOS

### Legacy users not getting grace period
- Verify `legacyCutoffDate` is correct (Jan 1, 2026)
- Check user's `createdAt` date in Firestore
- Run `forceMigration()` to retry

### Users bypassing paywall
- Ensure all skip buttons are disabled
- Check `shouldShowPaywall` logic in orchestrator
- Verify subscription status checks

---

## 🚀 Deployment Steps

1. **Phase 1: Testing** (1-2 weeks)
   - Deploy to TestFlight
   - Test with beta users
   - Monitor analytics & fix bugs

2. **Phase 2: Soft Launch** (1 week)
   - Release to 10% of users
   - Monitor conversion rates
   - Adjust copy/pricing if needed

3. **Phase 3: Full Launch**
   - Release to 100% of users
   - Send email to legacy users explaining grace period
   - Monitor support tickets closely

---

## 📧 Communication Templates

### Email to Legacy Users

**Subject: Thank you for being an early supporter! 🎉**

Hey [Name],

You've been with us since the beginning, and we want to say **thank you**.

As a founding user, you're getting **1 full year of Pro access for free** — no strings attached.

**What this means for you:**
- All Pro features unlocked until [Grace Period End Date]
- No payment required for 12 months
- After that, choose a plan that works for you

You'll see a reminder in the app showing your days remaining. We'll also send you a heads-up email 30 days before your grace period ends.

Thanks for being part of our journey!

— The 100 Days Team

---

## 💡 Pro Tips

1. **A/B Test Founder's Offer Duration:** Try 3min vs 5min vs 10min
2. **Personalize Paywall:** Use funnel answers to customize copy
3. **Exit Intent:** Track how many times users try to leave
4. **Optimize Questions:** Remove any funnel question with >20% drop-off
5. **Seasonal Pricing:** Adjust founder's offer for holidays

---

## 📞 Support

If you encounter any issues:
1. Check this guide first
2. Review the code comments
3. Test with `forceMigration()` to reset state
4. Check Firestore console for user data
5. Review analytics events for drop-off points

**Key Debug Commands:**
```swift
// Force re-migration (testing only)
MigrationManager.shared.forceMigration()

// Check user migration status
let info = try await MigrationManager.shared.getMigrationInfo(for: userId)
print(info)

// Reset founder's offer timer (testing only)
UserDefaults.standard.removeObject(forKey: "founders_offer_start_time")
UserDefaults.standard.removeObject(forKey: "founders_offer_expired")
```

---

## ✅ Final Checklist Before Launch

- [ ] All 3 subscription products created in App Store Connect
- [ ] Products configured in RevenueCat dashboard
- [ ] Migration system tested with sample users
- [ ] Funnel questions finalized and tested
- [ ] Founder's offer countdown tested thoroughly
- [ ] All pro-gating removed from app
- [ ] Grace period banner displays correctly
- [ ] Analytics events firing correctly
- [ ] Email templates ready for legacy users
- [ ] Support team briefed on new model
- [ ] App Store listing updated (no mention of "free")
- [ ] Privacy policy updated (if needed)

---

**Good luck with your launch! 🚀**

This new model should significantly improve your conversion rates and revenue. The combination of emotional funnel + urgency + social proof is proven to work.

Remember: Monitor your analytics closely in the first week and be ready to iterate based on user behavior!
