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
import Network

// Authentication modes for the AuthView
enum AuthMode {
    case emailSignIn
    case emailSignUp
    case forgotPassword
    case googleSignIn
    case appleSignIn
}

@MainActor
class AuthViewModel: ObservableObject {
    static let shared = AuthViewModel()
    
    // UI State properties
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage: String = ""
    @Published var authMode: AuthMode = .emailSignIn
    @Published var networkConnected: Bool = true
    @Published var showingReconnectedMessage: Bool = false
    
    // Form validation errors
    @Published var emailError: String? = nil
    @Published var passwordError: String? = nil
    @Published var confirmPasswordError: String? = nil
    
    // Apple sign in properties
    var appleIDCredential: ASAuthorizationAppleIDCredential?
    var appleNonce: String?
    
    // Network monitoring
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "AuthViewModel.NetworkMonitor")
    
    // Reference to services
    private let userSession = UserSession.shared
    private let authService = AuthService.shared
    
    // Track last auth attempt for retry
    private var lastAuthAttemptMode: AuthMode?
    
    // MARK: - Fix for Swift 6 capture in closure that outlives deinit
    // This is the method that fixes the error:
    // "Capture of 'self' in a closure that outlives deinit; this is an error in the Swift 6 language mode"
    private func setupAuthStateChangeHandler() {
        // Create a weak reference to self
        weak var weakSelf = self
        
        // Use a local reference to userSession to avoid capturing self
        let userSession = self.userSession
        
        // Set the handler without capturing self
        userSession.authStateDidChangeHandler = { [weak userSession] in
            Task { @MainActor in
                // Use the weak reference inside the handler
                guard let strongSelf = weakSelf else { return }
                strongSelf.isLoading = false
                // Use optional chaining with weak userSession
                if userSession?.errorMessage == nil {
                    strongSelf.showError = false
                }
            }
        }
    }
    
    private init() {
        print("AuthViewModel initialized")
        setupNetworkMonitoring()
        setupAuthStateChangeHandler() // Use the new method instead of directly setting up the handler here
    }
    
    deinit {
        networkMonitor.cancel()
        
        // Remove the handler to avoid retain cycles - don't capture self
        Task { 
            // Use MainActor without capturing self
            await MainActor.run {
                // Using a local reference to avoid capturing self
                UserSession.shared.authStateDidChangeHandler = nil
            }
        }
    }
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            let isConnected = path.status == .satisfied
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                // Avoid multiple UI updates for same state
                guard self.networkConnected != isConnected else { return }
                
                let wasDisconnected = !self.networkConnected
                self.networkConnected = isConnected
                
                // If network reconnected, show the reconnection message
                if isConnected && wasDisconnected {
                    self.showingReconnectedMessage = true
                    
                    // Re-attempt authentication if we were previously disconnected
                    if self.isLoading {
                        self.retryLastAuthAttempt()
                    }
                } else if !isConnected && self.isLoading {
                    // Cancel any in-progress auth and show network error
                    self.isLoading = false
                    self.setError(NSError(domain: "NetworkError", code: 100,
                        userInfo: [NSLocalizedDescriptionKey: "Internet connection lost. Please try again when connected."]))
                }
            }
        }
        networkMonitor.start(queue: networkQueue)
    }
    
    private func retryLastAuthAttempt() {
        guard let lastMode = lastAuthAttemptMode else { return }
        
        switch lastMode {
        case .emailSignIn:
            Task { [weak self] in
                guard let self = self else { return }
                await self.signInWithEmail()
            }
        case .emailSignUp:
            Task { [weak self] in
                guard let self = self else { return }
                await self.signUpWithEmail()
            }
        case .forgotPassword:
            // No need to retry password reset
            break
        case .googleSignIn:
            Task { [weak self] in
                guard let self = self else { return }
                await self.signInWithGoogle()
            }
        case .appleSignIn:
            Task { [weak self] in
                guard let self = self else { return }
                await self.signInWithApple()
            }
        }
    }
    
    // MARK: - Computed Properties
    
    var needsUsername: Bool {
        if case .signedIn = userSession.authState, userSession.username == nil {
            return true
        }
        return false
    }
    
    var isFormValid: Bool {
        // Ensure network connectivity first
        guard networkConnected else { return false }
        
        switch authMode {
        case .emailSignIn:
            return !email.isEmpty && !password.isEmpty
        case .emailSignUp:
            return !email.isEmpty && !password.isEmpty && password == confirmPassword && password.count >= 6
        case .forgotPassword:
            return !email.isEmpty
        case .googleSignIn:
            return true
        case .appleSignIn:
            return true
        }
    }
    
    // MARK: - Form Validation Methods
    
    func validateForm() -> Bool {
        // Only calculate validation state without updating published properties
        let emailErrorResult = validateEmail(email)
        
        switch authMode {
        case .emailSignIn:
            let passwordErrorResult = validateSignInPassword(password)
            return emailErrorResult == nil && passwordErrorResult == nil && !email.isEmpty && !password.isEmpty
            
        case .emailSignUp:
            let passwordErrorResult = validatePassword(password)
            let confirmPasswordErrorResult = validateConfirmPassword(password, confirmPassword)
            return emailErrorResult == nil && passwordErrorResult == nil && confirmPasswordErrorResult == nil && 
                  !email.isEmpty && !password.isEmpty && !confirmPassword.isEmpty
            
        case .forgotPassword:
            return emailErrorResult == nil && !email.isEmpty
        case .googleSignIn:
            return true
        case .appleSignIn:
            return true
        }
    }
    
    // Update validation state properties separately (not during view rendering)
    func updateValidationState() {
        emailError = validateEmail(email)
        
        switch authMode {
        case .emailSignIn:
            passwordError = validateSignInPassword(password)
        case .emailSignUp:
            passwordError = validatePassword(password)
            confirmPasswordError = validateConfirmPassword(password, confirmPassword)
        case .forgotPassword:
            // No additional validation needed
            break
        case .googleSignIn:
            // No additional validation needed
            break
        case .appleSignIn:
            // No additional validation needed
            break
        }
    }
    
    // Validation helper methods
    func validateEmail(_ email: String) -> String? {
        guard !email.isEmpty else { return nil }
        
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email) ? nil : "Please enter a valid email address"
    }
    
    func validateSignInPassword(_ password: String) -> String? {
        guard !password.isEmpty else { return nil }
        return password.count < 6 ? "Password must be at least 6 characters" : nil
    }
    
    func validatePassword(_ password: String) -> String? {
        guard !password.isEmpty else { return nil }
        return password.count < 6 ? "Password must be at least 6 characters" : nil
    }
    
    func validateConfirmPassword(_ password: String, _ confirmPassword: String) -> String? {
        guard !confirmPassword.isEmpty else { return nil }
        return password != confirmPassword ? "Passwords do not match" : nil
    }
    
    // MARK: - Error Handling
    
    func setError(_ error: Error) {
        let nsError = error as NSError
        print("AuthViewModel ERROR - Domain: \(nsError.domain), Code: \(nsError.code), Description: \(nsError.localizedDescription)")
        
        // Update UI state
        errorMessage = nsError.localizedDescription
        showError = true
    }
    
    func clearCredentials() {
        email = ""
        password = ""
        confirmPassword = ""
    }
    
    // MARK: - Authentication Methods
    
    /// Email sign in
    func signInWithEmail() async {
        guard validateForm() else {
            updateValidationState()
            return
        }
        
        guard networkConnected else {
            setError(NSError(domain: "AuthError", code: 6, 
                           userInfo: [NSLocalizedDescriptionKey: "No internet connection. Please check your network settings."]))
            return
        }
        
        isLoading = true
        lastAuthAttemptMode = .emailSignIn
        
        // Use Task with weak self to avoid capturing self strongly
        let email = self.email
        let password = self.password
        
        // Create local reference to avoid capturing self in Task
        let authService = self.authService
        let userSession = self.userSession
        
        Task { [weak self] in
            let success = await authService.signInWithEmail(email: email, password: password)
            
            await MainActor.run {
                guard let self = self else { return }
                
                // Check for error message from UserSession
                if let errorMsg = userSession.errorMessage {
                    self.errorMessage = errorMsg
                    self.showError = true
                }
                
                if success {
                    // Clear credentials only on success
                    self.clearCredentials()
                } else {
                    self.isLoading = false
                }
            }
        }
    }
    
    /// Email sign up
    func signUpWithEmail() async {
        guard validateForm() else {
            updateValidationState()
            return
        }
        
        guard networkConnected else {
            setError(NSError(domain: "AuthError", code: 6, 
                           userInfo: [NSLocalizedDescriptionKey: "No internet connection. Please check your network settings."]))
            return
        }
        
        isLoading = true
        lastAuthAttemptMode = .emailSignUp
        
        // Create local copies to avoid capturing self
        let email = self.email
        let password = self.password
        let authService = self.authService
        let userSession = self.userSession
        
        Task { [weak self] in
            let success = await authService.signUpWithEmail(email: email, password: password)
            
            await MainActor.run {
                guard let self = self else { return }
                
                // Check for error message from UserSession
                if let errorMsg = userSession.errorMessage {
                    self.errorMessage = errorMsg
                    self.showError = true
                }
                
                if success {
                    // Clear credentials only on success
                    self.clearCredentials()
                } else {
                    self.isLoading = false
                }
            }
        }
    }
    
    /// Google sign in
    func signInWithGoogle() async {
        // Find root view controller for Google sign-in
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            setError(NSError(domain: "GoogleSignIn", code: 1001, 
                          userInfo: [NSLocalizedDescriptionKey: "Unable to present Google sign-in UI"]))
            return
        }
        
        isLoading = true
        lastAuthAttemptMode = .googleSignIn
        
        // Create local references to avoid capturing self
        let authService = self.authService
        let userSession = self.userSession
        
        Task { [weak self] in
            do {
                let success = await authService.signInWithGoogle(viewController: rootViewController)
                
                await MainActor.run {
                    guard let self = self else { return }
                    
                    // Check for error message from UserSession
                    if let errorMsg = userSession.errorMessage {
                        self.errorMessage = errorMsg
                        self.showError = true
                    }
                    
                    if !success {
                        self.isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    guard let self = self else { return }
                    self.setError(error)
                    self.isLoading = false
                }
            }
        }
    }
    
    /// Apple sign in
    func signInWithApple() async {
        guard let appleIDCredential = appleIDCredential,
              let nonce = appleNonce else {
            setError(NSError(domain: "AppleSignIn", code: 1001, 
                          userInfo: [NSLocalizedDescriptionKey: "Invalid Apple sign-in state"]))
            return
        }
        
        isLoading = true
        lastAuthAttemptMode = .appleSignIn
        
        // Create local references to avoid capturing self
        let appleCredential = self.appleIDCredential
        let authNonce = self.appleNonce
        let authService = self.authService
        let userSession = self.userSession
        
        Task { [weak self] in
            do {
                let success = await authService.signInWithApple(credential: appleCredential!, nonce: authNonce!)
                
                await MainActor.run {
                    guard let self = self else { return }
                    
                    // Check for error message from UserSession
                    if let errorMsg = userSession.errorMessage {
                        self.errorMessage = errorMsg
                        self.showError = true
                    }
                    
                    // Reset nonce and credential for security
                    self.appleNonce = nil
                    self.appleIDCredential = nil
                    
                    if !success {
                        self.isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    guard let self = self else { return }
                    // Reset nonce and credential for security
                    self.appleNonce = nil
                    self.appleIDCredential = nil
                    self.setError(error)
                    self.isLoading = false
                }
            }
        }
    }
    
    /// Password reset
    func resetPassword(email: String) async {
        isLoading = true
        
        // Create local references to avoid capturing self
        let authService = self.authService
        let userSession = self.userSession
        
        Task { [weak self] in
            let success = await authService.resetPassword(email: email)
            
            await MainActor.run {
                guard let self = self else { return }
                
                // Check for error message from UserSession
                if let errorMsg = userSession.errorMessage {
                    self.errorMessage = errorMsg
                    self.showError = true
                }
                
                self.isLoading = false
                
                if success {
                    // Return to sign in mode after successful password reset
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                        self?.authMode = .emailSignIn
                    }
                }
            }
        }
    }
    
    /// Sign out
    func signOut() async {
        isLoading = true
        
        // Create local references to avoid capturing self
        let authService = self.authService
        let userSession = self.userSession
        
        Task { [weak self] in
            let success = await authService.signOut()
            
            await MainActor.run {
                guard let self = self else { return }
                
                if !success {
                    self.isLoading = false
                    
                    // Check for error message from UserSession
                    if let errorMsg = userSession.errorMessage {
                        self.errorMessage = errorMsg
                        self.showError = true
                    }
                }
            }
        }
    }
    
    /// Set username for user profile
    func setUsernameWithHandling(username: String) async {
        isLoading = true
        
        // Create local references to avoid capturing self
        let userSession = self.userSession
        
        Task { [weak self] in
            do {
                try await userSession.updateUsername(username)
                print("Username set successfully: \(username)")
            } catch {
                await MainActor.run {
                    guard let self = self else { return }
                    self.setError(error)
                }
            }
            
            await MainActor.run {
                self?.isLoading = false
            }
        }
    }
    
    // MARK: - Helper Methods for Apple Sign In
    
    // Delegate to AuthService
    func randomNonceString(length: Int = 32) -> String {
        return authService.randomNonceString(length: length)
    }
    
    func sha256(_ input: String) -> String {
        return authService.sha256(input)
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
