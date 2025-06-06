import SwiftUI
import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import UIKit
import AuthenticationServices
import Network
import FirebaseFirestore
import MessageUI
import Purchases

// Reduce Firebase cache size from 100MB to 10MB to prevent memory issues
let FirestoreCacheSizeUnlimited: Int64 = 10485760 // 10MB instead of 100MB

class AppDelegate: NSObject, UIApplicationDelegate {
    private var networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "NetworkMonitor")
    static var firebaseConfigured = false
    static var revenueCatConfigured = false
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Configure Firebase at the very beginning
        configureFirebaseOnce()
        
        // Configure RevenueCat after Firebase
        configureRevenueCat()
        
        // Set up transaction observation for StoreKit updates
        observeTransactionUpdates()
        
        // Fix for navigation layout constraints
        setupNavigationBarAppearance()
        
        // Fix layout constraint issues specifically
        fixLayoutConstraintIssues()
        
        // Set up network connectivity monitoring after Firebase is configured
        startNetworkMonitoring()
        
        // Enhanced app state monitoring
        setupAppStateMonitoring()
        
        return true
    }
    
    // Helper method to ensure Firebase is only initialized once
    private func configureFirebaseOnce() {
        guard !AppDelegate.firebaseConfigured else {
            print("DEBUG: Firebase already configured, skipping configuration")
            return
        }
        
        print("DEBUG: Configuring Firebase for the first time")
        FirebaseApp.configure()
        
        // Configure Firestore with minimal settings initially
        let db = Firestore.firestore()
        let settings = db.settings
        settings.isPersistenceEnabled = false // Disable persistence initially
        settings.cacheSizeBytes = 5242880 // 5MB cache
        db.settings = settings
        
        // Mark Firebase as configured using static flag
        AppDelegate.firebaseConfigured = true
        print("DEBUG: Firebase configured with persistence disabled")
    }
    
    private func configureRevenueCat() {
        // Skip if already configured
        guard !AppDelegate.revenueCatConfigured else {
            #if DEBUG
            print("🔐 RevenueCat: Already configured, skipping initialization")
            #endif
            return
        }
        
        // Get the current Firebase user ID if available
        let currentUserId = Auth.auth().currentUser?.uid
        
        #if DEBUG
        print("🔐 RevenueCat: Initial configuration with Firebase UID: \(currentUserId ?? "none")")
        #endif
        
        // Configure RevenueCat with proper production settings
        #if DEBUG
        Purchases.logLevel = .debug // More verbose logging in debug builds
        #else
        Purchases.logLevel = .error // Only log errors in production
        #endif
        
        Purchases.configure(
            with: Configuration.Builder(withAPIKey: "appl_BmXAuCdWBmPoVBAOgxODhJddUvc")
                .with(appUserID: currentUserId) // Use Firebase UID or null at configuration time
                .with(observerMode: false)
                .with(userDefaults: UserDefaults.standard)
                .with(usesStoreKit2IfAvailable: true)
                .build()
        )
        
        // Set the delegate immediately
        Purchases.shared.delegate = SubscriptionService.shared
        
        // Mark as configured to ensure it only happens once
        AppDelegate.revenueCatConfigured = true
        
        #if DEBUG
        print("🔐 RevenueCat: Configured with key: appl_BmXAuCdWBmPoVBAOgxODhJddUvc")
        print("🔐 RevenueCat: Current appUserID: \(Purchases.shared.appUserID)")
        #endif
        
        // Check and log the current environment
        Task {
            do {
                let customerInfo = try await Purchases.shared.customerInfo()
                #if DEBUG
                print("🔐 RevenueCat: Environment = \(customerInfo.entitlementVerification?.environment.rawValue ?? "unknown")")
                print("🔐 RevenueCat: Initial Pro status = \(customerInfo.entitlements["pro"]?.isActive ?? false)")
                #endif
            } catch {
                #if DEBUG
                print("🔐 RevenueCat: Failed to get initial customer info: \(error.localizedDescription)")
                #endif
            }
            
            // Only identify if we have a Firebase user
            if let currentUserId = currentUserId {
                await SubscriptionService.shared.identifyCurrentUser()
            }
        }
    }
    
    // Add transaction observation for StoreKit updates
    private func observeTransactionUpdates() {
        Task {
            for await verificationResult in Transaction.updates {
                if case .verified(let transaction) = verificationResult {
                    #if DEBUG
                    print("🔐 RevenueCat: Transaction update received for: \(transaction.productID)")
                    #endif
                    
                    // Always finish the transaction
                    await transaction.finish()
                    
                    // Refresh subscription status
                    await SubscriptionService.shared.updateSubscriptionStatus()
                }
            }
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
    
    // Function to set up network monitoring with weak self to prevent retain cycles
    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            
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
    
    // Enhanced app state monitoring
    private func setupAppStateMonitoring() {
        // App did become active notification observer
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    @objc private func handleAppDidBecomeActive() {
        #if DEBUG
        print("🔐 RevenueCat: App became active, verifying user identity and subscription")
        #endif
        
        Task {
            // Check if the current user is properly identified with RevenueCat
            if let currentFirebaseUID = Auth.auth().currentUser?.uid {
                #if DEBUG
                print("🔐 RevenueCat: Current Firebase UID: \(currentFirebaseUID)")
                print("🔐 RevenueCat: Current RevenueCat appUserID: \(Purchases.shared.appUserID)")
                #endif
                
                if Purchases.shared.appUserID != currentFirebaseUID {
                    #if DEBUG
                    print("🔐 RevenueCat: Identity mismatch detected, re-identifying user")
                    #endif
                    await SubscriptionService.shared.identifyCurrentUser()
                } else {
                    #if DEBUG
                    print("🔐 RevenueCat: User identity matches")
                    #endif
                }
                
                // Refresh subscription status
                await SubscriptionService.shared.updateSubscriptionStatus()
                
                // Log environment
                #if DEBUG
                do {
                    let customerInfo = try await Purchases.shared.customerInfo()
                    print("🔐 RevenueCat: Environment = \(customerInfo.entitlementVerification?.environment.rawValue ?? "unknown")")
                    print("🔐 RevenueCat: Pro status = \(customerInfo.entitlements["pro"]?.isActive ?? false)")
                } catch {
                    print("🔐 RevenueCat: Failed to get customer info: \(error.localizedDescription)")
                }
                #endif
            } else {
                #if DEBUG
                print("🔐 RevenueCat: No Firebase user logged in")
                #endif
            }
        }
    }
    
    deinit {
        networkMonitor.cancel()
        print("✅ AppDelegate released")
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
    
    // Only keep essential services at startup
    @StateObject private var appStateCoordinator = AppStateCoordinator.shared
    @StateObject private var userSession = UserSession.shared
    @StateObject private var themeManager = ThemeManager.shared
    
    init() {
        print("App100Days init - Using AppDelegate for Firebase initialization")
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if appStateCoordinator.appState == .initializing {
                    SplashScreen()
                        .environmentObject(themeManager)
                } else if case .error(let message) = appStateCoordinator.appState {
                    ErrorView(message: message) {
                        appStateCoordinator.attemptRecovery()
                    }
                    .environmentObject(themeManager)
                } else {
                    // Debug print to verify onboarding status
                    let _ = print("DEBUG: User authenticated: \(userSession.isAuthenticated), hasCompletedOnboarding: \(userSession.hasCompletedOnboarding)")
                    
                    if userSession.isAuthenticated && !userSession.hasCompletedOnboarding {
                        OnboardingView()
                            .environmentObject(userSession)
                            .environmentObject(themeManager)
                            .environmentObject(appStateCoordinator)
                    } else {
                        MainAppView()
                            .environmentObject(userSession)
                            .environmentObject(themeManager)
                            .environmentObject(appStateCoordinator)
                            .overlay(
                                appStateCoordinator.appState == .offline ?
                                    OfflineBanner()
                                        .transition(.move(edge: .top))
                                        .animation(.spring(), value: appStateCoordinator.appState)
                                    : nil
                            )
                    }
                }
            }
            .onAppear {
                print("App main view appeared")
            }
        }
    }
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
    @State private var isInitializing = true // Changed to true to show splash screen initially
    
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
                        // After a short delay, set isInitializing to false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isInitializing = false
                            }
                        }
                    }
            } else {
                Group {
                    if userSession.isAuthenticated {
                        if userSession.hasCompletedOnboarding {
                            MainAppView()
                                .environmentObject(navigationRouter)
                                .transition(.opacity.animation(.easeInOut(duration: 0.3)))
                        } else {
                            OnboardingView()
                                .transition(.opacity.animation(.easeInOut(duration: 0.3)))
                        }
                    } else {
                        AuthView()
                            .transition(.opacity.animation(.easeInOut(duration: 0.3)))
                    }
                }
                .environmentObject(navigationRouter)
            }
        }
    }
} 