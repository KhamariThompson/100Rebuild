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
        // Cleanup synchronously to avoid retain cycles
        // Set operations are thread-safe and don't require MainActor
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
        print("🧹 MainAppViewModel cleanup complete")
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
            // TODO: Trigger paywall via navigation
        }
    }
    
    // MARK: - Private Methods
    
    private func setupAppLifecycleHandling() {
        // CONSOLIDATED: Single subscription for app becoming active
        // Handles both expired challenges AND subscription verification
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                guard let self = self else { return }
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    // Check for expired challenges
                    await self.checkForExpiredChallenges()

                    // Verify subscription status
                    print("🔐 RevenueCat: MainAppViewModel - App became active, verifying subscription status")
                    await SubscriptionStore.shared.load()

                    // Identify current user if needed
                    if let currentUser = Auth.auth().currentUser {
                        print("🔐 RevenueCat: MainAppViewModel - Identifying current user")
                        await SubscriptionStore.shared.identifyUser(currentUser.uid)
                    }
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
        // Monitor the EntitlementsAdapter's hasProAccess property
        EntitlementsAdapter.shared.$hasProAccess
            .sink { [weak self] hasProAccess in
                guard let self = self else { return }
                if self.isProUser != hasProAccess {
                    print("🔐 RevenueCat: MainAppViewModel - Pro status changed to: \(hasProAccess)")
                    self.isProUser = hasProAccess
                }
            }
            .store(in: &cancellables)

        // Listen for subscription status changes via notification
        NotificationCenter.default.publisher(for: NSNotification.Name("SubscriptionStatusChanged"))
            .sink { [weak self] notification in
                guard let self = self else { return }
                if let isProUser = notification.userInfo?["isProUser"] as? Bool {
                    if self.isProUser != isProUser {
                        print("🔐 RevenueCat: MainAppViewModel - Subscription status notification: isProUser=\(isProUser)")
                        self.isProUser = isProUser
                    }
                }
            }
            .store(in: &cancellables)

        // Listen for auth state changes to refresh subscription status
        NotificationCenter.default.publisher(for: NSNotification.Name("AuthStateChanged"))
            .sink { [weak self] _ in
                guard let self = self else { return }
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    print("🔐 RevenueCat: MainAppViewModel - Auth state changed, verifying subscription status")
                    // Verify subscription status when auth state changes
                    if let currentUser = Auth.auth().currentUser {
                        await SubscriptionStore.shared.identifyUser(currentUser.uid)
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupCleanup() {
        // Cleanup will happen in deinit, no need for willTerminate handling
        // which can cause retain cycles
    }
} 