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

    // MARK: - Product Identifiers
    enum Products {
        static let monthlySubscription = "com.KhamariThompson.100Days.monthlyv2"
    }

    // MARK: - RevenueCat
    enum RevenueCat {
        static let proEntitlementID = "Pro"
        static let defaultOfferingID = "default_offerings"

        /// Get the RevenueCat API key from Info.plist
        /// - Returns: API key string
        /// - Note: Falls back to hardcoded key if not found in plist (for backwards compatibility during migration)
        static var apiKey: String {
            if let key = Bundle.main.object(forInfoDictionaryKey: "REVENUECAT_API_KEY") as? String {
                return key
            }

            #if DEBUG
            print("⚠️ REVENUECAT_API_KEY not found in Info.plist, using fallback key")
            print("⚠️ Please add the key to Info.plist for better security")
            #endif

            // Fallback for backwards compatibility (will be removed after migration)
            return "appl_BmXAuCdWBmPoVBAOgxODhJddUvc"
        }
    }

    // MARK: - App Configuration
    enum App {
        static let freeUserFriendLimit = 5
        static let freeUserChallengeLimit = 3
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
        static let friendLimitReached = "You've reached the maximum number of friends for the free tier. Upgrade to Pro for unlimited friends."
        static let challengeLimitReached = "You've reached the maximum number of challenges for the free tier. Upgrade to Pro for unlimited challenges."
    }

    // MARK: - Animation Durations
    enum Animation {
        static let short: TimeInterval = 0.2
        static let medium: TimeInterval = 0.3
        static let long: TimeInterval = 0.5
        static let splash: TimeInterval = 0.5
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
