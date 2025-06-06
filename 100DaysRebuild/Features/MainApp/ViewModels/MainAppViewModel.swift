import SwiftUI
import Combine

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
                    await SubscriptionService.shared.updateSubscriptionStatus(forceReset: false)
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