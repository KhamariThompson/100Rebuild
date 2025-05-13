import Foundation
import SwiftUI

enum SocialAction {
    case loadFriends
    case addFriend
    case removeFriend(friendId: String)
    case loadActivityFeed
    case shareProgress
}

struct SocialState {
    var friends: [Friend] = []
    var communityChallenges: [CommunityChallenge] = []
    var activityFeed: [Activity] = []
    var isLoading: Bool = false
    var error: String?
}

struct Activity: Identifiable {
    let id: String
    let friendId: String
    let type: ActivityType
    let timestamp: Date
}

enum ActivityType {
    case completedDay(day: Int)
    case reachedMilestone(milestone: String)
    case startedChallenge(challenge: String)
}

@MainActor
class SocialViewModel: ObservableObject {
    @Published private(set) var state: SocialState
    @Published private(set) var friends: [Friend] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?
    @Published var showError = false
    @Published var errorMessage = ""
    
    private let socialService = SocialService.shared
    private let subscriptionService = SubscriptionService.shared
    
    init() {
        self.state = SocialState()
    }
    
    func handle(_ action: SocialAction) {
        switch action {
        case .loadFriends:
            // Implementation pending
            break
        case .addFriend:
            // Implementation pending
            break
        case .removeFriend(let friendId):
            // Implementation pending
            print("Will remove friend with ID: \(friendId)")
            break
        case .loadActivityFeed:
            // Implementation pending
            break
        case .shareProgress:
            // Implementation pending
            break
        }
    }
    
    func loadFriends() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            friends = try await socialService.fetchFriends()
        } catch {
            handleError(error)
        }
    }
    
    func sendFriendRequest(to userId: String) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await socialService.sendFriendRequest(to: userId)
        } catch {
            handleError(error)
        }
    }
    
    func acceptFriendRequest(from userId: String) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await socialService.acceptFriendRequest(from: userId)
            await loadFriends()
        } catch {
            handleError(error)
        }
    }
    
    func createGroupChallenge(title: String, participants: [String]) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await socialService.createGroupChallenge(title: title, participants: participants)
        } catch {
            handleError(error)
        }
    }
    
    func joinGroupChallenge(challengeId: String) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await socialService.joinGroupChallenge(challengeId: challengeId)
        } catch {
            handleError(error)
        }
    }
    
    func shareMilestone(challengeId: String, message: String) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await socialService.shareMilestone(challengeId: challengeId, message: message)
        } catch {
            handleError(error)
        }
    }
    
    // Handles and displays errors to the user
    private func handleError(_ error: Error) {
        self.error = error
        
        if let socialError = error as? SocialError {
            switch socialError {
            case .friendLimitReached, .proFeatureRequired:
                // These errors will trigger the paywall in the service layer
                errorMessage = socialError.localizedDescription
                showError = true
            case .networkError, .notFound:
                errorMessage = socialError.localizedDescription
                showError = true
            }
        } else if let proError = error as? ProFeatureError {
            errorMessage = proError.localizedDescription
            showError = true
            subscriptionService.showPaywall = true
        } else {
            errorMessage = "An error occurred: \(error.localizedDescription)"
            showError = true
        }
    }
} 