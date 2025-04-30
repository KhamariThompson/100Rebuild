import Foundation
import FirebaseAuth
import GoogleSignIn
import AuthenticationServices

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var needsUsername = false
    @Published var error: String?
    
    private let userSession = UserSessionService.shared
    
    func checkAuthState() async {
        if let user = userSession.currentUser {
            await checkUsernameSetup(for: user.uid)
        } else {
            isAuthenticated = false
            needsUsername = false
        }
    }
    
    private func checkUsernameSetup(for userId: String) async {
        do {
            let profile = try await FirebaseService.shared.fetchUserProfile(userId: userId)
            
            if profile == nil {
                needsUsername = true
                isAuthenticated = false
            } else {
                needsUsername = false
                isAuthenticated = true
                userSession.username = profile?.username
            }
        } catch {
            print("Error checking username setup: \(error)")
            needsUsername = true
            isAuthenticated = false
        }
    }
    
    // ... existing auth methods ...
    
    func signInWithGoogle() async {
        do {
            try await userSession.signInWithGoogle()
            if let user = userSession.currentUser {
                await checkUsernameSetup(for: user.uid)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func signInWithApple() async {
        do {
            try await userSession.signInWithApple()
            if let user = userSession.currentUser {
                await checkUsernameSetup(for: user.uid)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func signIn(email: String, password: String) async {
        do {
            try await userSession.signIn(withEmail: email, password: password)
            if let user = userSession.currentUser {
                await checkUsernameSetup(for: user.uid)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func signUp(email: String, password: String) async {
        do {
            try await userSession.signUp(withEmail: email, password: password)
            needsUsername = true
            isAuthenticated = false
        } catch {
            self.error = error.localizedDescription
        }
    }
} 