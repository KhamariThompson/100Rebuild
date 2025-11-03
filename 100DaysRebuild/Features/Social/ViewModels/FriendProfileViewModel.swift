import Foundation
import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Combine

@MainActor
class FriendProfileViewModel: ObservableObject {
    // Published properties
    @Published var friendProfile: FriendProfile?
    @Published var activeChallenges: [FriendChallenge]?
    @Published var recentActivities: [FriendActivity]?
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage: String?

    // Private properties
    private let firestore = Firestore.firestore()
    private let notificationService = NotificationService.shared
    private var cancellables = Set<AnyCancellable>()
    private var loadTask: Task<Void, Never>?

    deinit {
        // Cancellables and tasks will be automatically cleaned up when deallocated
        print("✅ FriendProfileViewModel released")
    }

    // MARK: - Public Methods

    /// Load friend profile data
    func loadFriendProfile(friendId: String) {
        // Cancel any existing load
        loadTask?.cancel()

        // Clear stale data immediately
        friendProfile = nil
        activeChallenges = nil
        recentActivities = nil
        isLoading = true

        loadTask = Task {
            do {
                // Load profile data
                let profile = try await loadProfile(friendId: friendId)
                let challenges = try await loadActiveChallenges(friendId: friendId)
                let activities = try await loadRecentActivities(friendId: friendId)

                guard !Task.isCancelled else { return }

                await MainActor.run {
                    self.friendProfile = profile
                    self.activeChallenges = challenges
                    self.recentActivities = activities
                    self.isLoading = false
                }

            } catch {
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    self.showError(message: "Failed to load profile: \(error.localizedDescription)")
                    self.isLoading = false
                }
            }
        }
    }
    
    /// Refresh friend profile
    func refreshProfile(friendId: String) async {
        await loadFriendProfile(friendId: friendId)
    }
    
    /// Send encouragement to friend
    func sendEncouragement(to friendId: String) async {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            showError(message: "User not signed in")
            return
        }
        
        do {
            // Get current user info
            let userDoc = try await firestore
                .collection("users")
                .document(currentUserId)
                .getDocument()
            
            guard let userData = userDoc.data(),
                  let username = userData["username"] as? String else {
                showError(message: "User data not found")
                return
            }
            
            // Get friend's username
            let friendDoc = try await firestore
                .collection("users")
                .document(friendId)
                .getDocument()
            
            guard let friendData = friendDoc.data(),
                  let friendUsername = friendData["username"] as? String else {
                showError(message: "Friend data not found")
                return
            }
            
            // Create encouragement feed item
            try await SocialFeedViewModel.createFeedItem(
                type: .encouragement,
                description: "@\(username) sent encouragement to @\(friendUsername) 💪"
            )
            
            // Send notification to friend
            try await notificationService.scheduleEncouragementNotification(
                fromUser: username,
                message: "Keep going! You're doing amazing! 💪"
            )
            
            // Show success feedback
            await MainActor.run {
                // Could add a toast or haptic feedback here
                print("✅ Encouragement sent successfully")
            }
            
        } catch {
            showError(message: "Failed to send encouragement: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Methods
    
    private func loadProfile(friendId: String) async throws -> FriendProfile {
        // Get user document
        let userDoc = try await firestore
            .collection("users")
            .document(friendId)
            .getDocument()
        
        guard let userData = userDoc.data() else {
            throw NSError(domain: "FriendProfile", code: 0, userInfo: [NSLocalizedDescriptionKey: "User not found"])
        }
        
        let username = userData["username"] as? String ?? ""
        let displayName = userData["displayName"] as? String
        
        var photoURL: URL? = nil
        if let photoURLString = userData["photoURL"] as? String {
            photoURL = URL(string: photoURLString)
        }
        
        // Get user stats
        let currentStreak = userData["currentStreak"] as? Int ?? 0
        let totalCheckIns = userData["totalCheckIns"] as? Int ?? 0
        let completedChallenges = userData["completedChallenges"] as? Int ?? 0
        
        var joinedDate = Date()
        if let createdAt = userData["createdAt"] as? Timestamp {
            joinedDate = createdAt.dateValue()
        }
        
        var lastActive = Date()
        if let lastActiveTimestamp = userData["lastActive"] as? Timestamp {
            lastActive = lastActiveTimestamp.dateValue()
        }
        
        return FriendProfile(
            id: friendId,
            username: username,
            displayName: displayName,
            photoURL: photoURL,
            currentStreak: currentStreak,
            totalCheckIns: totalCheckIns,
            completedChallenges: completedChallenges,
            joinedDate: joinedDate,
            lastActive: lastActive
        )
    }
    
    private func loadActiveChallenges(friendId: String) async throws -> [FriendChallenge] {
        // Get user's active challenges
        let challengesQuery = try await firestore
            .collection("challenges")
            .whereField("userId", isEqualTo: friendId)
            .whereField("isCompleted", isEqualTo: false)
            .getDocuments()
        
        var challenges: [FriendChallenge] = []
        
        for doc in challengesQuery.documents {
            let data = doc.data()
            let title = data["title"] as? String ?? "Unknown Challenge"
            let daysCompleted = data["daysCompleted"] as? Int ?? 0
            let currentStreak = data["currentStreak"] as? Int ?? 0
            
            let challenge = FriendChallenge(
                id: doc.documentID,
                title: title,
                currentDay: daysCompleted + 1,
                streak: currentStreak
            )
            
            challenges.append(challenge)
        }
        
        return challenges
    }
    
    private func loadRecentActivities(friendId: String) async throws -> [FriendActivity] {
        // Get recent social feed items for this friend
        let feedQuery = try await firestore
            .collection("socialFeed")
            .whereField("userId", isEqualTo: friendId)
            .order(by: "timestamp", descending: true)
            .limit(to: 10)
            .getDocuments()
        
        var activities: [FriendActivity] = []
        
        for doc in feedQuery.documents {
            if let feedItem = SocialFeedItem(from: doc) {
                let activity = FriendActivity(
                    id: feedItem.id,
                    type: feedItem.type,
                    description: feedItem.description,
                    timestamp: feedItem.timestamp
                )
                activities.append(activity)
            }
        }
        
        return activities
    }
    
    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
}
