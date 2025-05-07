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
        // Configure Firebase
        FirebaseApp.configure()
        
        // Enable Firestore offline persistence
        let db = Firestore.firestore()
        let settings = db.settings
        settings.cacheSettings = PersistentCacheSettings(sizeBytes: NSNumber(value: FirestoreCacheSizeUnlimited))
        db.settings = settings
        
        // Set up network connectivity monitoring
        startNetworkMonitoring()
        
        // Fix for navigation layout constraints
        setupNavigationBarAppearance()
        
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
            
            // Perform actions based on network state if needed
            if isConnected {
                // Reconnect services if needed
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
        
        // Fix for SystemInputAssistantView constraint conflicts
        // By setting the appearance directly, we prevent some layout conflicts
        let toolbarAppearance = UIToolbarAppearance()
        toolbarAppearance.configureWithDefaultBackground()
        UIToolbar.appearance().standardAppearance = toolbarAppearance
        UIToolbar.appearance().compactAppearance = toolbarAppearance
        UIToolbar.appearance().scrollEdgeAppearance = toolbarAppearance
        
        // Ensure keyboard dismisses when tapping outside of text fields at UIKit level
        UIScrollView.appearance().keyboardDismissMode = .interactive
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

@main
struct App100Days: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var userSession = UserSession.shared
    @StateObject private var subscriptionService = SubscriptionService.shared
    @StateObject private var notificationService = NotificationService.shared
    @AppStorage("AppTheme") private var appTheme: String = "system"
    
    init() {
        // FirebaseApp is now configured in AppDelegate
        
        // Fix for layout constraints in NavigationViews - an alternative approach
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
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
        }
    }
    
    private func getPreferredColorScheme() -> ColorScheme? {
        switch appTheme {
        case "light":
            return .light
        case "dark":
            return .dark
        default:
            return nil // System default
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
                        .environmentObject(subscriptionService)
                } else {
                    OnboardingView()
                        .environmentObject(subscriptionService)
                }
            } else {
                AuthView()
                    .environmentObject(subscriptionService)
            }
        }
    }
}

