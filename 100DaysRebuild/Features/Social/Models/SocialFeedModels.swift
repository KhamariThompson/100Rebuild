import Foundation
import FirebaseFirestore
import SwiftUI

// MARK: - Social Feed Item
struct SocialFeedItem: Identifiable, Codable {
    let id: String
    let userId: String
    let username: String
    let displayName: String?
    let photoURL: URL?
    let type: ActivityType
    let description: String
    let challengeId: String?
    let challengeTitle: String?
    let timestamp: Date
    let reactions: [String: Int] // emoji -> count
    
    init(id: String = UUID().uuidString,
         userId: String,
         username: String,
         displayName: String? = nil,
         photoURL: URL? = nil,
         type: ActivityType,
         description: String,
         challengeId: String? = nil,
         challengeTitle: String? = nil,
         timestamp: Date = Date(),
         reactions: [String: Int] = [:]) {
        self.id = id
        self.userId = userId
        self.username = username
        self.displayName = displayName
        self.photoURL = photoURL
        self.type = type
        self.description = description
        self.challengeId = challengeId
        self.challengeTitle = challengeTitle
        self.timestamp = timestamp
        self.reactions = reactions
    }
    
    init?(from document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }
        
        self.id = document.documentID
        self.userId = data["userId"] as? String ?? ""
        self.username = data["username"] as? String ?? ""
        self.displayName = data["displayName"] as? String
        
        if let photoURLString = data["photoURL"] as? String {
            self.photoURL = URL(string: photoURLString)
        } else {
            self.photoURL = nil
        }
        
        if let typeString = data["type"] as? String,
           let activityType = ActivityType(rawValue: typeString) {
            self.type = activityType
        } else {
            self.type = .checkIn
        }
        
        self.description = data["description"] as? String ?? ""
        self.challengeId = data["challengeId"] as? String
        self.challengeTitle = data["challengeTitle"] as? String
        
        if let timestamp = data["timestamp"] as? Timestamp {
            self.timestamp = timestamp.dateValue()
        } else {
            self.timestamp = Date()
        }
        
        self.reactions = data["reactions"] as? [String: Int] ?? [:]
    }
    
    func asDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "userId": userId,
            "username": username,
            "type": type.rawValue,
            "description": description,
            "timestamp": Timestamp(date: timestamp),
            "reactions": reactions
        ]
        
        if let displayName = displayName {
            dict["displayName"] = displayName
        }
        
        if let photoURL = photoURL {
            dict["photoURL"] = photoURL.absoluteString
        }
        
        if let challengeId = challengeId {
            dict["challengeId"] = challengeId
        }
        
        if let challengeTitle = challengeTitle {
            dict["challengeTitle"] = challengeTitle
        }
        
        return dict
    }
}

// MARK: - Activity Type
enum ActivityType: String, Codable, CaseIterable {
    case checkIn = "check_in"
    case milestone = "milestone"
    case challengeComplete = "challenge_complete"
    case streak = "streak"
    case encouragement = "encouragement"
    
    var displayName: String {
        switch self {
        case .checkIn:
            return "Check-in"
        case .milestone:
            return "Milestone"
        case .challengeComplete:
            return "Complete"
        case .streak:
            return "Streak"
        case .encouragement:
            return "Support"
        }
    }
    
    var color: Color {
        switch self {
        case .checkIn:
            return .theme.accent
        case .milestone:
            return .orange
        case .challengeComplete:
            return .theme.success
        case .streak:
            return .orange
        case .encouragement:
            return .pink
        }
    }
    
    var icon: String {
        switch self {
        case .checkIn:
            return "checkmark.circle.fill"
        case .milestone:
            return "star.fill"
        case .challengeComplete:
            return "trophy.fill"
        case .streak:
            return "flame.fill"
        case .encouragement:
            return "heart.fill"
        }
    }
}

// MARK: - Social Feed Reaction
struct SocialFeedReaction: Identifiable, Codable {
    let id: String
    let feedItemId: String
    let userId: String
    let username: String
    let emoji: String
    let timestamp: Date
    
    init(id: String = UUID().uuidString,
         feedItemId: String,
         userId: String,
         username: String,
         emoji: String,
         timestamp: Date = Date()) {
        self.id = id
        self.feedItemId = feedItemId
        self.userId = userId
        self.username = username
        self.emoji = emoji
        self.timestamp = timestamp
    }
    
    init?(from document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }
        
        self.id = document.documentID
        self.feedItemId = data["feedItemId"] as? String ?? ""
        self.userId = data["userId"] as? String ?? ""
        self.username = data["username"] as? String ?? ""
        self.emoji = data["emoji"] as? String ?? ""
        
        if let timestamp = data["timestamp"] as? Timestamp {
            self.timestamp = timestamp.dateValue()
        } else {
            self.timestamp = Date()
        }
    }
    
    func asDictionary() -> [String: Any] {
        return [
            "feedItemId": feedItemId,
            "userId": userId,
            "username": username,
            "emoji": emoji,
            "timestamp": Timestamp(date: timestamp)
        ]
    }
}

// MARK: - Friend Profile Models
struct FriendProfile: Identifiable, Codable {
    let id: String
    let username: String
    let displayName: String?
    let photoURL: URL?
    let currentStreak: Int
    let totalCheckIns: Int
    let completedChallenges: Int
    let joinedDate: Date
    let lastActive: Date
    
    init(id: String,
         username: String,
         displayName: String? = nil,
         photoURL: URL? = nil,
         currentStreak: Int = 0,
         totalCheckIns: Int = 0,
         completedChallenges: Int = 0,
         joinedDate: Date = Date(),
         lastActive: Date = Date()) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.photoURL = photoURL
        self.currentStreak = currentStreak
        self.totalCheckIns = totalCheckIns
        self.completedChallenges = completedChallenges
        self.joinedDate = joinedDate
        self.lastActive = lastActive
    }
}

struct FriendChallenge: Identifiable, Codable {
    let id: String
    let title: String
    let currentDay: Int
    let totalDays: Int
    let streak: Int
    let progress: Double
    
    init(id: String,
         title: String,
         currentDay: Int,
         totalDays: Int = 100,
         streak: Int) {
        self.id = id
        self.title = title
        self.currentDay = currentDay
        self.totalDays = totalDays
        self.streak = streak
        self.progress = Double(currentDay) / Double(totalDays)
    }
}

struct FriendActivity: Identifiable, Codable {
    let id: String
    let type: ActivityType
    let description: String
    let timestamp: Date
    
    init(id: String = UUID().uuidString,
         type: ActivityType,
         description: String,
         timestamp: Date = Date()) {
        self.id = id
        self.type = type
        self.description = description
        self.timestamp = timestamp
    }
}

// MARK: - Extensions
// timeAgoDisplay() is defined in Core/Extensions/DateExtensions.swift 