import Foundation
import FirebaseAuth
import FirebaseFirestore

enum AuthState {
    case loading
    case signedIn(User)
    case signedOut
}

@MainActor
class UserSessionService: ObservableObject {
    static let shared = UserSessionService()
    
    @Published private(set) var authState: AuthState = .loading
    @Published private(set) var currentUser: User?
    @Published private(set) var username: String?
    
    private let auth = Auth.auth()
    private let firestore = Firestore.firestore()
    
    private init() {
        setupAuthStateListener()
    }
    
    private func setupAuthStateListener() {
        auth.addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                if let user = user {
                    self?.authState = .signedIn(user)
                    self?.currentUser = user
                    await self?.loadUserProfile()
                } else {
                    self?.authState = .signedOut
                    self?.currentUser = nil
                    self?.username = nil
                }
            }
        }
    }
    
    private func loadUserProfile() async {
        guard let userId = currentUser?.uid else { return }
        
        do {
            let document = try await firestore
                .collection("users")
                .document(userId)
                .getDocument()
            
            if let data = document.data() {
                username = data["username"] as? String
            }
        } catch {
            print("Error loading user profile: \(error)")
        }
    }
    
    func signOut() throws {
        try auth.signOut()
    }
    
    func updateUsername(_ newUsername: String) async throws {
        guard let userId = currentUser?.uid else { return }
        
        try await firestore
            .collection("users")
            .document(userId)
            .setData(["username": newUsername], merge: true)
        
        username = newUsername
    }
    
    // MARK: - Routing Helpers
    
    var shouldShowAuth: Bool {
        if case .signedOut = authState {
            return true
        }
        return false
    }
    
    var shouldShowUsernameSetup: Bool {
        if case .signedIn = authState, username == nil {
            return true
        }
        return false
    }
    
    var shouldShowMainApp: Bool {
        if case .signedIn = authState, username != nil {
            return true
        }
        return false
    }
} 