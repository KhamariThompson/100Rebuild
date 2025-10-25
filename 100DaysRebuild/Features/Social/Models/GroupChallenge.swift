import Foundation
import FirebaseFirestore

struct GroupChallenge: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let creatorId: String
    let creatorUsername: String
    let isPublic: Bool
    let maxParticipants: Int
    let startDate: Date
    let endDate: Date
    let createdAt: Date
    let updatedAt: Date
    
    init(id: String = UUID().uuidString,
         title: String,
         description: String = "",
         creatorId: String,
         creatorUsername: String,
         isPublic: Bool = false,
         maxParticipants: Int = 10,
         startDate: Date = Date(),
         endDate: Date = Calendar.current.date(byAdding: .day, value: 100, to: Date()) ?? Date(),
         createdAt: Date = Date(),
         updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.description = description
        self.creatorId = creatorId
        self.creatorUsername = creatorUsername
        self.isPublic = isPublic
        self.maxParticipants = maxParticipants
        self.startDate = startDate
        self.endDate = endDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    init?(from document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }
        
        self.id = document.documentID
        self.title = data["title"] as? String ?? ""
        self.description = data["description"] as? String ?? ""
        self.creatorId = data["creatorId"] as? String ?? ""
        self.creatorUsername = data["creatorUsername"] as? String ?? ""
        self.isPublic = data["isPublic"] as? Bool ?? false
        self.maxParticipants = data["maxParticipants"] as? Int ?? 10
        
        if let startTimestamp = data["startDate"] as? Timestamp {
            self.startDate = startTimestamp.dateValue()
        } else {
            self.startDate = Date()
        }
        
        if let endTimestamp = data["endDate"] as? Timestamp {
            self.endDate = endTimestamp.dateValue()
        } else {
            self.endDate = Calendar.current.date(byAdding: .day, value: 100, to: Date()) ?? Date()
        }
        
        if let createdTimestamp = data["createdAt"] as? Timestamp {
            self.createdAt = createdTimestamp.dateValue()
        } else {
            self.createdAt = Date()
        }
        
        if let updatedTimestamp = data["updatedAt"] as? Timestamp {
            self.updatedAt = updatedTimestamp.dateValue()
        } else {
            self.updatedAt = Date()
        }
    }
    
    func asDictionary() -> [String: Any] {
        return [
            "id": id,
            "title": title,
            "description": description,
            "creatorId": creatorId,
            "creatorUsername": creatorUsername,
            "isPublic": isPublic,
            "maxParticipants": maxParticipants,
            "startDate": Timestamp(date: startDate),
            "endDate": Timestamp(date: endDate),
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": Timestamp(date: updatedAt)
        ]
    }
}

// Participant in a group challenge
struct GroupChallengeParticipant: Identifiable, Codable {
    let id: String
    let userId: String
    let username: String
    let displayName: String?
    let photoURL: URL?
    let joinedAt: Date
    let status: ParticipantStatus
    
    enum ParticipantStatus: String, Codable {
        case active
        case completed
        case dropped
    }
    
    init(id: String = UUID().uuidString,
         userId: String,
         username: String,
         displayName: String? = nil,
         photoURL: URL? = nil,
         joinedAt: Date = Date(),
         status: ParticipantStatus = .active) {
        self.id = id
        self.userId = userId
        self.username = username
        self.displayName = displayName
        self.photoURL = photoURL
        self.joinedAt = joinedAt
        self.status = status
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
        
        if let joinedTimestamp = data["joinedAt"] as? Timestamp {
            self.joinedAt = joinedTimestamp.dateValue()
        } else {
            self.joinedAt = Date()
        }
        
        if let statusString = data["status"] as? String,
           let status = ParticipantStatus(rawValue: statusString) {
            self.status = status
        } else {
            self.status = .active
        }
    }
    
    func asDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "userId": userId,
            "username": username,
            "joinedAt": Timestamp(date: joinedAt),
            "status": status.rawValue
        ]
        
        if let displayName = displayName {
            dict["displayName"] = displayName
        }
        
        if let photoURL = photoURL {
            dict["photoURL"] = photoURL.absoluteString
        }
        
        return dict
    }
}

// Challenge invitation
struct ChallengeInvitation: Identifiable, Codable {
    let id: String
    let challengeId: String
    let challengeTitle: String
    let fromUserId: String
    let fromUsername: String
    let toUserId: String
    let status: InvitationStatus
    let createdAt: Date
    let updatedAt: Date
    
    enum InvitationStatus: String, Codable {
        case pending
        case accepted
        case rejected
        case expired
    }
    
    init(id: String = UUID().uuidString,
         challengeId: String,
         challengeTitle: String,
         fromUserId: String,
         fromUsername: String,
         toUserId: String,
         status: InvitationStatus = .pending,
         createdAt: Date = Date(),
         updatedAt: Date = Date()) {
        self.id = id
        self.challengeId = challengeId
        self.challengeTitle = challengeTitle
        self.fromUserId = fromUserId
        self.fromUsername = fromUsername
        self.toUserId = toUserId
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    init?(from document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }
        
        self.id = document.documentID
        self.challengeId = data["challengeId"] as? String ?? ""
        self.challengeTitle = data["challengeTitle"] as? String ?? ""
        self.fromUserId = data["fromUserId"] as? String ?? ""
        self.fromUsername = data["fromUsername"] as? String ?? ""
        self.toUserId = data["toUserId"] as? String ?? ""
        
        if let statusString = data["status"] as? String,
           let status = InvitationStatus(rawValue: statusString) {
            self.status = status
        } else {
            self.status = .pending
        }
        
        if let createdTimestamp = data["createdAt"] as? Timestamp {
            self.createdAt = createdTimestamp.dateValue()
        } else {
            self.createdAt = Date()
        }
        
        if let updatedTimestamp = data["updatedAt"] as? Timestamp {
            self.updatedAt = updatedTimestamp.dateValue()
        } else {
            self.updatedAt = Date()
        }
    }
    
    func asDictionary() -> [String: Any] {
        return [
            "challengeId": challengeId,
            "challengeTitle": challengeTitle,
            "fromUserId": fromUserId,
            "fromUsername": fromUsername,
            "toUserId": toUserId,
            "status": status.rawValue,
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": Timestamp(date: updatedAt)
        ]
    }
} 