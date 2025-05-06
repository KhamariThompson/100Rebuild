import Foundation

struct CommunityChallenge: Identifiable {
    let id: String
    let title: String
    let creatorId: String
    let participants: [String]
    let startDate: Date
    let endDate: Date
    
    init(id: String = UUID().uuidString,
         title: String,
         creatorId: String,
         participants: [String] = [],
         startDate: Date = Date(),
         endDate: Date = Date().addingTimeInterval(60*60*24*100)) {
        self.id = id
        self.title = title
        self.creatorId = creatorId
        self.participants = participants
        self.startDate = startDate
        self.endDate = endDate
    }
} 