import Foundation
import SwiftUI
import FirebaseFirestore
import FirebaseAuth

@MainActor
class SocialViewModel: ObservableObject {
    // Username state
    @Published var username = ""
    @Published var usernameStatus: UsernameStatus = .unclaimed
    
    // Loading state
    @Published private(set) var isLoading = false
    @Published var errorMessage: String? = nil
    
    // Dependencies
    private let firestore = Firestore.firestore()
    private let userSession = UserSession.shared
    
    enum UsernameStatus {
        case unclaimed
        case claimed(String)
        case error(String)
    }
    
    // MARK: - Public Methods
    
    /// Loads the current user's username from Firestore or UserSession
    func loadUserUsername() async {
        // First, try to get the username from UserSession if available
        if let sessionUsername = userSession.username {
            self.username = sessionUsername
            usernameStatus = .claimed(sessionUsername)
            return
        }
        
        // Fall back to Firestore if needed
        guard let userId = Auth.auth().currentUser?.uid else {
            usernameStatus = .error("User not signed in")
            return
        }
        
        isLoading = true
        
        do {
            let document = try await firestore
                .collection("users")
                .document(userId)
                .getDocument()
            
            if document.exists, let data = document.data(), let username = data["username"] as? String {
                self.username = username
                usernameStatus = .claimed(username)
            } else {
                usernameStatus = .unclaimed
            }
        } catch {
            usernameStatus = .error("Failed to load username: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
} 