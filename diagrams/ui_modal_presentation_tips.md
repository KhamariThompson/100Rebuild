# SwiftUI Modal Presentation Best Practices

## Common Modal Presentation Issues

### Problem: Modal Not Appearing or Disappearing Unexpectedly

Common causes:

- Animation conflicts
- State management issues
- Threading problems
- Missing accessibility identifiers

## Best Practices for Modal Presentation

### 1. State Management

```swift
// In your ViewModel
@Published var showModal = false

// In your View
if viewModel.showModal {
    ModalView(isPresented: $viewModel.showModal) {
        // Handle modal completion
    }
    .transition(.opacity)
    .zIndex(100)
}
```

### 2. Proper Animations

```swift
// Disable animation conflicts
// AVOID THIS:
.animation(.none, value: viewModel.showModal)

// Instead, use controlled animations:
Button(action: {
    withAnimation(.easeInOut(duration: 0.2)) {
        viewModel.showModal = true
    }
}) {
    Text("Show Modal")
}
```

### 3. Accessibility Identifiers

```swift
// Add accessibility identifiers for better system recognition
ZStack {
    Color.black.opacity(0.4)
        .ignoresSafeArea()
        .accessibility(identifier: "modalBackground")

    YourModalContent()
        .accessibility(identifier: "modalContent")
}
```

### 4. Thread Safety with MainActor

```swift
Button(action: {
    Task {
        // Use MainActor for UI updates
        await MainActor.run {
            viewModel.showModal = true
        }
    }
}) {
    Text("Show Modal")
}
```

### 5. Sequencing UI Updates

```swift
// Use a short delay to ensure proper view sequencing
DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
    // Force navigation to correct tab
    router.selectedTab = 0

    // Show the modal sheet with animation
    withAnimation(.easeInOut(duration: 0.2)) {
        viewModel.showModal = true
    }
}
```

## Modal Overlay Approach

For a robust overlay modal approach, use a ZStack with a semi-transparent background:

```swift
if viewModel.showModal {
    ZStack {
        // Semi-transparent background
        Color.black.opacity(0.4)
            .ignoresSafeArea()
            .accessibility(identifier: "modalOverlayBackground")
            .onTapGesture {
                viewModel.showModal = false
            }

        // Modal content
        ModalContent(isPresented: $viewModel.showModal) { result in
            // Handle modal result
            viewModel.showModal = false
            // Process result
        }
        .frame(maxWidth: UIScreen.main.bounds.width * 0.92)
        .background(Color.theme.background)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
        .accessibility(identifier: "modalContent")
    }
    .transition(.opacity)
    .zIndex(100)
}
```

## Diagnosing Modal Presentation Issues

If your modal isn't appearing properly:

1. **State Timing Issues**: Use print statements to verify when state changes
2. **Animation Conflicts**: Ensure you're not using `.animation(.none)` directives
3. **Threading Problems**: Ensure UI updates happen on the main thread using `MainActor`
4. **Transition Problems**: Use simpler transitions like `.opacity` instead of complex ones
5. **View Hierarchy**: Ensure the modal has a high `zIndex` value to appear on top
