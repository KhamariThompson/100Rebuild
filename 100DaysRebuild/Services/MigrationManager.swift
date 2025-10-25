import Foundation
import FirebaseFirestore
import FirebaseAuth

/// Manages the migration from free/pro model to funnel-based subscription model
///
/// Migration Rules:
/// - All users who registered before Jan 1, 2026 get 1 year free Pro
/// - New users go through funnel → paywall with founder's offer
/// - All features are now unlocked by default (everyone is "Pro")
class MigrationManager: ObservableObject {
    static let shared = MigrationManager()

    @Published var migrationStatus: MigrationStatus = .pending
    @Published var legacyUserGracePeriodEnd: Date?

    private let db = Firestore.firestore()
    private let userDefaults = UserDefaults.standard

    // MARK: - Constants

    private struct Keys {
        static let hasMigrated = "user_has_migrated_v2"
        static let legacyUserGracePeriod = "legacy_user_grace_period_end"
        static let migrationCompletedDate = "migration_completed_date"
        static let firstLaunchDate = "app_first_launch_date"
    }

    private let legacyCutoffDate: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 1
        components.hour = 0
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }()

    // MARK: - Migration Status

    enum MigrationStatus {
        case pending
        case migrating
        case completed
        case failed(Error)
    }

    enum UserType {
        case legacyFree          // Registered before Jan 1 2026, gets 1 year free
        case newUser             // New signup, goes through funnel
        case legacyExpired       // Legacy grace period ended
    }

    // MARK: - Public Methods

    /// Check if user needs migration and perform it
    func checkAndMigrate(for userId: String) async throws {
        // Check if already migrated
        if userDefaults.bool(forKey: Keys.hasMigrated) {
            migrationStatus = .completed
            return
        }

        migrationStatus = .migrating

        do {
            let userType = try await determineUserType(userId: userId)
            try await performMigration(userId: userId, userType: userType)

            // Mark as migrated
            userDefaults.set(true, forKey: Keys.hasMigrated)
            userDefaults.set(Date(), forKey: Keys.migrationCompletedDate)

            migrationStatus = .completed

            print("✅ Migration completed for user: \(userId) | Type: \(userType)")
        } catch {
            migrationStatus = .failed(error)
            print("❌ Migration failed: \(error.localizedDescription)")
            throw error
        }
    }

    /// Determine user type for migration
    func determineUserType(userId: String) async throws -> UserType {
        // Get user registration date from Firestore
        let userDoc = try await db.collection("users").document(userId).getDocument()

        guard let data = userDoc.data(),
              let createdAtTimestamp = data["createdAt"] as? Timestamp else {
            // No data means new user
            return .newUser
        }

        let registrationDate = createdAtTimestamp.dateValue()

        // Check if registered before cutoff
        if registrationDate < legacyCutoffDate {
            // Check if grace period has expired
            if let gracePeriodEnd = legacyUserGracePeriodEnd ?? userDefaults.object(forKey: Keys.legacyUserGracePeriod) as? Date {
                return gracePeriodEnd > Date() ? .legacyFree : .legacyExpired
            }
            return .legacyFree
        }

        return .newUser
    }

    /// Check if user is in legacy grace period
    func isInLegacyGracePeriod() -> Bool {
        guard let gracePeriodEnd = legacyUserGracePeriodEnd ?? userDefaults.object(forKey: Keys.legacyUserGracePeriod) as? Date else {
            return false
        }
        return gracePeriodEnd > Date()
    }

    /// Get days remaining in grace period
    func daysRemainingInGracePeriod() -> Int {
        guard let gracePeriodEnd = legacyUserGracePeriodEnd ?? userDefaults.object(forKey: Keys.legacyUserGracePeriod) as? Date else {
            return 0
        }

        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: gracePeriodEnd)
        return max(0, components.day ?? 0)
    }

    // MARK: - Private Methods

    private func performMigration(userId: String, userType: UserType) async throws {
        switch userType {
        case .legacyFree:
            try await migrateLegacyUser(userId: userId)

        case .newUser:
            try await setupNewUser(userId: userId)

        case .legacyExpired:
            try await handleExpiredLegacyUser(userId: userId)
        }
    }

    /// Migrate legacy users - grant 1 year free Pro
    private func migrateLegacyUser(userId: String) async throws {
        let gracePeriodEnd = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()

        // Store grace period locally
        userDefaults.set(gracePeriodEnd, forKey: Keys.legacyUserGracePeriod)
        legacyUserGracePeriodEnd = gracePeriodEnd

        // Update Firestore
        try await db.collection("users").document(userId).setData([
            "isLegacyUser": true,
            "legacyGracePeriodEnd": Timestamp(date: gracePeriodEnd),
            "subscriptionStatus": "legacy_free",
            "subscriptionTier": "pro",
            "migratedAt": Timestamp(date: Date()),
            "migrationVersion": "v2_funnel"
        ], merge: true)

        print("✅ Legacy user migrated: \(userId) | Grace period until: \(gracePeriodEnd)")
    }

    /// Setup new users (they'll go through funnel)
    private func setupNewUser(userId: String) async throws {
        try await db.collection("users").document(userId).setData([
            "isLegacyUser": false,
            "needsFunnelOnboarding": true,
            "subscriptionStatus": "trial_pending",
            "subscriptionTier": "none",
            "migratedAt": Timestamp(date: Date()),
            "migrationVersion": "v2_funnel"
        ], merge: true)

        print("✅ New user setup: \(userId)")
    }

    /// Handle expired legacy users
    private func handleExpiredLegacyUser(userId: String) async throws {
        try await db.collection("users").document(userId).setData([
            "isLegacyUser": true,
            "legacyGracePeriodExpired": true,
            "subscriptionStatus": "expired",
            "subscriptionTier": "none",
            "migratedAt": Timestamp(date: Date())
        ], merge: true)

        print("⏰ Legacy grace period expired: \(userId)")
    }

    /// Force re-migration (for testing or fixing issues)
    func forceMigration() {
        userDefaults.removeObject(forKey: Keys.hasMigrated)
        userDefaults.removeObject(forKey: Keys.legacyUserGracePeriod)
        userDefaults.removeObject(forKey: Keys.migrationCompletedDate)
        migrationStatus = .pending
        legacyUserGracePeriodEnd = nil

        print("🔄 Migration reset - will re-migrate on next check")
    }

    /// Get migration info for display
    func getMigrationInfo(for userId: String) async throws -> MigrationInfo {
        let userType = try await determineUserType(userId: userId)

        return MigrationInfo(
            userType: userType,
            isLegacyUser: userType == .legacyFree || userType == .legacyExpired,
            gracePeriodEnd: legacyUserGracePeriodEnd,
            daysRemaining: daysRemainingInGracePeriod(),
            hasMigrated: userDefaults.bool(forKey: Keys.hasMigrated)
        )
    }
}

// MARK: - Migration Info

struct MigrationInfo {
    let userType: MigrationManager.UserType
    let isLegacyUser: Bool
    let gracePeriodEnd: Date?
    let daysRemaining: Int
    let hasMigrated: Bool

    var displayMessage: String {
        switch userType {
        case .legacyFree:
            return "You have \(daysRemaining) days of free Pro access as a valued early user!"
        case .newUser:
            return "Welcome! Complete your personalized setup to get started."
        case .legacyExpired:
            return "Your grace period has ended. Subscribe to continue using Pro features."
        }
    }

    var shouldShowFunnel: Bool {
        userType == .newUser
    }

    var shouldShowPaywall: Bool {
        userType == .newUser || userType == .legacyExpired
    }

    var hasActiveAccess: Bool {
        switch userType {
        case .legacyFree:
            return true
        case .newUser, .legacyExpired:
            return false
        }
    }
}
