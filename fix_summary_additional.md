# Additional Fixes for 100DaysRebuild App

## Issues Fixed

### 1. DirectAuthService.swift

- Fixed the error "Cannot convert value of type 'String' to expected argument type 'AuthProviderID'" by using `AuthProviderID.apple` instead of the string literal "apple.com".

### 2. ChallengesViewModel.swift

- Fixed the error "Passing argument of non-sendable type '[AnyHashable : Any]' outside of main actor-isolated context" by:
  - Creating a proper Sendable struct `UpdateData` to hold the challenge update information
  - Using Task.detached for both check-in data and update data operations
  - Converting the struct data to dictionary inside the detached task

### 3. AuthView.swift

- Fixed "Publishing changes from within view updates is not allowed" errors by:
  - Updating the onChange handlers to use Task { @MainActor in ... } to defer UI updates
  - Calling the centralized updateValidationState() method instead of directly modifying published properties
  - Using the new value directly in the change handler instead of accessing the viewModel property

These fixes address all the compiler warnings and runtime errors that were causing issues in the app.

## Benefits of the Fixes

1. Improved type safety by using proper enum types for AuthProviderID
2. Better concurrency safety through proper Sendable types and actor isolation
3. Avoided SwiftUI update cycles that could lead to undefined behavior or blank screens
4. More maintainable code with better separation of validation logic from view code
