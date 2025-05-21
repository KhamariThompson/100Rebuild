import Foundation
import FirebaseFirestore
import FirebaseAuth
import SwiftUI
import Combine

/// Centralized service to track user statistics across the app
@MainActor
class UserStatsService: ObservableObject {
    static let shared = UserStatsService()
    
    @Published private(set) var userStats: UserStats = UserStats()
    @Published private(set) var isLoading = false
    @Published var error: Error?
    @Published private(set) var activeChallenge: Challenge?
    
    // Notification for when stats are updated
    static let userStatsDidUpdateNotification = Notification.Name("userStatsDidUpdate")
    
    private var cancellables = Set<AnyCancellable>()
    private let challengeStore = ChallengeStore.shared
    
    private init() {
        // Listen to challenge updates from ChallengeStore
        setupChallengeStoreObserver()
    }
    
    private func setupChallengeStoreObserver() {
        // Observe challenge updates via notification
        NotificationCenter.default
            .publisher(for: ChallengeStore.challengesDidUpdateNotification)
            .sink { [weak self] _ in
                self?.syncWithChallengeStore()
            }
            .store(in: &cancellables)
        
        // Also observe relevant published properties
        challengeStore.$challenges
            .dropFirst() // Skip initial empty value
            .sink { [weak self] _ in
                self?.syncWithChallengeStore()
            }
            .store(in: &cancellables)
    }
    
    private func syncWithChallengeStore() {
        // Get challenge metrics from the store
        let totalChallenges = challengeStore.totalChallenges
        let completedChallenges = challengeStore.completedChallenges
        let currentStreak = challengeStore.currentStreak
        let longestStreak = challengeStore.longestStreak
        let overallCompletionPercentage = challengeStore.overallCompletionPercentage
        let lastCheckInDate = challengeStore.lastCheckInDate
        
        // Create new UserStats with values from ChallengeStore
        let newStats = UserStats(
            totalChallenges: totalChallenges,
            completedChallenges: completedChallenges,
            currentStreak: currentStreak, 
            longestStreak: longestStreak,
            overallCompletionPercentage: overallCompletionPercentage,
            lastCheckInDate: lastCheckInDate
        )
        
        // Update the published userStats
        self.userStats = newStats
        self.activeChallenge = challengeStore.activeChallenge
        
        // Notify observers of the updated stats
        NotificationCenter.default.post(name: Self.userStatsDidUpdateNotification, object: nil)
    }
    
    /// Manually fetches user stats - now uses ChallengeStore instead of direct Firestore calls
    func fetchUserStats() async {
        isLoading = true
        error = nil
        
        // Use the ChallengeStore to refresh all challenge data
        await challengeStore.refreshChallenges()
        
        // After the refresh completes, sync with the updated data
        syncWithChallengeStore()
        
        isLoading = false
    }
    
    /// Manually triggers a refresh of the stats
    func refreshUserStats() async {
        await fetchUserStats()
    }
}

/// Model representing a user's aggregate statistics
struct UserStats: Equatable {
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
    
    static func == (lhs: UserStats, rhs: UserStats) -> Bool {
        lhs.totalChallenges == rhs.totalChallenges &&
        lhs.completedChallenges == rhs.completedChallenges &&
        lhs.currentStreak == rhs.currentStreak &&
        lhs.longestStreak == rhs.longestStreak &&
        lhs.overallCompletionPercentage == rhs.overallCompletionPercentage &&
        lhs.lastCheckInDate == rhs.lastCheckInDate
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