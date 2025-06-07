# RevenueCat Subscription Troubleshooting Guide

## Common Issues and Solutions

### 1. Subscription Not Appearing in RevenueCat Dashboard

**Possible Causes:**

- Receipt not properly synced with RevenueCat servers
- Environment mismatch (sandbox vs. production)
- Original purchaser ID not matching current user
- Failed API calls due to network issues

**Solutions:**

```swift
// Force sync purchases with retry logic
try await syncPurchasesWithRetry(maxRetries: 3)

// Verify environment
let receiptURL = Bundle.main.appStoreReceiptURL
let isSandboxReceipt = receiptURL?.lastPathComponent == "sandboxReceipt"
print("Using \(isSandboxReceipt ? "SANDBOX" : "PRODUCTION") receipt")

// Check original purchaser ID
let customerInfo = try await Purchases.shared.customerInfo()
print("Original AppUserID: \(customerInfo.originalAppUserId)")
print("Current AppUserID: \(Purchases.shared.appUserID)")
```

### 2. Subscription Persisting Across Different User Accounts

**Possible Causes:**

- Incomplete state reset on logout
- UserDefaults cache not properly cleared
- Missing verification of originalAppUserId
- Stale RevenueCat SDK state

**Solutions:**

```swift
// Complete reset of all state
func reset() {
    // Reset all published properties
    isProUser = false

    // Clear ALL cached subscriptions in UserDefaults
    let userDefaultsKeys = [
        "cachedProStatus", "cachedExpirationDate",
        "lastUserIdentified", "lastRevenueCatSync"
    ]

    for key in userDefaultsKeys {
        UserDefaults.standard.removeObject(forKey: key)
    }

    // Force sync on next login
    needsForcedPurchaseSync = true
}

// Verify original purchaser on app resume
if let originalAppUserId = customerInfo.originalAppUserId,
   !originalAppUserId.isEmpty && originalAppUserId != currentFirebaseUID {
    // Force Pro status to false if original purchaser doesn't match
    self.isProUser = false
}
```

### 3. UI Not Showing Correct Subscription Status

**Possible Causes:**

- State not updated on main thread
- Missing notification of state changes
- Cached state not invalidated
- Race conditions in async updates

**Solutions:**

```swift
// Always update UI state on MainActor
await MainActor.run {
    self.isProUser = hasPro

    // Post notification for subscription change
    NotificationCenter.default.post(
        name: NSNotification.Name("SubscriptionStatusChanged"),
        object: nil,
        userInfo: ["isProUser": hasPro]
    )
}

// Listen for notifications in UI components
.onReceive(NotificationCenter.default.publisher(for:
    NSNotification.Name("SubscriptionStatusChanged"))) { notification in
    if let isProUser = notification.userInfo?["isProUser"] as? Bool {
        self.isPro = isProUser
    }
}
```

## Diagnostic Tools

### RevenueCat Status Checker

```swift
func debugReceiptStatus() async -> Bool {
    print("🔐 RevenueCat: Debugging receipt status")

    // Check receipt existence and type
    guard let receiptURL = Bundle.main.appStoreReceiptURL else {
        print("🔐 RevenueCat: No receipt URL available")
        return false
    }

    let receiptExists = FileManager.default.fileExists(atPath: receiptURL.path)
    let isSandboxReceipt = receiptURL.lastPathComponent == "sandboxReceipt"

    print("🔐 RevenueCat: Receipt exists: \(receiptExists)")
    print("🔐 RevenueCat: Receipt type: \(isSandboxReceipt ? "SANDBOX" : "PRODUCTION")")

    // Force sync and check customer info
    try await syncPurchasesWithRetry(maxRetries: 3)
    let customerInfo = try await Purchases.shared.customerInfo()

    print("🔐 RevenueCat: Original AppUserID: \(customerInfo.originalAppUserId)")
    print("🔐 RevenueCat: Current AppUserID: \(Purchases.shared.appUserID)")
    print("🔐 RevenueCat: Active entitlements: \(customerInfo.entitlements.active.keys)")

    return true
}
```

## When to Contact RevenueCat Support

Contact RevenueCat support if:

1. Purchases are successful on device but never appear in the dashboard
2. Receipts show active subscriptions locally but not in RevenueCat
3. Customer reports a successful purchase but entitlements aren't granted
4. Significant discrepancies between StoreKit and RevenueCat subscription status

Include these diagnostic details when contacting support:

- App ID and version
- RevenueCat SDK version
- Receipt environment (sandbox vs production)
- Original and current app user IDs
- Transaction date and product identifier
