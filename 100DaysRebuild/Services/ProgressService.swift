import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
class ProgressService: ObservableObject {
    static let shared = ProgressService()
    private let firestore = FirebaseService.shared
    private let userSession = UserSessionService.shared
    
    @Published var metrics: ProgressMetrics?
    @Published var isLoading = false
    
    private init() {}
    
    func loadProgressMetrics() async {
        guard let userId = userSession.currentUser?.uid else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let challenges = try await ChallengeService.shared.loadChallenges(for: userId)
            metrics = calculateMetrics(from: challenges)
        } catch {
            print("Error loading progress metrics: \(error)")
        }
    }
    
    private func calculateMetrics(from challenges: [Challenge]) -> ProgressMetrics {
        let totalChallenges = challenges.count
        let completedChallenges = challenges.filter { $0.isCompleted }.count
        let totalDaysCompleted = challenges.reduce(0) { $0 + $1.daysCompleted }
        
        let currentStreak = challenges.map { $0.streakCount }.max() ?? 0
        let longestStreak = challenges.map { $0.streakCount }.max() ?? 0
        
        let completionRate = calculateCompletionRate(challenges: challenges)
        
        return ProgressMetrics(
            totalChallenges: totalChallenges,
            completedChallenges: completedChallenges,
            totalDaysCompleted: totalDaysCompleted,
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            completionRate: completionRate
        )
    }
    
    private func calculateCompletionRate(challenges: [Challenge]) -> Double {
        guard !challenges.isEmpty else { return 0 }
        
        let totalPossibleDays = challenges.count * 100
        let totalCompletedDays = challenges.reduce(0) { $0 + $1.daysCompleted }
        return totalPossibleDays > 0 ? Double(totalCompletedDays) / Double(totalPossibleDays) : 0
    }
}

struct ProgressMetrics {
    let totalChallenges: Int
    let completedChallenges: Int
    let totalDaysCompleted: Int
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
        case 14...20: return "🔥🔥🔥🔥"
        default: return "🔥🔥🔥🔥🔥"
        }
    }
    
    var motivationalText: String {
        switch currentStreak {
        case 0: return "Start your journey today!"
        case 1...2: return "Great start! Keep going!"
        case 3...6: return "You're building momentum!"
        case 7...13: return "🔥 You're on fire!"
        case 14...20: return "🔥🔥 Amazing consistency!"
        default: return "🔥🔥🔥 Legendary streak!"
        }
    }
} 