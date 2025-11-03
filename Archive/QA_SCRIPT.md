# QA Testing Script - Hard Paywall & Onboarding Funnel

## Prerequisites
- Clean install on simulator or test device
- Firebase Auth configured
- RevenueCat configured with test products
- Analytics dashboard access

---

## Test Path 1: New User (After Cutoff) - Full Flow

### Setup
1. Delete app from device/simulator
2. Clear all app data
3. Launch app fresh

### Expected Flow: Auth → Funnel → Setup → Commitment → Paywall (5min timer) → Purchase → App

#### Step 1: Authentication
- [ ] App shows splash screen for 2 seconds
- [ ] Auth screen appears
- [ ] Sign in with Apple/Google works
- [ ] User is NOT taken directly to app

#### Step 2: Funnel (8 Questions)
- [ ] Progress bar shows "Step 1 of 8"
- [ ] Q1: "What are you committing to check in for 100 days?"
  - Options: Move body, **Study & focus**, Create, Save money, Mindfulness, Other
- [ ] Q2: "What pushed you to start today?"
- [ ] Q3: **"What usually derails you?"** (not "biggest thing")
- [ ] Q4: **"How much time can you honestly give most days?"**
- [ ] Q5: **"When are you most likely to check in?"**
- [ ] Q6: Options include **"Streaks & badges"** (ampersand, not slash)
- [ ] Q7: **"If you miss a day, what tone helps you bounce back?"**
- [ ] Q8: "Name your 100-day commitment"
  - Subtitle: **"This becomes the title"** (not "This will be")
  - Shows text field with placeholder
  - Character counter shows X/100
  - Suggestion chips appear

#### Step 3: Streak Setup Preview
- [ ] Shows personalized configuration
- [ ] "Your 100-Day Setup" headline
- [ ] Cards show: Time window, Reminder style, Backup plan, Motivation tone, Goal
- [ ] Commitment name appears highlighted
- [ ] "Looks good!" button present
- [ ] "Edit settings" button goes back to funnel

#### Step 4: Commitment Prompt
- [ ] Headline: "Ready to transform your life through consistency?"
- [ ] Subcopy: "Unlock daily check-ins, streaks, reminders, and progress — no ads."
- [ ] Continue button present

#### Step 5: Hard Paywall - 5 Minute Timer
- [ ] Paywall appears immediately
- [ ] Headline shows: **"Unlock '[Commitment Name]' with 100Days Pro"**
- [ ] Circular countdown timer visible
- [ ] Timer shows 5:00 and counts down
- [ ] "Founder's Rate ends in X:XX" text visible
- [ ] Annual tab shows **$19.99**
- [ ] Monthly tab shows **$14.99**
- [ ] Both tabs are selectable
- [ ] No close/dismiss button (hard paywall)
- [ ] Back gesture is DISABLED
- [ ] Timer ticks down every second

#### Step 6: Timer Behavior
- [ ] Wait for timer to reach 4:30
  - Timer still shows Annual $19.99
- [ ] Wait for timer to reach 1:00
  - Timer pulsates (if Reduce Motion off)
  - Still shows Annual $19.99
- [ ] Wait for timer to reach 0:00
  - Timer stops
  - **Annual tab becomes unavailable/locked or disappears**
  - Only Monthly $14.99 remains
  - No founders ribbon visible

#### Step 7: Purchase Flow
- [ ] Tap "Continue" on Monthly
- [ ] iOS payment sheet appears
- [ ] Complete purchase (sandbox account)
- [ ] Loading indicator shows
- [ ] Success → navigates to MainAppView
- [ ] User can now access full app

#### Step 8: Analytics Verification
Check Firebase Analytics for these events in sequence:
- [ ] `quiz_started`
- [ ] `quiz_next` (7 times, steps 1-7)
- [ ] `quiz_completed` with time_spent
- [ ] `setup_shown`
- [ ] `setup_confirmed` with edited=false
- [ ] `transform_cta_tap`
- [ ] `paywall_shown` with cohort=new_after_update, annual_visible=true, founders_visible=false
- [ ] `timer_start`
- [ ] `timer_tick` (multiple times at 30s intervals)
- [ ] `timer_expire`
- [ ] `purchase_tap` with product_id=com.KhamariThompson.100Days.monthlyv2
- [ ] `purchase_success` with product_id

---

## Test Path 2: Legacy User (Before Cutoff) - Founders Ribbon

### Setup
1. Manually set account creation date to before Oct 24, 2025 in Firestore
2. OR use existing account created before cutoff
3. Delete app, reinstall

### Expected Flow: Auth → Funnel → Paywall (Founders Ribbon, no timer) → Purchase → App

#### Paywall Verification
- [ ] No circular countdown timer visible
- [ ] Founders ribbon appears:
  - **"🎉 Founders Special"**
  - **"$19.99 for your first year — then $29.99/yr. Ends January 1, 2026."**
- [ ] Annual tab shows **$19.99** (no timer required)
- [ ] Monthly tab shows **$14.99**
- [ ] Both tabs selectable
- [ ] Can purchase Annual at $19.99 immediately
- [ ] Ribbon has elevated card with accent border

#### Analytics Verification
- [ ] `paywall_shown` with cohort=legacy_pre_update, annual_visible=true, founders_visible=true
- [ ] No timer events (`timer_start`, `timer_tick`, `timer_expire`)

---

## Test Path 3: Already Pro User

### Setup
1. User with active Pro subscription
2. Delete and reinstall app

### Expected Flow: Auth → MainAppView (bypass funnel + paywall)

#### Verification
- [ ] Splash screen shows
- [ ] Auth screen appears
- [ ] Sign in
- [ ] **Immediately** taken to MainAppView
- [ ] Funnel is NOT shown
- [ ] Paywall is NOT shown
- [ ] Full app functionality available

---

## Test Path 4: Restore Purchases

### Setup
1. New user who previously purchased (different device)
2. Fresh install
3. Complete funnel

### Expected Flow: Auth → Funnel → Paywall → Restore → App

#### Paywall Actions
- [ ] Reach paywall
- [ ] Tap "Restore Purchases"
- [ ] Loading indicator shows
- [ ] iOS restore dialog appears
- [ ] Previous purchase detected
- [ ] Success → MainAppView

#### Analytics Verification
- [ ] `restore_tap`
- [ ] `restore_success` (if active subscription found)
- [ ] OR `restore_failure` with reason (if no subscription)

---

## Test Path 5: Edge Cases

### Editing Funnel Answers
- [ ] Complete 3 questions
- [ ] Tap "Back"
- [ ] Previous answer is still selected
- [ ] Change answer
- [ ] Progress persists

### Offline During Funnel
- [ ] Start funnel
- [ ] Turn off network
- [ ] Answers save locally
- [ ] Cannot proceed past funnel without network
- [ ] Turn network back on
- [ ] Continue successfully

### Force Kill During Timer
- [ ] Start paywall with 4:00 remaining
- [ ] Force kill app
- [ ] Reopen app
- [ ] Timer resumes from ~3:55 (accounting for time passed)
- [ ] firstPaywallAt persists

### Small Screen (iPhone SE)
- [ ] All text readable
- [ ] No truncation
- [ ] Buttons accessible
- [ ] Timer fits on screen

### Large Text (Accessibility)
- [ ] Settings → Accessibility → Display & Text Size → Larger Text
- [ ] Set to maximum
- [ ] All text scales properly
- [ ] Layout doesn't break
- [ ] Buttons remain tappable

### Dark Mode
- [ ] Toggle Dark Mode
- [ ] All colors adapt correctly
- [ ] Timer contrast is good
- [ ] Founders ribbon readable
- [ ] Accent colors visible

### VoiceOver
- [ ] Enable VoiceOver
- [ ] Progress announced: "Step X of 8"
- [ ] Timer announces: "Founder's offer ends in X minutes Y seconds"
- [ ] Buttons have clear labels
- [ ] Selected state announced
- [ ] All interactive elements accessible

### Reduce Motion
- [ ] Enable Reduce Motion
- [ ] Timer pulse is disabled
- [ ] Other animations simplified
- [ ] App still functional

---

## Test Path 6: Funnel Completion Without Purchase

### Expected: Funnel completed, but user remains on paywall

#### Setup
1. Complete full funnel
2. Reach paywall
3. Do NOT purchase
4. Force kill app

#### Verification
- [ ] Reopen app
- [ ] Auth succeeds
- [ ] User taken DIRECTLY to paywall (not funnel)
- [ ] hasCompletedFunnel = true in Firestore
- [ ] Timer continues from where it left off (or expired)
- [ ] Commitment name still shown in headline

---

## RevenueCat Attributes Verification

### Check RevenueCat Dashboard

#### For New Users
- [ ] Attribute `cohort` = "new_after_update"
- [ ] Attribute `funnel_completed_at` = ISO8601 timestamp
- [ ] Attribute `first_paywall_at` = ISO8601 timestamp

#### For Legacy Users
- [ ] Attribute `cohort` = "legacy_pre_update"
- [ ] Attribute `funnel_completed_at` = ISO8601 timestamp
- [ ] Attribute `first_paywall_at` = ISO8601 timestamp

---

## Firestore Data Verification

### User Document Structure
```
users/{userId}
  - hasCompletedOnboarding: false (until Pro purchase)
  - funnelCompletedAt: Timestamp
  - createdAt: Timestamp
  - username: string
  - displayName: string
```

---

## Pricing Accuracy

### Verify Correct Prices
- [ ] Monthly: Always **$14.99**
- [ ] Annual (regular): **$29.99**
- [ ] Annual (founders): **$19.99** for first year
- [ ] Founders text: "then $29.99/yr"

### Product IDs
- [ ] Monthly: `com.KhamariThompson.100Days.monthlyv2`
- [ ] Annual: `com.KhamariThompson.100Days.annualv1`

---

## Critical Business Rules

### Hard Paywall Enforcement
- [ ] CANNOT access main app without Pro
- [ ] No dismiss button on paywall
- [ ] Back gesture disabled on paywall
- [ ] Restore is only way to bypass purchase

### Timer Rules (New Users)
- [ ] Timer starts on first paywall view
- [ ] Timer is 5 minutes (300 seconds)
- [ ] firstPaywallAt is saved once, never reset
- [ ] After expiry, Annual becomes unavailable
- [ ] Timer state persists across app restarts

### Founders Rules (Legacy Users)
- [ ] Available until **January 1, 2026** (not Oct 10, 2025)
- [ ] No timer shown
- [ ] Founders ribbon always visible (until deadline)
- [ ] $19.99 pricing applies to first year only

---

## Post-Purchase Verification

### After Successful Purchase
- [ ] `hasCompletedOnboarding` = true in Firestore
- [ ] User can access MainAppView
- [ ] Check-in button functional
- [ ] All Pro features unlocked
- [ ] No more paywall on subsequent launches

---

## Regression Testing

### Ensure These Still Work
- [ ] Daily check-in functionality
- [ ] Streak tracking
- [ ] Progress analytics
- [ ] Settings
- [ ] Profile
- [ ] Notifications
- [ ] Dark mode toggle
- [ ] Sign out

---

## Known Issues / TODOs

Document any issues found during QA:
- [ ] List any bugs discovered
- [ ] Note any UI/UX improvements needed
- [ ] Performance issues
- [ ] Crash scenarios

---

## Sign-Off

- [ ] All critical paths tested
- [ ] Analytics verified
- [ ] No blocking issues
- [ ] Ready for production

**Tester Name:** _________________
**Date:** _________________
**Build Version:** _________________
**Notes:**

