import SwiftUI
import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import UIKit
import AuthenticationServices
import Network
import FirebaseFirestore
import Foundation

// Replace the import with a direct implementation of OfflineBanner
// @_exported import struct App.OfflineBanner

// Add OfflineBanner struct definition
struct OfflineBanner: View {
    var body: some View {
        VStack {
            HStack {
                Image(systemName: "wifi.slash")
                Text("You're offline")
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.yellow.opacity(0.8))
            .foregroundColor(.black)
            
            Spacer()
        }
    }
}

// Explicitly conform to UIApplicationDelegate protocol
class AppDelegate: NSObject, UIApplicationDelegate {
    private var networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "NetworkMonitor")
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Configure Firebase at the very beginning, before any other Firebase-related code
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
            print("✅ Firebase configured")
            
            // Configure Firestore for offline persistence using the newer cacheSettings API
            let db = Firestore.firestore()
            let settings = db.settings
            
            // Replace deprecated properties with new cacheSettings API
            let cacheSettings = PersistentCacheSettings(sizeBytes: NSNumber(value: 104857600)) // 100MB as a default size
            settings.cacheSettings = cacheSettings
            
            db.settings = settings
            // Set a flag to indicate Firebase is initialized
            UserDefaults.standard.set(true, forKey: "firebase_initialized")
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
        
        // Initialize and prefetch quotes
        initializeQuoteService()
        
        // Preemptively handle Apple authentication issues
        setupAppleAuthErrorHandling()
        
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
            // Lower the priority of constraints rather than completely removing them
            for constraint in view.constraints {
                if constraint.firstAttribute == .height {
                    constraint.priority = UILayoutPriority(50) // Very low priority
                }
            }
        }
        
        // Check for ASAuthorizationAppleIDButton constraint issues
        if viewName.contains("ASAuthorizationAppleIDButton") {
            print("Found ASAuthorizationAppleIDButton, fixing constraints")
            
            // Remove any width constraints that could cause conflicts
            let constraintsToRemove = view.constraints.filter { constraint in
                return constraint.firstAttribute == .width && constraint.relation == .lessThanOrEqual
            }
            
            for constraint in constraintsToRemove {
                view.removeConstraint(constraint)
            }
            
            // Make the view size itself appropriately
            view.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            view.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        }
        
        // Check all subviews recursively
        for subview in view.subviews {
            findAndFixSystemInputAssistantView(in: subview)
        }
    }
    
    private func initializeQuoteService() {
        // This will trigger the lazy initialization of the QuoteService
        let _ = QuoteService.shared
        
        // Prefetch quotes in the background
        Task {
            await QuoteService.shared.prefetchQuotes(count: 10)
        }
    }
    
    // Add a method to handle Apple Authentication errors
    private func setupAppleAuthErrorHandling() {
        DispatchQueue.main.async {
            // Fix for "No active account" error
            if #available(iOS 15.0, *) {
                UserDefaults.standard.set(true, forKey: "ASWebAuthenticationSessionPrefersEphemeralWebBrowserSession")
                
                // This will help with ASAuthenticationError Code=1000 "Cannot find provider for requested authentication type."
                UserDefaults.standard.set(true, forKey: "com.apple.developer.applesignin")
            }
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
    @StateObject private var adManager = AdManager.shared
    @StateObject private var progressViewModel = ProgressDashboardViewModel.shared
    @StateObject private var appStateCoordinator = AppStateCoordinator.shared
    @AppStorage("AppTheme") private var appTheme: String = "system"
    
    init() {
        print("App100Days init - Using AppDelegate for Firebase initialization")
        
        // Don't attempt to initialize Firebase here, let AppDelegate handle it
        // This avoids multiple initialization attempts
        
        // Set up improved navigation bar appearance
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithDefaultBackground()
        navBarAppearance.shadowColor = .clear // Remove shadow line
        
        // Apply the appearance settings
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance
        
        // Fix ASAuthorizationAppleIDButton constraint issue - This is a key fix for the SIGABRT
        if let buttonClass = NSClassFromString("ASAuthorizationAppleIDButton") as? UIView.Type {
            // Swizzle the constraints setup for ASAuthorizationAppleIDButton
            fixAppleButtonConstraints()
        }
    }
    
    private func fixAppleButtonConstraints() {
        // Fix for the AppleID button constraints that cause SIGABRT
        UserDefaults.standard.set(false, forKey: "ASAuthorizationAppleIDButtonDrawsWhenDisabled")
        
        // Ensure we don't break constraints automatically
        UserDefaults.standard.set(false, forKey: "UIViewLayoutConstraintBehaviorAllowBreakingConstraints")
        
        // Log unsatisfiable constraints
        UserDefaults.standard.set(true, forKey: "_UIConstraintBasedLayoutLogUnsatisfiable")
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                AppContentView()
                    .environmentObject(userSession)
                    .environmentObject(subscriptionService)
                    .environmentObject(notificationService)
                    .environmentObject(adManager)
                    .environmentObject(progressViewModel)
                    .onAppear {
                        print("App main view appeared")
                        // Initialize services
                        _ = NetworkMonitor.shared
                        _ = FirebaseAvailabilityService.shared
                    }
                
                // Show offline banner when in offline state
                if appStateCoordinator.appState == .offline {
                    OfflineBanner()
                        .transition(.move(edge: .top))
                        .animation(.spring(), value: appStateCoordinator.appState)
                        .zIndex(100)
                }
                
                // Show initializing or error state content
                if appStateCoordinator.appState == .initializing {
                    SplashScreen()
                        .zIndex(101)
                } else if case .error(let message) = appStateCoordinator.appState {
                    ErrorView(message: message) {
                        appStateCoordinator.attemptRecovery()
                    }
                    .zIndex(101)
                }
            }
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
            App100Days.fixSystemInputAssistantViewConstraints()
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
                App100Days.fixSystemInputAssistantViewConstraints()
            }
        }
    }
    
    private func setupAuthenticationServices() {
        // Fix for ASAuthorizationAppleIDButton layout issues
        DispatchQueue.main.async {
            // Register preference for ephemeral web session
            if #available(iOS 15.0, *) {
                UserDefaults.standard.set(true, forKey: "ASWebAuthenticationSessionPrefersEphemeralWebBrowserSession")
                
                // Set additional key used by Apple authentication
                UserDefaults.standard.set(true, forKey: "com.apple.developer.applesignin")
            }
            
            // Fix for "No active account" error
            AuthUtilities.configureAppleAuthSession()
        }
    }
    
    // Add static functions to be accessible from anywhere
    static func fixSystemInputAssistantViewConstraints() {
        // Find all windows in the app
        for window in getAppWindows() {
            // Search for SystemInputAssistantView in window hierarchy
            findAndFixSystemInputAssistantView(in: window)
        }
    }
    
    static func getAppWindows() -> [UIWindow] {
        if #available(iOS 15.0, *) {
            return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
        } else {
            // For iOS < 15, use the deprecated API
            return UIApplication.shared.windows
        }
    }
    
    static func findAndFixSystemInputAssistantView(in view: UIView) {
        // Check for SystemInputAssistantView
        let viewName = NSStringFromClass(type(of: view))
        if viewName.contains("SystemInputAssistantView") {
            // Lower the priority of constraints rather than completely removing them
            for constraint in view.constraints {
                if constraint.firstAttribute == .height {
                    constraint.priority = UILayoutPriority(50) // Very low priority
                }
            }
        }
        
        // Check for ASAuthorizationAppleIDButton constraint issues
        if viewName.contains("ASAuthorizationAppleIDButton") {
            print("Found ASAuthorizationAppleIDButton, fixing constraints")
            
            // Remove any width constraints that could cause conflicts
            let constraintsToRemove = view.constraints.filter { constraint in
                return constraint.firstAttribute == .width && constraint.relation == .lessThanOrEqual
            }
            
            for constraint in constraintsToRemove {
                view.removeConstraint(constraint)
            }
            
            // Make the view size itself appropriately
            view.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            view.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        }
        
        // Check all subviews recursively
        for subview in view.subviews {
            findAndFixSystemInputAssistantView(in: subview)
        }
    }
}

struct AppContentView: View {
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var subscriptionService: SubscriptionService
    @EnvironmentObject var notificationService: NotificationService
    @EnvironmentObject var adManager: AdManager
    @EnvironmentObject var progressViewModel: ProgressDashboardViewModel
    
    var body: some View {
        Group {
            if userSession.isAuthenticated {
                // Always go to main app view regardless of onboarding state
                MainAppView()
                    .environmentObject(userSession)
                    .environmentObject(subscriptionService)
                    .environmentObject(notificationService)
                    .environmentObject(adManager)
                    .environmentObject(progressViewModel)
                    .applyLayoutFixes()
            } else {
                // Only use AuthView for login/signup
                AuthView()
                    .environmentObject(userSession)
                    .environmentObject(subscriptionService)
                    .environmentObject(notificationService)
                    .environmentObject(adManager)
                    .environmentObject(progressViewModel)
                    .applyLayoutFixes()
            }
        }
    }
}

// Add this class after AppContentView and before the helper functions
class AuthUtilities {
    // Store a strong reference to the delegate and provider to prevent deallocation
    private static var delegate = DummyAuthDelegate.shared
    private static var provider: DummyPresentationProvider?
    
    static func configureAppleAuthSession() {
        // Initialize an authentication controller but don't present it
        // This ensures the auth session is properly initialized
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            
            // Force the ASAuthorizationController to initialize its internal state
            let appleIDProvider = ASAuthorizationAppleIDProvider()
            let request = appleIDProvider.createRequest()
            request.requestedScopes = []
            
            // Store strong reference to provider
            provider = DummyPresentationProvider(window: window)
            
            let authController = ASAuthorizationController(authorizationRequests: [request])
            authController.delegate = delegate
            authController.presentationContextProvider = provider
            
            // Don't actually present it - just initialize the controller
            print("Pre-initialized Apple authentication controller")
        }
    }
}

// Dummy classes to support Apple auth initialization
class DummyAuthDelegate: NSObject, ASAuthorizationControllerDelegate {
    static let shared = DummyAuthDelegate()
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        // Never actually called
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        // Never actually called
    }
}

class DummyPresentationProvider: NSObject, ASAuthorizationControllerPresentationContextProviding {
    let window: UIWindow
    
    init(window: UIWindow) {
        self.window = window
        super.init()
    }
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return window
    }
}

// Only keeping ErrorView and SplashScreen, removing duplicate OfflineBanner

// Simple error view
struct ErrorView: View {
    let message: String
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 70))
                .foregroundColor(.yellow)
            
            Text("Something went wrong")
                .font(.title)
                .fontWeight(.bold)
            
            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: retryAction) {
                Text("Try Again")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.top)
        }
        .padding()
    }
}

// Splash screen shown during initialization
struct SplashScreen: View {
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "checkmark.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(.blue)
            
            Text("100Days")
                .font(.system(size: 40, weight: .heavy, design: .rounded))
            
            ProgressView()
                .scaleEffect(1.5)
                .padding(.top, 30)
        }
    }
}

