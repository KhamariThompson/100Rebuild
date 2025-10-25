import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

@MainActor
class FriendSuggestionEngine: ObservableObject {
    static let shared = FriendSuggestionEngine()
    
    @Published var suggestions: [UserSuggestion] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let firestore = Firestore.firestore()
    private let friendService = FriendService.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupFriendUpdatesListener()
    }
    
    func generateSuggestions() async {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        var allSuggestions: [UserSuggestion] = []
        
        do {
            // Get mutual friend suggestions
            let mutualFriendSuggestions = try await findMutualFriendSuggestions(userId: currentUserId)
            allSuggestions.append(contentsOf: mutualFriendSuggestions)
            
            // Get similar challenge suggestions
            let challengeSuggestions = try await findSimilarChallengeSuggestions(userId: currentUserId)
            allSuggestions.append(contentsOf: challengeSuggestions)
            
            // Get recently active suggestions
            let activeSuggestions = try await findRecentlyActiveSuggestions(userId: currentUserId)
            allSuggestions.append(contentsOf: activeSuggestions)
            
            // Include contact-based suggestions
            allSuggestions.append(contentsOf: ContactSyncService.shared.suggestedFriends)
            
            // Remove duplicates and current friends
            let existingFriendIds = Set(friendService.friends.map { $0.id })
            let filteredSuggestions = allSuggestions
                .filter { !existingFriendIds.contains($0.id) }
                .removingDuplicates()
                .sorted { $0.mutualFriends > $1.mutualFriends }
                .prefix(10)
            
            suggestions = Array(filteredSuggestions)
            
        } catch {
            errorMessage = "Failed to generate suggestions: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Suggestion Algorithms
    
    private func findMutualFriendSuggestions(userId: String) async throws -> [UserSuggestion] {
        // Get current user's friends
        let friendsSnapshot = try await firestore
            .collection("friends")
            .document(userId)
            .collection("connections")
            .whereField("status", isEqualTo: "accepted")
            .getDocuments()
        
        let friendIds = friendsSnapshot.documents.map { $0.documentID }
        
        var suggestions: [UserSuggestion] = []
        
        // For each friend, get their friends
        for friendId in friendIds.prefix(10) { // Limit to prevent expensive queries
            let friendOfFriendSnapshot = try await firestore
                .collection("friends")
                .document(friendId)
                .collection("connections")
                .whereField("status", isEqualTo: "accepted")
                .getDocuments()
            
            for doc in friendOfFriendSnapshot.documents {
                let potentialFriendId = doc.documentID
                
                // Skip if it's the current user or already a friend
                guard potentialFriendId != userId,
                      !friendIds.contains(potentialFriendId) else { continue }
                
                // Get user details
                if let userSuggestion = try await createUserSuggestion(
                    userId: potentialFriendId,
                    type: .mutualFriend,
                    mutualFriends: 1
                ) {
                    suggestions.append(userSuggestion)
                }
            }
        }
        
        return suggestions
    }
    
    private func findSimilarChallengeSuggestions(userId: String) async throws -> [UserSuggestion] {
        // Get current user's challenges
        let userChallengesSnapshot = try await firestore
            .collection("challenges")
            .whereField("userId", isEqualTo: userId)
            .whereField("isCompleted", isEqualTo: false)
            .getDocuments()
        
        let userChallengeTypes = Set(userChallengesSnapshot.documents.compactMap { $0.data()["title"] as? String })
        
        guard !userChallengeTypes.isEmpty else { return [] }
        
        // Find users with similar active challenges
        var suggestions: [UserSuggestion] = []
        
        for challengeType in userChallengeTypes.prefix(3) { // Limit queries
            let similarChallengesSnapshot = try await firestore
                .collection("challenges")
                .whereField("title", isEqualTo: challengeType)
                .whereField("isCompleted", isEqualTo: false)
                .whereField("isPublic", isEqualTo: true)
                .limit(to: 20)
                .getDocuments()
            
            for doc in similarChallengesSnapshot.documents {
                guard let challengeUserId = doc.data()["userId"] as? String,
                      challengeUserId != userId else { continue }
                
                if let userSuggestion = try await createUserSuggestion(
                    userId: challengeUserId,
                    type: .similarChallenge,
                    mutualFriends: 0
                ) {
                    suggestions.append(userSuggestion)
                }
            }
        }
        
        return suggestions
    }
    
    private func findRecentlyActiveSuggestions(userId: String) async throws -> [UserSuggestion] {
        let oneDayAgo = Date().addingTimeInterval(-24 * 60 * 60)
        
        // Find users who checked in recently
        let recentActivitySnapshot = try await firestore
            .collection("socialFeed")
            .whereField("timestamp", isGreaterThan: oneDayAgo)
            .whereField("type", isEqualTo: "check_in")
            .order(by: "timestamp", descending: true)
            .limit(to: 30)
            .getDocuments()
        
        var suggestions: [UserSuggestion] = []
        
        for doc in recentActivitySnapshot.documents {
            guard let activityUserId = doc.data()["userId"] as? String,
                  activityUserId != userId else { continue }
            
            if let userSuggestion = try await createUserSuggestion(
                userId: activityUserId,
                type: .recentlyActive,
                mutualFriends: 0
            ) {
                suggestions.append(userSuggestion)
            }
        }
        
        return suggestions
    }
    
    private func createUserSuggestion(
        userId: String,
        type: UserSuggestion.SuggestionType,
        mutualFriends: Int
    ) async throws -> UserSuggestion? {
        let userDoc = try await firestore
            .collection("users")
            .document(userId)
            .getDocument()
        
        guard let userData = userDoc.data(),
              let username = userData["username"] as? String else { return nil }
        
        return UserSuggestion(
            id: userId,
            username: username,
            displayName: userData["displayName"] as? String,
            photoURL: userData["photoURL"] as? String != nil ? URL(string: userData["photoURL"] as! String) : nil,
            suggestionType: type,
            mutualFriends: mutualFriends
        )
    }
    
    private func setupFriendUpdatesListener() {
        // Regenerate suggestions when friends list changes
        NotificationCenter.default.publisher(for: FriendService.friendsDidUpdateNotification)
            .sink { [weak self] _ in
                Task {
                    await self?.generateSuggestions()
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - Array Extension
private extension Array where Element: Identifiable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element.ID>()
        return filter { seen.insert($0.id).inserted }
    }
} 