import Foundation

struct Friend: Identifiable {
    let id: String
    let name: String
    let streak: Int
    let lastActive: Date
    let profileImageURL: URL?
    
    init(id: String = UUID().uuidString,
         name: String,
         streak: Int = 0,
         lastActive: Date = Date(),
         profileImageURL: URL? = nil) {
        self.id = id
        self.name = name
        self.streak = streak
        self.lastActive = lastActive
        self.profileImageURL = profileImageURL
    }
} 