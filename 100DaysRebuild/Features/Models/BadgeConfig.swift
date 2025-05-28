import Foundation
import SwiftUI
import FirebaseFirestore

// MARK: - Badge Category Enum
enum BadgeCategory: String, Codable, CaseIterable {
    case consistency = "Consistency"
    case discipline = "Discipline"
    case engagement = "Engagement"
    case challenge = "Challenge Type"
    case milestone = "Milestone"
    case social = "Social"
    
    var icon: String {
        switch self {
        case .consistency: return "flame.fill"
        case .discipline: return "brain.head.profile"
        case .engagement: return "photo.fill"
        case .challenge: return "flag.fill"
        case .milestone: return "trophy.fill"
        case .social: return "person.2.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .consistency: return .orange
        case .discipline: return .blue
        case .engagement: return .purple
        case .challenge: return .green
        case .milestone: return .yellow
        case .social: return .pink
        }
    }
}

// MARK: - Badge Tier Enum
enum BadgeTier: Int, Codable, Comparable {
    case bronze = 1
    case silver = 2
    case gold = 3
    case platinum = 4
    
    var name: String {
        switch self {
        case .bronze: return "Bronze"
        case .silver: return "Silver"
        case .gold: return "Gold"
        case .platinum: return "Platinum"
        }
    }
    
    var color: Color {
        switch self {
        case .bronze: return Color(red: 0.8, green: 0.5, blue: 0.2)
        case .silver: return Color(red: 0.75, green: 0.75, blue: 0.8)
        case .gold: return Color(red: 1.0, green: 0.84, blue: 0.0)
        case .platinum: return Color(red: 0.9, green: 0.9, blue: 0.95)
        }
    }
    
    static func < (lhs: BadgeTier, rhs: BadgeTier) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Reward Type Enum
enum BadgeRewardType: String, Codable {
    case streakSaveToken
    case proAccessDay
    case themeUnlock
    case none
}

// MARK: - Badge Reward Struct
struct BadgeReward: Codable, Equatable {
    let type: BadgeRewardType
    let value: Int
    let description: String
    
    static let none = BadgeReward(type: .none, value: 0, description: "")
    static let streakSaveToken = BadgeReward(type: .streakSaveToken, value: 1, description: "1 Streak Save Token")
    static let threeDayPro = BadgeReward(type: .proAccessDay, value: 3, description: "3 Days of Pro Access")
}

// MARK: - Badge Model
struct Badge: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let description: String
    let category: BadgeCategory
    let iconName: String
    let tier: BadgeTier?
    let reward: BadgeReward
    let requiredValue: Int
    
    var isShowcased: Bool = false
    
    // Progress tracking
    var unlockedAt: Timestamp?
    var currentProgress: Int = 0
    
    var isUnlocked: Bool {
        return unlockedAt != nil
    }
    
    var progressPercentage: Double {
        guard requiredValue > 0 else { return isUnlocked ? 1.0 : 0.0 }
        return min(Double(currentProgress) / Double(requiredValue), 1.0)
    }
    
    var tooltipText: String {
        if isUnlocked {
            return "Unlocked \(formatDate(unlockedAt?.dateValue() ?? Date()))"
        } else {
            return "\(requiredValue - currentProgress) more to unlock"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    static func == (lhs: Badge, rhs: Badge) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Badge Factory
struct BadgeConfig {
    
    // MARK: - Consistency Badges
    
    static let dayOneWarrior = Badge(
        id: "day_one_warrior",
        name: "Day One Warrior",
        description: "Completed your first check-in",
        category: .consistency,
        iconName: "checkmark.circle.fill",
        tier: nil,
        reward: .none,
        requiredValue: 1
    )
    
    static let fiveDaySpark = Badge(
        id: "five_day_spark",
        name: "5-Day Spark",
        description: "Checked in 5 days in a row",
        category: .consistency,
        iconName: "sparkles",
        tier: nil,
        reward: .none,
        requiredValue: 5
    )
    
    static let firestarter = Badge(
        id: "firestarter",
        name: "Firestarter",
        description: "Maintained a 10-day streak",
        category: .consistency,
        iconName: "flame.fill",
        tier: nil,
        reward: BadgeReward.streakSaveToken,
        requiredValue: 10
    )
    
    static let momentumMachine = Badge(
        id: "momentum_machine",
        name: "Momentum Machine",
        description: "Maintained a 25-day streak",
        category: .consistency,
        iconName: "speedometer",
        tier: nil,
        reward: .none,
        requiredValue: 25
    )
    
    static let unstoppable = Badge(
        id: "unstoppable",
        name: "Unstoppable",
        description: "Maintained a 50-day streak",
        category: .consistency,
        iconName: "bolt.fill",
        tier: nil,
        reward: BadgeReward.streakSaveToken,
        requiredValue: 50
    )
    
    static let hundredClub = Badge(
        id: "hundred_club",
        name: "100 Club",
        description: "Completed all 100 days in one challenge",
        category: .consistency,
        iconName: "100.square.fill",
        tier: nil,
        reward: BadgeReward.threeDayPro,
        requiredValue: 100
    )
    
    // MARK: - Discipline Badges
    
    static let tryAgainChamp = Badge(
        id: "try_again_champ",
        name: "Try Again Champ",
        description: "Restarted a failed challenge",
        category: .discipline,
        iconName: "arrow.counterclockwise",
        tier: nil,
        reward: .none,
        requiredValue: 1
    )
    
    static let comebackKid = Badge(
        id: "comeback_kid",
        name: "Comeback Kid",
        description: "Broke a streak and came back",
        category: .discipline,
        iconName: "figure.walk.motion",
        tier: nil,
        reward: .none,
        requiredValue: 1
    )
    
    static let noExcuses = Badge(
        id: "no_excuses",
        name: "No Excuses",
        description: "Checked in while traveling or past 11pm",
        category: .discipline,
        iconName: "clock.badge.checkmark.fill",
        tier: nil,
        reward: .none,
        requiredValue: 1
    )
    
    static let silentStreaker = Badge(
        id: "silent_streaker",
        name: "Silent Streaker",
        description: "Completed 30+ days without posting publicly",
        category: .discipline,
        iconName: "person.fill.checkmark",
        tier: nil,
        reward: .none,
        requiredValue: 30
    )
    
    // MARK: - Engagement Badges
    
    static let snapSavant = Badge(
        id: "snap_savant",
        name: "Snap Savant",
        description: "Uploaded 10 challenge photos",
        category: .engagement,
        iconName: "camera.fill",
        tier: nil,
        reward: .none,
        requiredValue: 10
    )
    
    static let reflectionMaster = Badge(
        id: "reflection_master",
        name: "Reflection Master",
        description: "Wrote 20 journal entries",
        category: .engagement,
        iconName: "text.book.closed.fill",
        tier: nil,
        reward: .none,
        requiredValue: 20
    )
    
    static let shareTheWin = Badge(
        id: "share_the_win",
        name: "Share the Win",
        description: "Shared a streak or milestone publicly",
        category: .engagement,
        iconName: "square.and.arrow.up.fill",
        tier: nil,
        reward: .none,
        requiredValue: 1
    )
    
    // MARK: - Challenge Type Badges
    
    static let bodyBuilder = Badge(
        id: "body_builder",
        name: "Body Builder",
        description: "Complete 100 days of fitness/movement",
        category: .challenge,
        iconName: "figure.strengthtraining.traditional",
        tier: nil,
        reward: .none,
        requiredValue: 100
    )
    
    static let mindSculptor = Badge(
        id: "mind_sculptor",
        name: "Mind Sculptor",
        description: "Meditation or journaling challenge completed",
        category: .challenge,
        iconName: "brain.fill",
        tier: nil,
        reward: .none,
        requiredValue: 100
    )
    
    static let skillBuilder = Badge(
        id: "skill_builder",
        name: "Skill Builder",
        description: "Finish a learning or coding-based challenge",
        category: .challenge,
        iconName: "laptopcomputer",
        tier: nil,
        reward: .none,
        requiredValue: 100
    )
    
    static let creatorMode = Badge(
        id: "creator_mode",
        name: "Creator Mode",
        description: "Daily creative work challenge completed",
        category: .challenge,
        iconName: "paintbrush.fill",
        tier: nil,
        reward: .none,
        requiredValue: 100
    )
    
    // MARK: - Milestone Badges
    
    static let tenDaysStrong = Badge(
        id: "ten_days_strong",
        name: "10 Days Strong",
        description: "10 days completed in any challenge",
        category: .milestone,
        iconName: "10.square.fill",
        tier: nil,
        reward: .none,
        requiredValue: 10
    )
    
    static let twentyFivePercent = Badge(
        id: "twentyfive_percent",
        name: "25% Complete",
        description: "Hit Day 25",
        category: .milestone,
        iconName: "25.square.fill",
        tier: nil,
        reward: .none,
        requiredValue: 25
    )
    
    static let halfwayHero = Badge(
        id: "halfway_hero",
        name: "Halfway Hero",
        description: "Reach Day 50",
        category: .milestone,
        iconName: "50.square.fill",
        tier: nil,
        reward: .none,
        requiredValue: 50
    )
    
    static let finalStretch = Badge(
        id: "final_stretch",
        name: "Final Stretch",
        description: "Hit Day 90",
        category: .milestone,
        iconName: "90.square.fill",
        tier: nil,
        reward: .none,
        requiredValue: 90
    )
    
    static let completionist = Badge(
        id: "completionist",
        name: "Completionist",
        description: "100/100 days",
        category: .milestone,
        iconName: "trophy.fill",
        tier: nil,
        reward: BadgeReward.streakSaveToken,
        requiredValue: 100
    )
    
    // MARK: - Social Badges
    
    static let supportiveStreaker = Badge(
        id: "supportive_streaker",
        name: "Supportive Streaker",
        description: "Reacted to 10 friends' check-ins",
        category: .social,
        iconName: "hand.thumbsup.fill",
        tier: nil,
        reward: .none,
        requiredValue: 10
    )
    
    static let challengeCheerleader = Badge(
        id: "challenge_cheerleader",
        name: "Challenge Cheerleader",
        description: "Invited a friend to join 100Days",
        category: .social,
        iconName: "person.fill.badge.plus",
        tier: nil,
        reward: .none,
        requiredValue: 1
    )
    
    // MARK: - All Badges Array
    
    static let allBadges: [Badge] = [
        // Consistency
        dayOneWarrior, fiveDaySpark, firestarter, momentumMachine, unstoppable, hundredClub,
        
        // Discipline
        tryAgainChamp, comebackKid, noExcuses, silentStreaker,
        
        // Engagement
        snapSavant, reflectionMaster, shareTheWin,
        
        // Challenge Type
        bodyBuilder, mindSculptor, skillBuilder, creatorMode,
        
        // Milestone
        tenDaysStrong, twentyFivePercent, halfwayHero, finalStretch, completionist,
        
        // Social
        supportiveStreaker, challengeCheerleader
    ]
    
    // Get next badge to unlock by category
    static func nextBadgeToUnlock(category: BadgeCategory, currentProgress: Int) -> Badge? {
        return allBadges
            .filter { $0.category == category && $0.currentProgress < $0.requiredValue }
            .sorted { $0.requiredValue < $1.requiredValue }
            .first
    }
    
    // Get all badges grouped by category
    static func badgesByCategory() -> [BadgeCategory: [Badge]] {
        Dictionary(grouping: allBadges) { $0.category }
    }
}

// MARK: - Badge Unlock Conditions
extension BadgeConfig {
    
    // Check if a badge should be unlocked based on user stats and challenge data
    static func shouldUnlockBadge(
        badge: Badge,
        userStats: UserStats,
        challenges: [Challenge],
        checkInRecords: [Models_CheckInRecord]
    ) -> Bool {
        
        switch badge.id {
        // Consistency Badges
        case dayOneWarrior.id:
            return userStats.currentStreak > 0 || !challenges.isEmpty
            
        case fiveDaySpark.id:
            return userStats.currentStreak >= 5
            
        case firestarter.id:
            return userStats.currentStreak >= 10
            
        case momentumMachine.id:
            return userStats.currentStreak >= 25
            
        case unstoppable.id:
            return userStats.currentStreak >= 50
            
        case hundredClub.id:
            return challenges.contains(where: { $0.daysCompleted >= 100 })
            
        // Discipline Badges
        case tryAgainChamp.id:
            // Check if any challenge was restarted (previous streak broken but days > 0)
            return challenges.contains(where: { $0.daysCompleted > 0 && $0.streakCount == 1 })
            
        case comebackKid.id:
            // Returned after breaking a streak
            let hasStreakBreak = challenges.contains(where: { 
                guard let lastCheckIn = $0.lastCheckInDate else { return false }
                let calendar = Calendar.current
                let lastCheckInDay = calendar.startOfDay(for: lastCheckIn)
                let today = calendar.startOfDay(for: Date())
                let daysBetween = calendar.dateComponents([.day], from: lastCheckInDay, to: today).day ?? 0
                return daysBetween > 1 && $0.daysCompleted > 0
            })
            return hasStreakBreak
            
        case noExcuses.id:
            // Check if any check-in happened past 11 PM
            return checkInRecords.contains(where: {
                let hour = Calendar.current.component(.hour, from: $0.date)
                return hour >= 23
            })
            
        case silentStreaker.id:
            // At least 30 days without social sharing
            return userStats.currentStreak >= 30
            
        // Engagement Badges
        case snapSavant.id:
            // Count check-ins with photos
            let photosUploaded = checkInRecords.filter({ $0.photoURL != nil }).count
            return photosUploaded >= 10
            
        case reflectionMaster.id:
            // Count check-ins with notes
            let notesWritten = checkInRecords.filter({ $0.note != nil && !($0.note?.isEmpty ?? true) }).count
            return notesWritten >= 20
            
        case shareTheWin.id:
            // This would need to be triggered when a user shares via the app
            return false
            
        // Challenge Type Badges
        case bodyBuilder.id, mindSculptor.id, skillBuilder.id, creatorMode.id:
            // These would need to be based on challenge categories
            // For now, just check if any challenge is completed
            return challenges.contains(where: { $0.daysCompleted >= 100 })
            
        // Milestone Badges
        case tenDaysStrong.id:
            return challenges.contains(where: { $0.daysCompleted >= 10 })
            
        case twentyFivePercent.id:
            return challenges.contains(where: { $0.daysCompleted >= 25 })
            
        case halfwayHero.id:
            return challenges.contains(where: { $0.daysCompleted >= 50 })
            
        case finalStretch.id:
            return challenges.contains(where: { $0.daysCompleted >= 90 })
            
        case completionist.id:
            return challenges.contains(where: { $0.daysCompleted >= 100 })
            
        // Social Badges
        case supportiveStreaker.id, challengeCheerleader.id:
            // These would need to be triggered by social actions
            return false
            
        default:
            return false
        }
    }
} 