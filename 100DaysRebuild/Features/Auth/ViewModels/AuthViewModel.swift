import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
import AuthenticationServices
import CryptoKit
import UIKit

@MainActor
class AuthViewModel: ObservableObject {
    static let shared = AuthViewModel()
    
    @Published private(set) var isAuthenticated = false
    @Published private(set) var needsUsername = false
    @Published var error: Error?
    @Published var email = ""
    @Published var password = ""
    
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
    
    func signInWithApple() async throws {
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
    
    func signIn(email: String, password: String) async throws {
        try await auth.signIn(withEmail: email, password: password)
    }
    
    func signUp(email: String, password: String) async throws {
        try await auth.createUser(withEmail: email, password: password)
    }
    
    func signOut() async throws {
        try auth.signOut()
    }
    
    func resetPassword(email: String) async throws {
        try await auth.sendPasswordReset(withEmail: email)
    }
    
    func setUsername(username: String) async throws {
        guard let userId = auth.currentUser?.uid else {
            throw AuthError.unauthorized
        }
        
        try await FirebaseService.shared.createUserProfile(username: username, userId: userId)
    }
    
    var isLoading: Bool {
        return false // TODO: Add proper loading state
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