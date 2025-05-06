import Foundation
import SwiftUI
import FirebaseFirestore

@MainActor
class ChallengesViewModel: ObservableObject {
    @Published var challenges: [Challenge] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var isShowingNewChallenge = false
    @Published var challengeTitle = ""
    
    private let firestore = Firestore.firestore()
    private let userSession = UserSession.shared
    
    func loadChallenges() async {
        guard let userId = userSession.currentUser?.uid else { return }
        
        isLoading = true
        error = nil
        
        do {
            let snapshot = try await firestore
                .collection("challenges")
                .whereField("userId", isEqualTo: userId)
                .getDocuments()
            
            let loadedChallenges = snapshot.documents.compactMap { doc in
                try? doc.data(as: Challenge.self)
            }
            
            challenges = loadedChallenges
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func createChallenge(title: String) async {
        guard let userId = userSession.currentUser?.uid else { return }
        
        isLoading = true
        error = nil
        
        do {
            let challenge = Challenge(
                title: title,
                ownerId: userId
            )
            
            let docRef = firestore.collection("challenges").document(challenge.id.uuidString)
            try await docRef.setData(from: challenge)
            
            challenges.append(challenge)
            challengeTitle = ""
            isShowingNewChallenge = false
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func checkIn(to challenge: Challenge) async {
        guard let index = challenges.firstIndex(where: { $0.id == challenge.id }) else { return }
        
        do {
            var updatedChallenge = challenge
            updatedChallenge.daysCompleted += 1
            updatedChallenge.streakCount += 1
            
            let docRef = firestore.collection("challenges").document(challenge.id.uuidString)
            try await docRef.setData(from: updatedChallenge)
            
            await MainActor.run {
                challenges[index] = updatedChallenge
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
            }
        }
    }
    
    func archiveChallenge(_ challenge: Challenge) async {
        do {
            let docRef = firestore.collection("challenges").document(challenge.id.uuidString)
            try await docRef.delete()
            
            await MainActor.run {
                challenges.removeAll { $0.id == challenge.id }
            }
        } catch {
            await MainActor.run {
                showError = true
                errorMessage = error.localizedDescription
            }
        }
    }
} 