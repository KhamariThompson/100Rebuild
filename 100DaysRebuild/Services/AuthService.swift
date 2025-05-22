import Foundation
import Firebase
import FirebaseAuth
import GoogleSignIn
import AuthenticationServices
import UIKit
import CryptoKit
import SwiftUI

/// Centralized authentication service to handle all authentication methods
@MainActor
class AuthService {
    static let shared = AuthService()
    
    // Reference to UserSession for centralized auth state management
    private let userSession: UserSession
    
    private init() {
        self.userSession = UserSession.shared
        print("AuthService: Initialized")
    }
    
    // MARK: - Email Authentication
    
    /// Sign in with email and password
    func signInWithEmail(email: String, password: String) async -> Bool {
        do {
            print("AuthService: Attempting sign in with email: \(email)")
            let _ = try await Auth.auth().signIn(withEmail: email, password: password)
            print("AuthService: Sign in successful")
            await userSession.handleAuthSuccess(provider: "password")
            return true
        } catch {
            print("AuthService: Sign in failed - \(error.localizedDescription)")
            await userSession.handleAuthError(error, for: .signIn, provider: "password")
            return false
        }
    }
    
    /// Sign up with email and password
    func signUpWithEmail(email: String, password: String) async -> Bool {
        do {
            print("AuthService: Attempting sign up with email: \(email)")
            let _ = try await Auth.auth().createUser(withEmail: email, password: password)
            print("AuthService: Sign up successful")
            await userSession.handleAuthSuccess(provider: "password")
            return true
        } catch {
            print("AuthService: Sign up failed - \(error.localizedDescription)")
            await userSession.handleAuthError(error, for: .signUp, provider: "password")
            return false
        }
    }
    
    /// Send password reset email
    func resetPassword(email: String) async -> Bool {
        do {
            print("AuthService: Sending password reset email to: \(email)")
            try await Auth.auth().sendPasswordReset(withEmail: email)
            print("AuthService: Password reset email sent successfully")
            await userSession.handlePasswordResetSuccess(email: email)
            return true
        } catch {
            print("AuthService: Password reset failed - \(error.localizedDescription)")
            await userSession.handlePasswordResetError(error, email: email)
            return false
        }
    }
    
    // MARK: - Google Authentication
    
    /// Sign in with Google
    func signInWithGoogle(viewController: UIViewController) async -> Bool {
        do {
            guard let clientID = FirebaseApp.app()?.options.clientID else {
                let error = NSError(domain: "AuthService", code: 1, 
                                  userInfo: [NSLocalizedDescriptionKey: "Missing Google client ID"])
                print("AuthService: \(error.localizedDescription)")
                await userSession.handleAuthError(error, for: .signIn, provider: "google.com")
                return false
            }
            
            let config = GIDConfiguration(clientID: clientID)
            GIDSignIn.sharedInstance.configuration = config
            
            print("AuthService: Starting Google sign-in flow")
            
            // IMPROVED: Create a custom UIViewController with proper styling to present the auth flow
            let authContainerVC = UIViewController()
            authContainerVC.view.backgroundColor = UIColor(Color.theme.background)
            authContainerVC.modalPresentationStyle = .fullScreen
            authContainerVC.modalTransitionStyle = .crossDissolve
            
            // Add a loading indicator to show while the auth screen is loading
            let loadingIndicator = UIActivityIndicatorView(style: .large)
            loadingIndicator.color = UIColor(Color.theme.accent)
            loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
            loadingIndicator.startAnimating()
            
            let loadingLabel = UILabel()
            loadingLabel.text = "Preparing sign-in..."
            loadingLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
            loadingLabel.textColor = UIColor(Color.theme.text)
            loadingLabel.translatesAutoresizingMaskIntoConstraints = false
            
            authContainerVC.view.addSubview(loadingIndicator)
            authContainerVC.view.addSubview(loadingLabel)
            
            NSLayoutConstraint.activate([
                loadingIndicator.centerXAnchor.constraint(equalTo: authContainerVC.view.centerXAnchor),
                loadingIndicator.centerYAnchor.constraint(equalTo: authContainerVC.view.centerYAnchor, constant: -20),
                loadingLabel.topAnchor.constraint(equalTo: loadingIndicator.bottomAnchor, constant: 16),
                loadingLabel.centerXAnchor.constraint(equalTo: authContainerVC.view.centerXAnchor)
            ])
            
            // Present our styled container first
            await MainActor.run {
                viewController.present(authContainerVC, animated: true)
            }
            
            // Configure the proper authentication session
            UserDefaults.standard.set(true, forKey: "ASWebAuthenticationSessionPrefersEphemeralWebBrowserSession")
            
            // Use async/await with a small delay to ensure proper dismissal of any current views
            try await Task.sleep(nanoseconds: 300_000_000) // 0.3 second
            
            // Now perform the Google sign-in within our container
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: authContainerVC)
            
            guard let idToken = result.user.idToken?.tokenString else {
                // Dismiss the auth container on error
                await MainActor.run {
                    authContainerVC.dismiss(animated: true)
                }
                
                let error = NSError(domain: "AuthService", code: 2, 
                                  userInfo: [NSLocalizedDescriptionKey: "Missing ID token from Google sign-in"])
                print("AuthService: \(error.localizedDescription)")
                await userSession.handleAuthError(error, for: .signIn, provider: "google.com")
                return false
            }
            
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )
            
            print("AuthService: Authenticating with Firebase using Google credential")
            try await Auth.auth().signIn(with: credential)
            
            // Dismiss the auth container on success
            await MainActor.run {
                authContainerVC.dismiss(animated: true)
            }
            
            print("AuthService: Firebase authentication with Google successful")
            await userSession.handleAuthSuccess(provider: "google.com")
            return true
        } catch {
            // Dismiss the auth container view if it's presented
            if let rootVC = viewController.presentedViewController {
                await MainActor.run {
                    rootVC.dismiss(animated: true)
                }
            }
            
            print("AuthService: Google sign in failed - \(error.localizedDescription)")
            // If error is user cancellation, provide a more specific error message
            if (error as NSError).code == GIDSignInError.canceled.rawValue {
                let userCanceledError = NSError(domain: "AuthService", code: 3,
                                             userInfo: [NSLocalizedDescriptionKey: "The user canceled the sign-in flow."])
                await userSession.handleAuthError(userCanceledError, for: .signIn, provider: "google.com")
            } else {
                await userSession.handleAuthError(error, for: .signIn, provider: "google.com")
            }
            return false
        }
    }
    
    // MARK: - Apple Authentication
    
    /// Generate a random nonce for Apple Sign In
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
                if remainingLength == 0 { return }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
    
    /// Hash a string using SHA256
    func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%%02x", $0)
        }.joined()
        
        return hashString
    }
    
    /// Sign in with Apple
    func signInWithApple(credential: ASAuthorizationAppleIDCredential, nonce: String) async -> Bool {
        // Retrieve the ID token
        guard let appleIDToken = credential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            let error = NSError(domain: "AuthService", code: 1002, 
                              userInfo: [NSLocalizedDescriptionKey: "Unable to retrieve identity token"])
            print("AuthService: \(error.localizedDescription)")
            await userSession.handleAuthError(error, for: .signIn, provider: "apple.com")
            return false
        }
        
        print("AuthService: Got Apple ID token, creating Firebase credential")
        
        // Create Firebase credential with the Apple ID token
        let authCredential = OAuthProvider.credential(
            providerID: AuthProviderID.apple,
            idToken: idTokenString,
            rawNonce: nonce
        )
        
        do {
            // Attempt Firebase sign in with Apple credential
            print("AuthService: Signing in to Firebase with Apple credential")
            let result = try await Auth.auth().signIn(with: authCredential)
            let firebaseUser = result.user
            
            // Check if this is a new user
            let isNewUser = result.additionalUserInfo?.isNewUser ?? false
            
            // If new user, update display name if available from Apple credentials
            if isNewUser, let fullName = credential.fullName {
                let displayName = [fullName.givenName, fullName.familyName]
                    .compactMap { $0 }
                    .joined(separator: " ")
                
                if !displayName.isEmpty {
                    // Create a profile change request to update the display name
                    print("AuthService: Updating new user's display name to: \(displayName)")
                    let changeRequest = firebaseUser.createProfileChangeRequest()
                    changeRequest.displayName = displayName
                    try await changeRequest.commitChanges()
                }
            }
            
            // Success, notify UserSession
            print("AuthService: Apple sign-in successful for user: \(firebaseUser.uid)")
            await userSession.handleAuthSuccess(provider: "apple.com")
            return true
        } catch {
            print("AuthService: Error signing in with Apple: \(error.localizedDescription)")
            await userSession.handleAuthError(error, for: .signIn, provider: "apple.com")
            return false
        }
    }
    
    // MARK: - Sign Out
    
    func signOut() async -> Bool {
        // Skip sign out for anonymous users to prevent errors
        if Auth.auth().currentUser?.isAnonymous == true {
            print("AuthService: Current user is anonymous, skipping sign out")
            return true
        }
        
        do {
            print("AuthService: Signing out")
            try Auth.auth().signOut()
            await userSession.handleSignOutSuccess()
            return true
        } catch {
            print("AuthService: Sign out failed - \(error.localizedDescription)")
            await userSession.handleSignOutError(error)
            return false
        }
    }
}

// MARK: - Authentication Enums

enum AuthAction {
    case signIn
    case signUp
    case resetPassword
    case signOut
}

// MARK: - Apple Sign In Delegate

// Helper class to handle Apple Sign In response
class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate {
    private let completion: (Result<ASAuthorization, Error>) -> Void
    
    init(completion: @escaping (Result<ASAuthorization, Error>) -> Void) {
        self.completion = completion
        super.init()
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        print("AppleSignInDelegate: Authorization completed")
        completion(.success(authorization))
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("AppleSignInDelegate: Authorization failed: \(error.localizedDescription)")
        completion(.failure(error))
    }
} 