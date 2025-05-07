import SwiftUI
import UIKit

// MARK: - UIApplication Extension to disable input assistants
extension UIApplication {
    // Disables the input assistant view that can cause layout constraint issues
    static func disableInputAssistant() {
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
            // Instead of hiding or removing, disable its fixed height constraint
            for constraint in view.constraints {
                if constraint.identifier == "assistantHeight" {
                    constraint.isActive = false
                    #if DEBUG
                    print("Disabled SystemInputAssistantView height constraint")
                    #endif
                    // Add a flexible height constraint instead
                    let flexibleHeight = NSLayoutConstraint(
                        item: view,
                        attribute: .height,
                        relatedBy: .greaterThanOrEqual,
                        toItem: nil,
                        attribute: .notAnAttribute,
                        multiplier: 1.0,
                        constant: 20.0
                    )
                    flexibleHeight.identifier = "flexibleAssistantHeight"
                    flexibleHeight.priority = .defaultHigh
                    view.addConstraint(flexibleHeight)
                    break
                }
            }
        }
        
        // Recursively search and disable input assistants in subviews
        for subview in view.subviews {
            disableInputAssistantInView(subview)
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
    
    /// Improved keyboard handling for forms
    func adaptiveKeyboardHandler() -> some View {
        return self.modifier(AdaptiveKeyboardHandler())
    }
    
    /// Prevents layout constraints errors by disabling input assistant views
    func withSafeKeyboardHandling() -> some View {
        return self.modifier(SafeKeyboardHandlingModifier())
    }
}

// MARK: - Safe Keyboard Handling Modifier
struct SafeKeyboardHandlingModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear {
                UIApplication.disableInputAssistant()
                
                // Apply additional fixes for keyboard handling
                let notificationCenter = NotificationCenter.default
                notificationCenter.addObserver(
                    forName: UIWindow.didBecomeKeyNotification,
                    object: nil,
                    queue: .main
                ) { _ in
                    // Re-disable input assistant when window becomes key
                    UIApplication.disableInputAssistant()
                }
                
                // Fix text input focus issues that can cause layout problems
                notificationCenter.addObserver(
                    forName: UITextField.textDidBeginEditingNotification,
                    object: nil,
                    queue: .main
                ) { _ in
                    UIApplication.disableInputAssistant()
                }
                
                notificationCenter.addObserver(
                    forName: UITextView.textDidBeginEditingNotification,
                    object: nil,
                    queue: .main
                ) { _ in
                    UIApplication.disableInputAssistant()
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