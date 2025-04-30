import Foundation
import FirebaseFirestore

@MainActor
class UsernameSetupViewModel: ObservableObject {
    @Published var username = ""
    @Published var error: String?
    @Published var isLoading = false
    @Published var showSuccess = false
    
    private let firestore = FirebaseService.shared
    private let userSession = UserSessionService.shared
    
    var isValid: Bool {
        let usernameRegex = "^[a-zA-Z0-9]{3,20}$"
        let usernamePredicate = NSPredicate(format: "SELF MATCHES %@", usernameRegex)
        return usernamePredicate.evaluate(with: username)
    }
    
    func submitUsername() async {
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
            userSession.username = username
            showSuccess = true
        } catch {
            self.error = "Failed to create username. Please try again."
        }
    }
}

struct UsernameLookup: Codable {
    let userId: String
} 