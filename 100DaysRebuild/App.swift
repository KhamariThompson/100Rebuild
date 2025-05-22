import SwiftUI
import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import UIKit
import AuthenticationServices
import Network
import FirebaseFirestore
import Foundation
import RevenueCat

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
    // Add a static flag to track when Firebase has been configured
    static var firebaseConfigured = false
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        print("App100Days init - Using AppDelegate for Firebase initialization")
        
        // IMPORTANT: Configure Firebase at the very beginning, before any other Firebase-related code runs
        configureFirebase()
        
        // Configure RevenueCat after Firebase
        configureRevenueCat()
        
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
    
    // Extract Firebase configuration to a separate method
    private func configureFirebase() {
        // Clear any previous flags to ensure we initialize properly
        AppDelegate.firebaseConfigured = false
        
        // Only configure Firebase if it hasn't been configured yet
        if !AppDelegate.firebaseConfigured {
            // Explicitly configure Firebase with the default GoogleService-Info.plist first
            if FirebaseApp.app() == nil {
                FirebaseApp.configure()
            }
            print("✅ Firebase configured")
            
            // Now that Firebase is configured but before any Firestore method is called,
            // we can set the Firestore settings
            let settings = FirestoreSettings()
            
            // Replace deprecated properties with new cacheSettings API
            let cacheSettings = PersistentCacheSettings(sizeBytes: NSNumber(value: 100 * 1024 * 1024)) // 100MB cache size
            settings.cacheSettings = cacheSettings
            
            // Apply these settings to the Firestore instance before any other Firestore method is called
            Firestore.firestore().settings = settings
            
            // Set a flag to indicate Firebase is initialized
            UserDefaults.standard.set(true, forKey: "firebase_initialized")
            // Set our static flag
            AppDelegate.firebaseConfigured = true
            print("Firestore offline persistence configured")
        } else {
            print("Firebase already configured, skipping initialization")
        }
    }
    
    // Extract RevenueCat configuration to a separate method
    private func configureRevenueCat() {
        Purchases.logLevel = .debug
        Purchases.configure(
            with: Configuration.Builder(withAPIKey: "appl_BmXAuCdWBmPoVBAOgxODhJddUvc")
                .with(appUserID: nil)
                .with(purchasesAreCompletedBy: .revenueCat, storeKitVersion: .storeKit2)
                .with(userDefaults: UserDefaults.standard)
                .with(usesStoreKit2IfAvailable: true)
                .build()
        )
        print("RevenueCat configured with key: appl_BmXAuCdWBmPoVBAOgxODhJddUvc")
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
        networkMonitor.pathUpdateHandler = { [weak self] path in
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
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var userSession = UserSession.shared
    @StateObject private var subscriptionService = SubscriptionService.shared
    @StateObject private var notificationService = NotificationService.shared
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var progressDashboardViewModel = ProgressDashboardViewModel.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @StateObject private var userStatsService = UserStatsService.shared
    @StateObject private var navigationRouter = NavigationRouter()
    
    init() {
        print("App100Days init - Using AppDelegate for Firebase initialization")
        // Firebase will be configured in AppDelegate
    }
    
    var body: some Scene {
        WindowGroup {
            AppContentView()
                .environmentObject(userSession)
                .environmentObject(subscriptionService)
                .environmentObject(notificationService)
                .environmentObject(themeManager)
                .environmentObject(progressDashboardViewModel)
                .environmentObject(networkMonitor)
                .environmentObject(userStatsService)
                .environmentObject(navigationRouter)
                .withAppTheme()
                .task {
                    // Register custom fonts if any
                    FontRegistration.registerFonts()
                }
        }
    }
    
    private func initializeServices() {
        // Log initialized services, but don't re-configure Firestore
        // as it's already configured in AppDelegate
        print("Services already initialized in AppDelegate")
        print("Auth service initialized")
        print("Firestore service initialized")
        print("Storage service initialized")
    }
}

// App content view for the main content area
struct AppContentView: View {
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var subscriptionService: SubscriptionService
    @EnvironmentObject var notificationService: NotificationService
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var progressDashboardViewModel: ProgressDashboardViewModel
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var userStatsService: UserStatsService
    @StateObject private var navigationRouter = NavigationRouter()
    @State private var isInitializing = true
    
    var body: some View {
        ZStack {
            // Background color for the entire app
            Color.theme.background
                .ignoresSafeArea()
            
            // Content based on state
            if isInitializing {
                SplashScreen()
                    .transition(.opacity)
                    .onAppear {
                        // Delay to show splash screen briefly
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            withAnimation(.easeInOut(duration: 0.4)) {
                                isInitializing = false
                            }
                        }
                    }
            } else {
                Group {
                    if userSession.isAuthenticated {
                        // Main app for authenticated users
                        MainAppView()
                            .environmentObject(userSession)
                            .environmentObject(subscriptionService)
                            .environmentObject(notificationService)
                            .environmentObject(themeManager)
                            .environmentObject(progressDashboardViewModel)
                            .environmentObject(networkMonitor)
                            .environmentObject(userStatsService)
                            .environmentObject(navigationRouter)
                    } else {
                        // Welcome view for non-authenticated users
                        WelcomeView()
                            .environmentObject(userSession)
                            .environmentObject(themeManager)
                    }
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.4), value: userSession.isAuthenticated)
            }
            
            // Offline banner overlay (always on top)
            if !networkMonitor.isConnected {
                VStack {
                    OfflineBanner()
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut, value: networkMonitor.isConnected)
                .zIndex(100) // Ensure it's on top
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
    @State private var opacity = 0.0
    @State private var scale = 0.9
    @State private var rotation = 0.0
    
    var body: some View {
        ZStack {
            // Clean background
            Color.theme.background.ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Clean, minimalist logo
                ZStack {
                    // Outer circle with gradient
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.theme.accent, Color.theme.accent.opacity(0.7)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 110, height: 110)
                        .shadow(color: Color.theme.accent.opacity(0.2), radius: 10, x: 0, y: 5)
                    
                    // Inner checkmark
                    Image(systemName: "checkmark")
                        .font(.system(size: 50, weight: .bold))
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(rotation))
                }
                
                // App name with clean typography
                Text("100Days")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundColor(.theme.text)
                    .tracking(1) // Slightly increased letter spacing for cleaner look
            }
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                // Subtle animations
                withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                    opacity = 1.0
                    scale = 1.0
                }
                
                // Subtle rotation animation for the checkmark
                withAnimation(.easeInOut(duration: 1.2)) {
                    rotation = 360
                }
            }
        }
    }
}

