import Foundation
import FirebaseFirestore
import SwiftUI

@MainActor
class UsernameSetupViewModel: ObservableObject {
    @Published var username = ""
    @Published var error: String?
    @Published var isLoading = false
    @Published var showSuccess = false
    
    private let firestore = FirebaseService.shared
    private let userSession = UserSession.shared
    
    var isValid: Bool {
        let usernameRegex = "^[a-zA-Z0-9]{3,20}$"
        let usernamePredicate = NSPredicate(format: "SELF MATCHES %@", usernameRegex)
        return usernamePredicate.evaluate(with: username)
    }
    
    func submitUsername() async throws {
        guard isValid else {
            error = "Username must be 3-20 characters, letters and numbers only"
            return
        }
        
        guard let userId = userSession.currentUser?.uid else {
            error = "User not authenticated"
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await firestore.createUserProfile(username: username, userId: userId)
            try await userSession.updateUsername(username)
            showSuccess = true
        } catch {
            self.error = "Failed to create username. Please try again."
            throw error
        }
    }
    
    func saveUsername() async {
        guard !username.isEmpty else {
            error = "Username cannot be empty"
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            try await userSession.updateUsername(username)
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
}

struct UsernameLookup: Codable {
    let userId: String
} 