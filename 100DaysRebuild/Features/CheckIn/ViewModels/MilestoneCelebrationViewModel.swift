import Foundation
import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth

@MainActor
class MilestoneCelebrationViewModel: ObservableObject {
    // MARK: - Properties
    
    // Dependencies
    private let firestore = Firestore.firestore()
    
    // AppStorage key for milestone tracking
    private let appStoragePrefix = "milestone_shown_"
    
    // MARK: - Public Methods
    
    /// Returns the appropriate emoji for a milestone day
    func getMilestoneEmoji(for day: Int) -> String {
        switch day {
        case 3: return "🔥"
        case 7: return "🌟"
        case 30: return "🎯"
        case 50: return "💪"
        case 100: return "🏆"
        default: return "✨"
        }
    }
    
    /// Returns the motivational message for a milestone day
    func getMilestoneMessage(for day: Int) -> String {
        switch day {
        case 3:
            return "Most people give up by now. You didn't."
        case 7:
            return "Completing a full week shows real commitment. Keep this momentum going!"
        case 30:
            return "A whole month of consistency puts you ahead of most people. You're building something great."
        case 50:
            return "Halfway there! You've shown incredible dedication. Keep pushing forward."
        case 100:
            return "You've accomplished what you set out to do. This is just the beginning!"
        default:
            return "You're making consistent progress. That's what matters most."
        }
    }
    
    /// Checks if a milestone has already been shown to the user
    func shouldShowMilestone(challengeId: String, day: Int) -> Bool {
        // First, check AppStorage for local device tracking
        if UserDefaults.standard.bool(forKey: "\(appStoragePrefix)\(challengeId)_\(day)") {
            return false
        }
        
        // Return true as we haven't shown this milestone yet
        return true
    }
    
    /// Marks a milestone as seen so it won't be shown again
    func markMilestoneAsSeen(challengeId: String, day: Int) {
        // Store in local UserDefaults
        UserDefaults.standard.set(true, forKey: "\(appStoragePrefix)\(challengeId)_\(day)")
        
        // Store in Firestore for cross-device consistency
        saveSeenMilestoneToFirestore(challengeId: challengeId, day: day)
    }
    
    // MARK: - Private Methods
    
    /// Saves the seen milestone to Firestore
    private func saveSeenMilestoneToFirestore(challengeId: String, day: Int) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let milestoneData: [String: Any] = [
            "day": day,
            "seenAt": FieldValue.serverTimestamp()
        ]
        
        let milestoneRef = firestore
            .collection("users").document(userId)
            .collection("challenges").document(challengeId)
            .collection("seenMilestones").document("day\(day)")
        
        Task {
            do {
                try await milestoneRef.setData(milestoneData)
            } catch {
                print("Error saving milestone to Firestore: \(error.localizedDescription)")
            }
        }
    }
    
    /// Syncs seen milestones from Firestore
    func syncSeenMilestones(challengeId: String) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            let snapshot = try await firestore
                .collection("users").document(userId)
                .collection("challenges").document(challengeId)
                .collection("seenMilestones")
                .getDocuments()
            
            for document in snapshot.documents {
                guard let dayNumber = document.data()["day"] as? Int else { continue }
                
                // Update local storage
                UserDefaults.standard.set(true, forKey: "\(appStoragePrefix)\(challengeId)_\(dayNumber)")
            }
        } catch {
            print("Error syncing seen milestones: \(error.localizedDescription)")
        }
    }
} 