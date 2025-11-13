import Foundation

/// Centralized constants for the 100Days app
/// Eliminates magic strings and improves maintainability
enum Constants {

    // MARK: - Firestore Collections
    enum Firestore {
        static let users = "users"
        static let challenges = "challenges"
        static let checkIns = "checkIns"
        static let friends = "friends"
        static let connections = "connections"
        static let friendRequests = "friendRequests"
        static let communityChallenges = "communityChallenges"
        static let participants = "participants"
        static let posts = "posts"
        static let reactions = "reactions"
    }

    // MARK: - Firestore Fields
    enum FirestoreFields {
        static let status = "status"
        static let timestamp = "timestamp"
        static let userId = "userId"
        static let username = "username"
        static let email = "email"
        static let displayName = "displayName"
        static let profileImageURL = "profileImageURL"
        static let createdAt = "createdAt"
        static let lastModified = "lastModified"
        static let daysCompleted = "daysCompleted"
        static let streakCount = "streakCount"
        static let lastCheckInDate = "lastCheckInDate"
        static let isCompletedToday = "isCompletedToday"
        static let date = "date"
        static let dayNumber = "dayNumber"
        static let note = "note"
    }

    // MARK: - Notification Names
    enum Notifications {
        static let networkStatusChanged = "NetworkStatusChanged"
        static let subscriptionStatusChanged = "SubscriptionStatusChanged"
        static let authStateChanged = "AuthStateChanged"
        static let subscriptionMigrationCompleted = "SubscriptionMigrationCompleted"
        static let subscriptionRenewalIssue = "SubscriptionRenewalIssue"
        static let friendsDidUpdate = "friendsDidUpdate"
        static let friendRequestsDidUpdate = "friendRequestsDidUpdate"
    }

    // MARK: - UserDefaults Keys
    enum CacheKeys {
        static let cachedProStatus = "cachedProStatus"
        static let cachedExpirationDate = "cachedExpirationDate"
        static let offeringsRetryCount = "offeringsRetryCount"
        static let lastSubscriptionCheck = "lastSubscriptionCheck"
        static let hasCompletedSubscriptionMigration = "hasCompletedSubscriptionMigration"
        static let lastUserIdentified = "lastUserIdentified"
        static let lastRevenueCatSync = "lastRevenueCatSync"
        static let subscriptionLastVerified = "subscriptionLastVerified"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let userDisplayName = "userDisplayName"
        static let userEmail = "userEmail"
    }

    // MARK: - Product Identifiers (DEPRECATED - Use SubscriptionIDs instead)
    /// ⚠️ DEPRECATED: Use SubscriptionIDs.ProductID instead
    /// This enum is kept for backward compatibility during migration
    enum ProductID {
        static let monthly       = SubscriptionIDs.ProductID.monthly
        static let annualIntro   = SubscriptionIDs.ProductID.annualIntro
        static let annualNoIntro = SubscriptionIDs.ProductID.annualNoIntro
    }

    // MARK: - Founders Campaign
    enum FoundersCampaign {
        /// Campaign start date: November 1, 2025
        static let startDate: Date = {
            var comps = DateComponents()
            comps.year = 2025
            comps.month = 11
            comps.day = 1
            comps.timeZone = TimeZone.current
            return Calendar.current.date(from: comps)!
        }()

        /// Check if campaign is live (date >= Nov 1, 2025)
        static var isLive: Bool {
            Date() >= startDate
        }
    }

    // MARK: - Onboarding & Grandfathering
    enum Onboarding {
        /// Legacy cutoff date: November 1, 2025 (00:00 UTC)
        /// Users registered BEFORE this date get grandfathered access (1 year free Pro)
        /// Users registered ON OR AFTER this date are new users (must see funnel → paywall)
        /// ⚠️ SINGLE SOURCE OF TRUTH: SubscriptionPolicy.grandfatherCutoffUTC
        static var newFunnelStartDate: Date {
            SubscriptionPolicy.grandfatherCutoffUTC
        }

        /// Founder window cutoff: October 10, 2025 (00:00 UTC)
        /// Users who registered before this date may be eligible for special founder pricing
        static let founderWindowCutoff: Date = {
            var comps = DateComponents()
            comps.year = 2025
            comps.month = 10
            comps.day = 10
            comps.hour = 0
            comps.minute = 0
            comps.second = 0
            comps.timeZone = TimeZone(identifier: "UTC")
            return Calendar.current.date(from: comps)!
        }()

        /// Grandfathered users get 1 year of free Pro from their account creation date
        /// ⚠️ SINGLE SOURCE OF TRUTH: SubscriptionPolicy.grandfatherDurationYears
        static let grandfatherDuration: TimeInterval = 365 * 24 * 60 * 60 // 1 year in seconds (kept for backwards compatibility)

        /// Current funnel schema version - bump this to force re-showing funnel if design changes
        static let funnelSchemaVersion = 1

        /// Grace period for new signups (time window to consider a user "new")
        /// Only users who signed up within this window should see the funnel
        static let newSignupGracePeriod: TimeInterval = 10 * 60 // 10 minutes

        /// Entitlements load timeout - maximum time to wait for RevenueCat before routing
        static let entitlementsLoadTimeout: TimeInterval = 4.0 // 4 seconds
    }

    // MARK: - Feature Flags
    enum FeatureFlags {
        /// Enable new routing v2 logic
        /// Set to false to revert to legacy routing behavior
        static var routingV2Enabled: Bool {
            #if DEBUG
            return UserDefaults.standard.object(forKey: "routing.v2.enabled") as? Bool ?? true
            #else
            return true  // Always enabled in Release
            #endif
        }

        /// Manual override to skip funnel (for support/debug only)
        /// ⚠️ DISABLED in Release builds to prevent revenue bypass
        static var overrideNoFunnel: Bool {
            #if DEBUG
            return UserDefaults.standard.bool(forKey: "override.no_funnel")
            #else
            return false  // Always false in Release - no funnel skipping
            #endif
        }
    }

    // MARK: - RevenueCat (DEPRECATED - Use SubscriptionIDs instead)
    /// ⚠️ DEPRECATED: Use SubscriptionIDs instead
    enum RevenueCat {
        static let proEntitlementID = SubscriptionIDs.proEntitlementID
        static let defaultOfferingID = SubscriptionIDs.defaultOfferingID

        /// Get the RevenueCat API key from Info.plist
        /// - Returns: API key string
        static var apiKey: String {
            if let key = Bundle.main.object(forInfoDictionaryKey: "REVENUECAT_API_KEY") as? String {
                return key
            }

            // Return empty string if not found - configuration error will be caught at runtime
            return ""
        }
    }

    // MARK: - App Configuration
    enum App {
        // No free tier limits - all users get unlimited access
        static let firebaseCacheSizeBytes: Int64 = 5_242_880 // 5MB
        static let memoryWarningCheckInterval: TimeInterval = 5.0 // Seconds
        static let friendListPageSize = 20
        static let feedPageSize = 20
        static let challengeListPageSize = 20
    }

    // MARK: - Timeouts
    enum Timeouts {
        static let purchaseTimeout: TimeInterval = 30 // Seconds
        static let restoreTimeout: TimeInterval = 30
        static let firestoreTimeout: TimeInterval = 10
        static let networkRequestTimeout: TimeInterval = 15
    }

    // MARK: - Error Messages
    enum ErrorMessages {
        static let userNotSignedIn = "You must be signed in to perform this action."
        static let networkOffline = "You're offline. Please check your internet connection."
        static let subscriptionFailed = "The purchase failed to complete."
        static let restoreFailed = "Failed to restore purchases."
        static let proRequired = "Pro subscription required to access this feature."
    }

    // MARK: - Animation Durations
    enum Animation {
        static let short: TimeInterval = 0.2
        static let medium: TimeInterval = 0.3
        static let long: TimeInterval = 0.5
        static let splash: TimeInterval = 1.5  // Minimum splash screen display duration
    }

    // MARK: - URLs
    enum URLs {
        static let privacyPolicy = "https://100days.site/privacy"
        static let termsOfService = "https://100days.site/terms"
        static let support = "https://100days.site/support"
    }
}

// MARK: - Notification.Name Extension
extension Notification.Name {
    static let networkStatusChanged = Notification.Name(Constants.Notifications.networkStatusChanged)
    static let subscriptionStatusChanged = Notification.Name(Constants.Notifications.subscriptionStatusChanged)
    static let authStateChanged = Notification.Name(Constants.Notifications.authStateChanged)
    static let subscriptionMigrationCompleted = Notification.Name(Constants.Notifications.subscriptionMigrationCompleted)
    static let subscriptionRenewalIssue = Notification.Name(Constants.Notifications.subscriptionRenewalIssue)
    static let friendsDidUpdate = Notification.Name(Constants.Notifications.friendsDidUpdate)
    static let friendRequestsDidUpdate = Notification.Name(Constants.Notifications.friendRequestsDidUpdate)
}
