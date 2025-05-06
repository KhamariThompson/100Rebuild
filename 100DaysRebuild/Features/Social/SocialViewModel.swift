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
    
    private let socialService = SocialService.shared
    
    init() {
        self.state = SocialState()
    }
    
    func handle(_ action: SocialAction) {
        switch action {
        case .loadFriends:
            // TODO: Implement friends loading
            break
        case .addFriend:
            // TODO: Implement friend addition
            break
        case .removeFriend(let friendId):
            // TODO: Implement friend removal using friendId
            print("Will remove friend with ID: \(friendId)")
            break
        case .loadActivityFeed:
            // TODO: Implement activity feed loading
            break
        case .shareProgress:
            // TODO: Implement progress sharing
            break
        }
    }
    
    func loadFriends() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            friends = try await socialService.fetchFriends()
        } catch {
            self.error = error
        }
    }
    
    func sendFriendRequest(to userId: String) async {
        do {
            try await socialService.sendFriendRequest(to: userId)
        } catch {
            self.error = error
        }
    }
    
    func acceptFriendRequest(from userId: String) async {
        do {
            try await socialService.acceptFriendRequest(from: userId)
            await loadFriends()
        } catch {
            self.error = error
        }
    }
    
    func createGroupChallenge(title: String, participants: [String]) async {
        do {
            try await socialService.createGroupChallenge(title: title, participants: participants)
        } catch {
            self.error = error
        }
    }
    
    func joinGroupChallenge(challengeId: String) async {
        do {
            try await socialService.joinGroupChallenge(challengeId: challengeId)
        } catch {
            self.error = error
        }
    }
    
    func shareMilestone(challengeId: String, message: String) async {
        do {
            try await socialService.shareMilestone(challengeId: challengeId, message: message)
        } catch {
            self.error = error
        }
    }
} 