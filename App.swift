import SwiftUI
import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import UIKit
import AuthenticationServices
import Network
import FirebaseFirestore
import MessageUI

class AppDelegate: NSObject, UIApplicationDelegate {
    private var networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "NetworkMonitor")
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Configure Firebase at the very beginning, before any other Firebase-related code
        configureFirebaseOnce()
        
        // Fix for navigation layout constraints
        setupNavigationBarAppearance()
        
        // Fix layout constraint issues specifically
        fixLayoutConstraintIssues()
        
        // Set up network connectivity monitoring after Firebase is configured
        startNetworkMonitoring()
        
        return true
    }
    
    // Helper method to ensure Firebase is only initialized once
    private func configureFirebaseOnce() {
        if FirebaseApp.app() == nil {
            print("DEBUG: Configuring Firebase for the first time")
            FirebaseApp.configure()
            
            // Configure Firestore for offline persistence
            let db = Firestore.firestore()
            let settings = db.settings
            settings.cacheSettings = PersistentCacheSettings(sizeBytes: NSNumber(value: FirestoreCacheSizeUnlimited))
            settings.isPersistenceEnabled = true // Ensure persistence is enabled
            db.settings = settings
            
            // Set a flag to indicate Firebase is initialized
            UserDefaults.standard.set(true, forKey: "firebase_initialized")
            
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
    }
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
    @AppStorage("AppTheme") private var appTheme: String = "system"
    
    init() {
        print("App100Days init - Using AppDelegate for Firebase initialization")
        
        // Ensure Firebase is initialized immediately if AppDelegate hasn't done it yet
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
            print("Firebase configured in App init (fallback)")
            
            // Set Firestore offline persistence settings
            let db = Firestore.firestore()
            let settings = db.settings
            settings.cacheSettings = PersistentCacheSettings(sizeBytes: NSNumber(value: FirestoreCacheSizeUnlimited))
            settings.isPersistenceEnabled = true // Ensure persistence is enabled
            db.settings = settings
            
            // Mark Firebase as initialized
            UserDefaults.standard.set(true, forKey: "firebase_initialized")
        } else {
            print("Firebase already configured by AppDelegate")
        }
        
        // Set up improved navigation bar appearance
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithDefaultBackground()
        navBarAppearance.shadowColor = .clear // Remove shadow line
        
        // Apply the appearance settings
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance
        
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
                } else if case .error(let message) = appStateCoordinator.appState {
                    // Show error screen if there's an error
                    ErrorView(message: message) {
                        appStateCoordinator.attemptRecovery()
                    }
                } else {
                    // Show main content when ready or offline
                    MainTabView()
                        .environmentObject(userSession)
                        .environmentObject(subscriptionService)
                        .environmentObject(notificationService)
                        .environmentObject(adManager)
                        .environmentObject(appTheme)
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
            .background(Color.yellow.opacity(0.8))
            .foregroundColor(.black)
            
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