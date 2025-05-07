import Foundation
import FirebaseFirestore
import FirebaseAuth

enum ProgressAction {
    case loadProgress
    case viewMilestone(milestoneId: String)
    case shareProgress
}

struct ProgressState {
    var overallProgress: Double = 0.0
    var milestones: [Milestone] = []
    var isLoading: Bool = false
    var error: String?
}

struct Milestone: Identifiable {
    let id: String
    let title: String
    let date: Date
    let isCompleted: Bool
}

class ProgressViewModel: ViewModel<ProgressState, ProgressAction> {
    private let firestore = Firestore.firestore()
    
    init() {
        super.init(initialState: ProgressState())
    }
    
    override func handle(_ action: ProgressAction) {
        switch action {
        case .loadProgress:
            loadUserProgress()
        case .viewMilestone(let id):
            // This would typically navigate to a milestone detail view
            print("Will view milestone with ID: \(id)")
        case .shareProgress:
            // Share functionality would be implemented here
            print("Share progress functionality")
        }
    }
    
    private func loadUserProgress() {
        state.isLoading = true
        state.error = nil
        
        guard let userId = Auth.auth().currentUser?.uid else {
            state.isLoading = false
            state.error = "User not authenticated"
            return
        }
        
        Task {
            do {
                // Get user challenges from Firestore
                let challenges = try await loadChallenges(for: userId)
                
                // Calculate overall progress
                let overallProgress = calculateOverallProgress(challenges)
                
                // Convert significant milestones to our data model
                let milestones = extractMilestones(from: challenges)
                
                await MainActor.run {
                    state.overallProgress = overallProgress
                    state.milestones = milestones
                    state.isLoading = false
                }
            } catch {
                await MainActor.run {
                    state.error = "Failed to load progress: \(error.localizedDescription)"
                    state.isLoading = false
                }
            }
        }
    }
    
    private func loadChallenges(for userId: String) async throws -> [Challenge] {
        let snapshot = try await firestore
            .collection("users")
            .document(userId)
            .collection("challenges")
            .getDocuments()
        
        return try snapshot.documents.compactMap { document in
            try document.data(as: Challenge.self)
        }
    }
    
    private func calculateOverallProgress(_ challenges: [Challenge]) -> Double {
        guard !challenges.isEmpty else { return 0.0 }
        
        let totalCompletedDays = challenges.reduce(0) { $0 + $1.daysCompleted }
        let totalPossibleDays = challenges.count * 100 // Each challenge is 100 days
        
        return Double(totalCompletedDays) / Double(totalPossibleDays)
    }
    
    private func extractMilestones(from challenges: [Challenge]) -> [Milestone] {
        var milestones: [Milestone] = []
        
        // Significant milestones from challenges
        for challenge in challenges {
            // Add the start of each challenge as a milestone
            milestones.append(Milestone(
                id: "start-\(challenge.id.uuidString)",
                title: "Started \(challenge.title)",
                date: challenge.startDate,
                isCompleted: true
            ))
            
            // Add completion milestone if applicable
            if challenge.isCompleted {
                milestones.append(Milestone(
                    id: "complete-\(challenge.id.uuidString)",
                    title: "Completed \(challenge.title)",
                    date: challenge.lastCheckInDate ?? challenge.startDate,
                    isCompleted: true
                ))
            }
            
            // Add milestone for reaching 25%, 50%, 75% if applicable
            let thresholds = [25, 50, 75]
            for threshold in thresholds {
                if challenge.daysCompleted >= threshold {
                    milestones.append(Milestone(
                        id: "milestone-\(threshold)-\(challenge.id.uuidString)",
                        title: "Reached \(threshold)% in \(challenge.title)",
                        date: challenge.lastCheckInDate ?? challenge.startDate,
                        isCompleted: true
                    ))
                }
            }
        }
        
        // Sort milestones by date
        return milestones.sorted(by: { $0.date > $1.date })
    }
} 