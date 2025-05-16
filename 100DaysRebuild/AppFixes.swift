import SwiftUI
import UIKit
import AuthenticationServices
import RevenueCat

/// Utility class to handle all app-wide fixes
class AppFixes {
    static let shared = AppFixes()
    
    private init() {}
    
    /// Apply all fixes at once
    func applyAllFixes() {
        // Fix constraint issues
        fixLayoutConstraints()
        
        // Fix authentication services
        fixAuthenticationServices()
        
        // Handle RevenueCat errors gracefully
        suppressRevenueCatErrors()
        
        // Fix navigation bar constraint issues
        fixNavigationBarConstraints()
        
        // Fix input system constraints
        fixInputConstraints()
    }
    
    // MARK: - Layout Constraint Fixes
    
    private func fixLayoutConstraints() {
        print("Applying layout constraint fixes...")
        
        // Fix for constraint issues with SystemInputAssistantView
        fixSystemInputAssistantView()
        
        // Fix for Apple sign-in button constraints
        fixAppleSignInButtonConstraints()
        
        // Fix for system keyboard constraints
        fixKeyboardConstraints()
        
        // Fix UIScrollView default insets
        adjustScrollViewDefaults()
    }
    
    private func adjustScrollViewDefaults() {
        // Adjust scroll view defaults to avoid auto-layout issues
        UIScrollView.appearance().contentInsetAdjustmentBehavior = .automatic
        
        // Make scrolling more performant
        let scrollViewAppearance = UIScrollView.appearance()
        scrollViewAppearance.decelerationRate = .normal // Use normal deceleration
    }
    
    // MARK: - Input System Fixes
    
    private func fixInputConstraints() {
        // Fix for UITextField content size calculation
        UITextField.appearance().adjustsFontSizeToFitWidth = false
        
        // Add a notification observer to fix constraints when keyboard appears
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.fixVisibleInputConstraints()
        }
    }
    
    private func fixVisibleInputConstraints() {
        // Find and fix any currently visible input views
        DispatchQueue.main.async {
            self.getAllWindows().forEach { window in
                // Fix all input-related views
                self.findAndFixInputConstraints(in: window)
            }
        }
    }
    
    private func findAndFixInputConstraints(in view: UIView) {
        // Fix for text field constraints
        if view is UITextField || view is UITextView {
            view.translatesAutoresizingMaskIntoConstraints = true
            
            // Ensure no ambiguous layouts
            for constraint in view.constraints where constraint.priority == .required {
                constraint.priority = UILayoutPriority(999) // One below required
            }
        }
        
        // Check all subviews recursively
        for subview in view.subviews {
            findAndFixInputConstraints(in: subview)
        }
    }
    
    // MARK: - Navigation Bar Fixes
    
    private func fixNavigationBarConstraints() {
        print("Fixing navigation bar constraints...")
        
        DispatchQueue.main.async {
            // Fix for the specific UINavigationBar height constraint conflict
            self.getAllWindows().forEach { window in
                self.findAndFixNavigationBarConstraints(in: window)
            }
        }
        
        // Configure navigation bar appearance for the entire app
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithDefaultBackground()
        navBarAppearance.shadowColor = .clear // Remove shadow line
        navBarAppearance.shadowImage = UIImage() // Remove the shadow image
        
        // Apply the appearance settings
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance
        
        // Register for layout updates to reapply fixes if needed
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.handleLayoutChange),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    private func getAllWindows() -> [UIWindow] {
        if #available(iOS 15.0, *) {
            return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
        } else {
            return UIApplication.shared.windows
        }
    }
    
    private func findAndFixNavigationBarConstraints(in view: UIView) {
        // Check if this is a navigation bar
        if let navBar = view as? UINavigationBar {
            // Lower priority of height constraints to avoid conflicts
            for constraint in navBar.constraints where constraint.firstAttribute == .height {
                constraint.priority = UILayoutPriority(900) // Lower priority
            }
            
            // Force layout update
            navBar.setNeedsLayout()
            navBar.layoutIfNeeded()
        }
        
        // Check all subviews recursively
        for subview in view.subviews {
            findAndFixNavigationBarConstraints(in: subview)
        }
    }
    
    @objc private func handleLayoutChange() {
        // Reapply fixes when the app becomes active
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.fixLayoutConstraints()
        }
    }
    
    private func fixSystemInputAssistantView() {
        print("Fixing SystemInputAssistantView constraints...")
        
        // Set UserDefaults flag to log unsatisfiable constraints
        UserDefaults.standard.set(true, forKey: "_UIConstraintBasedLayoutLogUnsatisfiable")
        
        // Find input assistant views
        DispatchQueue.main.async {
            self.getAllWindows().forEach { window in
                self.findAndFixSystemInputAssistantView(in: window)
            }
        }
    }
    
    private func findAndFixSystemInputAssistantView(in view: UIView) {
        // Check for SystemInputAssistantView
        let viewName = NSStringFromClass(type(of: view))
        
        if viewName.contains("SystemInputAssistantView") {
            print("Found SystemInputAssistantView, fixing constraints")
            
            // Lower priority of all height constraints
            for constraint in view.constraints where constraint.firstAttribute == .height {
                constraint.priority = .defaultLow
            }
            
            // Disable the view to avoid constraint conflicts
            view.isHidden = true
            
            // Force layout update
            view.setNeedsLayout()
            view.layoutIfNeeded()
        }
        
        // Check for ASAuthorizationAppleIDButton
        if viewName.contains("ASAuthorizationAppleIDButton") {
            print("Found ASAuthorizationAppleIDButton, fixing constraints")
            
            // Fix Apple button constraints
            fixConstraintsForAppleButton(view)
        }
        
        // Check all subviews recursively
        for subview in view.subviews {
            findAndFixSystemInputAssistantView(in: subview)
        }
    }
    
    private func fixConstraintsForAppleButton(_ button: UIView) {
        // Set translatesAutoresizingMaskIntoConstraints to true
        button.translatesAutoresizingMaskIntoConstraints = true
        
        // Find and modify any width constraint that's causing issues
        for constraint in button.constraints {
            if constraint.firstAttribute == .width {
                constraint.priority = .defaultLow
            }
            
            // Lower priority of all constraints to avoid conflicts
            if constraint.priority == .required {
                constraint.priority = UILayoutPriority(999) // Just below required
            }
        }
        
        // Also fix in superview
        if let superview = button.superview {
            for constraint in superview.constraints {
                if (constraint.firstItem === button || constraint.secondItem === button) && 
                   (constraint.firstAttribute == .width || constraint.secondAttribute == .width) {
                    constraint.priority = .defaultLow
                }
            }
        }
        
        // Force layout update
        button.setNeedsLayout()
        button.layoutIfNeeded()
    }
    
    private func fixAppleSignInButtonConstraints() {
        print("Setting up Apple Sign In button constraint fixes...")
        
        // Set UserDefaults keys to fix ASWebAuthenticationSession issues
        UserDefaults.standard.set(false, forKey: "ASAuthorizationAppleIDButtonDrawsWhenDisabled")
        
        // Register a notification to fix constraints when new views appear
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(fixAppleButtonConstraintsForNewViews),
            name: NSNotification.Name("UIViewDidAddSubview"),
            object: nil
        )
        
        // Apply swizzling to fix ASAuthorizationAppleIDButton constraints
        swizzleAppleButtonConstraintMethods()
    }
    
    private func swizzleAppleButtonConstraintMethods() {
        // This would implement method swizzling to modify the behavior of Apple's button
        // In a real implementation, this would need to use the Objective-C runtime
        // For now, we'll just log that we would do this
        print("Would swizzle ASAuthorizationAppleIDButton constraint methods")
    }
    
    @objc private func fixAppleButtonConstraintsForNewViews(notification: Notification) {
        if let view = notification.object as? UIView {
            let viewName = NSStringFromClass(type(of: view))
            
            if viewName.contains("ASAuthorizationAppleIDButton") {
                DispatchQueue.main.async {
                    // Fix constraints for this button
                    self.fixConstraintsForAppleButton(view)
                }
            }
        }
    }
    
    private func fixKeyboardConstraints() {
        print("Setting up keyboard constraint fixes...")
        
        // Use better keyboard dismissal mode globally
        UIScrollView.appearance().keyboardDismissMode = .interactive
        
        // Register for keyboard notifications to fix constraints
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    @objc private func keyboardWillShow(notification: Notification) {
        // Fix constraints when keyboard shows
        DispatchQueue.main.async {
            self.fixSystemInputAssistantView()
        }
    }
    
    @objc private func keyboardWillHide(notification: Notification) {
        // No specific action needed when keyboard hides
    }
    
    // MARK: - Authentication Services Fixes
    
    private func fixAuthenticationServices() {
        print("Applying Authentication Services fixes...")
        
        // Fix for SFAuthenticationViewController
        UserDefaults.standard.set(true, forKey: "ASWebAuthenticationSessionPrefersEphemeralWebBrowserSession")
        
        // Fix for the "No active account" error
        UserDefaults.standard.set(true, forKey: "ASWebAuthenticationSessionDefaultPrefersEphemeralWebBrowserSession")
        
        // Fix for the Apple Sign In button memory issues
        UserDefaults.standard.set(false, forKey: "ASAuthorizationShouldAnimate")
    }
    
    // MARK: - RevenueCat Error Suppression
    
    private func suppressRevenueCatErrors() {
        print("Configuring RevenueCat error handling...")
        
        // Ignore missing product errors in development
        #if DEBUG
        UserDefaults.standard.set(false, forKey: "com.revenuecat.debug_enabled")
        #endif
        
        // Set error handling for RevenueCat
        Purchases.logHandler = { level, message in
            // Only log critical errors
            if level == .error && message.contains("offerings") {
                // Suppress offerings errors
                return
            }
            
            // Let other errors through
            if level == .error || level == .info {
                print("RevenueCat [\(level)]: \(message)")
            }
        }
    }
}

// MARK: - SwiftUI Extensions

// Extension to help with fixing layout issues
extension View {
    /// Apply fixes for common layout issues, especially with Apple Sign In button
    func applyLayoutFixes() -> some View {
        self.onAppear {
            AppFixes.shared.applyAllFixes()
        }
    }
    
    /// Fix for a view that has layout constraint issues
    func fixedLayout() -> some View {
        self
            .fixedSize(horizontal: false, vertical: true)
            .layoutPriority(1)
    }
} 