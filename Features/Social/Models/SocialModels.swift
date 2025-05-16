import Foundation
import SwiftUI

// Friend represents a user's connection in the social graph
struct Friend: Identifiable {
    let id: String
    let name: String
    let username: String
    let profileImageURL: URL?
    let streak: Int
}

// CommunityChallenge represents a group challenge
struct CommunityChallenge: Identifiable {
    let id: String
    let title: String
    let description: String
    let participants: [String] // User IDs
    let startDate: Date
    let endDate: Date
    let progress: Double // 0.0 to 1.0
} 