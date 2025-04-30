import Foundation

struct Challenge: Identifiable, Codable {
    let id: UUID
    let title: String
    let startDate: Date
    var lastCheckInDate: Date?
    var streakCount: Int
    var daysCompleted: Int // Total days completed
    var isCompletedToday: Bool
    var isArchived: Bool
    let ownerId: String
    
    // Computed properties
    var hasStreakExpired: Bool {
        guard let lastCheckIn = lastCheckInDate else { return true }
        return Calendar.current.dateComponents([.day], from: lastCheckIn, to: Date()).day ?? 0 > 1
    }
    
    var endDate: Date {
        Calendar.current.date(byAdding: .day, value: 100, to: startDate) ?? startDate
    }
    
    var daysRemaining: Int {
        max(0, 100 - daysCompleted)
    }
    
    var isCompleted: Bool {
        daysCompleted >= 100
    }
    
    var progressPercentage: Double {
        Double(daysCompleted) / 100.0
    }
    
    var streakEmoji: String {
        switch streakCount {
        case 0...2: return "🔥"
        case 3...6: return "🔥🔥"
        case 7...13: return "🔥🔥🔥"
        case 14...20: return "🔥🔥🔥🔥"
        default: return "🔥🔥🔥🔥🔥"
        }
    }
    
    init(id: UUID = UUID(), 
         title: String, 
         startDate: Date = Date(), 
         lastCheckInDate: Date? = nil, 
         streakCount: Int = 0, 
         daysCompleted: Int = 0,
         isCompletedToday: Bool = false, 
         isArchived: Bool = false, 
         ownerId: String) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.lastCheckInDate = lastCheckInDate
        self.streakCount = streakCount
        self.daysCompleted = daysCompleted
        self.isCompletedToday = isCompletedToday
        self.isArchived = isArchived
        self.ownerId = ownerId
    }
} 