import SwiftUI
import UIKit
import PhotosUI

// MARK: - UIApplication Extension to disable input assistants
extension UIApplication {
    // Disables the input assistant view that can cause layout constraint issues
    static func disableInputAssistant() {
        print("Disabling input assistant view to fix layout constraints")
        DispatchQueue.main.async {
            // Use the scenes API for iOS 15 and later
            if #available(iOS 15.0, *) {
                // Get all connected scenes
                for scene in UIApplication.shared.connectedScenes {
                    if let windowScene = scene as? UIWindowScene {
                        for window in windowScene.windows {
                            disableInputAssistantInView(window)
                        }
                    }
                }
            } else {
                // Fallback for older iOS versions
                // Warning: Using deprecated UIApplication.windows
                #if DEBUG
                print("Warning: Using deprecated UIApplication.windows API for iOS < 15")
                #endif
                
                for window in UIApplication.shared.windows {
                    disableInputAssistantInView(window)
                }
            }
        }
    }
    
    private static func disableInputAssistantInView(_ view: UIView) {
        // Check if current view is a SystemInputAssistant
        let viewClassName = NSStringFromClass(type(of: view))
        if viewClassName.contains("SystemInputAssistant") {
            print("Found SystemInputAssistantView, fixing constraints")
            
            // Instead of removing constraints, lower their priority
            for constraint in view.constraints {
                if constraint.identifier == "assistantHeight" || 
                   (constraint.firstAttribute == .height && constraint.firstItem === view) {
                    print("Lowering priority for constraint: \(constraint)")
                    constraint.priority = .defaultLow
                }
            }
            
            // Specifically fix the constraint conflict from error message
            for constraint in view.superview?.constraints ?? [] {
                if constraint.identifier == "assistantView.bottom" {
                    print("Found assistantView.bottom constraint, lowering priority")
                    constraint.priority = .defaultLow + 1
                }
            }
            
            // Look for _UIRemoteKeyboardPlaceholderView
            var current: UIView? = view
            while let parent = current?.superview {
                if NSStringFromClass(type(of: parent)).contains("UIRemoteKeyboardPlaceholderView") {
                    print("Found _UIRemoteKeyboardPlaceholderView, fixing constraints")
                    for constraint in parent.constraints {
                        if constraint.identifier == "accessoryView.bottom" {
                            print("Found accessoryView.bottom constraint, lowering priority")
                            constraint.priority = .defaultHigh - 1
                        }
                    }
                }
                current = parent
            }
            
            // Force layout update
            view.setNeedsLayout()
            view.layoutIfNeeded()
        }
        
        // Also check for _UIRemoteKeyboardPlaceholderView directly
        if viewClassName.contains("UIRemoteKeyboardPlaceholderView") {
            print("Found _UIRemoteKeyboardPlaceholderView directly, fixing constraints")
            for constraint in view.constraints {
                if constraint.identifier == "accessoryView.bottom" {
                    print("Found accessoryView.bottom constraint, lowering priority")
                    constraint.priority = .defaultHigh - 1
                }
            }
            view.setNeedsLayout()
            view.layoutIfNeeded()
        }
        
        // Recursively search and disable input assistants in subviews
        for subview in view.subviews {
            disableInputAssistantInView(subview)
        }
    }
    
    // New method to address the specific constraints mentioned in the error log
    static func fixConstraintConflict() {
        print("Fixing specific constraint conflict mentioned in error log")
        DispatchQueue.main.async {
            // Get all windows
            var windows: [UIWindow] = []
            if #available(iOS 15.0, *) {
                for scene in UIApplication.shared.connectedScenes {
                    if let windowScene = scene as? UIWindowScene {
                        windows.append(contentsOf: windowScene.windows)
                    }
                }
            } else {
                #if DEBUG
                print("Warning: Using deprecated UIApplication.windows API for iOS < 15")
                #endif
                windows = UIApplication.shared.windows
            }
            
            // Search for the specific views mentioned in the error
            for window in windows {
                findAndFixSpecificConstraintConflict(in: window)
            }
        }
    }
    
    private static func findAndFixSpecificConstraintConflict(in view: UIView) {
        let viewClassName = NSStringFromClass(type(of: view))
        
        // Fix SystemInputAssistantView
        if viewClassName.contains("SystemInputAssistantView") {
            for constraint in view.constraints where constraint.identifier == "assistantHeight" {
                constraint.priority = .defaultLow
                print("Fixed assistantHeight constraint in SystemInputAssistantView")
            }
            view.setNeedsLayout()
        }
        
        // Fix _UIRemoteKeyboardPlaceholderView
        if viewClassName.contains("UIRemoteKeyboardPlaceholderView") {
            for constraint in view.constraints where constraint.identifier == "accessoryView.bottom" {
                constraint.priority = .defaultHigh - 1
                print("Fixed accessoryView.bottom constraint in _UIRemoteKeyboardPlaceholderView")
            }
            view.setNeedsLayout()
        }
        
        // Fix _UIKBCompatInputView
        if viewClassName.contains("UIKBCompatInputView") {
            // Look for incoming constraints
            for subview in view.subviews {
                for constraint in subview.constraints {
                    if constraint.identifier == "assistantView.bottom" {
                        constraint.priority = .defaultHigh - 1
                        print("Fixed assistantView.bottom constraint in _UIKBCompatInputView subview")
                    }
                }
            }
            view.setNeedsLayout()
        }
        
        // Recursively search subviews
        for subview in view.subviews {
            findAndFixSpecificConstraintConflict(in: subview)
        }
    }
}

// MARK: - View Extensions
extension View {
    /// Apply a circular avatar style to an Image or other View
    func circularAvatarStyle(size: CGFloat, borderColor: Color = .theme.accent, borderWidth: CGFloat = 2) -> some View {
        return self
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(borderColor, lineWidth: borderWidth)
            )
    }
    
    /// Adds a checkmark success animation overlay in the corner of a view
    func successCheckmark(isShowing: Bool, size: CGFloat = 30, offset: CGPoint = CGPoint(x: 35, y: 35)) -> some View {
        ZStack {
            self
            
            if isShowing {
                Circle()
                    .fill(Color.green)
                    .frame(width: size, height: size)
                    .overlay(
                        Image(systemName: "checkmark")
                            .foregroundColor(.white)
                            .font(.system(size: size * 0.6, weight: .bold))
                    )
                    .offset(x: offset.x, y: offset.y)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3), value: isShowing)
    }
    
    /// Dismisses the keyboard when tapping outside of text input fields
    func dismissKeyboardOnTap() -> some View {
        return self.modifier(DismissKeyboardOnTap())
    }
    
    /// Smart keyboard dismissal that doesn't interfere with tab navigation
    func focusedDismissKeyboardOnTap() -> some View {
        return self.modifier(FocusedDismissKeyboardOnTap())
    }
    
    /// Improved keyboard handling for forms
    func adaptiveKeyboardHandler() -> some View {
        return self.modifier(AdaptiveKeyboardHandler())
    }
    
    /// Prevents layout constraints errors by disabling input assistant views
    func withSafeKeyboardHandling() -> some View {
        return self.modifier(SafeKeyboardHandlingModifier())
    }
    
    /// Applies safe text input settings to prevent RTIInputSystemClient errors
    func withSafeTextInput() -> some View {
        self
            .disableAutocorrection(true)
            .autocapitalization(.none)
            .modifier(SafeTextInputModifier())
    }
    
    /// Debounces navigation transitions to prevent keyboard snapshot warnings
    func withSafeNavigation() -> some View {
        self.modifier(NavigationDebounceModifier())
    }
    
    /// Adds a PhotosPicker that activates when this view is tapped
    func photoPickerTrigger(selection: Binding<PhotosPickerItem?>) -> some View {
        ZStack {
            self
            
            PhotosPicker(
                selection: selection,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Color.clear
                    .frame(width: 0, height: 0)
            }
            .opacity(0.001) // Nearly invisible but still functional
        }
    }
    
    /// Adds a menu for choosing between camera and photo library
    func photoSourcePicker(
        showSourceOptions: Binding<Bool>,
        showCameraPicker: Binding<Bool>, 
        photosPickerSelection: Binding<PhotosPickerItem?>
    ) -> some View {
        self
            .onTapGesture {
                showSourceOptions.wrappedValue = true
            }
            .confirmationDialog("Choose Photo Source", isPresented: showSourceOptions) {
                Button("Camera") {
                    showCameraPicker.wrappedValue = true
                }
                Button("Photo Library") {
                    // This will trigger the PhotosPicker
                }
                Button("Cancel", role: .cancel) {}
            }
            .photoPickerTrigger(selection: photosPickerSelection)
    }
}

// MARK: - Safe Keyboard Handling Modifier
struct SafeKeyboardHandlingModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear {
                // One-time fix for layout constraint issues at the view level
                UIApplication.disableInputAssistant()
                UIApplication.fixConstraintConflict()
                
                // Modify keyboard handling to prevent interference with TabView
                let notificationCenter = NotificationCenter.default
                
                // Only observe keyboard notifications
                notificationCenter.addObserver(
                    forName: UIResponder.keyboardWillShowNotification,
                    object: nil,
                    queue: .main
                ) { _ in
                    // Fix constraints when keyboard appears
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        UIApplication.disableInputAssistant()
                        UIApplication.fixConstraintConflict()
                    }
                }
                
                // Fix constraints when keyboard disappears
                notificationCenter.addObserver(
                    forName: UIResponder.keyboardWillHideNotification,
                    object: nil,
                    queue: .main
                ) { _ in
                    // Reset any constraint fixes after keyboard is gone
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        UIApplication.fixConstraintConflict() 
                    }
                }
            }
    }
}

// MARK: - Dismiss Keyboard Modifier
struct DismissKeyboardOnTap: ViewModifier {
    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
    }
}

// MARK: - Focused Dismiss Keyboard Modifier
// This version doesn't interfere with tab view navigation
struct FocusedDismissKeyboardOnTap: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            // The main content
            content
            
            // Invisible overlay just for keyboard dismissal that ignores all tab bar regions
            GeometryReader { geometry in
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // Only dismiss if a text field is currently active
                        let keyWindow = UIApplication.shared.connectedScenes
                            .filter { $0.activationState == .foregroundActive }
                            .compactMap { $0 as? UIWindowScene }
                            .first?.windows
                            .filter { $0.isKeyWindow }.first
                        
                        if let currentResponder = keyWindow?.findFirstResponderInView(), 
                           (currentResponder is UITextField || currentResponder is UITextView) {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), 
                                                          to: nil, from: nil, for: nil)
                        }
                    }
                    // Important: exclude the tab bar region (typically bottom 49 points)
                    .frame(height: geometry.size.height - 49)
                    .allowsHitTesting(keyboardIsPresent())
            }
        }
    }
    
    // Helper to check if keyboard is visible
    private func keyboardIsPresent() -> Bool {
        let keyWindow = UIApplication.shared.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .compactMap { $0 as? UIWindowScene }
            .first?.windows
            .filter { $0.isKeyWindow }.first
        
        return keyWindow?.findFirstResponderInView() is UITextField || keyWindow?.findFirstResponderInView() is UITextView
    }
}

// Helper extension to find first responder
@objc extension UIView {
    @objc func findFirstResponderInView() -> UIView? {
        guard !isFirstResponder else { return self }
        
        for subview in subviews {
            if let firstResponder = subview.findFirstResponderInView() {
                return firstResponder
            }
        }
        
        return nil
    }
}

// Extension for UIWindow to find first responder
extension UIWindow {
    override func findFirstResponderInView() -> UIView? {
        return rootViewController?.view.findFirstResponderInView()
    }
}

// MARK: - Adaptive Keyboard Handler
struct AdaptiveKeyboardHandler: ViewModifier {
    @State private var keyboardHeight: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .padding(.bottom, keyboardHeight > 0 ? keyboardHeight : 20)
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .onAppear {
                setupKeyboardNotifications()
            }
            .onDisappear {
                removeKeyboardNotifications()
            }
            .gesture(
                DragGesture().onChanged { _ in
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            )
            .contentShape(Rectangle())
    }
    
    private func setupKeyboardNotifications() {
        // Remove any existing observers first to prevent duplicates
        removeKeyboardNotifications()
        
        // Delay to ensure proper timing for keyboard notifications
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.addObserver(
                forName: UIResponder.keyboardWillShowNotification,
                object: nil,
                queue: .main
            ) { notification in
                if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                    // Add a small buffer to avoid constraint conflicts
                    self.keyboardHeight = keyboardFrame.height + 10
                }
            }
            
            NotificationCenter.default.addObserver(
                forName: UIResponder.keyboardWillHideNotification,
                object: nil,
                queue: .main
            ) { _ in
                self.keyboardHeight = 0
            }
        }
    }
    
    private func removeKeyboardNotifications() {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
}

// Modifier to ensure text inputs have safe options
struct SafeTextInputModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onChange(of: UIResponder.currentFirstResponder()) { _, newValue in
                if let textField = newValue as? UITextField {
                    // Disable predictive options to prevent RTIInputSystemClient errors
                    textField.autocorrectionType = .no
                    textField.spellCheckingType = .no
                    textField.smartQuotesType = .no
                    textField.smartDashesType = .no
                    textField.smartInsertDeleteType = .no
                    
                    // Disable input assistant
                    textField.inputAssistantItem.leadingBarButtonGroups = []
                    textField.inputAssistantItem.trailingBarButtonGroups = []
                }
                
                if let textView = newValue as? UITextView {
                    // Disable predictive options to prevent RTIInputSystemClient errors
                    textView.autocorrectionType = .no
                    textView.spellCheckingType = .no
                    textView.smartQuotesType = .no
                    textView.smartDashesType = .no
                    textView.smartInsertDeleteType = .no
                    
                    // Disable input assistant
                    textView.inputAssistantItem.leadingBarButtonGroups = []
                    textView.inputAssistantItem.trailingBarButtonGroups = []
                }
            }
    }
}

// Helper extension to get current first responder
extension UIResponder {
    private static weak var _currentFirstResponder: UIResponder?
    
    static func currentFirstResponder() -> UIResponder? {
        _currentFirstResponder = nil
        UIApplication.shared.sendAction(#selector(UIResponder.findFirstResponder(_:)), to: nil, from: nil, for: nil)
        return _currentFirstResponder
    }
    
    @objc private func findFirstResponder(_ sender: Any?) {
        UIResponder._currentFirstResponder = self
    }
}

/// Modifier to debounce navigation transitions and prevent UIKeyboardImpl snapshotting warnings
struct NavigationDebounceModifier: ViewModifier {
    @State private var isTransitioning = false
    @State private var debounceTimer: Timer? = nil
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                // Listen for keyboard notifications
                let notificationCenter = NotificationCenter.default
                notificationCenter.addObserver(
                    forName: UIResponder.keyboardWillShowNotification,
                    object: nil,
                    queue: .main
                ) { _ in
                    self.isTransitioning = true
                    
                    // Reset after a delay
                    self.debounceTimer?.invalidate()
                    self.debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
                        self.isTransitioning = false
                    }
                }
                
                notificationCenter.addObserver(
                    forName: UIResponder.keyboardWillHideNotification,
                    object: nil,
                    queue: .main
                ) { _ in
                    self.isTransitioning = true
                    
                    // Reset after a delay
                    self.debounceTimer?.invalidate()
                    self.debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
                        self.isTransitioning = false
                    }
                }
            }
            .onDisappear {
                // Clean up timer when view disappears
                self.debounceTimer?.invalidate()
                self.debounceTimer = nil
            }
            .transaction { transaction in
                // If keyboard is transitioning, disable animation to prevent snapshot issues
                if isTransitioning {
                    transaction.animation = nil
                    transaction.disablesAnimations = true
                }
            }
    }
}

// MARK: - Button Styles

/// Simple scale effect button style for interactive feedback
public struct ScaleButtonStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// Extension to make it accessible via .buttonStyle(.scale)
public extension ButtonStyle where Self == ScaleButtonStyle {
    static var scale: ScaleButtonStyle { ScaleButtonStyle() }
} 
