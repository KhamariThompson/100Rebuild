/*
 Changes made to fix AuthView.swift issues:
 
 1. Binding vs FocusState Issue (Line 67):
    - Changed the EmailPasswordForm component to use a binding to the FocusState property
    - Updated EmailPasswordForm struct to use @Binding instead of @FocusState for focusedField
 
 2. Unnecessary try expressions (Line 600):
    - Removed all unnecessary try? keywords from async calls that don't throw
    - Created non-throwing wrappers in the ViewModel for all potentially throwing methods:
      • signInWithEmail(email:password:) - non-throwing wrapper for auth.signIn
      • signUpWithEmail(email:password:) - non-throwing wrapper for auth.createUser
      • signInWithGoogle() - handles finding rootViewController and error handling
      • signInWithApple() - wraps the throwing signInWithAppleInternal with error handling
      • resetPassword(email:) - non-throwing wrapper for auth.sendPasswordReset
      • signOutWithoutThrowing() - non-throwing wrapper for auth.signOut
 
 These changes maintain the same functionality while making the code safer by handling errors
 properly at the ViewModel level instead of in the View.
 */

import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
import AuthenticationServices
import CryptoKit
import UIKit
import SwiftUI

// Authentication modes for the AuthView
enum AuthMode {
    case emailSignIn
    case emailSignUp
    case forgotPassword
}

@MainActor
class AuthViewModel: ObservableObject {
    static let shared = AuthViewModel()
    
    @Published private(set) var isAuthenticated = false
    @Published private(set) var needsUsername = false
    @Published var error: Error?
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage: String = ""
    @Published var authMode: AuthMode = .emailSignIn
    
    private let auth = Auth.auth()
    private let firestore = Firestore.firestore()
    var currentNonce: String?
    private var authStateListener: AuthStateDidChangeListenerHandle?
    
    private init() {
        setupAuthStateListener()
    }
    
    private func setupAuthStateListener() {
        authStateListener = auth.addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                if let user = user {
                    self?.isAuthenticated = true
                    await self?.checkUsernameSetup(for: user.uid)
                } else {
                    self?.isAuthenticated = false
                    self?.needsUsername = false
                }
            }
        }
    }
    
    deinit {
        if let handle = authStateListener {
            auth.removeStateDidChangeListener(handle)
        }
    }
    
    // MARK: - Computed Properties
    
    var isFormValid: Bool {
        switch authMode {
        case .emailSignIn:
            return !email.isEmpty && !password.isEmpty
        case .emailSignUp:
            return !email.isEmpty && !password.isEmpty && password == confirmPassword && password.count >= 6
        case .forgotPassword:
            return !email.isEmpty
        }
    }
    
    // MARK: - Authentication Methods
    
    // Email Sign In
    func signInWithEmail() async {
        guard isFormValid else {
            setError(NSError(domain: "AuthError", code: 1, 
                             userInfo: [NSLocalizedDescriptionKey: "Please enter valid email and password"]))
            return
        }
        
        isLoading = true
        
        do {
            try await auth.signIn(withEmail: email, password: password)
            // Success is handled by auth state listener
            clearCredentials()
        } catch {
            setError(error)
        }
        
        isLoading = false
    }
    
    // Email Sign Up
    func signUpWithEmail() async {
        guard isFormValid else {
            if password != confirmPassword {
                setError(NSError(domain: "AuthError", code: 2, 
                                 userInfo: [NSLocalizedDescriptionKey: "Passwords do not match"]))
            } else if password.count < 6 {
                setError(NSError(domain: "AuthError", code: 3, 
                                 userInfo: [NSLocalizedDescriptionKey: "Password must be at least 6 characters"]))
            } else {
                setError(NSError(domain: "AuthError", code: 1, 
                                 userInfo: [NSLocalizedDescriptionKey: "Please enter valid email and password"]))
            }
            return
        }
        
        isLoading = true
        
        do {
            try await auth.createUser(withEmail: email, password: password)
            // Success is handled by auth state listener
            clearCredentials()
        } catch {
            setError(error)
        }
        
        isLoading = false
    }
    
    // Google Sign In - Updated for new UI
    func signInWithGoogle() async {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            setError(NSError(domain: "AuthError", code: 4, 
                             userInfo: [NSLocalizedDescriptionKey: "Could not find root view controller"]))
            return
        }
        
        isLoading = true
        
        do {
            try await signInWithGoogle(presenting: rootViewController)
            // Success is handled by auth state listener
        } catch {
            setError(error)
        }
        
        isLoading = false
    }
    
    // Apple Sign In - non-throwing wrapper
    func signInWithApple() async {
        isLoading = true
        
        do {
            try await signInWithAppleInternal()
            // Success is handled by auth state listener
        } catch {
            // Only show errors that aren't cancellation errors
            let nsError = error as NSError
            if nsError.domain != "authenticationServices" || nsError.code != ASAuthorizationError.canceled.rawValue {
                setError(error)
            }
        }
        
        isLoading = false
    }
    
    // Password Reset
    func resetPassword() async {
        guard !email.isEmpty else {
            setError(NSError(domain: "AuthError", code: 5, 
                             userInfo: [NSLocalizedDescriptionKey: "Please enter your email address"]))
            return
        }
        
        isLoading = true
        
        do {
            try await auth.sendPasswordReset(withEmail: email)
            
            // Show success message
            errorMessage = "Password reset email sent to \(email)"
            showError = true
            
            // Reset and go back to sign in
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.authMode = .emailSignIn
            }
        } catch {
            setError(error)
        }
        
        isLoading = false
    }
    
    // Non-throwing wrapper for resetPassword(email:)
    func resetPassword(email: String) async {
        isLoading = true
        
        do {
            try await auth.sendPasswordReset(withEmail: email)
            
            // Show success message
            errorMessage = "Password reset email sent to \(email)"
            showError = true
        } catch {
            setError(error)
        }
        
        isLoading = false
    }
    
    private func clearCredentials() {
        email = ""
        password = ""
        confirmPassword = ""
    }
    
    private func checkUsernameSetup(for userId: String) async {
        do {
            let document = try await firestore
                .collection("users")
                .document(userId)
                .getDocument()
            
            needsUsername = !document.exists || document.data()?["username"] == nil
        } catch {
            self.error = error
        }
    }
    
    func signInWithGoogle(presenting viewController: UIViewController) async throws {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthError.missingClientID
        }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: viewController)
            guard let idToken = result.user.idToken?.tokenString else {
                throw AuthError.missingIDToken
            }
            
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )
            
            try await auth.signIn(with: credential)
        } catch {
            throw AuthError.googleSignInFailed(error)
        }
    }
    
    func signInWithAppleInternal() async throws {
        let nonce = randomNonceString()
        currentNonce = nonce
        let hashedNonce = sha256(nonce)
        
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = hashedNonce
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ASAuthorization, Error>) in
            let delegate = AppleSignInDelegate(continuation: continuation)
            // Keep the delegate around until completion
            authorizationController.delegate = delegate
            // Store delegate as associated object on controller to extend its lifetime
            objc_setAssociatedObject(authorizationController, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
            authorizationController.performRequests()
        }
        
        if let appleIDCredential = result.credential as? ASAuthorizationAppleIDCredential,
           let appleIDToken = appleIDCredential.identityToken,
           let idTokenString = String(data: appleIDToken, encoding: .utf8) {
            
            // Create a Firebase credential using the standard approach for Apple
            let credential = OAuthProvider.appleCredential(
                withIDToken: idTokenString,
                rawNonce: nonce,
                fullName: appleIDCredential.fullName
            )
            
            try await auth.signIn(with: credential)
        } else {
            throw AuthError.appleSignInFailed
        }
    }
    
    // Non-throwing signIn wrapper
    func signInWithEmail(email: String, password: String) async {
        isLoading = true
        
        do {
            try await auth.signIn(withEmail: email, password: password)
            // Success is handled by auth state listener
        } catch {
            setError(error)
        }
        
        isLoading = false
    }
    
    // Non-throwing signUp wrapper
    func signUpWithEmail(email: String, password: String) async {
        isLoading = true
        
        do {
            try await auth.createUser(withEmail: email, password: password)
            // Success is handled by auth state listener
        } catch {
            setError(error)
        }
        
        isLoading = false
    }
    
    func signOut() async throws {
        try auth.signOut()
    }
    
    // Non-throwing signOut wrapper
    func signOutWithoutThrowing() async {
        do {
            try auth.signOut()
        } catch {
            setError(error)
        }
    }
    
    // Non-throwing setUsername wrapper
    func setUsernameWithHandling(username: String) async {
        isLoading = true
        
        do {
            guard let userId = auth.currentUser?.uid else {
                throw AuthError.unauthorized
            }
            
            try await FirebaseService.shared.createUserProfile(username: username, userId: userId)
        } catch {
            setError(error)
        }
        
        isLoading = false
    }
    
    // Helper method to update error properties
    func setError(_ error: Error) {
        self.error = error
        self.errorMessage = error.localizedDescription
        self.showError = true
    }
    
    // MARK: - Helper Methods
    
    func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
    
    func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
}

enum AuthError: Error {
    case missingClientID
    case missingIDToken
    case googleSignInFailed(Error)
    case appleSignInFailed
    case unauthorized
}

enum AuthProviders: String {
    case apple = "apple.com"
    case google = "google.com"
    case facebook = "facebook.com"
}

// MARK: - Apple Sign In Delegate
private class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate {
    private let continuation: CheckedContinuation<ASAuthorization, Error>
    
    init(continuation: CheckedContinuation<ASAuthorization, Error>) {
        self.continuation = continuation
        super.init()
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        continuation.resume(returning: authorization)
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation.resume(throwing: error)
    }
} 