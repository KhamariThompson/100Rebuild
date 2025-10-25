import Foundation
import FirebaseFirestore

struct FriendRequest: Identifiable, Codable {
    let id: String
    let fromUserId: String
    let fromUsername: String
    let fromDisplayName: String?
    let fromPhotoURL: URL?
    let toUserId: String
    let status: RequestStatus
    let createdAt: Date
    let updatedAt: Date
    
    enum RequestStatus: String, Codable {
        case pending
        case accepted
        case rejected
    }
    
    init(id: String = UUID().uuidString,
         fromUserId: String,
         fromUsername: String,
         fromDisplayName: String? = nil,
         fromPhotoURL: URL? = nil,
         toUserId: String,
         status: RequestStatus = .pending,
         createdAt: Date = Date(),
         updatedAt: Date = Date()) {
        self.id = id
        self.fromUserId = fromUserId
        self.fromUsername = fromUsername
        self.fromDisplayName = fromDisplayName
        self.fromPhotoURL = fromPhotoURL
        self.toUserId = toUserId
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    init?(from document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }
        
        self.id = document.documentID
        self.fromUserId = data["fromUserId"] as? String ?? ""
        self.fromUsername = data["fromUsername"] as? String ?? ""
        self.fromDisplayName = data["fromDisplayName"] as? String
        if let photoURLString = data["fromPhotoURL"] as? String {
            self.fromPhotoURL = URL(string: photoURLString)
        } else {
            self.fromPhotoURL = nil
        }
        self.toUserId = data["toUserId"] as? String ?? ""
        
        if let statusString = data["status"] as? String,
           let status = RequestStatus(rawValue: statusString) {
            self.status = status
        } else {
            self.status = .pending
        }
        
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        self.updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
    }
} 