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

// MARK: - AppDelegate (Optimized)
@preconcurrency
class AppDelegate: NSObject, UIApplicationDelegate {
    private var networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "NetworkMonitor")
    static var firebaseConfigured = false
    static var revenueCatConfigured = false

    // Public helper to configure Firebase as early as possible.
    // This is safe to call multiple times; it will only configure once.
    static func configureFirebaseIfNeeded() {
        guard !AppDelegate.firebaseConfigured && FirebaseApp.app() == nil else { return }

        FirebaseApp.configure()

        let settings = FirestoreSettings()
        let cacheSettings = PersistentCacheSettings(sizeBytes: NSNumber(value: 100 * 1024 * 1024))
        settings.cacheSettings = cacheSettings
        Firestore.firestore().settings = settings

        AppDelegate.firebaseConfigured = true
        // Notify any deferred initializers that Firebase is now configured
        NotificationCenter.default.post(name: NSNotification.Name("FirebaseConfigured"), object: nil)
    }

    @MainActor
    static func configureRevenueCatIfNeeded() {
        RevenueCatManager.configureIfNeeded()
        AppDelegate.revenueCatConfigured = RevenueCatManager.isConfigured
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
    // 1. Configure Firebase FIRST (critical)
    AppDelegate.configureFirebaseIfNeeded()

        // 2. Configure RevenueCat (critical for subscriptions) - runs on main thread
        Task { @MainActor in
            AppDelegate.configureRevenueCatIfNeeded()
        }

        // 3. Initialize AdMob (removed) — no ad SDK in this build

        // 4. Start network monitoring (lightweight)
        startNetworkMonitoring()

        // 5. Memory management
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )

        return true
    }

    @objc private func handleMemoryWarning() {
        URLCache.shared.removeAllCachedResponses()
    }

    private func configureFirebase() {
        // Keep instance wrapper for compatibility; delegate to static helper
        AppDelegate.configureFirebaseIfNeeded()
    }

    private func configureRevenueCat() {
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

            Task { @MainActor [weak self] in
                guard self?.lastNetworkStatus != isConnected else { return }

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

// MARK: - Main App
@main
struct App100Days: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var userSession: UserSession
    @StateObject private var subscriptionStore: SubscriptionStore
    @StateObject private var subscriptionService: SubscriptionService
    @StateObject private var entitlementsAdapter: EntitlementsAdapter
    @StateObject private var notificationService: NotificationService
    @StateObject private var themeManager: ThemeManager
    @StateObject private var progressDashboardViewModel: ProgressDashboardViewModel
    @StateObject private var networkMonitor: NetworkMonitor
    @StateObject private var userStatsService: UserStatsService
    @StateObject private var navigationRouter: NavigationRouter
    @StateObject private var badgeService: BadgeService
    @StateObject private var analyticsService: AnalyticsService

    init() {
        // Ensure Firebase is configured before any singletons/StateObjects access Auth/Firestore
        AppDelegate.configureFirebaseIfNeeded()

        // Configure RevenueCat after Firebase is configured - App init is already on MainActor
        MainActor.assumeIsolated {
            AppDelegate.configureRevenueCatIfNeeded()
        }

        // Initialize all StateObjects after Firebase is configured to avoid early Auth access
        _userSession = StateObject(wrappedValue: UserSession.shared)
        _subscriptionStore = StateObject(wrappedValue: SubscriptionStore.shared)
        _subscriptionService = StateObject(wrappedValue: SubscriptionService.shared)
        _entitlementsAdapter = StateObject(wrappedValue: EntitlementsAdapter(store: SubscriptionStore.shared))
        _notificationService = StateObject(wrappedValue: NotificationService.shared)
        _themeManager = StateObject(wrappedValue: ThemeManager.shared)
        _progressDashboardViewModel = StateObject(wrappedValue: ProgressDashboardViewModel.shared)
        _networkMonitor = StateObject(wrappedValue: NetworkMonitor.shared)
        _userStatsService = StateObject(wrappedValue: UserStatsService.shared)
        _navigationRouter = StateObject(wrappedValue: NavigationRouter())
        _badgeService = StateObject(wrappedValue: BadgeService.shared)
        _analyticsService = StateObject(wrappedValue: AnalyticsService.shared)
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
        }
    }
}

// MARK: - App Content View
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
    @EnvironmentObject var navigationRouter: NavigationRouter
    @StateObject private var appRouter = AppRouter()
    @State private var isInitializing = true
    @State private var forceWelcomeView = false
    @State private var subscriptionLoaded = false
    @State private var accountCreatedAt: Date? = nil
    @State private var completedOnboarding = false
    @State private var previousAuthState: Bool? = nil
    @State private var isAuthResolved = false

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
                    .task {
                        await handleSplashTimeout()
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

                    case .mainPro, .mainFree:
                        MainAppView()
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
                withAnimation(.easeInOut(duration: 0.3)) {
                    // Animate state change
                }
            }
            previousAuthState = newValue
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ForceNavigateToWelcome"))) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                forceWelcomeView = true
            }

            Task { @MainActor in
                await handleForceWelcome()
            }
        }
    }

    // MARK: - Helper Methods

    private func handleSplashTimeout() async {
        // Quick check
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
        await MainActor.run {
            if userSession.authState != .loading {
                withAnimation(.easeInOut(duration: 0.4)) {
                    previousAuthState = userSession.isAuthenticated
                    isInitializing = false
                    isAuthResolved = true
                }
            }
        }

        // Maximum timeout
        try? await Task.sleep(nanoseconds: 1_700_000_000) // 1.7s more (total 2s)
        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.4)) {
                previousAuthState = userSession.isAuthenticated
                isInitializing = false
                isAuthResolved = true
            }
        }

        // Hard timeout - force data to be considered loaded after 3 seconds total
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s more (total 3s)
        await MainActor.run {
            if userSession.isAuthenticated && !subscriptionLoaded {
                print("⚠️ AppContentView: Force loading data after timeout")
                subscriptionLoaded = true
            }
        }
    }

    private func handleFunnelCompletion() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        do {
            try await MigrationManager.shared.markOnboardingCompleted(userId: userId)
            await MainActor.run {
                completedOnboarding = true
            }
            await subscriptionStore.load()
        } catch {
            // Silent error handling
        }
    }

    private func handleAuthChange(isAuth: Bool) async {
        if isAuth, let userId = Auth.auth().currentUser?.uid {
            async let migration = MigrationManager.shared.checkAndMigrate(for: userId)
            async let identity = subscriptionStore.identifyUser(userId)

            do {
                try await migration
            } catch {
                print("❌ Migration failed: \(error.localizedDescription)")
            }
            await identity
            await subscriptionStore.load()

            await MainActor.run {
                checkIfDataLoaded()
            }
        } else {
            await MainActor.run {
                subscriptionLoaded = false
                accountCreatedAt = nil
                completedOnboarding = false
            }
            await subscriptionStore.reset()
        }
    }

    private func handleForceWelcome() async {
        // Reset local navigation state only
        navigationRouter.reset()

        // Don't reset singleton services here - they reset themselves when they receive
        // the "PreparingForSignOut" notification from UserSession.
        // Calling reset() from here while they're @StateObject can cause crashes.

        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s
        if !userSession.isAuthenticated {
            forceWelcomeView = false
        }
    }

    private var shouldShowWelcomeView: Bool {
        return !userSession.isAuthenticated || forceWelcomeView
    }

    private func checkIfDataLoaded() {
        guard userSession.isAuthenticated, !subscriptionLoaded else { return }

        let hasAccountData = accountCreatedAt != nil
        let hasSubscriptionData = subscriptionStore.isPro || subscriptionStore.state.rcIsPro || subscriptionStore.state.isGrandfatherActive

        // More lenient check: if we have account data, consider it ready
        // The subscription state will be updated asynchronously
        let isReady = hasAccountData || hasSubscriptionData

        if isReady {
            print("✅ AppContentView: Data loaded - accountData: \(hasAccountData), subscriptionData: \(hasSubscriptionData)")
            subscriptionLoaded = true
        }
    }
}

// MARK: - Error View
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

// MARK: - Splash Screen
struct SplashScreen: View {
    @State private var opacity = 0.0
    @State private var scale = 0.9
    @State private var rotation = 0.0

    var body: some View {
        ZStack {
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
                ZStack {
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

                    Image(systemName: "checkmark")
                        .font(AppTypography.display())
                        .foregroundStyle(.white)
                        .rotationEffect(.degrees(rotation))
                }

                Text("100Days")
                    .font(AppTypography.largeTitle(.bold))
                    .foregroundStyle(Color.primary)
            }
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                    opacity = 1.0
                    scale = 1.0
                }

                withAnimation(.easeInOut(duration: 1.2)) {
                    rotation = 360
                }
            }
        }
    }
}
