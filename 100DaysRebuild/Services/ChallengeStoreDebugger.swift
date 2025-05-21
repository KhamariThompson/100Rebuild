import Foundation
import SwiftUI

/// Utility class for verifying that challenge data is consistent across the app
class ChallengeStoreDebugger {
    static let shared = ChallengeStoreDebugger()
    
    private let challengeStore = ChallengeStore.shared
    private let userStatsService = UserStatsService.shared
    
    /// Create a debug log of the current state of challenges across the app
    @MainActor
    func logDebugInfo() {
        // Output header
        print("=== CHALLENGE STORE DEBUGGER ===")
        print("Timestamp: \(Date())")
        
        // ChallengeStore metrics
        print("\n--- CHALLENGE STORE METRICS ---")
        print("Total challenges: \(challengeStore.totalChallenges)")
        print("Active challenges: \(challengeStore.getActiveChallenges().count)")
        print("Completed challenges: \(challengeStore.completedChallenges)")
        print("Current streak: \(challengeStore.currentStreak)")
        print("Longest streak: \(challengeStore.longestStreak)")
        print("Last check-in: \(challengeStore.lastCheckInDate?.formatted() ?? "None")")
        print("Active challenge: \(challengeStore.activeChallenge?.title ?? "None")")
        
        // UserStatsService metrics
        print("\n--- USER STATS SERVICE METRICS ---")
        print("Total challenges: \(userStatsService.userStats.totalChallenges)")
        print("Completed challenges: \(userStatsService.userStats.completedChallenges)")
        print("Current streak: \(userStatsService.userStats.currentStreak)")
        print("Longest streak: \(userStatsService.userStats.longestStreak)")
        print("Last check-in: \(userStatsService.userStats.lastCheckInDate?.formatted() ?? "None")")
        
        // Challenge data
        print("\n--- CHALLENGE LIST (via ChallengeStore) ---")
        for (index, challenge) in challengeStore.challenges.enumerated() {
            print("[\(index+1)] ID: \(challenge.id.uuidString.prefix(8))...")
            print("  Title: \(challenge.title)")
            print("  Days completed: \(challenge.daysCompleted)/100")
            print("  Last check-in: \(challenge.lastCheckInDate?.formatted() ?? "None")")
            print("  Streak: \(challenge.streakCount)")
            print("  Archived: \(challenge.isArchived)")
            print("")
        }
        
        print("=== END DEBUG LOG ===")
    }
    
    /// Create a diagnostic view that can be added to any view for development
    func createDebugView() -> some View {
        DiagnosticView()
    }
}

/// A SwiftUI view that displays real-time diagnostic information
struct DiagnosticView: View {
    @StateObject private var challengeStore = ChallengeStore.shared
    @StateObject private var userStatsService = UserStatsService.shared
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack {
            HStack {
                Text("🔍 Diagnostics")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    isExpanded.toggle()
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                }
            }
            .padding(.horizontal)
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 5) {
                    Text("ChallengeStore:")
                        .fontWeight(.bold)
                    
                    metricRow("Total challenges", "\(challengeStore.totalChallenges)")
                    metricRow("Active challenges", "\(challengeStore.getActiveChallenges().count)")
                    metricRow("Completed", "\(challengeStore.completedChallenges)")
                    metricRow("Current streak", "\(challengeStore.currentStreak)")
                    
                    Divider()
                    
                    Text("UserStatsService:")
                        .fontWeight(.bold)
                    
                    metricRow("Total challenges", "\(userStatsService.userStats.totalChallenges)")
                    metricRow("Completed", "\(userStatsService.userStats.completedChallenges)")
                    metricRow("Current streak", "\(userStatsService.userStats.currentStreak)")
                    
                    Divider()
                    
                    if !challengeStore.challenges.isEmpty {
                        Text("Latest challenge: \(challengeStore.challenges[0].title)")
                            .font(.caption)
                    }
                    
                    Button("Refresh Now") {
                        Task {
                            await challengeStore.refreshChallenges()
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 4)
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
        .padding()
    }
    
    private func metricRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.caption)
            Spacer()
            Text(value)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

extension View {
    /// Add diagnostic view in debug builds only
    func withDiagnostics() -> some View {
        #if DEBUG
        return self.overlay(
            ChallengeStoreDebugger.shared.createDebugView()
                .frame(maxHeight: .infinity, alignment: .bottom)
                .edgesIgnoringSafeArea(.bottom),
            alignment: .bottom
        )
        #else
        return self // Return the view unchanged in production
        #endif
    }
} 