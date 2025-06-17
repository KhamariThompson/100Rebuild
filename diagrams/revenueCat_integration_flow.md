# RevenueCat Integration Flow Diagram

This diagram shows the complete flow of RevenueCat integration in the 100Days app, including:

1. App initialization and configuration
2. User authentication flows (login/logout)
3. Purchase and restore processes
4. Subscription verification mechanisms

```mermaid
graph TD
    A[App Launch] --> B[AppDelegate initializes]
    B --> C[Configure RevenueCat]
    C --> D[Set observer mode & API key]
    D --> E[App becomes active]
    E --> F[handleAppDidBecomeActive]
    F --> G{User logged in?}
    G -->|Yes| H[Check IDs match]
    G -->|No| I[Skip]
    H -->|Match| J[Check originalAppUserId]
    H -->|Mismatch| K[identifyCurrentUser]
    J -->|Match| L[updateSubscriptionStatus]
    J -->|Mismatch| M[Reset Pro status]
    L --> N[forceVerification=true]
    N --> O[syncPurchasesWithRetry]
    O --> P[Use entitlements]

    Q[User Login/SignUp] --> R[AuthService methods]
    R --> S[identifyUserWithRevenueCat]
    S --> T[Purchases.shared.logIn]
    T --> U[syncPurchasesWithRetry]

    V[User Logout] --> W[AuthService.signOut]
    W --> X[Purchases.shared.logOut]
    X --> Y[SubscriptionService.reset]
    Y --> Z[Clear ALL UserDefaults]
    Z --> AA[needsForcedPurchaseSync=true]

    AB[Purchase] --> AC[purchaseSubscription]
    AC --> AD[Check environment]
    AD --> AE[Purchases.shared.purchase]
    AE --> AF[syncPurchasesWithRetry]

    AG[Restore] --> AH[restorePurchases]
    AH --> AI[syncPurchasesWithRetry]
    AI --> AJ[Check originalAppUserId]
```

## Key Implementation Points

1. **User Identity Management**

   - Firebase UID is used as RevenueCat's user identifier
   - Original purchaser verification happens at multiple points
   - Complete reset of state on user switching

2. **Receipt Syncing Strategy**

   - Robust `syncPurchasesWithRetry` with exponential backoff
   - Multiple retry attempts for network failures
   - Explicit sync after login, purchase, and restore

3. **Environment Verification**

   - Sandbox vs. production receipt checking
   - Bundle ID verification
   - Detailed logging of all receipt operations

4. **State Isolation**
   - Complete UserDefaults clearing
   - Force verification on app resume
   - Subscription cache invalidation
