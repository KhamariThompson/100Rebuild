import SwiftUI
import Combine
import FirebaseAuth

@MainActor
class MainAppViewModel: ObservableObject {
    // Published properties
    @Published var showNotificationSettings = false
    @Published var showPaywall = false
    @Published var isProUser = false
    
    // Services (injected through the environment)
    // No more direct static references to .shared instances
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupCleanup()
        setupSubscriptionMonitoring()
        setupAppLifecycleHandling()
    }
    
    deinit {
        print("✅ MainAppViewModel released")
        // Safe to call nonisolated cleanup from deinit
        nonisolatedCleanup()
    }
    
    // MARK: - Public Methods
    
    func onAppear(updateSafeArea: () -> Void) {
        // Update safe area
        updateSafeArea()
    }
    
    func handleOrientationChange(updateSafeArea: () -> Void) {
        updateSafeArea()
    }
    
    func handleNotificationSettingsRequest() {
        withAnimation {
            showNotificationSettings = true
        }
    }
    
    func showPaywallForFeature() {
        withAnimation {
            showPaywall = true
            // Also set the subscription service property to ensure consistency
            SubscriptionService.shared.showPaywall = true
        }
    }
    
    // MARK: - Private Methods
    
    private func setupAppLifecycleHandling() {
        // Listen for app becoming active to check for expired challenges
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task {
                    await self?.checkForExpiredChallenges()
                }
            }
            .store(in: &cancellables)
    }
    
    /// Check for expired challenges when the app becomes active
    private func checkForExpiredChallenges() async {
        guard Auth.auth().currentUser != nil else { return }
        
        // Use ChallengeService to check for expired challenges
        do {
            // Get expired challenges
            let expiredChallenges = await ChallengeService.shared.checkForExpiredChallenges()
            
            // If there are expired challenges, post a notification for the ChallengesViewModel to handle
            if !expiredChallenges.isEmpty {
                // Post notification so the ChallengesViewModel can handle showing the alert
                NotificationCenter.default.post(
                    name: NSNotification.Name("CheckForExpiredChallenges"),
                    object: nil
                )
            }
        } catch {
            print("Error checking for expired challenges: \(error.localizedDescription)")
        }
    }
    
    private func setupSubscriptionMonitoring() {
        // Monitor the subscription service's showPaywall property
        SubscriptionService.shared.$showPaywall
            .sink { [weak self] showPaywall in
                guard let self = self else { return }
                if showPaywall != self.showPaywall {
                    // Update our local property to match the service
                    DispatchQueue.main.async {
                        withAnimation {
                            self.showPaywall = showPaywall
                        }
                    }
                }
            }
            .store(in: &cancellables)
            
        // Monitor the subscription service's isProUser property
        SubscriptionService.shared.$isProUser
            .sink { [weak self] isProUser in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    if self.isProUser != isProUser {
                        print("🔐 RevenueCat: MainAppViewModel - Pro status changed to: \(isProUser)")
                        self.isProUser = isProUser
                    }
                }
            }
            .store(in: &cancellables)
            
        // Also listen for subscription status changes via notification
        NotificationCenter.default.publisher(for: NSNotification.Name("SubscriptionStatusChanged"))
            .sink { [weak self] notification in
                guard let self = self else { return }
                if let isProUser = notification.userInfo?["isProUser"] as? Bool {
                    DispatchQueue.main.async {
                        if self.isProUser != isProUser {
                            print("🔐 RevenueCat: MainAppViewModel - Subscription status notification: isProUser=\(isProUser)")
                            self.isProUser = isProUser
                        }
                    }
                }
            }
            .store(in: &cancellables)
        
        // Add listener for when the app becomes active to validate subscription status
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                guard let _ = self else { return }
                print("🔐 RevenueCat: MainAppViewModel - App became active, verifying subscription status")
                Task {
                    // Force refresh subscription status
                    await SubscriptionService.shared.updateSubscriptionStatus()
                    
                    // Attempt to migrate subscription from anonymous user if needed
                    if Auth.auth().currentUser != nil {
                        print("🔐 RevenueCat: MainAppViewModel - Checking for anonymous subscription to migrate")
                        let migrationOccurred = await SubscriptionService.shared.migrateAnonymousSubscription()
                        print("🔐 RevenueCat: MainAppViewModel - Migration result: \(migrationOccurred ? "Transferred subscription" : "No migration needed")")
                    }
                }
            }
            .store(in: &cancellables)
        
        // Listen for auth state changes to refresh subscription status
        NotificationCenter.default.publisher(for: NSNotification.Name("AuthStateChanged"))
            .sink { [weak self] _ in
                guard let _ = self else { return }
                print("🔐 RevenueCat: MainAppViewModel - Auth state changed, verifying subscription status")
                Task {
                    // Verify subscription status when auth state changes
                    await SubscriptionService.shared.identifyCurrentUser()
                    
                    // Also attempt migration after auth state changes (e.g., user logs in)
                    if Auth.auth().currentUser != nil {
                        print("🔐 RevenueCat: MainAppViewModel - Auth state changed, checking for subscription migration")
                        _ = await SubscriptionService.shared.migrateAnonymousSubscription()
                    }
                }
            }
            .store(in: &cancellables)
            
        // Listen for successful subscription migrations
        NotificationCenter.default.publisher(for: NSNotification.Name("SubscriptionMigrationCompleted"))
            .sink { [weak self] notification in
                guard let _ = self else { return }
                if let originalUserId = notification.userInfo?["originalAppUserId"] as? String {
                    print("🔐 RevenueCat: MainAppViewModel - Subscription successfully migrated from user: \(originalUserId)")
                    // Could add UI feedback here if desired
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupCleanup() {
        // Store the workItem for cleanup
        NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)
            .sink { [weak self] _ in
                self?.nonisolatedCleanup()
            }
            .store(in: &cancellables)
    }
    
    /// Cleanup method that can be safely called from any thread
    /// Set and Cancellable operations are thread-safe
    @MainActor(unsafe)
    private func nonisolatedCleanup() {
        print("🧹 MainAppViewModel cleaning up")
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }
} 