import SwiftUI
import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import UIKit
import AuthenticationServices
import Network
import FirebaseFirestore

class AppDelegate: NSObject, UIApplicationDelegate {
    private var networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "NetworkMonitor")
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Configure Firebase at the very beginning, before any other Firebase-related code
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
            print("Firebase configured successfully at app launch")
            
            // Configure Firestore for offline persistence
            let db = Firestore.firestore()
            let settings = db.settings
            settings.cacheSettings = PersistentCacheSettings(sizeBytes: NSNumber(value: FirestoreCacheSizeUnlimited))
            db.settings = settings
            print("Firestore offline persistence configured")
        } else {
            print("Firebase was already configured")
        }
        
        // Fix for navigation layout constraints
        setupNavigationBarAppearance()
        
        // Fix layout constraint issues specifically
        fixLayoutConstraintIssues()
        
        // Set up network connectivity monitoring after Firebase is configured
        startNetworkMonitoring()
        
        return true
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let sceneConfig = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        sceneConfig.delegateClass = SceneDelegate.self
        return sceneConfig
    }
    
    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { path in
            let isConnected = path.status == .satisfied
            print("Network connectivity changed: \(isConnected ? "Connected" : "Disconnected")")
            
            // Notify Firebase service about network status change
            if isConnected {
                // Post notification to let app components know network is back
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("NetworkStatusChanged"),
                        object: nil,
                        userInfo: ["isConnected": true]
                    )
                }
            }
        }
        
        networkMonitor.start(queue: networkQueue)
    }
    
    deinit {
        networkMonitor.cancel()
    }
    
    private func setupNavigationBarAppearance() {
        // Fix for layout constraints in NavigationViews
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        
        // Fix for SystemInputAssistantView constraint conflicts by using a more compatible approach
        if let assistantViewClass = NSClassFromString("SystemInputAssistantView") as? UIView.Type {
            fixAssistantViewConstraints(assistantViewClass: assistantViewClass)
        }
        
        // Use a better keyboard dismissal mechanism that doesn't interfere with text entry
        setupKeyboardDismissal()
        
        // Set up to handle keyboard properly
        setupKeyboardHandling()
        
        // Fix for SFAuthenticationViewController constraint issues
        if #available(iOS 15.0, *) {
            UserDefaults.standard.set(true, forKey: "ASWebAuthenticationSessionPrefersEphemeralWebBrowserSession")
        }
    }
    
    private func fixAssistantViewConstraints(assistantViewClass: UIView.Type) {
        // Set up SwizzleKit to monitor and fix constraints at runtime safely
        // This approach avoids directly manipulating constraints which can be risky
        
        // This method will be called when any window becomes key
        NotificationCenter.default.addObserver(
            forName: UIWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            
            // Delay the fix to ensure the window hierarchy is fully set up
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.findAndFixAssistantViewInWindows(assistantViewClass: assistantViewClass)
            }
        }
    }
    
    private func findAndFixAssistantViewInWindows(assistantViewClass: UIView.Type) {
        // Use UIApplication.windows for iOS < 15 or UIWindowScene.windows for iOS 15+
        if #available(iOS 15.0, *) {
            for scene in UIApplication.shared.connectedScenes {
                if let windowScene = scene as? UIWindowScene {
                    for window in windowScene.windows {
                        findAndFixAssistantView(in: window, assistantViewClass: assistantViewClass)
                    }
                }
            }
        } else {
            // For iOS < 15, use the deprecated API with warning suppressed
            #if DEBUG
            print("Warning: Using deprecated UIApplication.windows API for iOS < 15")
            #endif
            
            // swiftlint:disable:next deprecated
            for window in UIApplication.shared.windows {
                findAndFixAssistantView(in: window, assistantViewClass: assistantViewClass)
            }
        }
    }
    
    private func findAndFixAssistantView(in window: UIWindow, assistantViewClass: UIView.Type) {
        // Find the assistant view and modify its constraints
        for view in window.subviews {
            if type(of: view) == assistantViewClass {
                // Instead of removing the constraint, make it a lower priority
                for constraint in view.constraints {
                    if constraint.identifier == "assistantHeight" {
                        constraint.priority = .defaultLow  // Lower priority instead of disabling
                        break
                    }
                }
                
                // Ensure the view updates its layout
                view.setNeedsLayout()
                view.layoutIfNeeded()
            }
            
            // Recursively search subviews
            for subview in view.subviews {
                findAndFixAssistantView(in: subview, assistantViewClass: assistantViewClass)
            }
        }
    }
    
    private func findAndFixAssistantView(in view: UIView, assistantViewClass: UIView.Type) {
        // Check if this view is the assistant view
        if type(of: view) == assistantViewClass {
            // Instead of removing the constraint, make it a lower priority
            for constraint in view.constraints {
                if constraint.identifier == "assistantHeight" {
                    constraint.priority = .defaultLow  // Lower priority instead of disabling
                    break
                }
            }
            
            // Ensure the view updates its layout
            view.setNeedsLayout()
            view.layoutIfNeeded()
        }
        
        // Recursively search subviews
        for subview in view.subviews {
            findAndFixAssistantView(in: subview, assistantViewClass: assistantViewClass)
        }
    }
    
    private func setupKeyboardDismissal() {
        // Set up interactive keyboard dismissal globally
        UIScrollView.appearance().keyboardDismissMode = .interactive
    }
    
    private func setupKeyboardHandling() {
        // Fix for keyboard issues without disrupting text entry
        // Remove the problematic handlers that were calling resignFirstResponder/becomeFirstResponder
        
        // Register for keyboard appearance notifications for statistics only
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { notification in
            // Just log keyboard appearance without disrupting focus
            print("Keyboard will show")
        }
        
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { notification in
            // Just log keyboard dismissal without disrupting focus
            print("Keyboard will hide")
        }
    }
    
    private func fixLayoutConstraintIssues() {
        // Register to detect unsatisfiable constraints
        UserDefaults.standard.set(true, forKey: "_UIConstraintBasedLayoutLogUnsatisfiable")
        
        // Disable automatic constraints breaking when a conflict occurs
        UserDefaults.standard.set(false, forKey: "UIViewLayoutConstraintBehaviorAllowBreakingConstraints")
        
        // Fix SystemInputAssistantView height constraint
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let assistantViewClass = NSClassFromString("SystemInputAssistantView") {
                let swizzler = ConstraintSwizzler(classType: assistantViewClass)
                swizzler.swizzleUpdateConstraints()
            }
        }
        
        // Register observer to fix constraints on keyboard appearance
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(fixKeyboardConstraints),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
    }
    
    @objc private func fixKeyboardConstraints(notification: Notification) {
        // Fix the specific constraint conflict mentioned in the error log
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.fixSystemInputAssistantViewConstraints()
        }
    }
    
    private func fixSystemInputAssistantViewConstraints() {
        // Find all windows in the app
        var windows: [UIWindow] = []
        
        if #available(iOS 15.0, *) {
            for scene in UIApplication.shared.connectedScenes {
                if let windowScene = scene as? UIWindowScene {
                    windows.append(contentsOf: windowScene.windows)
                }
            }
        } else {
            // For iOS < 15, use the deprecated API
            windows = UIApplication.shared.windows
        }
        
        // Search for SystemInputAssistantView in the window hierarchy
        for window in windows {
            findAndFixSystemInputAssistantView(in: window)
        }
    }
}

class SceneDelegate: NSObject, UIWindowSceneDelegate {
    var window: UIWindow?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        // Use this method to set up the scene
        guard let windowScene = scene as? UIWindowScene else { return }
        
        // Set up the window with the windowScene
        window = UIWindow(windowScene: windowScene)
        
        // Handle connection options if needed
        if let urlContext = options.urlContexts.first {
            GIDSignIn.sharedInstance.handle(urlContext.url)
        }
    }
    
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        GIDSignIn.sharedInstance.handle(url)
    }
}

// Simplified InputAssistantManager that focuses on safely handling constraints
class InputAssistantManager {
    static let shared = InputAssistantManager()
    
    private init() {}
    
    func setupConstraintFixing(assistantViewClass: UIView.Type) {
        // Ensure we're on the main thread
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.setupConstraintFixing(assistantViewClass: assistantViewClass)
            }
            return
        }
        
        // Add observer for when windows become key
        NotificationCenter.default.addObserver(
            forName: UIWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.fixConstraintsInWindows(assistantViewClass: assistantViewClass)
        }
    }
    
    private func fixConstraintsInWindows(assistantViewClass: UIView.Type) {
        // Delay to ensure window hierarchy is fully established
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Find and fix the constraints in all windows
            if #available(iOS 15.0, *) {
                for scene in UIApplication.shared.connectedScenes {
                    if let windowScene = scene as? UIWindowScene {
                        for window in windowScene.windows {
                            self.lowerAssistantViewConstraintPriority(in: window, assistantViewClass: assistantViewClass)
                        }
                    }
                }
            } else {
                // For iOS < 15, use the deprecated API
                #if DEBUG
                print("Using deprecated UIApplication.windows API for iOS < 15")
                #endif
                
                // swiftlint:disable:next deprecated
                for window in UIApplication.shared.windows {
                    self.lowerAssistantViewConstraintPriority(in: window, assistantViewClass: assistantViewClass)
                }
            }
        }
    }
    
    private func lowerAssistantViewConstraintPriority(in window: UIWindow, assistantViewClass: UIView.Type) {
        for view in window.subviews {
            if type(of: view) == assistantViewClass {
                // Instead of removing constraints, lower their priority
                for constraint in view.constraints {
                    if constraint.identifier == "assistantHeight" {
                        constraint.priority = UILayoutPriority(250)  // Lower priority
                        break
                    }
                }
                
                // Force layout update
                view.setNeedsLayout()
                view.layoutIfNeeded()
            }
            
            // Check subviews recursively
            self.searchAndFixAssistantView(in: view, assistantViewClass: assistantViewClass)
        }
    }
    
    private func searchAndFixAssistantView(in view: UIView, assistantViewClass: UIView.Type) {
        // Recursively search for and fix assistant views
        for subview in view.subviews {
            if type(of: subview) == assistantViewClass {
                for constraint in subview.constraints {
                    if constraint.identifier == "assistantHeight" {
                        constraint.priority = UILayoutPriority(250)  // Lower priority
                        break
                    }
                }
                
                // Force layout update
                subview.setNeedsLayout()
                subview.layoutIfNeeded()
            }
            
            // Continue recursion
            searchAndFixAssistantView(in: subview, assistantViewClass: assistantViewClass)
        }
    }
}

// Helper class to safely modify constraints at runtime
class ConstraintSwizzler {
    private let classType: AnyClass
    
    init(classType: AnyClass) {
        self.classType = classType
    }
    
    func swizzleUpdateConstraints() {
        // Register a method that will run before and after constraints are added
        NotificationCenter.default.addObserver(
            forName: UIWindow.didBecomeVisibleNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.fixAssistantViewConstraints()
        }
        
        // Also register for keyboard notifications
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.fixAssistantViewConstraints()
        }
    }
    
    private func fixAssistantViewConstraints() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.findAndFixAssistantViews()
        }
    }
    
    private func findAndFixAssistantViews() {
        // Find all windows
        var windows: [UIWindow] = []
        
        if #available(iOS 15.0, *) {
            for scene in UIApplication.shared.connectedScenes {
                if let windowScene = scene as? UIWindowScene {
                    windows.append(contentsOf: windowScene.windows)
                }
            }
        } else {
            // For iOS < 15, use the deprecated API
            windows = UIApplication.shared.windows
        }
        
        // Find and fix constraints in each window
        for window in windows {
            findAndFixConstraintsRecursively(in: window)
        }
    }
    
    private func findAndFixConstraintsRecursively(in view: UIView) {
        // Check if this is an assistant view
        if type(of: view) == classType {
            var constraintsToModify: [NSLayoutConstraint] = []
            
            // Find the height constraint
            for constraint in view.constraints {
                if constraint.identifier == "assistantHeight" {
                    constraintsToModify.append(constraint)
                }
            }
            
            // Modify the constraints
            for constraint in constraintsToModify {
                constraint.priority = .defaultLow  // Lower priority to 250
            }
            
            // Update layout
            view.setNeedsLayout()
            view.layoutIfNeeded()
        }
        
        // Recursively search subviews
        for subview in view.subviews {
            findAndFixConstraintsRecursively(in: subview)
        }
    }
}

@main
struct App100Days: App {
    // Use UIApplicationDelegateAdaptor to ensure AppDelegate is used for Firebase initialization
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var userSession = UserSession.shared
    @StateObject private var subscriptionService = SubscriptionService.shared
    @StateObject private var notificationService = NotificationService.shared
    @AppStorage("AppTheme") private var appTheme: String = "system"
    
    init() {
        print("App100Days init - Using AppDelegate for Firebase initialization")
        
        // Remove Firebase initialization from here - it should only be in AppDelegate
        
        // Set up improved navigation bar appearance
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithDefaultBackground()
        navBarAppearance.shadowColor = .clear // Remove shadow line
        
        // Apply the appearance settings
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance
        
        // Fix for SFAuthenticationViewController
        if #available(iOS 15.0, *) {
            // Using the UserDefaults key is more reliable
            UserDefaults.standard.set(true, forKey: "ASWebAuthenticationSessionPrefersEphemeralWebBrowserSession")
        }
        
        // Fix for layout constraints
        UserDefaults.standard.set(true, forKey: "_UIConstraintBasedLayoutLogUnsatisfiable")
    }
    
    var body: some Scene {
        WindowGroup {
            AppContentView()
                .environmentObject(userSession)
                .environmentObject(subscriptionService)
                .environmentObject(notificationService)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
                .preferredColorScheme(getPreferredColorScheme())
                .onAppear {
                    print("Firebase confirmed initialized in body.onAppear")
                    
                    // Fix layout constraint issues
                    fixLayoutConstraintIssues()
                }
                // Replace global tap gesture with a more focused approach
                .modifier(FocusedDismissKeyboardOnTap())
        }
    }
    
    // Helper to get color scheme from app theme setting
    private func getPreferredColorScheme() -> ColorScheme? {
        switch appTheme {
        case "dark":
            return .dark
        case "light":
            return .light
        default:
            return nil
        }
    }
    
    // Fix layout constraint issues at the app level
    private func fixLayoutConstraintIssues() {
        print("Disabling input assistant view to fix layout constraints")
        
        // Register for unsatisfiable constraints
        UserDefaults.standard.set(true, forKey: "_UIConstraintBasedLayoutLogUnsatisfiable")
        
        // Disable automatic constraint breaking
        UserDefaults.standard.set(false, forKey: "UIViewShowAlignmentRects")
        
        // Fix the specific constraint conflict mentioned in the error log
        print("Fixing specific constraint conflict mentioned in error log")
        
        // Schedule a task to fix the height constraint of SystemInputAssistantView
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            fixSystemInputAssistantViewConstraints()
        }
        
        // Register for keyboard appearance notification
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { notification in
            print("Keyboard will show")
            // Fix constraints when keyboard is shown
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                fixSystemInputAssistantViewConstraints()
            }
        }
    }
}

struct AppContentView: View {
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var subscriptionService: SubscriptionService
    @EnvironmentObject var notificationService: NotificationService
    
    var body: some View {
        Group {
            if userSession.isAuthenticated {
                if userSession.hasCompletedOnboarding {
                    MainAppView()
                        .environmentObject(userSession)
                        .environmentObject(subscriptionService)
                        .environmentObject(notificationService)
                } else {
                    OnboardingView()
                        .environmentObject(userSession)
                        .environmentObject(subscriptionService)
                        .environmentObject(notificationService)
                }
            } else {
                AuthView()
                    .environmentObject(userSession)
                    .environmentObject(subscriptionService)
                    .environmentObject(notificationService)
            }
        }
    }
}

// Private helper function to fix SystemInputAssistantView constraints
private func fixSystemInputAssistantViewConstraints() {
    // Find all windows in the app
    for window in getAppWindows() {
        // Search for SystemInputAssistantView in window hierarchy
        findAndFixSystemInputAssistantView(in: window)
    }
}

private func getAppWindows() -> [UIWindow] {
    if #available(iOS 15.0, *) {
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
    } else {
        // For iOS < 15, use the deprecated API
        return UIApplication.shared.windows
    }
}

private func findAndFixSystemInputAssistantView(in view: UIView) {
    // Check for SystemInputAssistantView
    let viewName = NSStringFromClass(type(of: view))
    if viewName.contains("SystemInputAssistantView") {
        // Completely disable the view to avoid constraint conflicts
        view.isHidden = true
        
        // Remove all constraints to avoid conflicts
        let constraints = view.constraints
        constraints.forEach { view.removeConstraint($0) }
        
        // Or lower priority of all existing constraints
        for constraint in view.constraints {
            constraint.priority = UILayoutPriority(rawValue: 250)
        }
        
        // Also disable subviews to be thorough
        view.subviews.forEach { $0.isHidden = true }
    }
    
    // Check all subviews recursively
    for subview in view.subviews {
        findAndFixSystemInputAssistantView(in: subview)
    }
}

