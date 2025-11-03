# RevenueCat Apple In-App Purchase Key Setup

## Problem

RevenueCat logs show: **"Apple In-App Purchase Key is invalid or not present"** in debug mode, and receipt POST is failing. This blocks correct entitlement syncing and can cause users to not receive Pro access even after purchase.

## Solution

Follow these steps to configure the RevenueCat In-App Purchase Key properly:

---

## Step 1: Generate In-App Purchase Key in App Store Connect

1. Go to [App Store Connect](https://appstoreconnect.apple.com/)
2. Navigate to **Users and Access** (in the top menu)
3. Click on **Keys** in the left sidebar
4. Select the **In-App Purchase** tab
5. Click **Generate In-App Purchase Key** (+ icon)
6. Name the key (e.g., "RevenueCat IAP Key")
7. Click **Generate**
8. **Download the `.p8` file immediately** (you can only download it once!)
9. **Note down the Key ID** (e.g., `ABC123XYZ`)
10. **Note down the Issuer ID** (found at the top of the Keys page, e.g., `12345678-1234-1234-1234-123456789012`)

⚠️ **IMPORTANT**: Keep the `.p8` file secure. You cannot re-download it. If lost, you must revoke and generate a new key.

---

## Step 2: Upload Key to RevenueCat Dashboard

1. Go to [RevenueCat Dashboard](https://app.revenuecat.com/)
2. Select your project
3. Click on **Apps** in the left sidebar
4. Select your iOS app
5. Click on **Apple App Store** (or **Integrations** → **App Store Connect**)
6. Scroll to **In-App Purchase Key** section
7. Click **Add In-App Purchase Key**
8. Upload the `.p8` file
9. Enter the **Key ID** (from Step 1.9)
10. Enter the **Issuer ID** (from Step 1.10)
11. Click **Save**

---

## Step 3: Verify Bundle ID and Products

While in the RevenueCat dashboard:

1. **Verify Bundle ID matches your app**:
   - Should be: `com.KhamariThompson.100Days` (or your actual bundle ID)
   - Found in: RevenueCat Dashboard → Apps → (Your App) → Settings

2. **Verify Products are configured**:
   - Go to: RevenueCat Dashboard → Products
   - Ensure these products exist and match App Store Connect:
     - Monthly: `com.KhamariThompson.100Days.monthlyv2`
     - Annual (Intro): `com.KhamariThompson.100Days.annualv1`
     - Annual (No Intro): `com.KhamariThompson.100Days.annualv1.no_intro1`

3. **Verify Products are in an Offering**:
   - Go to: RevenueCat Dashboard → Offerings
   - Ensure there's a `default_offerings` (or similar) offering
   - Attach all 3 products to this offering

---

## Step 4: Enable App Store Server Notifications (Optional but Recommended)

This allows RevenueCat to receive real-time updates about subscriptions:

1. In RevenueCat Dashboard → Apps → (Your App) → Apple App Store
2. Copy the **App Store Server Notification URL** (looks like `https://api.revenuecat.com/v1/notifications/apple/...`)
3. Go to [App Store Connect](https://appstoreconnect.apple.com/)
4. Navigate to your app → **App Information**
5. Scroll to **App Store Server Notifications**
6. Click **+ Production Server URL** (and/or Sandbox if testing)
7. Paste the RevenueCat webhook URL
8. Select **Version 2** (ASN v2)
9. Click **Save**

---

## Step 5: Verify Configuration in App

After completing the above steps:

1. Launch your app in **debug mode** on a device or simulator
2. Sign in with a test account
3. Check Xcode console logs for:
   ```
   ✅ SubscriptionStore: Loaded status - isPro: ...
   ```

4. **Should NOT see**:
   ```
   ❌ Apple In-App Purchase Key is invalid or not present
   ```

5. If you still see the error:
   - Wait 5-10 minutes (propagation delay)
   - Clear app data and reinstall
   - Verify all steps above were completed correctly

---

## Step 6: Test With Sandbox Account

1. On your iOS device, sign out of your real Apple ID in **Settings → App Store**
2. Create a Sandbox Tester in App Store Connect:
   - Go to **Users and Access** → **Sandbox Testers**
   - Click **+** to create a new tester
   - Use a unique email (does not need to be real)
3. Launch your app and sign in
4. When prompted to purchase, sign in with the sandbox tester account
5. Verify the purchase completes and `isPro` becomes `true`

---

## Troubleshooting

### Error: "Apple In-App Purchase Key is invalid"

**Possible causes:**
- Key ID or Issuer ID entered incorrectly
- `.p8` file corrupted during upload
- Bundle ID mismatch between RevenueCat and App Store Connect
- Propagation delay (wait 5-10 minutes)

**Solution:**
- Re-verify Key ID and Issuer ID in RevenueCat dashboard
- Re-upload the `.p8` file
- Check Bundle ID matches exactly

### Error: "No offerings found"

**Possible causes:**
- Products not attached to an offering in RevenueCat
- Product IDs don't match App Store Connect
- Products not approved in App Store Connect

**Solution:**
- Go to RevenueCat Dashboard → Offerings
- Ensure products are attached to `default_offerings`
- Verify product IDs match exactly (case-sensitive)
- Check App Store Connect → My Apps → (Your App) → In-App Purchases

### Error: "User is not eligible for intro price"

**Possible causes:**
- User already consumed an intro offer for this subscription group
- Intro price not configured in App Store Connect
- Using production environment with sandbox account (or vice versa)

**Solution:**
- Use a fresh sandbox tester account
- Verify intro price is set in App Store Connect
- Ensure you're using the correct environment (sandbox vs production)

---

## Important Notes

1. **StoreKit 2 vs StoreKit 1**: This app uses StoreKit 2 APIs via RevenueCat. The In-App Purchase Key is **required** for StoreKit 2.

2. **App-Specific Shared Secret** (legacy): NOT required if you're using In-App Purchase Key. Only needed for legacy StoreKit 1 receipt validation.

3. **Revoke Old Keys**: If you previously had a key and generated a new one, ensure the old key is either revoked or not being used by RevenueCat.

4. **Key Permissions**: In-App Purchase Keys have read-only access to transaction history. They cannot make purchases or refunds.

5. **One Key Per Provider**: You can use the same In-App Purchase Key across multiple apps in your developer account.

---

## Verification Checklist

- [ ] In-App Purchase Key generated in App Store Connect
- [ ] `.p8` file downloaded and saved securely
- [ ] Key ID noted (e.g., `ABC123XYZ`)
- [ ] Issuer ID noted (e.g., `12345678-1234-...`)
- [ ] Key uploaded to RevenueCat dashboard
- [ ] Key ID and Issuer ID entered in RevenueCat
- [ ] Bundle ID matches in both systems
- [ ] All products exist in RevenueCat and match App Store Connect
- [ ] Products are attached to an offering in RevenueCat
- [ ] (Optional) App Store Server Notifications configured
- [ ] Tested with sandbox account - no errors in console
- [ ] `CustomerInfo` updates successfully without error

---

## Support

If you continue to experience issues:
- [RevenueCat Documentation](https://docs.revenuecat.com/)
- [RevenueCat Community](https://community.revenuecat.com/)
- [Apple StoreKit Documentation](https://developer.apple.com/storekit/)
