Why: prepare preview patches to convert risky Firestore `runTransaction` usages to a safe pattern that avoids capturing actor-isolated state and prevents non-Sendable `Any?` from crossing actor boundaries.

What you'll see: for each file I found a `runTransaction` call executed from an actor context — the preview shows the current snippet and the proposed replacement using a detached `Task` that creates a local `Firestore.firestore()` instance and ensures the transaction closure is non-throwing (errors are marshaled into the provided `NSErrorPointer`).

Outcome: if you approve, I'll apply these patches so runTransaction closures stop causing Swift Concurrency "non-sendable" and actor-isolation compile errors.

---

File: `100DaysRebuild/Services/FirebaseService.swift`

Old (excerpt):

```swift
try await Task.detached {
    let fs = firestore
    _ = try await fs.runTransaction { transaction, errorPointer -> Any? in
        // ... transaction code ...
    }
}.value
```

Proposed replacement:

```swift
try await Task.detached {
    // Instantiate Firestore inside the detached task to avoid capturing actor state
    let fs = Firestore.firestore()

    _ = try await fs.runTransaction { (transaction, errorPointer) -> Any? in
        do {
            // ... transaction code unchanged ...
            return nil
        } catch {
            errorPointer?.pointee = error as NSError
            return nil
        }
    }
}.value
```

Notes: this replaces `let fs = firestore` (which captured the instance stored on the actor) with a local `Firestore.firestore()` call. The transaction body is wrapped with `do/catch` and uses `errorPointer?.pointee = (error as NSError)` so the closure remains non-throwing.

---

File: `100DaysRebuild/Services/GroupChallengeService.swift`

Old (excerpt):

```swift
try await Task.detached {
    let fs = self.firestore
    _ = try await fs.runTransaction { transaction, errorPointer -> Any? in
        // ... transaction code ...
    }
}.value
```

Proposed replacement:

```swift
try await Task.detached {
    let fs = Firestore.firestore()
    _ = try await fs.runTransaction { (transaction, errorPointer) -> Any? in
        do {
            // ... transaction code unchanged ...
            return nil
        } catch {
            errorPointer?.pointee = error as NSError
            return nil
        }
    }
}.value
```

Notes: same change: avoid capturing `self.firestore` and ensure the transaction closure sets the NSError pointer on errors.

---

File: `100DaysRebuild/Services/FriendService.swift`

Old (excerpt):

```swift
try await Task.detached {
    let fs = self.firestore
    _ = try await fs.runTransaction { transaction, errorPointer -> Any? in
        do {
            // ... transaction code ...
            return nil
        } catch {
            errorPointer?.pointee = error as NSError
            return nil
        }
    }
}.value
```

Proposed replacement:

```swift
try await Task.detached {
    let fs = Firestore.firestore()
    _ = try await fs.runTransaction { (transaction, errorPointer) -> Any? in
        do {
            // ... transaction code unchanged ...
            return nil
        } catch {
            errorPointer?.pointee = error as NSError
            return nil
        }
    }
}.value
```

Notes: same pattern applied to all Task-detached runTransaction invocations in this file.

---

File: `100DaysRebuild/CheckInService.swift`

Old (excerpt):

```swift
let fs = firestore

return try await Task.detached(priority: .userInitiated) {
    let result = try await fs.runTransaction { (transaction, errorPointer) -> Any? in
        do {
            // ... transaction work ...
            return true
        } catch {
            errorPointer?.pointee = error as NSError
            return false
        }
    }

    // ... interpret result ...
}.value
```

Proposed replacement:

```swift
return try await Task.detached(priority: .userInitiated) {
    let fs = Firestore.firestore()
    let result = try await fs.runTransaction { (transaction, errorPointer) -> Any? in
        do {
            // ... transaction work unchanged ...
            return true
        } catch {
            errorPointer?.pointee = error as NSError
            return false
        }
    }

    // ... interpret result ...
}.value
```

Notes: avoid capturing the `firestore` property from the `@MainActor` class; create a fresh `Firestore.firestore()` inside detached task.

---

File: `100DaysRebuild/Services/UserSession.swift`

Old (excerpt):

```swift
let firestoreInstance = firestore

try await Task.detached {
    _ = try await firestoreInstance.runTransaction { (transaction, errorPointer) -> Any? in
        // ... transaction code ...
        return nil
    }
}.value
```

Proposed replacement:

```swift
try await Task.detached {
    let fs = Firestore.firestore()
    _ = try await fs.runTransaction { (transaction, errorPointer) -> Any? in
        do {
            // ... transaction code unchanged ...
            return nil
        } catch {
            errorPointer?.pointee = error as NSError
            return nil
        }
    }
}.value
```

Notes: this prevents capturing `firestoreInstance` which may be actor-bound.

---

File: `100DaysRebuild/Features/Social/ViewModels/SocialViewModel.swift`

Old (excerpt):

```swift
let firestoreInstance = firestore

try await Task.detached {
    _ = try await firestoreInstance.runTransaction { (transaction, errorPointer) -> Any? in
        // ... transaction code ...
        return nil
    }
}.value
```

Proposed replacement:

```swift
try await Task.detached {
    let fs = Firestore.firestore()
    _ = try await fs.runTransaction { (transaction, errorPointer) -> Any? in
        do {
            // ... transaction code unchanged ...
            return nil
        } catch {
            errorPointer?.pointee = error as NSError
            return nil
        }
    }
}.value
```

---

How I generated these previews

- I inspected each file that contained `runTransaction` calls and prepared a minimal, safe transformation: instantiate Firestore inside the detached task and wrap the transaction body in do/catch setting the NSError pointer.
- I kept the transaction semantics identical; the only changes are the local Firestore instantiation and the explicit error marshaling to `errorPointer`.

Next steps

- Confirm you want me to apply these changes repository-wide. If you say "go", I'll apply the patches in a single batch and then run a second sweep to normalize any remaining `runTransaction` usages and timer/sendable issues.
- If you want a smaller sample first, tell me which files and I will apply only those.

If you'd like adjustments to the exact code style (for example, prefer `let fs = Firestore.firestore()` _and_ `let fsRef = fs` or prefer adding comments), say so and I'll update the previews before applying.
