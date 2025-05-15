import Foundation
import FirebaseFirestore
import FirebaseAuth
import SwiftUI

/// Centralized service to track user statistics across the app
@MainActor
class UserStatsService: ObservableObject {
    static let shared = UserStatsService()
    
    @Published private(set) var userStats: UserStats = UserStats()
    @Published private(set) var isLoading = false
    @Published var error: Error?
    
    private let firestore = Firestore.firestore()
    private var fetchTask: Task<Void, Never>?
    
    private init() {}
    
    deinit {
        fetchTask?.cancel()
    }
    
    func fetchUserStats() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            self.userStats = UserStats()
            return
        }
        
        // Cancel any previous task
        fetchTask?.cancel()
        
        isLoading = true
        error = nil
        
        fetchTask = Task { [weak self] in
            guard let self = self else { return }
            
            do {
                // First fetch user-level stats - assign to _ since we're not using it yet
                _ = try await firestore
                    .collection("users")
                    .document(userId)
                    .getDocument()
                
                // Then fetch all challenges for this user
                let challengesSnapshot = try await firestore
                    .collection("users")
                    .document(userId)
                    .collection("challenges")
                    .getDocuments()
                
                if Task.isCancelled { return }
                
                // Parse the challenges into our model
                let challenges = challengesSnapshot.documents.compactMap { doc -> ChallengeStats? in
                    guard 
                        let title = doc.data()["title"] as? String,
                        let daysCompleted = doc.data()["daysCompleted"] as? Int,
                        let streakCount = doc.data()["streakCount"] as? Int,
                        let lastCheckInDate = (doc.data()["lastCheckInDate"] as? Timestamp)?.dateValue()
                    else { return nil }
                    
                    return ChallengeStats(
                        id: doc.documentID,
                        title: title,
                        daysCompleted: daysCompleted,
                        streakCount: streakCount,
                        lastCheckInDate: lastCheckInDate
                    )
                }
                
                if Task.isCancelled { return }
                
                // Calculate aggregate stats
                let totalChallenges = challenges.count
                let currentStreak = self.calculateCurrentStreak(challenges)
                let longestStreak = challenges.map(\.streakCount).max() ?? 0
                let completedChallenges = challenges.filter { $0.daysCompleted >= 100 }.count
                
                // Calculate overall completion percentage
                let overallCompletionPercentage: Double
                if totalChallenges > 0 {
                    let totalCompletedDays = challenges.reduce(0) { $0 + $1.daysCompleted }
                    let totalPossibleDays = totalChallenges * 100
                    overallCompletionPercentage = min(1.0, Double(totalCompletedDays) / Double(totalPossibleDays))
                } else {
                    overallCompletionPercentage = 0.0
                }
                
                // Get most recent check-in date
                let lastCheckInDate = challenges
                    .compactMap(\.lastCheckInDate)
                    .max()
                
                // Assemble the final stats object
                let newStats = UserStats(
                    totalChallenges: totalChallenges,
                    completedChallenges: completedChallenges,
                    currentStreak: currentStreak,
                    longestStreak: longestStreak,
                    overallCompletionPercentage: overallCompletionPercentage,
                    lastCheckInDate: lastCheckInDate
                )
                
                if Task.isCancelled { return }
                
                await MainActor.run {
                    self.userStats = newStats
                    self.isLoading = false
                }
                
            } catch {
                if !Task.isCancelled {
                    await MainActor.run {
                        self.error = error
                        self.isLoading = false
                        print("Error fetching user stats: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    private func calculateCurrentStreak(_ challenges: [ChallengeStats]) -> Int {
        // Find the most recent streak that's still active
        let activeStreaks = challenges.compactMap { challenge -> Int? in
            guard let lastCheckIn = challenge.lastCheckInDate else { return nil }
            
            let calendar = Calendar.current
            let daysSinceLastCheckIn = calendar.dateComponents([.day], from: lastCheckIn, to: Date()).day ?? 0
            
            // A streak is only active if the user checked in today or yesterday
            return daysSinceLastCheckIn <= 1 ? challenge.streakCount : nil
        }
        
        return activeStreaks.max() ?? 0
    }
}

/// Model representing a user's aggregate statistics
struct UserStats {
    let totalChallenges: Int
    let completedChallenges: Int
    let currentStreak: Int
    let longestStreak: Int
    let overallCompletionPercentage: Double
    let lastCheckInDate: Date?
    
    init(
        totalChallenges: Int = 0,
        completedChallenges: Int = 0,
        currentStreak: Int = 0,
        longestStreak: Int = 0,
        overallCompletionPercentage: Double = 0.0,
        lastCheckInDate: Date? = nil
    ) {
        self.totalChallenges = totalChallenges
        self.completedChallenges = completedChallenges
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.overallCompletionPercentage = overallCompletionPercentage
        self.lastCheckInDate = lastCheckInDate
    }
    
    var completionPercentageFormatted: String {
        String(format: "%.0f%%", overallCompletionPercentage * 100)
    }
}

/// Simplified stats model for a challenge
struct ChallengeStats {
    let id: String
    let title: String
    let daysCompleted: Int
    let streakCount: Int
    let lastCheckInDate: Date?
    
    var isCompleted: Bool {
        daysCompleted >= 100
    }
} 