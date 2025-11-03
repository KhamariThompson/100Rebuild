import Foundation
import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Combine

@MainActor
class SocialFeedViewModel: ObservableObject {
    // Published properties
    @Published var feedItems: [SocialFeedItem] = []
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage: String?
    
    // Private properties
    private let firestore = Firestore.firestore()
    nonisolated(unsafe) private var feedListener: ListenerRegistration?
    private var cancellables = Set<AnyCancellable>()
    
    // Dependencies
    private let friendService = FriendService.shared
    private let notificationService = NotificationService.shared
    
    deinit {
        // Cancellables and listeners will be automatically cleaned up when deallocated
        print("✅ SocialFeedViewModel released")
    }
    
    // MARK: - Public Methods
    
    /// Start listening for social feed updates
    func startListening() {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            showError(message: "User not signed in")
            return
        }
        
        isLoading = true
        
        // Get friend IDs
        let friendIds = friendService.friends.map { $0.id }
        var userIds = friendIds
        userIds.append(currentUserId) // Include current user's activities
        
        if userIds.isEmpty {
            // No friends, show empty state
            feedItems = []
            isLoading = false
            return
        }
        
        // Listen for feed items from friends and self
        stopListening()
        feedListener = firestore
            .collection("socialFeed")
            .whereField("userId", in: userIds)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    Task { @MainActor in
                        self.showError(message: "Failed to load feed: \(error.localizedDescription)")
                    }
                    return
                }
                
                guard let snapshot = snapshot else { return }
                
                let items = snapshot.documents.compactMap { SocialFeedItem(from: $0) }
                
                // Sort by timestamp on the client side to avoid needing a composite index
                let sortedItems = items.sorted { $0.timestamp > $1.timestamp }
                
                Task { @MainActor in
                    self.feedItems = sortedItems
                    self.isLoading = false
                }
            }
    }
    
    /// Stop listening for feed updates
    nonisolated func stopListening() {
        feedListener?.remove()
        feedListener = nil
    }
    
    /// Refresh the feed
    func refreshFeed() async {
        stopListening()
        startListening()
    }
    
    /// Add a reaction to a feed item
    func addReaction(to feedItemId: String, emoji: String) async {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            showError(message: "User not signed in")
            return
        }
        
        do {
            // Get current user's username
            let userDoc = try await firestore
                .collection("users")
                .document(currentUserId)
                .getDocument()
            
            guard let username = userDoc.data()?["username"] as? String else {
                showError(message: "Username not found")
                return
            }
            
            // Check if user already reacted with this emoji
            let existingReaction = try await firestore
                .collection("socialFeedReactions")
                .whereField("feedItemId", isEqualTo: feedItemId)
                .whereField("userId", isEqualTo: currentUserId)
                .whereField("emoji", isEqualTo: emoji)
                .getDocuments()
            
            if !existingReaction.documents.isEmpty {
                // User already reacted with this emoji, remove it
                for doc in existingReaction.documents {
                    try await doc.reference.delete()
                }
            } else {
                // Add new reaction
                let reaction = SocialFeedReaction(
                    feedItemId: feedItemId,
                    userId: currentUserId,
                    username: username,
                    emoji: emoji
                )
                
                try await firestore
                    .collection("socialFeedReactions")
                    .document(reaction.id)
                    .setData(reaction.asDictionary())
                
                // Send notification to the feed item owner (if not self)
                await sendReactionNotification(feedItemId: feedItemId, emoji: emoji, reactorUsername: username)
            }
            
            // Update the feed item's reaction count
            await updateFeedItemReactionCount(feedItemId: feedItemId)
            
        } catch {
            showError(message: "Failed to add reaction: \(error.localizedDescription)")
        }
    }
    
    /// Create a feed item for user activity
    static func createFeedItem(
        type: ActivityType,
        description: String,
        challengeId: String? = nil,
        challengeTitle: String? = nil
    ) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "SocialFeed", code: 0, userInfo: [NSLocalizedDescriptionKey: "User not signed in"])
        }
        
        let firestore = Firestore.firestore()
        
        // Get current user info
        let userDoc = try await firestore
            .collection("users")
            .document(currentUserId)
            .getDocument()
        
        guard let userData = userDoc.data(),
              let username = userData["username"] as? String else {
            throw NSError(domain: "SocialFeed", code: 0, userInfo: [NSLocalizedDescriptionKey: "User data not found"])
        }
        
        let displayName = userData["displayName"] as? String
        var photoURL: URL? = nil
        if let photoURLString = userData["photoURL"] as? String {
            photoURL = URL(string: photoURLString)
        }
        
        // Create feed item
        let feedItem = SocialFeedItem(
            userId: currentUserId,
            username: username,
            displayName: displayName,
            photoURL: photoURL,
            type: type,
            description: description,
            challengeId: challengeId,
            challengeTitle: challengeTitle
        )
        
        // Save to Firestore
        try await firestore
            .collection("socialFeed")
            .document(feedItem.id)
            .setData(feedItem.asDictionary())
    }
    
    // MARK: - Private Methods
    
    private func updateFeedItemReactionCount(feedItemId: String) async {
        do {
            // Get all reactions for this feed item
            let reactions = try await firestore
                .collection("socialFeedReactions")
                .whereField("feedItemId", isEqualTo: feedItemId)
                .getDocuments()
            
            // Count reactions by emoji
            var reactionCounts: [String: Int] = [:]
            for doc in reactions.documents {
                if let reaction = SocialFeedReaction(from: doc) {
                    reactionCounts[reaction.emoji, default: 0] += 1
                }
            }
            
            // Update the feed item
            try await firestore
                .collection("socialFeed")
                .document(feedItemId)
                .updateData(["reactions": reactionCounts])
            
        } catch {
            print("Error updating reaction count: \(error.localizedDescription)")
        }
    }
    
    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
    
    // MARK: - Notification Methods
    
    /// Send a notification when someone reacts to a feed item
    private func sendReactionNotification(feedItemId: String, emoji: String, reactorUsername: String) async {
        do {
            // Get the feed item to find the owner
            let feedItemDoc = try await firestore
                .collection("socialFeed")
                .document(feedItemId)
                .getDocument()
            
            guard let feedItemData = feedItemDoc.data(),
                  let feedItem = SocialFeedItem(from: feedItemDoc),
                  let currentUserId = Auth.auth().currentUser?.uid else {
                return
            }
            
            // Don't send notification if user reacted to their own post
            if feedItem.userId == currentUserId {
                return
            }
            
            // Get challenge title if available
            let challengeTitle = feedItem.challengeTitle ?? "your post"
            
            // Send notification to the feed item owner
            // Note: In a real app, you would need to check if the target user has notifications enabled
            // For now, we'll assume they do
            try await notificationService.scheduleReactionNotification(
                friendName: reactorUsername,
                emoji: emoji,
                challengeTitle: challengeTitle
            )
            
        } catch {
            print("Error sending reaction notification: \(error.localizedDescription)")
        }
    }
    
    /// Send notification for friend check-ins
    static func sendFriendCheckInNotification(
        friendUsername: String,
        challengeTitle: String
    ) async {
        do {
            let notificationService = NotificationService.shared
            try await notificationService.scheduleFriendCheckInNotification(
                friendName: friendUsername,
                challengeTitle: challengeTitle
            )
        } catch {
            print("Error sending friend check-in notification: \(error.localizedDescription)")
        }
    }
    
    /// Send notification for milestone achievements
    static func sendMilestoneNotification(
        friendUsername: String,
        milestone: Int,
        challengeTitle: String
    ) async {
        do {
            let notificationService = NotificationService.shared
            try await notificationService.scheduleMilestoneNotification(
                friendName: friendUsername,
                milestone: milestone,
                challengeTitle: challengeTitle
            )
        } catch {
            print("Error sending milestone notification: \(error.localizedDescription)")
        }
    }
    
    /// Send notification for challenge completion
    static func sendChallengeCompletionNotification(
        friendUsername: String,
        challengeTitle: String
    ) async {
        do {
            let notificationService = NotificationService.shared
            try await notificationService.scheduleChallengeCompletionNotification(
                friendName: friendUsername,
                challengeTitle: challengeTitle
            )
        } catch {
            print("Error sending challenge completion notification: \(error.localizedDescription)")
        }
    }
}
