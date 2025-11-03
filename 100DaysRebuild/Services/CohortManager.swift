import Foundation
import Combine

// MARK: - Cohort Manager
//
// CHANGED: New service for managing user cohorts and paywall business rules
// - Legacy vs new user classification
// - 5-minute timer for Annual plan visibility
// - Founders deadline management (Oct 10, 2025)
// - Persistent storage of cohort data

// MARK: - User Cohort Types

enum UserCohort: String, Codable {
    case legacyPreUpdate = "legacy_pre_update"
    case newAfterUpdate = "new_after_update"
}

// MARK: - Cohort Manager

/// Manages user cohorts and paywall business rules
@MainActor
class CohortManager: ObservableObject {
    static let shared = CohortManager()
    
    // MARK: - Published Properties
    
    @Published private(set) var userCohort: UserCohort = .newAfterUpdate
    @Published private(set) var firstPaywallAt: Date?
    @Published private(set) var paywallTimerElapsed: TimeInterval = 0
    
    // MARK: - Constants
    
    /// Founders deadline - January 1, 2026
    static let foundersDeadline = Calendar.current.date(from: DateComponents(
        year: 2026,
        month: 1,
        day: 1,
        hour: 0,
        minute: 0,
        second: 0
    )) ?? Date()
    
    /// 5-minute timer duration for new users
    static let paywallTimerDuration: TimeInterval = 300 // 5 minutes
    
    // MARK: - Storage Keys
    
    private enum StorageKeys {
        static let userCohort = "UserCohort"
        static let firstPaywallAt = "FirstPaywallAt"
        static let paywallTimerStart = "PaywallTimerStart"
    }
    
    // MARK: - Timer
    
    private var timer: Timer?
    
    // MARK: - Initialization
    
    private init() {
        loadUserCohort()
        loadPaywallTimer()
        setupTimer()
    }
    
    deinit {
        // Timer cleanup handled automatically
    }
    
    // MARK: - Cohort Management
    
    /// Set the user cohort (should only be called once per user)
    func setUserCohort(_ cohort: UserCohort) {
        guard UserDefaults.standard.object(forKey: StorageKeys.userCohort) == nil else {
            print("⚠️ User cohort already set, ignoring update")
            return
        }
        
        userCohort = cohort
        UserDefaults.standard.set(cohort.rawValue, forKey: StorageKeys.userCohort)
        
        print("📊 User cohort set to: \(cohort.rawValue)")
    }
    
    /// Load user cohort from storage
    private func loadUserCohort() {
        if let cohortString = UserDefaults.standard.string(forKey: StorageKeys.userCohort),
           let cohort = UserCohort(rawValue: cohortString) {
            userCohort = cohort
        } else {
            // Default to new user for fresh installs
            userCohort = .newAfterUpdate
        }
        
        print("📊 Loaded user cohort: \(userCohort.rawValue)")
    }
    
    // MARK: - Paywall Timer Management
    
    /// Start the paywall timer for new users
    func startPaywallTimer() {
        guard userCohort == .newAfterUpdate else { return }
        
        let now = Date()
        
        // Set first paywall timestamp if not set
        if firstPaywallAt == nil {
            firstPaywallAt = now
            UserDefaults.standard.set(now, forKey: StorageKeys.firstPaywallAt)
        }
        
        // Set timer start if not set
        if UserDefaults.standard.object(forKey: StorageKeys.paywallTimerStart) == nil {
            UserDefaults.standard.set(now, forKey: StorageKeys.paywallTimerStart)
        }
        
        print("⏱️ Paywall timer started for new user")
    }
    
    /// Load paywall timer state from storage
    private func loadPaywallTimer() {
        firstPaywallAt = UserDefaults.standard.object(forKey: StorageKeys.firstPaywallAt) as? Date
        
        if let timerStart = UserDefaults.standard.object(forKey: StorageKeys.paywallTimerStart) as? Date {
            paywallTimerElapsed = Date().timeIntervalSince(timerStart)
        }
    }
    
    /// Setup timer to update elapsed time
    private func setupTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateTimerElapsed()
            }
        }
    }
    
    /// Update timer elapsed time
    private func updateTimerElapsed() {
        guard let timerStart = UserDefaults.standard.object(forKey: StorageKeys.paywallTimerStart) as? Date else {
            return
        }
        
        paywallTimerElapsed = Date().timeIntervalSince(timerStart)
    }
    
    // MARK: - Business Rules
    
    /// Check if Annual plan should be visible
    func annualVisible(now: Date = Date()) -> Bool {
        switch userCohort {
        case .legacyPreUpdate:
            // Legacy users see Annual until founders deadline
            return now < Self.foundersDeadline
            
        case .newAfterUpdate:
            // New users see Annual only within 5-minute window
            guard let firstPaywall = firstPaywallAt else { return true }
            let elapsed = now.timeIntervalSince(firstPaywall)
            return elapsed < Self.paywallTimerDuration
        }
    }
    
    /// Check if Founders ribbon should be visible
    func foundersRibbonVisible(now: Date = Date()) -> Bool {
        return userCohort == .legacyPreUpdate && now < Self.foundersDeadline
    }
    
    /// Get the appropriate Annual price based on cohort and timing
    func annualPrice(now: Date = Date()) -> String {
        if foundersRibbonVisible(now: now) {
            return "$19.99" // First year founders price
        }
        return "$29.99" // Regular annual price
    }
    
    /// Check if user is in founders period
    func isFoundersPeriod(now: Date = Date()) -> Bool {
        return foundersRibbonVisible(now: now)
    }
    
    /// Get remaining time in paywall timer (for new users)
    func paywallTimerRemaining(now: Date = Date()) -> TimeInterval {
        guard userCohort == .newAfterUpdate,
              let firstPaywall = firstPaywallAt else {
            return 0
        }
        
        let elapsed = now.timeIntervalSince(firstPaywall)
        return max(0, Self.paywallTimerDuration - elapsed)
    }
    
    /// Check if paywall timer has expired
    func paywallTimerExpired(now: Date = Date()) -> Bool {
        return paywallTimerRemaining(now: now) <= 0
    }
    
    // MARK: - Debug Methods
    
    #if DEBUG
    /// Reset cohort and timer data (for testing only)
    func resetForTesting() {
        UserDefaults.standard.removeObject(forKey: StorageKeys.userCohort)
        UserDefaults.standard.removeObject(forKey: StorageKeys.firstPaywallAt)
        UserDefaults.standard.removeObject(forKey: StorageKeys.paywallTimerStart)
        
        userCohort = .newAfterUpdate
        firstPaywallAt = nil
        paywallTimerElapsed = 0
        
        print("🧹 Cohort data reset for testing")
    }
    
    /// Simulate legacy user (for testing)
    func simulateLegacyUser() {
        UserDefaults.standard.removeObject(forKey: StorageKeys.userCohort)
        setUserCohort(.legacyPreUpdate)
        print("🧪 Simulating legacy user")
    }
    
    /// Simulate expired timer (for testing)
    func simulateExpiredTimer() {
        let pastDate = Date().addingTimeInterval(-400) // 6 minutes ago
        UserDefaults.standard.set(pastDate, forKey: StorageKeys.firstPaywallAt)
        UserDefaults.standard.set(pastDate, forKey: StorageKeys.paywallTimerStart)
        
        firstPaywallAt = pastDate
        paywallTimerElapsed = 400
        
        print("🧪 Simulating expired timer")
    }
    #endif
}

// MARK: - Extensions

extension CohortManager {
    /// Get a summary of current cohort state for debugging
    var debugDescription: String {
        let now = Date()
        return """
        CohortManager State:
        - User Cohort: \(userCohort.rawValue)
        - First Paywall: \(firstPaywallAt?.description ?? "nil")
        - Timer Elapsed: \(paywallTimerElapsed)s
        - Annual Visible: \(annualVisible(now: now))
        - Founders Ribbon Visible: \(foundersRibbonVisible(now: now))
        - Timer Remaining: \(paywallTimerRemaining(now: now))s
        """
    }
}
