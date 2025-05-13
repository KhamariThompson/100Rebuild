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
            return "Free users can have a maximum of 5 friends. Upgrade to Pro for unlimited friends."
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
    private let maxFriendCountForFreeUsers = 5
    
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
        // Check friend limit for free users
        if !subscriptionService.isProUser {
            let friendCount = try await getFriendCount()
            if friendCount >= maxFriendCountForFreeUsers {
                // Update UI on main thread
                await MainActor.run {
                    subscriptionService.showPaywall = true
                }
                throw SocialError.friendLimitReached
            }
        }
        
        // Implementation pending
    }
    
    func acceptFriendRequest(from userId: String) async throws {
        // Check friend limit for free users before accepting
        if !subscriptionService.isProUser {
            let friendCount = try await getFriendCount()
            if friendCount >= maxFriendCountForFreeUsers {
                // Update UI on main thread
                await MainActor.run {
                    subscriptionService.showPaywall = true
                }
                throw SocialError.friendLimitReached
            }
        }
        
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