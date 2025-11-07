import Foundation
import SwiftUI

enum SocialError: Error, LocalizedError {
    case proFeatureRequired
    case friendLimitReached
    case networkError
    case notFound
    
    var errorDescription: String? {
        switch self {
        case .proFeatureRequired:
            return "This feature requires a Pro subscription"
        case .friendLimitReached:
            return "Friend limit reached."
        case .networkError:
            return "A network error occurred. Please try again."
        case .notFound:
            return "The requested item couldn't be found."
        }
    }
}

@MainActor
class SocialService: ObservableObject {
    static let shared = SocialService()
    private let subscriptionService = SubscriptionService.shared
    // No friend limits - unlimited for all users

    private init() {}
    
    // MARK: - Future Social Features
    
    func fetchFriends() async throws -> [Friend] {
        // Implementation pending
        return []
    }
    
    /// Gets the current number of friends the user has
    func getFriendCount() async throws -> Int {
        let friends = try await fetchFriends()
        return friends.count
    }
    
    func sendFriendRequest(to userId: String) async throws {
        // No friend limits - unlimited for all users
        // Implementation pending
    }
    
    func acceptFriendRequest(from userId: String) async throws {
        // No friend limits - unlimited for all users

        // Implementation pending
    }
    
    func createGroupChallenge(title: String, participants: [String]) async throws {
        // Group challenges are a Pro feature
        guard subscriptionService.isProUser else {
            // Update UI on main thread
            await MainActor.run {
                subscriptionService.showPaywall = true
            }
            throw SocialError.proFeatureRequired
        }
        
        // Implementation pending
    }
    
    func joinGroupChallenge(challengeId: String) async throws {
        // Group challenges are a Pro feature
        guard subscriptionService.isProUser else {
            // Update UI on main thread
            await MainActor.run {
                subscriptionService.showPaywall = true
            }
            throw SocialError.proFeatureRequired
        }
        
        // Implementation pending
    }
    
    func shareMilestone(challengeId: String, message: String) async throws {
        // Shareable milestones are a Pro feature
        guard subscriptionService.isProUser else {
            // Update UI on main thread
            await MainActor.run {
                subscriptionService.showPaywall = true
            }
            throw SocialError.proFeatureRequired
        }
        
        // Implementation pending
    }
} 