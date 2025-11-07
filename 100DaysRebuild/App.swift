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
import StoreKit

// MARK: - Splash Screen
struct SplashScreen: View {
    var body: some View {
        ZStack {
            Color.theme.background.ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.theme.accent)
                Text("100Days")
                    .font(.largeTitle.bold())
            }
        }
    }
}

// MARK: - Offline Banner
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

// MARK: - AppDelegate (Lightweight)
@preconcurrency
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Minimal work only - everything else deferred to StartupCoordinator
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
}

// MARK: - SceneDelegate
class SceneDelegate: NSObject, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        window = UIWindow(windowScene: windowScene)

        if let urlContext = options.urlContexts.first {
            GIDSignIn.sharedInstance.handle(urlContext.url)
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        GIDSignIn.sharedInstance.handle(url)
    }
}

// MARK: - Startup Coordinator (Defers Heavy Work)
@MainActor
class StartupCoordinator: ObservableObject {
    @Published var isReady = false

    private var userSession: UserSession?
    private var subscriptionStore: SubscriptionStore?
    private var subscriptionService: SubscriptionService?
    private var networkMonitor: NetworkMonitor?

    func start() async {
        // Step 1: Configure Firebase (blocking but necessary)
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()

            let settings = FirestoreSettings()
            let cacheSettings = PersistentCacheSettings(sizeBytes: NSNumber(value: 100 * 1024 * 1024))
            settings.cacheSettings = cacheSettings
            Firestore.firestore().settings = settings
        }

        // Post notification that Firebase is configured (whether newly configured or already was)
        // This ensures UserSession sets up its auth state listener
        NotificationCenter.default.post(name: NSNotification.Name("FirebaseConfigured"), object: nil)

        // Step 2: Configure RevenueCat AFTER Firebase
        RevenueCatManager.configureIfNeeded()

        // Step 3: Initialize critical services (lazy - won't init until accessed)
        userSession = UserSession.shared
        subscriptionStore = SubscriptionStore.shared
        subscriptionService = SubscriptionService.shared
        networkMonitor = NetworkMonitor.shared

        // Step 3.5: Wait for UserSession to complete its async setup
        // This ensures the auth state listener is set up before showing UI
        await userSession?.waitForSetup()

        // Step 4: Mark ready
        isReady = true
    }

    func getUserSession() -> UserSession { userSession ?? UserSession.shared }
    func getSubscriptionStore() -> SubscriptionStore { subscriptionStore ?? SubscriptionStore.shared }
    func getSubscriptionService() -> SubscriptionService { subscriptionService ?? SubscriptionService.shared }
    func getNetworkMonitor() -> NetworkMonitor { networkMonitor ?? NetworkMonitor.shared }
}

// MARK: - Main App (Optimized for Instant Launch)
@main
struct App100Days: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var startupCoordinator = StartupCoordinator()
    @StateObject private var themeManager = ThemeManager.shared

    var body: some Scene {
        WindowGroup {
            if startupCoordinator.isReady {
                AppContentView()
                    .environmentObject(startupCoordinator.getUserSession())
                    .environmentObject(startupCoordinator.getSubscriptionStore())
                    .environmentObject(startupCoordinator.getSubscriptionService())
                    .environmentObject(EntitlementsAdapter(store: startupCoordinator.getSubscriptionStore()))
                    .environmentObject(NotificationService.shared)
                    .environmentObject(themeManager)
                    .environmentObject(ProgressDashboardViewModel.shared)
                    .environmentObject(startupCoordinator.getNetworkMonitor())
                    .environmentObject(UserStatsService.shared)
                    .environmentObject(NavigationRouter())
                    .environmentObject(BadgeService.shared)
                    .environmentObject(AnalyticsService.shared)
            } else {
                // Show immediately - minimal splash
                ZStack {
                    Color.theme.background.ignoresSafeArea()
                    VStack(spacing: 20) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.theme.accent)
                        Text("100Days")
                            .font(.largeTitle.bold())
                    }
                }
                .task {
                    await startupCoordinator.start()
                }
            }
        }
    }
}

// MARK: - App Content View
struct AppContentView: View {
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var subscriptionService: SubscriptionService
    @EnvironmentObject var entitlementsAdapter: EntitlementsAdapter
    @EnvironmentObject var notificationService: NotificationService
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var progressDashboardViewModel: ProgressDashboardViewModel
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var userStatsService: UserStatsService
    @EnvironmentObject var badgeService: BadgeService
    @EnvironmentObject var navigationRouter: NavigationRouter
    @StateObject private var appRouter = AppRouter()
    @State private var isInitializing = false
    @State private var forceWelcomeView = false
    @State private var subscriptionLoaded = false
    @State private var accountCreatedAt: Date? = nil
    @State private var completedOnboarding = false
    @State private var previousAuthState: Bool? = nil
    @State private var isAuthResolved = true

    var body: some View {
        ZStack {
            Color.theme.background
                .ignoresSafeArea()

            let shouldShowSplash = isInitializing ||
                                   (userSession.authState == .loading && !isAuthResolved) ||
                                   (userSession.isAuthenticated && !subscriptionLoaded && isAuthResolved)

            if shouldShowSplash {
                SplashScreen()
                    .transition(.opacity)
                    .onAppear {
                        isInitializing = false
                        isAuthResolved = true
                    }
            } else {
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
                        SplashScreen()
                            .transition(.opacity)

                    case .funnel:
                        ImprovedFunnelView {
                            Task {
                                await handleFunnelCompletion()
                            }
                        }
                        .transition(.opacity)

                    case .mainPro:
                        MainAppView()
                            .transition(.opacity)

                    case .paywall:
                        PaywallView()
                            .transition(.opacity)
                    }
                }
                .environmentObject(navigationRouter)
                .animation(.easeInOut(duration: 0.3), value: route)
                .animation(.easeInOut(duration: 0.3), value: userSession.isAuthenticated)
                .animation(.easeInOut(duration: 0.3), value: forceWelcomeView)
                .onReceive(userSession.$authState) { state in
                    if state != .loading {
                        withAnimation {
                            isAuthResolved = true
                        }
                    }
                }
                .onChange(of: subscriptionLoaded) { loaded in
                    Task { @MainActor in
                        if loaded {
                            appRouter.markEntitlementsLoaded()
                        } else if userSession.isAuthenticated {
                            appRouter.startEntitlementsTimer()
                        }
                    }
                }
                .onChange(of: userSession.accountCreatedAt) { newValue in
                    accountCreatedAt = newValue
                    checkIfDataLoaded()
                }
                .onChange(of: userSession.hasCompletedOnboarding) { newValue in
                    completedOnboarding = newValue
                    checkIfDataLoaded()
                }
                .onChange(of: subscriptionStore.isPro) { _ in
                    checkIfDataLoaded()
                }
                .onChange(of: subscriptionStore.state.isGrandfatherActive) { _ in
                    checkIfDataLoaded()
                }
                .task {
                    accountCreatedAt = userSession.accountCreatedAt
                    completedOnboarding = userSession.hasCompletedOnboarding
                    checkIfDataLoaded()
                }
                .onChange(of: userSession.isAuthenticated) { isAuth in
                    Task {
                        await handleAuthChange(isAuth: isAuth)
                    }
                }
            }

            if !networkMonitor.isConnected {
                VStack {
                    OfflineBanner()
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut, value: networkMonitor.isConnected)
                .zIndex(100)
            }
        }
        .onChange(of: userSession.isAuthenticated) { newValue in
            if let previous = previousAuthState, previous != newValue {
                previousAuthState = newValue
            } else {
                previousAuthState = newValue
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ForceNavigateToWelcome"))) { _ in
            Task { @MainActor in
                forceWelcomeView = true
                await handleForceWelcome()
            }
        }
    }

    // MARK: - Helper Methods

    private func handleFunnelCompletion() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        Task { @MainActor in
            async let migration = MigrationManager.shared.checkAndMigrate(for: userId)
            async let identity = subscriptionStore.identifyUser(userId)

            do {
                try await migration
            } catch {
                #if DEBUG
                print("❌ Migration failed: \(error.localizedDescription)")
                #endif
            }
            await identity
            await subscriptionStore.load()

            await MainActor.run {
                subscriptionLoaded = true
            }
        }
    }

    private func handleAuthChange(isAuth: Bool) async {
        if isAuth {
            await MainActor.run {
                subscriptionLoaded = false
            }

            guard let userId = Auth.auth().currentUser?.uid else { return }

            await subscriptionStore.identifyUser(userId)
            await subscriptionStore.load()

            await MainActor.run {
                subscriptionLoaded = true
            }
        } else {
            await subscriptionStore.reset()
            await MainActor.run {
                subscriptionLoaded = false
            }
        }
    }

    private func handleForceWelcome() async {
        navigationRouter.reset()
        if !userSession.isAuthenticated {
            forceWelcomeView = false
        }
    }

    private var shouldShowWelcomeView: Bool {
        return !userSession.isAuthenticated || forceWelcomeView
    }

    private func checkIfDataLoaded() {
        let hasAccountData = userSession.accountCreatedAt != nil
        let hasSubscriptionData = !subscriptionStore.isLoading

        let isReady = hasAccountData || hasSubscriptionData

        if isReady {
            #if DEBUG
            print("✅ AppContentView: Data loaded - accountData: \(hasAccountData), subscriptionData: \(hasSubscriptionData)")
            #endif
            subscriptionLoaded = true
        }
    }
}

// MARK: - Error View
struct ErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.red)

            Text(message)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Retry", action: retry)
                .buttonStyle(.borderedProminent)
        }
    }
}
