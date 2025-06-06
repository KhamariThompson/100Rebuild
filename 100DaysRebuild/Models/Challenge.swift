import Foundation

struct Challenge: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    let startDate: Date
    var lastCheckInDate: Date?
    var streakCount: Int
    var daysCompleted: Int // Total days completed
    var isCompletedToday: Bool
    var isArchived: Bool
    let ownerId: String
    var lastModified: Date // Added for syncing and sorting by recent edits
    var isTimed: Bool // New property for timer-based challenges
    
    // Computed properties
    var hasStreakExpired: Bool {
        guard let lastCheckIn = lastCheckInDate else { return true }
        
        // A streak is considered expired if the last check-in was before yesterday
        // This allows users to check in anytime during the current day, even if more than 24 hours have passed
        let calendar = Calendar.current
        let lastCheckInDay = calendar.startOfDay(for: lastCheckIn)
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        
        // Streak is expired if the last check-in was before yesterday
        // This means the user must check in at least once per calendar day, but not exactly every 24 hours
        return lastCheckInDay < yesterday
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
    
    // Recalculate isCompletedToday based on lastCheckInDate
    func checkIfCompletedToday() -> Challenge {
        var updatedChallenge = self
        
        if let lastCheckIn = lastCheckInDate {
            updatedChallenge.isCompletedToday = Calendar.current.isDateInToday(lastCheckIn)
        } else {
            updatedChallenge.isCompletedToday = false
        }
        
        return updatedChallenge
    }
    
    // Check if streak is active (not expired)
    func isStreakActive() -> Bool {
        !hasStreakExpired
    }
    
    // Get the effective streak count (0 if expired)
    func effectiveStreakCount() -> Int {
        isStreakActive() ? streakCount : 0
    }
    
    // Create an updated version of this challenge after check-in
    func afterCheckIn() -> Challenge {
        var updatedChallenge = self
        
        // Set today as the last check-in date
        updatedChallenge.lastCheckInDate = Date()
        
        // Calculate new streak count
        if let lastCheckIn = lastCheckInDate {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let lastCheckInDay = calendar.startOfDay(for: lastCheckIn)
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
            
            if lastCheckInDay == yesterday || lastCheckInDay == today {
                // Checked in yesterday or already today, continue streak
                updatedChallenge.streakCount = streakCount + 1
            } else if lastCheckInDay < yesterday {
                // Streak broken (last check-in was before yesterday), start new streak
                updatedChallenge.streakCount = 1
                
                // Reset progress if the streak was broken (auto-restart)
                if !isArchived && !isCompleted {
                    // Keep at least one day completed (today's check-in)
                    updatedChallenge.daysCompleted = 1
                    print("Challenge restarted due to missed check-in: \(title)")
                }
            } else {
                // Same day check-in (shouldn't happen), keep streak
                updatedChallenge.streakCount = streakCount
            }
        } else {
            // First check-in
            updatedChallenge.streakCount = 1
        }
        
        // If we didn't restart the challenge, increment days completed
        if updatedChallenge.daysCompleted == self.daysCompleted {
            updatedChallenge.daysCompleted += 1
        }
        
        // Mark as completed today
        updatedChallenge.isCompletedToday = true
        
        // Update last modified
        updatedChallenge.lastModified = Date()
        
        return updatedChallenge
    }
    
    init(id: UUID = UUID(), 
         title: String, 
         startDate: Date = Date(), 
         lastCheckInDate: Date? = nil, 
         streakCount: Int = 0, 
         daysCompleted: Int = 0,
         isCompletedToday: Bool = false, 
         isArchived: Bool = false, 
         ownerId: String,
         lastModified: Date = Date(),
         isTimed: Bool = false) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.lastCheckInDate = lastCheckInDate
        self.streakCount = streakCount
        self.daysCompleted = daysCompleted
        
        // Set isCompletedToday based on lastCheckInDate if provided
        if let lastCheckIn = lastCheckInDate {
            self.isCompletedToday = Calendar.current.isDateInToday(lastCheckIn)
        } else {
            self.isCompletedToday = isCompletedToday
        }
        
        self.isArchived = isArchived
        self.ownerId = ownerId
        self.lastModified = lastModified
        self.isTimed = isTimed
    }
    
    // MARK: - Equatable
    
    public static func == (lhs: Challenge, rhs: Challenge) -> Bool {
        return lhs.id == rhs.id &&
               lhs.title == rhs.title &&
               lhs.startDate == rhs.startDate &&
               lhs.lastCheckInDate == rhs.lastCheckInDate &&
               lhs.streakCount == rhs.streakCount &&
               lhs.daysCompleted == rhs.daysCompleted &&
               lhs.isCompletedToday == rhs.isCompletedToday &&
               lhs.isArchived == rhs.isArchived &&
               lhs.ownerId == rhs.ownerId &&
               lhs.lastModified == rhs.lastModified &&
               lhs.isTimed == rhs.isTimed
    }
} 