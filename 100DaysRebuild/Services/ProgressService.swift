import Foundation
import FirebaseFirestore
import FirebaseAuth
import SwiftUI

@MainActor
class ProgressService: ObservableObject {
    static let shared = ProgressService()
    
    @Published private(set) var metrics: ProgressMetrics?
    @Published private(set) var isLoading = false
    
    private let firestore = Firestore.firestore()
    private let userSession = UserSession.shared
    
    private init() {}
    
    func loadProgressMetrics() async {
        guard let userId = userSession.currentUser?.uid else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let challengesSnapshot = try await firestore
                .collection("challenges")
                .whereField("userId", isEqualTo: userId)
                .getDocuments()
            
            let challenges = challengesSnapshot.documents.compactMap { doc -> Challenge? in
                try? doc.data(as: Challenge.self)
            }
            
            let metrics = ProgressMetrics(
                totalChallenges: challenges.count,
                currentStreak: calculateCurrentStreak(challenges),
                longestStreak: calculateLongestStreak(challenges),
                completionRate: calculateCompletionRate(challenges)
            )
            
            self.metrics = metrics
        } catch {
            print("Error loading progress metrics: \(error)")
        }
    }
    
    private func calculateCurrentStreak(_ challenges: [Challenge]) -> Int {
        // Get the maximum current streak across all active challenges
        let activeChallenges = challenges.filter { !$0.isArchived && !$0.isCompleted }
        if activeChallenges.isEmpty {
            return 0
        }
        
        // Find challenges with active streaks (checked in yesterday or today)
        let challengesWithActiveStreaks = activeChallenges.filter { challenge in
            guard let lastCheckIn = challenge.lastCheckInDate else { return false }
            let daysSinceLastCheckIn = Calendar.current.dateComponents([.day], from: lastCheckIn, to: Date()).day ?? 0
            return daysSinceLastCheckIn <= 1 // Streak is active if checked in today or yesterday
        }
        
        // Return the maximum streak count from active challenges
        return challengesWithActiveStreaks.map { $0.streakCount }.max() ?? 0
    }
    
    private func calculateLongestStreak(_ challenges: [Challenge]) -> Int {
        // Consider both active and completed challenges to find the longest streak ever
        let allStreaks = challenges.map { $0.streakCount }
        return allStreaks.max() ?? 0
    }
    
    private func calculateCompletionRate(_ challenges: [Challenge]) -> Double {
        if challenges.isEmpty {
            return 0.0
        }
        
        // Calculate total days completed across all challenges
        let totalDaysCompleted = challenges.reduce(0) { $0 + $1.daysCompleted }
        
        // Calculate total possible days (100 days per challenge)
        let totalPossibleDays = challenges.count * 100
        
        // Return completion percentage as a decimal (0.0-1.0)
        return Double(totalDaysCompleted) / Double(totalPossibleDays)
    }
}

struct ProgressMetrics {
    let totalChallenges: Int
    let currentStreak: Int
    let longestStreak: Int
    let completionRate: Double
    
    var completionRatePercentage: Int {
        Int(completionRate * 100)
    }
    
    var streakEmoji: String {
        switch currentStreak {
        case 0...2: return "🔥"
        case 3...6: return "🔥🔥"
        case 7...13: return "🔥🔥🔥"
        default: return "🔥🔥🔥🔥"
        }
    }
    
    var motivationalText: String {
        if currentStreak == 0 {
            return "Start your journey today!"
        } else if currentStreak < 3 {
            return "You're just getting started! Keep going!"
        } else if currentStreak < 7 {
            return "You're building momentum! Don't stop now!"
        } else {
            return "You're on fire! Keep up the amazing work!"
        }
    }
} 