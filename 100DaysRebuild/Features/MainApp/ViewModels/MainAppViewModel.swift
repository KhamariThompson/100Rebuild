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