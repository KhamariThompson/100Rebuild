# 100Days - Habit Tracking App

A production-ready iOS app for building sustainable habits through 100-day challenges. Built with SwiftUI following MVVM + Feature-based architecture.

## Overview

100Days helps users commit to and track 100-day challenges with features including:

- Daily check-ins and progress tracking
- Streak monitoring and consistency analytics
- Achievement badges and milestones
- Pro subscription with RevenueCat

## Requirements

- **iOS:** 16.0+
- **Xcode:** 15.0+
- **Swift:** 5.9+

## Quick Start

### 1. Clone & Install

```bash
git clone <repository-url>
cd 100Rebuild
open 100DaysRebuild.xcodeproj
```

Dependencies are managed via Swift Package Manager and will download automatically.

### 2. Firebase Setup

1. Add `GoogleService-Info.plist` to the `100DaysRebuild` folder
2. Configure Firebase Console with:
   - Authentication (Email/Password, Google, Apple)
   - Firestore Database
   - Storage

### 3. RevenueCat Setup

**Product IDs (must match App Store Connect):**

- `com.KhamariThompson.100Days.monthlyv2`
- `com.KhamariThompson.100Days.annualv1`
- `com.KhamariThompson.100Days.annualv1.no_introv1`

**RevenueCat Dashboard Configuration:**

- Offering ID: `default`
- Entitlement: `Pro`
- Packages: `monthly`, `annual`, `annual_no_intro`

## Architecture

```
100DaysRebuild/
├── Core/
│   ├── DesignSystem/     # UI components, colors, typography
│   ├── Navigation/       # AppRouter, centralized routing
│   ├── UI/               # Reusable components
│   └── Utils/            # Constants, extensions
├── Features/
│   ├── Auth/             # Authentication flows
│   ├── CheckIn/          # Daily check-in
│   ├── Challenges/       # Challenge management
│   ├── Profile/          # User profile
│   ├── Progress/         # Progress tracking
│   ├── Settings/         # Settings
│   └── Social/           # Friend features
├── Services/
│   ├── UserSession.swift          # Auth state (SSOT)
│   ├── MigrationManager.swift     # Data migrations
│   └── SubscriptionService.swift  # Legacy service
└── Subscription/
    ├── Domain/           # Models, policies, IDs
    ├── Service/          # SubscriptionStore (SSOT)
    ├── Data/             # RevenueCat repository
    └── UI/               # Paywall, subscription UI
```

## Key Features

### Subscription System

- **Grandfather Policy:** Users before Nov 1, 2025 get 1 year free Pro
- **New User Funnel:** Post-signup onboarding with paywall
- **RevenueCat Integration:** Production-ready with StoreKit 2
- **Offline Support:** Graceful offline handling

### Progress Tracking

- Consistency calendar heatmap
- Streak tracking (current & longest)
- Completion percentage & trends
- Projected completion date

### Social Features

- Friend connections
- Group challenges
- Activity feed
- Leaderboards

## Configuration

### Constants (`Constants.swift`)

```swift
// Subscription cutoff date
enum Onboarding {
    static let newFunnelStartDate = Nov 1, 2025 00:00:00 UTC
    static let grandfatherDuration = 365 days
}

// Feature flags
enum FeatureFlags {
    static var routingV2Enabled: Bool { true }
    static var overrideNoFunnel: Bool { false }
}
```

### Subscription IDs (`SubscriptionIDs.swift`)

```swift
static let entitlement = "Pro"
static let offeringID = "default"

enum ProductID {
    static let monthly = "com.KhamariThompson.100Days.monthlyv2"
    static let annualIntro = "com.KhamariThompson.100Days.annualv1"
    static let annualNoIntro = "com.KhamariThompson.100Days.annualv1.no_introv1"
}
```

## Production Build

### Pre-Release Checklist

✅ **Code:**

- Debug logging removed
- Product IDs verified
- RevenueCat production API key set
- Firebase production mode enabled

✅ **Testing:**

- Subscription flows (purchase, restore, cancel)
- Grandfather logic (users before cutoff)
- New user onboarding flow
- Offline scenarios

✅ **App Store Connect:**

- In-App Purchases created & approved
- Pricing configured
- All metadata filled
- Screenshots uploaded

### Build Steps

1. Archive: Product → Archive
2. Distribute: App Store Connect
3. TestFlight: Beta test with real users
4. Submit: App Store Review

## Documentation

Essential documentation is located in the `docs/` folder:

- **App Store Submission:** `docs/APP_STORE_SUBMISSION_CHECKLIST.md`
- **Production Readiness:** `docs/PRODUCTION_READINESS_CHECKLIST.md`
- **Design System:** `docs/DESIGN_SYSTEM.md`
- **App Icons:** `docs/APP_ICONS.md`

Archived historical documentation: `Archive/` folder

## Support

- Support URL: https://100days.site/support
- Privacy Policy: https://100days.site/privacy
- Terms of Service: https://100days.site/terms

---

**Copyright © 2025 Khamari Thompson. All rights reserved.**
