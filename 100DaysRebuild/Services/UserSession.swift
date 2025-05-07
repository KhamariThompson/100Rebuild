import SwiftUI
import FirebaseAuth
import FirebaseFirestore

enum AuthState {
    case loading
    case signedIn(FirebaseAuth.User)
    case signedOut
}

@MainActor
class UserSession: ObservableObject {
    static let shared = UserSession()
    
    @Published private(set) var authState: AuthState = .loading
    @Published private(set) var isAuthenticated = false
    @Published private(set) var hasCompletedOnboarding = false
    @Published private(set) var currentUser: FirebaseAuth.User?
    @Published private(set) var username: String?
    @Published private(set) var photoURL: URL?
    
    // Add a handler that other components can set to be notified of auth changes
    var authStateDidChangeHandler: (() -> Void)?
    
    private let auth = Auth.auth()
    private let firestore = Firestore.firestore()
    private var stateListener: AuthStateDidChangeListenerHandle?
    
    private init() {
        setupAuthStateListener()
    }
    
    private func setupAuthStateListener() {
        stateListener = auth.addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                if let user = user {
                    self?.authState = .signedIn(user)
                    self?.currentUser = user
                    self?.isAuthenticated = true
                    Task {
                        await self?.loadUserProfile()
                    }
                } else {
                    self?.authState = .signedOut
                    self?.currentUser = nil
                    self?.isAuthenticated = false
                    self?.username = nil
                    self?.photoURL = nil
                }
                
                // Notify listeners about auth state change
                self?.authStateDidChangeHandler?()
            }
        }
    }
    
    deinit {
        if let listener = stateListener {
            auth.removeStateDidChangeListener(listener)
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
                await MainActor.run {
                    self.username = data["username"] as? String
                    self.hasCompletedOnboarding = self.username != nil
                    
                    // Load the photoURL if available
                    if let photoURLString = data["photoURL"] as? String, 
                       let url = URL(string: photoURLString) {
                        self.photoURL = url
                    }
                }
            }
        } catch {
            print("Error loading user profile: \(error)")
        }
    }
    
    func signIn(email: String, password: String) async throws {
        let result = try await auth.signIn(withEmail: email, password: password)
        await MainActor.run {
            self.currentUser = result.user
            self.isAuthenticated = true
            self.authState = .signedIn(result.user)
        }
    }
    
    func signOut() async throws {
        try auth.signOut()
        await MainActor.run {
            currentUser = nil
            isAuthenticated = false
            authState = .signedOut
            username = nil
            photoURL = nil
        }
    }
    
    func signOutWithoutThrowing() async {
        do {
            try auth.signOut()
            await MainActor.run {
                currentUser = nil
                isAuthenticated = false
                authState = .signedOut
                username = nil
                photoURL = nil
            }
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }
    
    func updateUsername(_ newUsername: String) async throws {
        guard let userId = currentUser?.uid else { return }
        
        try await firestore
            .collection("users")
            .document(userId)
            .setData(["username": newUsername], merge: true)
        
        await MainActor.run {
            self.username = newUsername
            self.hasCompletedOnboarding = true
        }
    }
    
    func updateProfilePhoto(_ url: URL) async throws {
        guard let userId = currentUser?.uid else { return }
        
        try await firestore
            .collection("users")
            .document(userId)
            .setData(["photoURL": url.absoluteString], merge: true)
        
        await MainActor.run {
            self.photoURL = url
        }
    }
    
    // Add a proper account deletion method that handles Firestore cleanup
    func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser, let userId = currentUser?.uid else {
            throw NSError(domain: "UserSession", code: 1, userInfo: [NSLocalizedDescriptionKey: "No user is signed in"])
        }
        
        // 1. Delete all user data from Firestore first
        try await FirebaseService.shared.deleteUserData(userId: userId)
        
        // 2. Delete the actual Firebase Auth account
        try await user.delete()
        
        // 3. Clean up local state
        await MainActor.run {
            self.currentUser = nil
            self.isAuthenticated = false
            self.authState = .signedOut
            self.username = nil
            self.photoURL = nil
        }
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