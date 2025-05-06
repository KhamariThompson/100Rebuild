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
        // Implementation
        return 0
    }
    
    private func calculateLongestStreak(_ challenges: [Challenge]) -> Int {
        // Implementation
        return 0
    }
    
    private func calculateCompletionRate(_ challenges: [Challenge]) -> Double {
        // Implementation
        return 0.0
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