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
    @State private var isAnimating = false
    @State private var showContent = false
    @State private var progressValue: CGFloat = 0.0
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            // Animated gradient background
            LinearGradient(
                colors: colorScheme == .dark ?
                    [Color.theme.background, Color.theme.accent.opacity(0.15)] :
                    [Color.theme.background, Color.theme.accent.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .hueRotation(.degrees(isAnimating ? 10 : 0))
            .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isAnimating)

            VStack(spacing: 32) {
                // Animated circular progress with "100" inside
                ZStack {
                    // Outer glow ring
                    Circle()
                        .stroke(
                            Color.theme.accent.opacity(0.2),
                            lineWidth: 2
                        )
                        .frame(width: 140, height: 140)
                        .scaleEffect(isAnimating ? 1.1 : 1.0)
                        .opacity(isAnimating ? 0.3 : 0.8)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)

                    // Animated progress ring
                    Circle()
                        .trim(from: 0, to: progressValue)
                        .stroke(
                            LinearGradient(
                                colors: [Color.theme.accent, Color.theme.accent.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                        .rotationEffect(.degrees(isAnimating ? 360 : 0))
                        .animation(.linear(duration: 2.0).repeatForever(autoreverses: false), value: isAnimating)

                    // Inner circle background
                    Circle()
                        .fill(colorScheme == .dark ? Color.theme.background : Color.white)
                        .frame(width: 100, height: 100)
                        .shadow(color: Color.theme.accent.opacity(0.3), radius: 20, x: 0, y: 5)

                    // "100" text
                    Text("100")
                        .font(AppTypography.display(.bold))
                        .foregroundColor(.theme.accent)
                        .opacity(showContent ? 1 : 0)
                        .scaleEffect(showContent ? 1 : 0.5)
                }
                .opacity(showContent ? 1 : 0)
                .scaleEffect(showContent ? 1 : 0.8)

                // App name with animated appearance
                VStack(spacing: 8) {
                    Text("100Days")
                        .font(AppTypography.largeTitle(.bold))
                        .foregroundColor(.primary)
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)

                    Text("Start Your Journey")
                        .font(AppTypography.callout(.medium))
                        .foregroundColor(.secondary)
                        .opacity(showContent ? 0.7 : 0)
                        .offset(y: showContent ? 0 : 20)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                showContent = true
            }

            withAnimation(.easeInOut(duration: 1.2).delay(0.2)) {
                progressValue = 0.75
            }

            withAnimation(.linear(duration: 0.1).delay(0.3)) {
                isAnimating = true
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
    #if DEBUG
    private var subscriptionService: SubscriptionService?  // DEBUG only
    #endif
    private var networkMonitor: NetworkMonitor?

    func start() async {
        // Track startup time to ensure minimum splash display duration
        let startTime = Date()

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

        // Step 2.5: Validate RevenueCat configuration (non-blocking)
        Task {
            await SubscriptionIDs.performRuntimeValidation()
        }

        // Step 3: Initialize critical services (lazy - won't init until accessed)
        userSession = UserSession.shared
        subscriptionStore = SubscriptionStore.shared
        #if DEBUG
        subscriptionService = SubscriptionService.shared  // DEBUG only - use subscriptionStore in Release
        #endif
        networkMonitor = NetworkMonitor.shared

        // Step 4: Ensure minimum splash screen display time
        let elapsed = Date().timeIntervalSince(startTime)
        let minimumDuration = Constants.Animation.splash
        if elapsed < minimumDuration {
            let remainingTime = minimumDuration - elapsed
            try? await Task.sleep(nanoseconds: UInt64(remainingTime * 1_000_000_000))
        }

        // Step 5: Mark ready - services handle their own async initialization
        isReady = true
    }

    func getUserSession() -> UserSession { userSession ?? UserSession.shared }
    func getSubscriptionStore() -> SubscriptionStore { subscriptionStore ?? SubscriptionStore.shared }
    #if DEBUG
    func getSubscriptionService() -> SubscriptionService { subscriptionService ?? SubscriptionService.shared }
    #endif
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
                    #if DEBUG
                    .environmentObject(startupCoordinator.getSubscriptionService())
                    #endif
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
                // Show immediately - enhanced splash
                SplashScreen()
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
    #if DEBUG
    @EnvironmentObject var subscriptionService: SubscriptionService  // DEBUG only
    #endif
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
    @State private var checkDataTask: Task<Void, Never>? = nil

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
                    hasCompletedFunnel: userSession.hasCompletedFunnel,
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
                        // Show Founder's Offer if 5-minute window is active, otherwise regular paywall
                        Group {
                            if let window = subscriptionStore.getFiveMinuteWindow(), window.isActive {
                                FoundersOfferView()
                            } else {
                                PaywallView()
                            }
                        }
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
        // CRITICAL: These handlers must be outside the if/else to prevent deadlock
        // where authenticated users get stuck on splash because onChange never fires
        .task {
            // Initialize state from services immediately on appear
            accountCreatedAt = userSession.accountCreatedAt
            completedOnboarding = userSession.hasCompletedOnboarding
            checkIfDataLoaded()
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
        .onChange(of: subscriptionStore.isLoading) { _ in
            // Also check when loading state changes
            checkIfDataLoaded()
        }
        .onChange(of: userSession.isAuthenticated) { newValue in
            // Handle auth state changes
            if let previous = previousAuthState, previous != newValue {
                previousAuthState = newValue
            } else {
                previousAuthState = newValue
            }

            // Trigger auth change handler
            Task {
                await handleAuthChange(isAuth: newValue)
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
                accountCreatedAt = nil
                completedOnboarding = false
            }

            guard let userId = Auth.auth().currentUser?.uid else { return }

            await subscriptionStore.identifyUser(userId)
            await subscriptionStore.load()

            await MainActor.run {
                subscriptionLoaded = true
            }
        } else {
            // User signed out - reset all state
            await subscriptionStore.reset()
            await MainActor.run {
                subscriptionLoaded = false
                accountCreatedAt = nil
                completedOnboarding = false
                isAuthResolved = false
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
        // Cancel any pending check to debounce rapid calls
        checkDataTask?.cancel()

        // Debounce rapid calls by delaying execution slightly
        checkDataTask = Task { @MainActor in
            // Small delay to coalesce multiple rapid calls
            try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds

            guard !Task.isCancelled else { return }

            let hasAccountData = userSession.accountCreatedAt != nil
            let hasSubscriptionData = !subscriptionStore.isLoading

            // For authenticated users, require BOTH account and subscription data
            // For non-authenticated users, just subscription data is enough
            let isReady: Bool
            if userSession.isAuthenticated {
                isReady = hasAccountData && hasSubscriptionData
            } else {
                isReady = hasSubscriptionData
            }

            #if DEBUG
            print("🔍 AppContentView.checkIfDataLoaded:")
            print("   - userSession.isAuthenticated: \(userSession.isAuthenticated)")
            print("   - hasAccountData: \(hasAccountData), hasSubscriptionData: \(hasSubscriptionData)")
            print("   - isReady: \(isReady), subscriptionLoaded: \(subscriptionLoaded)")
            #endif

            if isReady {
                #if DEBUG
                print("✅ AppContentView: Data loaded - setting subscriptionLoaded = true")
                #endif
                subscriptionLoaded = true
            }
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
