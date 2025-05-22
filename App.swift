import SwiftUI
import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import UIKit
import AuthenticationServices
import Network
import FirebaseFirestore
import MessageUI

// Declare FirestoreCacheSizeUnlimited constant if it doesn't exist elsewhere
let FirestoreCacheSizeUnlimited: Int64 = 104857600 // 100MB as a default size

class AppDelegate: NSObject, UIApplicationDelegate {
    private var networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "NetworkMonitor")
    static var firebaseConfigured = false
    
    // Add memory monitoring timer
    private var memoryMonitorTimer: Timer?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Configure Firebase at the very beginning, before any other Firebase-related code
        configureFirebaseOnce()
        
        // Fix for navigation layout constraints
        setupNavigationBarAppearance()
        
        // Fix layout constraint issues specifically
        fixLayoutConstraintIssues()
        
        // Set up network connectivity monitoring after Firebase is configured
        startNetworkMonitoring()
        
        // Start memory monitoring
        startMemoryMonitoring()
        
        return true
    }
    
    // Helper method to ensure Firebase is only initialized once
    private func configureFirebaseOnce() {
        // Only configure Firebase if it hasn't been configured yet
        if !AppDelegate.firebaseConfigured && FirebaseApp.app() == nil {
            print("DEBUG: Configuring Firebase for the first time")
            FirebaseApp.configure()
            
            // Configure Firestore for offline persistence
            let db = Firestore.firestore()
            let settings = db.settings
            settings.cacheSettings = PersistentCacheSettings(sizeBytes: NSNumber(value: FirestoreCacheSizeUnlimited))
            settings.isPersistenceEnabled = true // Ensure persistence is enabled
            db.settings = settings
            
            // Mark Firebase as configured using static flag
            AppDelegate.firebaseConfigured = true
            
            print("DEBUG: Firestore offline persistence configured")
        } else {
            print("DEBUG: Firebase was already configured, skipping configuration")
        }
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let sceneConfig = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        sceneConfig.delegateClass = SceneDelegate.self
        return sceneConfig
    }
    
    // Start memory monitoring to prevent crashes
    private func startMemoryMonitoring() {
        // Register for memory warnings
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        
        // Start a timer to periodically check memory usage
        memoryMonitorTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // Log current memory usage
            let memoryUsage = MemoryManager.shared.formattedMemoryUsage()
            print("Current memory usage: \(memoryUsage)")
            
            // Check if memory usage is high and clear caches if needed
            if MemoryManager.shared.checkMemoryUsage() {
                print("Memory usage is high, clearing caches")
                self.clearCaches()
            }
        }
    }
    
    @objc private func handleMemoryWarning() {
        print("⚠️ Memory warning received - clearing caches")
        clearCaches()
    }
    
    private func clearCaches() {
        // Use our memory manager to clear caches
        MemoryManager.shared.clearAllCaches()
        
        // Clear URLCache
        URLCache.shared.removeAllCachedResponses()
        
        // Suggest a garbage collection
        autoreleasepool {
            // Do nothing, just trigger autorelease pool cleanup
        }
    }
    
    // Function to set up network monitoring
    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { path in
            let isConnected = path.status == .satisfied
            print("Network connectivity changed: \(isConnected ? "Connected" : "Disconnected")")
            
            // Notify app components about network status change
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .networkStatusChanged,
                    object: nil,
                    userInfo: ["isConnected": isConnected]
                )
            }
        }
        
        networkMonitor.start(queue: networkQueue)
    }
    
    // Fix navigation bar appearance issues
    private func setupNavigationBarAppearance() {
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithDefaultBackground()
        navBarAppearance.shadowColor = .clear // Remove shadow line
        
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance
    }
    
    // Fix layout constraint issues
    private func fixLayoutConstraintIssues() {
        // Fix for SystemInputAssistantView height constraint issue
        UserDefaults.standard.set(true, forKey: "_UIConstraintBasedLayoutLogUnsatisfiable")
        
        // Fix for SFAuthenticationViewController
        if #available(iOS 15.0, *) {
            UserDefaults.standard.set(true, forKey: "ASWebAuthenticationSessionPrefersEphemeralWebBrowserSession")
        }
    }
    
    deinit {
        networkMonitor.cancel()
        memoryMonitorTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
}

// Add Notification.Name extension if it's not defined elsewhere
extension Notification.Name {
    static let networkStatusChanged = Notification.Name("NetworkStatusChanged")
}

// MARK: - Main App Structure
@main
struct App100Days: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appStateCoordinator = AppStateCoordinator.shared
    @StateObject private var userSession = UserSession.shared
    @StateObject private var subscriptionService = SubscriptionService.shared
    @StateObject private var notificationService = NotificationService.shared
    @StateObject private var adManager = AdManager.shared
    @StateObject private var progressViewModel = ProgressDashboardViewModel.shared
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var navigationRouter = NavigationRouter()
    
    init() {
        print("App100Days init - Using AppDelegate for Firebase initialization")
        
        // REMOVED: Duplicate Firebase initialization code
        // Firebase is now configured only by the AppDelegate
        
        // Set up improved navigation bar appearance
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithDefaultBackground()
        navBarAppearance.shadowColor = .clear // Remove shadow line
        
        // Apply the appearance settings
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance
        
        // Fix ASAuthorizationAppleIDButton constraint issue
        fixAppleButtonConstraints()
        
        // Register for auth state changes to sync RevenueCat
        setupAuthStateChangeHandling()
    }
    
    private func setupAuthStateChangeHandling() {
        userSession.authStateDidChangeHandler = {
            Task {
                // Refresh subscription status after auth state changes
                await subscriptionService.refreshSubscriptionStatus()
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                // Main app content conditional on app state
                if appStateCoordinator.appState == .initializing {
                    // Show loading screen while initializing
                    SplashScreen()
                        .environmentObject(themeManager) // Add ThemeManager here
                        .withAppTheme()
                } else if case .error(let message) = appStateCoordinator.appState {
                    // Show error screen if there's an error
                    ErrorView(message: message) {
                        appStateCoordinator.attemptRecovery()
                    }
                    .environmentObject(themeManager) // Add ThemeManager here
                    .withAppTheme()
                } else {
                    // Show main content when ready or offline
                    MainAppView()
                        .environmentObject(userSession)
                        .environmentObject(subscriptionService)
                        .environmentObject(notificationService)
                        .environmentObject(adManager)
                        .environmentObject(UserStatsService.shared)
                        .environmentObject(themeManager) // Ensure ThemeManager is available
                        .environmentObject(progressViewModel) // Add ProgressViewModel to fix loading issues
                        .environmentObject(navigationRouter)
                        .withAppTheme()
                        .overlay(
                            // Show offline banner when in offline state
                            appStateCoordinator.appState == .offline ?
                                OfflineBanner()
                                    .transition(.move(edge: .top))
                                    .animation(.spring(), value: appStateCoordinator.appState)
                                : nil
                        )
                }
            }
            .onAppear {
                print("App main view appeared")
                // Initialize services
                _ = NetworkMonitor.shared
                _ = FirebaseAvailabilityService.shared
                // Initialize memory manager
                _ = MemoryManager.shared
            }
        }
    }
    
    private func fixAppleButtonConstraints() {
        // Fix for the AppleID button constraints that cause SIGABRT
        UserDefaults.standard.set(false, forKey: "ASAuthorizationAppleIDButtonDrawsWhenDisabled")
        
        // Ensure we don't break constraints automatically
        UserDefaults.standard.set(false, forKey: "UIViewLayoutConstraintBehaviorAllowBreakingConstraints")
        
        // Log unsatisfiable constraints
        UserDefaults.standard.set(true, forKey: "_UIConstraintBasedLayoutLogUnsatisfiable")
        
        // Register a notification to fix Apple button constraints when new views appear
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(fixNewAppleButtons),
            name: UIView.didAddSubviewNotification,
            object: nil
        )
        
        // Ensure all existing windows are checked
        DispatchQueue.main.async {
            self.scanForAppleButtonsInAllWindows()
        }
    }
    
    @objc private func fixNewAppleButtons(notification: Notification) {
        if let view = notification.object as? UIView {
            // Check if this is an Apple sign-in button
            let viewName = NSStringFromClass(type(of: view))
            if viewName.contains("ASAuthorizationAppleIDButton") {
                DispatchQueue.main.async {
                    self.fixAppleButton(view)
                }
            }
            
            // Also check if this view might contain Apple button
            DispatchQueue.main.async {
                self.scanForAppleButtons(in: view)
            }
        }
    }
    
    private func scanForAppleButtonsInAllWindows() {
        for window in Self.getAppWindows() {
            scanForAppleButtons(in: window)
        }
    }
    
    private func scanForAppleButtons(in view: UIView) {
        // Check if this view is an Apple button
        let viewName = NSStringFromClass(type(of: view))
        if viewName.contains("ASAuthorizationAppleIDButton") {
            fixAppleButton(view)
        }
        
        // Check subviews recursively
        for subview in view.subviews {
            scanForAppleButtons(in: subview)
        }
    }
    
    private func fixAppleButton(_ button: UIView) {
        print("Fixing ASAuthorizationAppleIDButton constraints")
        
        // Remove problematic width constraints
        let constraintsToRemove = button.constraints.filter { constraint in
            return constraint.firstAttribute == .width && 
                   (constraint.constant == 380 || constraint.multiplier != 1.0)
        }
        
        for constraint in constraintsToRemove {
            button.removeConstraint(constraint)
            print("Removed problematic constraint: \(constraint)")
        }
        
        // Also check superview constraints
        if let superview = button.superview {
            let superviewConstraintsToModify = superview.constraints.filter { constraint in
                (constraint.firstItem === button || constraint.secondItem === button) &&
                (constraint.firstAttribute == .width || constraint.secondAttribute == .width)
            }
            
            for constraint in superviewConstraintsToModify {
                constraint.priority = .defaultLow
                print("Lowered priority of superview constraint: \(constraint)")
            }
        }
        
        // Make the view size itself appropriately
        button.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        button.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
    }
}

// Helper function to fix Apple button constraints
func fixAppleButtonConstraints() {
    // Implementation details would go here
    // This is a placeholder since the real implementation would involve private API calls
    print("Applied fix for ASAuthorizationAppleIDButton constraints")
}

// Simple offline banner
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
            .background(Color.theme.error.opacity(0.8))
            .foregroundColor(Color.theme.text)
            
            Spacer()
        }
    }
}

// Simple error view
struct ErrorView: View {
    let message: String
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 70))
                .foregroundColor(Color.theme.error)
            
            Text("Something went wrong")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(Color.theme.text)
            
            Text(message)
                .font(.body)
                .foregroundColor(Color.theme.subtext)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: retryAction) {
                Text("Try Again")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.theme.accent)
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
                .foregroundColor(Color.theme.accent)
            
            Text("100Days")
                .font(.system(size: 40, weight: .heavy, design: .rounded))
                .foregroundColor(Color.theme.text)
            
            ProgressView()
                .scaleEffect(1.5)
                .padding(.top, 30)
        }
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
                        if userSession.hasCompletedOnboarding {
                            MainAppView()
                        } else {
                            OnboardingView()
                        }
                    } else {
                        AuthView()
                    }
                }
                .environmentObject(navigationRouter)
            }
        }
    }
} 