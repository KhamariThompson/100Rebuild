import Foundation

enum SocialAction {
    case loadFriends
    case addFriend
    case removeFriend(friendId: String)
    case loadActivityFeed
    case shareProgress
}

struct SocialState {
    var friends: [Friend] = []
    var activityFeed: [Activity] = []
    var isLoading: Bool = false
    var error: String?
}

struct Friend: Identifiable {
    let id: String
    let name: String
    let avatarURL: URL?
    let currentStreak: Int
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

class SocialViewModel: ViewModel<SocialState, SocialAction> {
    init() {
        super.init(initialState: SocialState())
    }
    
    override func handle(_ action: SocialAction) {
        switch action {
        case .loadFriends:
            // TODO: Implement friends loading
            break
        case .addFriend:
            // TODO: Implement friend addition
            break
        case .removeFriend(let friendId):
            // TODO: Implement friend removal
            break
        case .loadActivityFeed:
            // TODO: Implement activity feed loading
            break
        case .shareProgress:
            // TODO: Implement progress sharing
            break
        }
    }
} 