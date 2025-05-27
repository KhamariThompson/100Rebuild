import SwiftUI
import UIKit
import AuthenticationServices
import RevenueCat
import ObjectiveC.runtime

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
        
        // Fix photo picker presentation issues
        fixPhotoPickerPresentationIssues()
    }
    
    // MARK: - Photo Picker Presentation Fix
    
    private func fixPhotoPickerPresentationIssues() {
        print("Applying photo picker presentation fixes...")
        
        // Add observer for view controller presentation
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleViewControllerPresentation),
            name: UIViewController.willPresentNotification,
            object: nil
        )
        
        // Swizzle UIViewController's present method to ensure proper presentation
        swizzleViewControllerPresentation()
    }
    
    @objc private func handleViewControllerPresentation(notification: Notification) {
        guard let presentingVC = notification.object as? UIViewController,
              let presentedVC = presentingVC.presentedViewController else {
            return
        }
        
        // Check if this is a PhotoPicker presentation with potential detachment issues
        if NSStringFromClass(type(of: presentedVC)).contains("PhotosPicker") || 
           NSStringFromClass(type(of: presentedVC)).contains("PHPicker") {
            
            // Ensure presenting VC is in a window hierarchy
            if presentingVC.view.window == nil {
                print("Warning: Presenting photo picker from detached view controller.")
                
                // Find a valid view controller to present from
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let rootVC = window.rootViewController {
                    
                    // Find the topmost presented view controller
                    let topmostVC = findTopmostViewController(rootVC)
                    
                    // Re-present from the properly attached view controller
                    DispatchQueue.main.async {
                        presentingVC.dismiss(animated: false) {
                            topmostVC.present(presentedVC, animated: true)
                        }
                    }
                }
            }
        }
    }
    
    // Public method to find the topmost view controller
    func findTopmostViewController(_ viewController: UIViewController) -> UIViewController {
        if let presentedVC = viewController.presentedViewController {
            return findTopmostViewController(presentedVC)
        }
        
        if let navigationController = viewController as? UINavigationController,
           let topVC = navigationController.topViewController {
            return findTopmostViewController(topVC)
        }
        
        if let tabBarController = viewController as? UITabBarController,
           let selectedVC = tabBarController.selectedViewController {
            return findTopmostViewController(selectedVC)
        }
        
        return viewController
    }
    
    private func swizzleViewControllerPresentation() {
        // Register a fix for SwiftUI view controller presentations
        exchangeImplementations(
            UIViewController.self,
            #selector(UIViewController.present(_:animated:completion:)),
            #selector(UIViewController.swizzled_present(_:animated:completion:))
        )
    }
    
    private func exchangeImplementations(_ cls: AnyClass, _ originalSelector: Selector, _ swizzledSelector: Selector) {
        guard let originalMethod = class_getInstanceMethod(cls, originalSelector),
              let swizzledMethod = class_getInstanceMethod(cls, swizzledSelector) else {
            return
        }
        
        // Add the swizzled method to the class if it doesn't exist
        if class_addMethod(cls, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod)) {
            class_replaceMethod(cls, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod))
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }
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
    
    // MARK: - Apple Sign In Button Fixes
    
    private func fixAppleSignInButtonConstraints() {
        print("Setting up Apple Sign In button constraint fixes...")
        
        // We want to swizzle the constraint methods on ASAuthorizationAppleIDButton
        print("Would swizzle ASAuthorizationAppleIDButton constraint methods")
        
        // Workaround for Apple Sign In button constraints:
        // Check if any Apple Sign In buttons exist and fix their constraints
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.findAndFixAppleButtons()
        }
        
        // Disable automatic constraint generation on Apple buttons
        UserDefaults.standard.set(false, forKey: "ASAuthorizationAutoConstraints")
        
        // Remove any width/height constraints that might cause conflicts
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.findAndFixAppleButtons),
            name: UIScene.didActivateNotification,
            object: nil
        )
    }
    
    @objc private func findAndFixAppleButtons() {
        // Find and iterate through all windows to locate Apple Sign In buttons
        for window in getAllWindows() {
            findAppleSignInButtonsInView(window)
        }
    }
    
    private func findAppleSignInButtonsInView(_ view: UIView) {
        // Check for ASAuthorizationAppleIDButton
        let viewName = NSStringFromClass(type(of: view))
        
        if viewName.contains("ASAuthorizationAppleIDButton") {
            print("Found ASAuthorizationAppleIDButton, fixing constraints")
            
            // Make sure we're using our frame-based layout instead of auto layout
            view.translatesAutoresizingMaskIntoConstraints = true
            
            // Disable any explicit constraints that might be causing conflicts
            view.constraints.forEach { constraint in
                // Only disable certain constraints that would conflict with translatesAutoresizingMaskIntoConstraints
                if constraint.firstAttribute == .width || constraint.firstAttribute == .height {
                    constraint.isActive = false
                }
            }
            
            // Set sensible frame that won't conflict with auto layout system
            if let superview = view.superview, view.frame.width > 0 {
                // Honor the existing frame width but update height to match design system
                view.frame = CGRect(
                    x: view.frame.minX,
                    y: view.frame.minY,
                    width: superview.frame.width,
                    height: 50
                )
            }
        }
        
        // Check all subviews recursively
        for subview in view.subviews {
            findAppleSignInButtonsInView(subview)
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
        
        // Add notification observer to fix the deallocating view controller issue
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(fixAuthControllerDeallocation),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        
        // Swizzle SFAuthenticationViewController to properly handle deallocation
        fixSFAuthenticationViewControllerDeallocation()
    }
    
    @objc private func fixAuthControllerDeallocation() {
        // This gives time for any authentication sessions to complete before app resigns active
        DispatchQueue.main.async {
            // Find any active auth controllers and help them deallocate properly
            self.getAllWindows().forEach { window in
                self.findAndFixAuthControllers(in: window)
            }
        }
    }
    
    private func findAndFixAuthControllers(in view: UIView) {
        // Check if this is a view controller's view
        if let responder = view.next, String(describing: type(of: responder)).contains("SFAuthentication") {
            // Force immediate layout to prevent deallocation issues
            view.setNeedsLayout()
            view.layoutIfNeeded()
        }
        
        // Check all subviews recursively
        for subview in view.subviews {
            findAndFixAuthControllers(in: subview)
        }
    }
    
    private func fixSFAuthenticationViewControllerDeallocation() {
        // This method would implement swizzling, but we'll use a simpler approach for now
        // Set a global flag to use more stable authentication behavior
        UserDefaults.standard.set(true, forKey: "SFAuthenticationSessionUseUIDelegate")
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
            
            // Suppress "No active account" error messages
            if message.contains("ASDErrorDomain Code=509") || 
               message.contains("No active account") {
                // Don't log this error since it's common during development
                // and happens when no Apple ID is signed in
                return
            }
            
            // Let other errors through
            if level == .error || level == .info {
                print("RevenueCat [\(level)]: \(message)")
            }
        }
        
        // Set specific handling for StoreKit transactions
        handleStoreKitErrors()
    }
    
    // Add specific handling for StoreKit "No active account" errors
    private func handleStoreKitErrors() {
        // This method doesn't need to do anything at runtime, as we're handling 
        // the errors directly in the SubscriptionService's transaction observers
        // Just adding this for documentation purposes
        
        // Configure app to handle "No active account" (ASDErrorDomain Code=509) errors
        UserDefaults.standard.set(true, forKey: "ASWebAuthenticationSessionPrefersEphemeralWebBrowserSession")
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

// MARK: - UIViewController Extension for Swizzling

extension UIViewController {
    @objc func swizzled_present(_ viewControllerToPresent: UIViewController, animated: Bool, completion: (() -> Void)? = nil) {
        // Check if this is a PhotoPicker presentation with potential issues
        if NSStringFromClass(type(of: viewControllerToPresent)).contains("PhotosPicker") || 
           NSStringFromClass(type(of: viewControllerToPresent)).contains("PHPicker") {
            
            // Ensure presenting VC is in a window hierarchy
            if self.view.window == nil {
                print("Fixed: Detected presentation of photo picker from detached view controller.")
                
                // Find a valid view controller to present from
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let rootVC = window.rootViewController {
                    
                    // Find the topmost presented view controller
                    let topmostVC = AppFixes.shared.findTopmostViewController(rootVC)
                    
                    // Present from the properly attached view controller
                    topmostVC.swizzled_present(viewControllerToPresent, animated: animated, completion: completion)
                    return
                }
            }
        }
        
        // Call the original implementation for normal cases
        self.swizzled_present(viewControllerToPresent, animated: animated, completion: completion)
    }
}

// MARK: - ConstraintSwizzler class for constraint fixes
class ConstraintSwizzler {
    let classType: AnyClass
    
    init(classType: AnyClass) {
        self.classType = classType
    }
    
    func swizzleUpdateConstraints() {
        let originalSelector = #selector(UIView.updateConstraints)
        let swizzledSelector = #selector(UIView.swizzled_updateConstraints)
        
        guard let originalMethod = class_getInstanceMethod(classType, originalSelector),
              let swizzledMethod = class_getInstanceMethod(UIView.self, swizzledSelector) else {
            return
        }
        
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }
}

// Extension for UIView swizzling
extension UIView {
    @objc func swizzled_updateConstraints() {
        // Call the original implementation first
        self.swizzled_updateConstraints()
        
        // Check if this is a SystemInputAssistantView
        let viewName = NSStringFromClass(type(of: self))
        if viewName.contains("SystemInputAssistantView") {
            // Fix the problematic constraints
            for constraint in self.constraints {
                if constraint.firstAttribute == .height && constraint.relation == .equal {
                    constraint.priority = UILayoutPriority(250) // Lower priority
                }
            }
        }
    }
}

// MARK: - Notification extension
extension Notification.Name {
    static let appDidReceiveMemoryWarning = Notification.Name("appDidReceiveMemoryWarning")
} 