import Foundation
import SwiftUI

@MainActor
class ChallengesViewModel: ObservableObject {
    @Published var challenges: [Challenge] = []
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""
    
    private let challengeService = ChallengeService.shared
    private let userSession = UserSessionService.shared
    
    func loadChallenges() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            guard let userId = userSession.currentUser?.uid else {
                throw ChallengeError.unauthorized
            }
            
            challenges = try await challengeService.loadChallenges(for: userId)
        } catch {
            showError = true
            errorMessage = error.localizedDescription
        }
    }
    
    func createChallenge(title: String) async {
        do {
            guard let userId = userSession.currentUser?.uid else {
                throw ChallengeError.unauthorized
            }
            
            let newChallenge = try await challengeService.createChallenge(title: title, userId: userId)
            challenges.append(newChallenge)
        } catch {
            showError = true
            errorMessage = error.localizedDescription
        }
    }
    
    func checkIn(to challenge: Challenge) async {
        do {
            let updatedChallenge = try await challengeService.checkIn(to: challenge)
            if let index = challenges.firstIndex(where: { $0.id == challenge.id }) {
                challenges[index] = updatedChallenge
            }
        } catch {
            showError = true
            errorMessage = error.localizedDescription
        }
    }
    
    func archiveChallenge(_ challenge: Challenge) async {
        do {
            try await challengeService.archiveChallenge(challenge)
            challenges.removeAll { $0.id == challenge.id }
        } catch {
            showError = true
            errorMessage = error.localizedDescription
        }
    }
} 