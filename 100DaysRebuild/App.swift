import SwiftUI
import FirebaseCore
import FirebaseAuth
import GoogleSignIn
@preconcurrency import UIKit
import AuthenticationServices
import Network
import FirebaseFirestore
import Foundation
import RevenueCat
import GoogleMobileAds
import StoreKit

// Replace the import with a direct implementation of OfflineBanner
// @_exported import struct App.OfflineBanner

// NOTE: top-level executable statements are not allowed in app modules.
// Firebase configuration (and Firestore settings) will be performed early
// inside the App lifecycle initializer below to avoid static initialization
// races while remaining within a valid declaration context.

// Add OfflineBanner struct definition
struct OfflineBanner: View {
    var body: some View {
        VStack {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "wifi.slash")
                    .font(AppTypography.subhead())
                Text("You're offline")
                    .font(AppTypography.subhead(.medium))
                Spacer()
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.xs)
            .background(Color.yellow.opacity(0.8))
            .foregroundStyle(.black)

            Spacer()
        }
    }
}

// Explicitly conform to UIApplicationDelegate protocol
@preconcurrency
class AppDelegate: NSObject, UIApplicationDelegate {
    private var networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "NetworkMonitor")
    // Add a static flag to track when Firebase has been configured
    static var firebaseConfigured = false
    static var revenueCatConfigured = false
    
    // Public helper to ensure RevenueCat (Purchases) is configured as early as possible.
    // This is intentionally static so it can be called from App init before other
    // objects (like SubscriptionStore) are constructed which might access Purchases.shared.
    static func configureRevenueCatIfNeeded() {
        // Delegate to the centralized manager which ensures a single configure call
        RevenueCatManager.configureIfNeeded()

        // Keep the AppDelegate-level flag in sync for backwards compatibility
        AppDelegate.revenueCatConfigured = RevenueCatManager.isConfigured
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // IMPORTANT: Configure Firebase at the very beginning, before any other Firebase-related code runs
        configureFirebase()

        // Configure RevenueCat after Firebase
        configureRevenueCat()

        // Initialize Google AdMob SDK
        MobileAds.initialize()
        
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
        
        // Register for memory warning notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        
        return true
    }
    
    // Handle memory warnings by clearing caches and non-essential data
    @objc private func handleMemoryWarning() {
        // Clear image caches
        URLCache.shared.removeAllCachedResponses()

        // Perform garbage collection
        autoreleasepool {
            // Force a garbage collection cycle
        }
    }
    
    // Extract Firebase configuration to a separate method
    private func configureFirebase() {
        // Only configure Firebase if it hasn't been configured yet
        if !AppDelegate.firebaseConfigured && FirebaseApp.app() == nil {
            #if DEBUG
            print("🔥 Configuring Firebase...")
            #endif

            // Explicitly configure Firebase with the default GoogleService-Info.plist first
            FirebaseApp.configure()

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
        }
    }
    
    // Extract RevenueCat configuration to a separate method
    private func configureRevenueCat() {
        // Delegate to the static configurator so callers can configure early (from App.init)
        AppDelegate.configureRevenueCatIfNeeded()
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let sceneConfig = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        sceneConfig.delegateClass = SceneDelegate.self
        return sceneConfig
    }
    
    private var lastNetworkStatus: Bool?

    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            let isConnected = path.status == .satisfied

            // Notify Firebase service about network status change
            DispatchQueue.main.async { [weak self] in
                // Only post notification when status actually changes to prevent spam
                guard self?.lastNetworkStatus != isConnected else {
                    return
                }

                self?.lastNetworkStatus = isConnected

                NotificationCenter.default.post(
                    name: NSNotification.Name("NetworkStatusChanged"),
                    object: nil,
                    userInfo: ["isConnected": isConnected]
                )
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
        appearance.shadowColor = .clear // Remove the bottom border
        
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
        
        // Keyboard notifications removed for production
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
            // For iOS < 15, use the Scene-based lookup which is safer than the deprecated API
            return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
        }
    }
    
    private func findAndFixSystemInputAssistantView(in view: UIView) {
        // Check for SystemInputAssistantView
        let viewName = NSStringFromClass(type(of: view))
        if viewName.contains("SystemInputAssistantView") {
            
            // Lower the priority of constraints rather than completely removing them
            for constraint in view.constraints {
                // Safely check constraint attributes
                if let identifier = constraint.identifier, identifier == "assistantHeight" {
                    constraint.priority = UILayoutPriority(50) // Very low priority
                } else if constraint.firstAttribute == .height && constraint.firstItem === view {
                    // Also catch height constraints without identifiers
                    constraint.priority = UILayoutPriority(50)
                }
            }
        }
        
        // Check for ASAuthorizationAppleIDButton constraint issues
        if viewName.contains("ASAuthorizationAppleIDButton") {
            
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
@MainActor
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
            // Ensure the call runs on the main actor since InputAssistantManager is @MainActor
            Task { @MainActor in
                await self?.fixConstraintsInWindows(assistantViewClass: assistantViewClass)
            }
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
                // For iOS < 15, use the Scene-based lookup
                for scene in UIApplication.shared.connectedScenes {
                    if let windowScene = scene as? UIWindowScene {
                        for window in windowScene.windows {
                            self.lowerAssistantViewConstraintPriority(in: window, assistantViewClass: assistantViewClass)
                        }
                    }
                }
            }
        }
    }
    
    private func lowerAssistantViewConstraintPriority(in window: UIWindow, assistantViewClass: UIView.Type) {
        for view in window.subviews {
            if type(of: view) == assistantViewClass {
                // Use safer approach to modify constraints
                for constraint in view.constraints {
                    // Safely check identifier to avoid EXC_BAD_ACCESS crash
                    if let identifier = constraint.identifier, identifier == "assistantHeight" {
                        constraint.priority = UILayoutPriority(250)  // Lower priority
                    } else if constraint.firstAttribute == .height && constraint.firstItem === view {
                        // Also modify height constraints without identifiers
                        constraint.priority = UILayoutPriority(250)
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
                // Use a safer approach to find and modify constraints
                for constraint in subview.constraints {
                    // Safely check constraint identifier to avoid EXC_BAD_ACCESS
                    if let identifier = constraint.identifier, identifier == "assistantHeight" {
                        constraint.priority = UILayoutPriority(250)  // Lower priority
                    } else if constraint.firstAttribute == .height && constraint.firstItem === subview {
                        // Also modify any height constraint directly affecting this view
                        constraint.priority = UILayoutPriority(250)
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
@MainActor
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
            Task { @MainActor in
                await self?.fixAssistantViewConstraints()
            }
        }
        
        // Also register for keyboard notifications
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.fixAssistantViewConstraints()
            }
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
            // For iOS < 15, use the Scene-based lookup
            windows = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
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
            
            // Find the height constraint - use safer approach
            for constraint in view.constraints {
                // Safely check for constraint identifier to avoid EXC_BAD_ACCESS
                if let identifier = constraint.identifier, identifier == "assistantHeight" {
                    constraintsToModify.append(constraint)
                } else if constraint.firstAttribute == .height && constraint.firstItem === view {
                    // Also modify height constraints without identifiers
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
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var userSession = UserSession.shared
    @StateObject private var subscriptionStore: SubscriptionStore
    @StateObject private var subscriptionService = SubscriptionService.shared
    @StateObject private var entitlementsAdapter: EntitlementsAdapter
    @StateObject private var notificationService = NotificationService.shared
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var progressDashboardViewModel = ProgressDashboardViewModel.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @StateObject private var userStatsService = UserStatsService.shared
    @StateObject private var navigationRouter = NavigationRouter()
    @StateObject private var badgeService = BadgeService.shared
    @StateObject private var analyticsService = AnalyticsService.shared

    init() {
        // Perform early Firebase configuration here (inside init) rather than
        // at top-level so we remain within a valid declaration context.
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()

            // Apply Firestore settings immediately to avoid race conditions
            let settings = FirestoreSettings()
            let cacheSettings = PersistentCacheSettings(sizeBytes: NSNumber(value: 100 * 1024 * 1024)) // 100MB cache
            settings.cacheSettings = cacheSettings
            Firestore.firestore().settings = settings

            UserDefaults.standard.set(true, forKey: "firebase_initialized")
            AppDelegate.firebaseConfigured = true
        }
        
    // Ensure RevenueCat (Purchases) is configured early so any downstream
    // objects (SubscriptionStore / repositories) that access Purchases.shared
    // during initialization do not trigger the "Purchases has not been configured" fatal error.
    AppDelegate.configureRevenueCatIfNeeded()

    // Use shared singleton SubscriptionStore instance
        _subscriptionStore = StateObject(wrappedValue: SubscriptionStore.shared)
        _entitlementsAdapter = StateObject(wrappedValue: EntitlementsAdapter(store: SubscriptionStore.shared))
    }
    
    var body: some Scene {
        WindowGroup {
            AppContentView()
                .environmentObject(userSession)
                .environmentObject(subscriptionStore)
                .environmentObject(subscriptionService)
                .environmentObject(entitlementsAdapter)
                .environmentObject(notificationService)
                .environmentObject(themeManager)
                .environmentObject(progressDashboardViewModel)
                .environmentObject(networkMonitor)
                .environmentObject(userStatsService)
                .environmentObject(navigationRouter)
                .environmentObject(badgeService)
                .environmentObject(analyticsService)
                .preferredColorScheme(themeManager.effectiveColorScheme())
                .onAppear {
                    setupApp()
                }
        }
    }
    
    private func setupApp() {
        // Configure non-Firebase aspects
        configureUndimmedAnimations()
        setupNavigationBarAppearance()
        setupKeyboardDismissal()
        
        // Prevent layout constraint issues, especially on iOS 15+
        fixLayoutConstraintIssues()
        
        // Configure Apple Auth to prevent initialization delays
        AuthUtilities.configureAppleAuthSession()
    }
    
    private func configureUndimmedAnimations() {
        UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self]).tintColor = UIColor(Color.theme.accent)
    }
    
    private func setupKeyboardDismissal() {
        // Implement better keyboard dismissal
        UIScrollView.appearance().keyboardDismissMode = .onDrag
    }
    
    private func fixLayoutConstraintIssues() {
        // This is a workaround for constraint issues, particularly on iOS 15+
        UserDefaults.standard.setValue(false, forKey: "_UIConstraintBasedLayoutLogUnsatisfiable")
    }
    
    // Remove NavigationBar bottom border
    private func setupNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.shadowColor = .clear // Remove the bottom border
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
}

// App content view for the main content area
struct AppContentView: View {
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var entitlementsAdapter: EntitlementsAdapter
    @EnvironmentObject var notificationService: NotificationService
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var progressDashboardViewModel: ProgressDashboardViewModel
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var userStatsService: UserStatsService
    @EnvironmentObject var badgeService: BadgeService
    @StateObject private var navigationRouter = NavigationRouter()
    @StateObject private var appRouter = AppRouter()
    @State private var isInitializing = true
    @State private var forceWelcomeView = false
    @State private var subscriptionLoaded = false
    @State private var accountCreatedAt: Date? = nil
    @State private var completedOnboarding = false

    // Track previous auth state to prevent flickering
    @State private var previousAuthState: Bool? = nil

    // Track if auth state is resolved
    @State private var isAuthResolved = false
    
    var body: some View {
        ZStack {
            // Background color for the entire app - always present for consistent visual
            Color.theme.background
                .ignoresSafeArea()
            
            // Content based on state with controlled transitions
            // Keep splash visible until BOTH auth is resolved AND (user is logged out OR subscription data loaded)
            // This prevents flashing a stale screen while subscription data loads after login
            let shouldShowSplash = isInitializing ||
                                   (userSession.authState == .loading && !isAuthResolved) ||
                                   (userSession.isAuthenticated && !subscriptionLoaded && isAuthResolved)

            if shouldShowSplash {
                // Show splash screen while auth resolves or subscription data loads
                SplashScreen()
                    .transition(.opacity)
                    .onAppear {
                        // Quick check (0.3s) to see if auth is already resolved
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            if userSession.authState != .loading {
                                withAnimation(Animation.easeInOut(duration: 0.4)) {
                                    previousAuthState = userSession.isAuthenticated
                                    isInitializing = false
                                    isAuthResolved = true
                                }
                            }
                        }

                        // Maximum timeout (2s) to prevent infinite waiting
                        // Extended to give subscription data time to load
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            withAnimation(Animation.easeInOut(duration: 0.4)) {
                                previousAuthState = userSession.isAuthenticated
                                isInitializing = false
                                isAuthResolved = true
                            }
                        }
                    }
            } else {
                // Use centralized routing logic
                let route = appRouter.computeRoute(
                    isAuthenticated: userSession.isAuthenticated,
                    accountCreatedAt: accountCreatedAt,
                    completedOnboarding: completedOnboarding,
                    isPro: subscriptionStore.isPro,
                    entitlementsLoaded: subscriptionLoaded
                )

                Group {
                    switch route {
                    case .splash:
                        SplashScreen()
                            .transition(.opacity)

                    case .auth:
                        WelcomeView()
                            .transition(.opacity)

                    case .loading:
                        // Show splash screen instead of separate loading screen
                        // This prevents the jarring "Loading..." screen flash
                        SplashScreen()
                            .transition(.opacity)

                    case .funnel:
                        ImprovedFunnelView {
                            // Funnel completed - mark as complete and refresh
                            Task {
                                if let userId = Auth.auth().currentUser?.uid {
                                    do {
                                        try await MigrationManager.shared.markOnboardingCompleted(userId: userId)
                                        print("[Onboarding] completedOnboardingAt set: \(Date())")

                                        // Update local state
                                        completedOnboarding = true

                                        // Refresh subscription status
                                        await subscriptionStore.load()
                                    } catch {
                                        print("❌ Failed to mark onboarding complete: \(error)")
                                    }
                                }
                            }
                        }
                        .transition(.opacity)

                    case .mainPro:
                        MainAppView()
                            .transition(.opacity)

                    case .mainFree:
                        MainAppView()
                            .transition(.opacity)
                    }
                }
                .environmentObject(navigationRouter)
                .animation(Animation.easeInOut(duration: 0.3), value: route)
                .animation(Animation.easeInOut(duration: 0.3), value: userSession.isAuthenticated)
                .animation(Animation.easeInOut(duration: 0.3), value: forceWelcomeView)
                .onReceive(userSession.$authState) { state in
                    if state != .loading {
                        withAnimation {
                            isAuthResolved = true
                        }
                    }
                }
                .onChange(of: subscriptionLoaded) { loaded in
                    // Update router timer state when subscription loads
                    Task { @MainActor in
                        if loaded {
                            appRouter.markEntitlementsLoaded()
                        } else if userSession.isAuthenticated {
                            appRouter.startEntitlementsTimer()
                        }
                    }
                }
                .onChange(of: userSession.accountCreatedAt) { newValue in
                    // Sync local accountCreatedAt with UserSession
                    accountCreatedAt = newValue
                    // Check if we should mark as loaded
                    checkIfDataLoaded()
                }
                .onChange(of: userSession.hasCompletedOnboarding) { newValue in
                    // Sync local completedOnboarding with UserSession
                    completedOnboarding = newValue
                    // Check if we should mark as loaded
                    checkIfDataLoaded()
                }
                .onChange(of: subscriptionStore.isPro) { _ in
                    // Check if we should mark as loaded
                    checkIfDataLoaded()
                }
                .onChange(of: subscriptionStore.state.isGrandfatherActive) { _ in
                    // Check if we should mark as loaded (important for grandfathered users)
                    checkIfDataLoaded()
                }
                .onAppear {
                    // Initial sync when view appears
                    accountCreatedAt = userSession.accountCreatedAt
                    completedOnboarding = userSession.hasCompletedOnboarding
                    // Check if already loaded
                    checkIfDataLoaded()
                }
                .onChange(of: userSession.isAuthenticated) { isAuth in
                    // When user authenticates, identify with RevenueCat and load subscription status
                    if isAuth, let userId = Auth.auth().currentUser?.uid {
                        Task {
                            // Run migration and RevenueCat identity in parallel for faster loading
                            async let migration = MigrationManager.shared.checkAndMigrate(for: userId)
                            async let identity = subscriptionStore.identifyUser(userId)

                            // Wait for both to complete
                            do {
                                try await migration
                            } catch {
                                print("❌ Migration failed: \(error.localizedDescription)")
                            }
                            await identity

                            // UserSession automatically loads profile via auth state listener
                            // Local state will sync via onChange observers above

                            // Load subscription status after identity is set
                            await subscriptionStore.load()

                            // Check if data is loaded (accountCreatedAt + subscription status)
                            await MainActor.run {
                                checkIfDataLoaded()
                            }
                        }
                    } else {
                        // Reset when user signs out
                        subscriptionLoaded = false
                        accountCreatedAt = nil
                        completedOnboarding = false
                        Task {
                            await subscriptionStore.reset()
                        }
                    }
                }
            }
            
            // Offline banner overlay (always on top)
            if !networkMonitor.isConnected {
                VStack {
                    OfflineBanner()
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(Animation.easeInOut, value: networkMonitor.isConnected)
                .zIndex(100) // Ensure it's on top
            }
        }
        .onChange(of: userSession.isAuthenticated) { newValue in
            // Only animate if we have a previous state and it's different
            if let previous = previousAuthState, previous != newValue {
                withAnimation(Animation.easeInOut(duration: 0.3)) {
                    // Update state with animation
                }
            }
            // Always update the previous state
            previousAuthState = newValue
        }
        .onAppear {
            // No-op here; we handle ForceNavigateToWelcome via onReceive to safely mutate view state
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ForceNavigateToWelcome"))) { _ in
            withAnimation(Animation.easeInOut(duration: 0.3)) {
                // Trigger the transition to the welcome view
                forceWelcomeView = true
            }

            // Reset services/view models on the main actor
            Task { @MainActor in
                navigationRouter.reset()
                progressDashboardViewModel.reset()

                // Give views time to update
                try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s

                userStatsService.reset()
                badgeService.reset()
                notificationService.reset()

                // Wait briefly then clear the flag if the user is still signed out
                try? await Task.sleep(nanoseconds: 800_000_000) // 0.8s
                if !userSession.isAuthenticated {
                    forceWelcomeView = false
                }
            }
        }
    }
    
    // Computed property to determine if welcome view should show
    private var shouldShowWelcomeView: Bool {
        return !userSession.isAuthenticated || forceWelcomeView
    }

    // Helper to check if all data is loaded and mark subscriptionLoaded
    private func checkIfDataLoaded() {
        // Only mark as loaded if authenticated and not already loaded
        guard userSession.isAuthenticated, !subscriptionLoaded else {
            return
        }

        // Check if SubscriptionStore has computed the isPro status
        // We know it's ready when it has set isPro to a meaningful value
        // IMPORTANT: For grandfathered users, we need accountCreatedAt to be loaded
        // to compute grandfather status, so check that as well
        let hasAccountData = accountCreatedAt != nil
        let hasSubscriptionData = subscriptionStore.isPro || subscriptionStore.state.rcIsPro || subscriptionStore.state.isGrandfatherActive

        // Mark as loaded if we have EITHER:
        // 1. Subscription data (RC Pro or Grandfather Pro is computed), OR
        // 2. Account data is loaded AND subscription state has been initialized (even if false)
        //    This handles the case where user is not Pro and not grandfathered
        let isReady = hasSubscriptionData || (hasAccountData && subscriptionStore.state != .default)

        if isReady {
            subscriptionLoaded = true
        }
    }
}

// Add this class after AppContentView and before the helper functions
@MainActor
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
                .font(AppTypography.font(size: 70))
                .foregroundColor(.yellow)
            
            Text("Something went wrong")
                .font(AppTypography.title1(.bold))
            
            Text(message)
                .font(AppTypography.body())
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: retryAction) {
                Text("Try Again")
                    .font(AppTypography.headline())
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
            // Background gradient matching other screens
            LinearGradient(
                colors: [
                    DS.Colors.gradientA,
                    DS.Colors.gradientB
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: DS.Spacing.xl) {
                // Clean, minimalist logo
                ZStack {
                    // Outer glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.primary.opacity(0.2),
                                    Color.primary.opacity(0.08),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 30,
                                endRadius: 90
                            )
                        )
                        .frame(width: 180, height: 180)
                        .blur(radius: 20)

                    // Outer circle with gradient
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.primary.opacity(0.18),
                                    Color.primary.opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)

                    // Inner checkmark
                    Image(systemName: "checkmark")
                        .font(AppTypography.display())
                        .foregroundStyle(.white)
                        .rotationEffect(.degrees(rotation))
                }

                // App name with proper typography
                Text("100Days")
                    .font(AppTypography.largeTitle(.bold))
                    .foregroundStyle(Color.primary)
            }
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                // Subtle animations
                withAnimation(Animation.spring(response: 0.8, dampingFraction: 0.7)) {
                    opacity = 1.0
                    scale = 1.0
                }

                // Subtle rotation animation for the checkmark
                withAnimation(Animation.easeInOut(duration: 1.2)) {
                    rotation = 360
                }
            }
        }
    }
}

// Notification names are now defined in Constants.swift

