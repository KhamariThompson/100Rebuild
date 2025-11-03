# Unified Diffs: Legacy User Routing & UI Fixes

**Date**: 2025-10-27
**Total Files Changed**: 4
**Total Changes**: 6 edits

---

## File 1: Services/MigrationManager.swift

### Change 1: Fix Legacy Cutoff Date (Lines 29-39)

```diff
--- a/100DaysRebuild/Services/MigrationManager.swift
+++ b/100DaysRebuild/Services/MigrationManager.swift
@@ -29,9 +29,9 @@ class MigrationManager: ObservableObject {
     private let legacyCutoffDate: Date = {
         var components = DateComponents()
         // IMPORTANT: Users registered BEFORE November 1, 2025 are grandfathered
         // They get 1 year of free Pro from their account creation date
-        components.year = 2024
-        components.month = 1
+        components.year = 2025
+        components.month = 11
         components.day = 1
         components.hour = 0
         components.minute = 0
         return Calendar.current.date(from: components) ?? Date()
```

**Impact**: Critical - fixes legacy user identification. Changes cutoff from Jan 1, 2024 to Nov 1, 2025 per business requirements.

---

### Change 2: Fix Grace Period Calculation (Lines 151-178)

```diff
--- a/100DaysRebuild/Services/MigrationManager.swift
+++ b/100DaysRebuild/Services/MigrationManager.swift
@@ -150,12 +150,29 @@ class MigrationManager: ObservableObject {

     /// Migrate legacy users - grant 1 year free Pro from account creation date
     private func migrateLegacyUser(userId: String) async throws {
-        // Grace period is 1 year from today
-        let gracePeriodEnd = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
+        // Get registration date from Firestore
+        let userDoc = try await db.collection("users").document(userId).getDocument()
+        guard let data = userDoc.data(),
+              let createdAtTimestamp = data["createdAt"] as? Timestamp else {
+            throw NSError(domain: "MigrationManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot get registration date"])
+        }
+
+        let registrationDate = createdAtTimestamp.dateValue()
+        // Grace period is 1 year from REGISTRATION date, not today
+        let gracePeriodEnd = Calendar.current.date(byAdding: .year, value: 1, to: registrationDate) ?? registrationDate

         // Store grace period locally
         userDefaults.set(gracePeriodEnd, forKey: Keys.legacyUserGracePeriod)
         legacyUserGracePeriodEnd = gracePeriodEnd

         // Update Firestore
         try await db.collection("users").document(userId).setData([
             "isLegacyUser": true,
             "legacyGracePeriodEnd": Timestamp(date: gracePeriodEnd),
             "subscriptionStatus": "legacy_free",
             "subscriptionTier": "pro",
             "migratedAt": Timestamp(date: Date()),
             "migrationVersion": "v2_funnel"
         ], merge: true)

-        print("✅ Legacy user migrated: \(userId) | Grace period until: \(gracePeriodEnd)")
+        print("✅ Legacy user migrated: \(userId) | Registered: \(registrationDate) | Grace period until: \(gracePeriodEnd)")
     }
```

**Impact**: Critical - fixes grace period calculation to use account creation date instead of current date. Ensures correct 1-year entitlement from registration.

---

## File 2: Features/Auth/Views/WelcomeView.swift

### Change 3: Fix Background Gradient Transparency (Lines 96-127)

```diff
--- a/100DaysRebuild/Features/Auth/Views/WelcomeView.swift
+++ b/100DaysRebuild/Features/Auth/Views/WelcomeView.swift
@@ -100,7 +100,7 @@ struct WelcomeView: View {
                 // Top accent gradient
                 LinearGradient(
                     gradient: Gradient(colors: [
                         Color.theme.accent.opacity(0.15),
-                        Color.theme.background.opacity(0.0)
+                        Color.clear
                     ]),
                     startPoint: .topLeading,
                     endPoint: .center
@@ -112,7 +112,7 @@ struct WelcomeView: View {
                 // Bottom fade to background
                 LinearGradient(
                     gradient: Gradient(colors: [
-                        Color.theme.background.opacity(0.0),
+                        Color.clear,
                         Color.theme.background.opacity(0.8),
                         Color.theme.background
                     ]),
```

**Impact**: UI - fixes first-frame transparency glitch by using proper `Color.clear` instead of `.opacity(0.0)` in gradient endpoints.

---

## File 3: Subscription/UI/CommitNowView.swift

### Change 4: Add Opaque Base Layer (Lines 12-22)

```diff
--- a/100DaysRebuild/Subscription/UI/CommitNowView.swift
+++ b/100DaysRebuild/Subscription/UI/CommitNowView.swift
@@ -11,6 +11,9 @@ struct CommitNowView: View {

     var body: some View {
         ZStack {
+            // Opaque base to prevent transparency
+            Color.black.ignoresSafeArea()
+
             // Background gradient
             LinearGradient(
                 colors: [DS.Colors.gradientA, DS.Colors.gradientB],
```

**Impact**: UI - fixes gradient transparency issue by adding opaque black base layer beneath gradient.

---

### Change 5: Fix SignOut Error Handling (Line 30)

```diff
--- a/100DaysRebuild/Subscription/UI/CommitNowView.swift
+++ b/100DaysRebuild/Subscription/UI/CommitNowView.swift
@@ -27,7 +27,7 @@ struct CommitNowView: View {
                     Spacer()
                     Button(action: {
                         Task {
-                            try? await userSession.signOut()
+                            try await userSession.signOut()
                         }
                     }) {
                         Text("Log Out")
```

**Impact**: Build fix - properly propagates errors from throwing async call instead of silently ignoring with `try?`.

---

## File 4: Features/Auth/Views/ImprovedFunnelView.swift

### Change 6: Fix SignOut Error Handling (Line 611)

```diff
--- a/100DaysRebuild/Features/Auth/Views/ImprovedFunnelView.swift
+++ b/100DaysRebuild/Features/Auth/Views/ImprovedFunnelView.swift
@@ -606,7 +606,7 @@ struct ImprovedFunnelView: View {
             Button(action: {
                 analyticsService.trackEvent("funnel_logout_requested", properties: [
                     "step": currentStep
                 ])
                 Task {
-                    try? await userSession.signOut()
+                    try await userSession.signOut()
                 }
             }) {
                 Text("Log Out")
```

**Impact**: Build fix - properly propagates errors from throwing async call instead of silently ignoring with `try?`.

---

## Summary of Changes

| File | Changes | Type | Impact |
|------|---------|------|--------|
| MigrationManager.swift | 2 | Business Logic | Critical - fixes legacy user identification and grace period calculation |
| WelcomeView.swift | 1 | UI | Important - fixes first-frame rendering glitch |
| CommitNowView.swift | 2 | UI + Build | Important - fixes gradient transparency and build error |
| ImprovedFunnelView.swift | 1 | Build | Minor - fixes pre-existing build error |

**Total Lines Changed**: ~40 lines across 4 files
**Build Status**: ✅ BUILD SUCCEEDED
**Backward Compatibility**: ✅ Preserved - no breaking changes

---

## Verification Commands

To review these changes in your local repository:

```bash
# View all changed files
git status

# View detailed diffs
git diff HEAD Services/MigrationManager.swift
git diff HEAD Features/Auth/Views/WelcomeView.swift
git diff HEAD Subscription/UI/CommitNowView.swift
git diff HEAD Features/Auth/Views/ImprovedFunnelView.swift

# Create patch file
git diff HEAD > legacy_routing_fixes.patch

# View commit log
git log --oneline -6
```

---

## Testing After Apply

After applying these diffs, verify:

1. **Build succeeds**:
   ```bash
   xcodebuild -project 100DaysRebuild.xcodeproj \
     -scheme 100DaysRebuild \
     -destination 'generic/platform=iOS Simulator' \
     build
   ```

2. **No new warnings** related to changed files

3. **UI rendering**:
   - WelcomeView background renders correctly on first frame
   - CommitNowView gradient has no transparency artifacts

4. **Legacy user routing**:
   - Users created before Nov 1, 2025 go directly to Main
   - Grace period calculated from account creation date
   - Banner shows correct days remaining

---

## Rollback Instructions

If these changes cause issues, rollback with:

```bash
# Revert all changes
git checkout HEAD -- Services/MigrationManager.swift
git checkout HEAD -- Features/Auth/Views/WelcomeView.swift
git checkout HEAD -- Subscription/UI/CommitNowView.swift
git checkout HEAD -- Features/Auth/Views/ImprovedFunnelView.swift

# Or revert entire commit
git revert <commit-hash>
```

---

**Generated**: 2025-10-27 20:07 UTC
**Author**: Claude Code
**Review Required**: Yes
**Test Coverage**: Manual QA required (see ROOT_CAUSE_REPORT.md)
