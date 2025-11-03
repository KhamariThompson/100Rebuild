# Smooth Navigation - Stale Content Flash Fixes

## Summary

Fixed stale content flashing issues during navigation by enforcing view identity, implementing async task cancellation, and ensuring proper first-frame placeholder rendering.

---

## Root Causes & Fixes

### 1. **View Identity Enforcement**

**Problem:** SwiftUI was reusing view instances across different navigation contexts, causing previous data to briefly display.

**Affected Files:**
- `FriendProfileView.swift:27` - Added `.id(friendId)`
- `CheckInHistoryView.swift:109` - Added `.id(challenge.id)`
- `GroupChallengeDetailView.swift:143` - Added `.id(challengeId)`
- `ChallengeDetailView.swift:145` - Added `.id(challenge.id)`

**Fix:** Each view now has a stable identity tied to its input parameter, forcing SwiftUI to create fresh instances when navigating between different items.

```swift
// Before: View reused, stale data flashes
NavigationLink(destination: FriendProfileView(friendId: newId, ...))

// After: Fresh view instance per friendId
FriendProfileView(friendId: newId, ...)
    .id(friendId)  // ✅ New identity = new view instance
```

---

### 2. **Async Task Cancellation**

**Problem:** Network requests from previous navigation contexts continued running and painted stale data after user navigated away.

**Affected Files:**
- `FriendProfileViewModel.swift:21,34` - Added `loadTask` property and cancellation
- `CheckInHistoryView.swift:15,135,147` - Added `loadTask` and `.onDisappear` cancellation
- `GroupChallengeViewModel.swift:29,40` - Added `loadTask` and cancellation

**Fix:** All async loads now cancel previous tasks and check `Task.isCancelled` before updating UI.

```swift
// Before: Old requests kept running
func loadData() {
    Task {
        let data = try await fetchData()
        self.data = data  // ❌ May be stale
    }
}

// After: Cancel old, check before painting
private var loadTask: Task<Void, Never>?

func loadData() {
    loadTask?.cancel()  // ✅ Cancel previous
    loadTask = Task {
        let data = try await fetchData()
        guard !Task.isCancelled else { return }  // ✅ Safety check
        self.data = data
    }
}
```

---

### 3. **First-Frame Placeholder Rendering**

**Problem:** Views rendered previous data while loading, instead of showing a neutral loading state.

**Affected Files:**
- `FriendProfileView.swift:18` - Changed to `isLoading || friendProfile == nil`
- `GroupChallengeDetailView.swift:16` - Changed to `isLoading || challenge == nil`

**Fix:** Views now show loading spinner until fresh data is available, preventing any stale content from rendering.

```swift
// Before: Stale data renders for a frame
if viewModel.isLoading {
    ProgressView()
} else {
    ScrollView { /* renders old data until new arrives */ }
}

// After: Loading until fresh data
if viewModel.isLoading || viewModel.friendProfile == nil {
    ProgressView()  // ✅ No stale data shown
} else {
    ScrollView { /* only renders when fresh */ }
}
```

---

### 4. **Immediate Stale Data Clearing**

**Problem:** ViewModels retained previous data in memory when starting new loads, causing brief flashes.

**Affected Files:**
- `FriendProfileViewModel.swift:36-39` - Clear all data immediately on load start
- `CheckInHistoryView.swift:149-151` - Clear checkIns array before loading
- `GroupChallengeViewModel.swift:42-48` - Clear all challenge state

**Fix:** All published properties are set to `nil` or empty at the start of each load, ensuring no stale state persists.

```swift
// Before: Old data persists during load
func loadData(id: String) {
    isLoading = true
    Task {
        data = try await fetch(id)  // ❌ Old data visible until this completes
    }
}

// After: Clear immediately
func loadData(id: String) {
    loadTask?.cancel()
    data = nil  // ✅ Clear stale immediately
    isLoading = true
    loadTask = Task { ... }
}
```

---

### 5. **Removed Implicit Animations**

**Problem:** Animations on data-bound views made stale → fresh transitions visible and jarring.

**Affected Files:**
- `ChallengeDetailView.swift:327` - Removed `.animation(.linear, value: progress)`

**Fix:** Removed automatic animations on progress values that change during navigation, preventing visual "morphing" from old to new data.

```swift
// Before: Animates from stale to fresh (visible flash)
Circle()
    .trim(from: 0, to: progress)
    .animation(.linear, value: progress)  // ❌ Animates stale → fresh

// After: No animation = instant correct state
Circle()
    .trim(from: 0, to: progress)  // ✅ Just shows current value
```

---

## Performance Impact

**Minimal.** Changes are surgical and follow SwiftUI best practices:

- **View identity:** Negligible - SwiftUI already tracks identity internally
- **Task cancellation:** Positive - prevents wasted network/CPU on obsolete requests
- **Data clearing:** Negligible - setting variables to nil is instant
- **Removed animations:** Positive - slightly less layout work

**No regressions expected** - all changes are defensive and prevent bugs rather than adding features.

---

## Testing Checklist

To verify fixes work correctly:

1. **Friend Profile Navigation:**
   - [ ] Tap different friends rapidly
   - [ ] Verify no previous friend's name/photo flashes
   - [ ] Verify loading spinner shows until data loads

2. **Challenge History:**
   - [ ] Navigate between different challenges' history
   - [ ] Verify no previous challenge's check-ins flash
   - [ ] Verify challenge title updates correctly

3. **Group Challenge Details:**
   - [ ] Open different group challenges
   - [ ] Verify no previous challenge's participants flash
   - [ ] Verify loading state shows until data ready

4. **Challenge Detail:**
   - [ ] Navigate between personal challenges
   - [ ] Verify progress bar doesn't animate from old value
   - [ ] Verify all stats show correct challenge

---

## Technical Notes

### Why `.id()` Works
SwiftUI uses view identity to determine if it can reuse an existing view instance or must create a new one. Without explicit identity, SwiftUI may decide two views with different parameters are "the same" and reuse the instance, causing stale content. `.id()` forces a new instance.

### Why Task Cancellation Matters
Swift Tasks continue running even after the view disappears. Without cancellation, a slow network request from a previous screen can complete and update `@Published` properties, causing UI updates on the wrong screen or flashes when returning.

### Why Nil Checks Matter
SwiftUI may render a frame with `isLoading = false` before data arrives if timing is unlucky. Checking `data == nil` ensures we show loading state until actual fresh data is present.

---

## Files Changed Summary

| File | Changes | Reason |
|------|---------|--------|
| FriendProfileView.swift | Added `.id(friendId)`, nil check | View identity + placeholder |
| FriendProfileViewModel.swift | Task cancellation, data clearing | Prevent stale async updates |
| CheckInHistoryView.swift | `.id()`, task cancellation, async/await | Identity + async safety |
| GroupChallengeDetailView.swift | Added `.id(challengeId)`, nil check | View identity + placeholder |
| GroupChallengeViewModel.swift | Task cancellation, data clearing | Prevent stale async updates |
| ChallengeDetailView.swift | Added `.id()`, removed animation | Identity + no stale transitions |
| RevenueCatSubscriptionRepository.swift | Fixed `productIdentifier` property | Unrelated build fix |

---

## Future Improvements

Consider these patterns for new navigation screens:

1. **Always use `.id()` when view inputs change** - Don't rely on SwiftUI to infer identity
2. **Store Task references in ViewModels** - Enable cancellation on new loads
3. **Clear data immediately on load start** - Don't wait for async to complete
4. **Check `data == nil` in loading conditions** - Show placeholder until fresh data
5. **Avoid animations on rapidly-changing data** - Prevents visual morphing

---

**Date:** 2025-10-26
**Author:** Claude Code
**Status:** ✅ Complete - All fixes applied, build verified
