import SwiftUI
import FirebaseAuth
import GoogleSignIn
import AuthenticationServices
import CryptoKit

struct WelcomeView: View {
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var themeManager: ThemeManager
    @State private var isShowingAuthView = false
    @State private var animationCompleted = false
    
    // State for Apple Sign In
    @State private var currentNonce: String?
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.theme.background
                    .ignoresSafeArea()
                
                // Main content
                VStack(spacing: 40) {
                    Spacer()
                    
                    // App logo and branding
                    VStack(spacing: 15) {
                        Image(systemName: "checkmark.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                            .foregroundColor(.theme.accent)
                        
                        Text("100Days")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundColor(.theme.text)
                        
                        Text("Build habits that last")
                            .font(.system(size: 18, design: .rounded))
                            .foregroundColor(.theme.subtext)
                    }
                    .padding(.bottom, 40)
                    
                    // Welcome message
                    VStack(spacing: 16) {
                        Text("Track your progress")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.theme.text)
                        
                        Text("Create challenges, build streaks, and achieve your goals with 100Days")
                            .font(.system(size: 16))
                            .foregroundColor(.theme.subtext)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    
                    Spacer()
                    
                    // Action buttons
                    VStack(spacing: 16) {
                        // Get Started button
                        Button {
                            isShowingAuthView = true
                        } label: {
                            Text("Get Started")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.theme.accent)
                                )
                                .shadow(color: Color.theme.accent.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        
                        // Sign in with Apple
                        SignInWithAppleButton(
                            text: .signIn,
                            onRequest: { request in
                                let nonce = randomNonceString()
                                currentNonce = nonce
                                request.requestedScopes = [.email]
                                request.nonce = sha256(nonce)
                            },
                            onCompletion: { result in
                                Task {
                                    await handleAppleSignIn(result: result)
                                }
                            }
                        )
                        .frame(height: 55)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 30)
                    .padding(.bottom, 50)
                }
                .padding()
            }
            .fullScreenCover(isPresented: $isShowingAuthView) {
                AuthView()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // MARK: - Helper Methods
    
    private func handleAppleSignIn(result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                // Process Apple ID credential
                await signInWithApple(credential: appleIDCredential)
            }
        case .failure(let error):
            print("Apple Sign In failed: \(error.localizedDescription)")
        }
    }
    
    private func signInWithApple(credential: ASAuthorizationAppleIDCredential) async {
        // Extract tokens from credential
        guard let tokenData = credential.identityToken,
              let token = String(data: tokenData, encoding: .utf8),
              let nonce = currentNonce else {
            print("Unable to fetch identity token or nonce is missing")
            return
        }
        
        // Create Firebase credential
        let firebaseCredential = OAuthProvider.credential(withProviderID: "apple.com",
                                                         idToken: token,
                                                         rawNonce: nonce)
        
        // Sign in with Firebase
        do {
            let authResult = try await Auth.auth().signIn(with: firebaseCredential)
            
            // Check if this is a new user and name data is available
            if authResult.additionalUserInfo?.isNewUser == true,
               let givenName = credential.fullName?.givenName,
               !givenName.isEmpty {
                
                // Create a display name from the Apple credential data
                var components: [String] = []
                if let givenName = credential.fullName?.givenName {
                    components.append(givenName)
                }
                if let familyName = credential.fullName?.familyName {
                    components.append(familyName)
                }
                
                if !components.isEmpty {
                    let displayName = components.joined(separator: " ")
                    
                    // Use Firebase's profile change request
                    let changeRequest = authResult.user.createProfileChangeRequest()
                    changeRequest.displayName = displayName
                    try await changeRequest.commitChanges()
                    
                    print("Updated user display name to: \(displayName)")
                }
            }
        } catch {
            print("Error signing in with Apple: \(error.localizedDescription)")
        }
    }
    
    // Generate a random nonce for authentication
    private func randomNonceString(length: Int = 32) -> String {
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
    
    // Compute the SHA256 hash of the nonce
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
}

// MARK: - Preview Provider
struct WelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeView()
            .environmentObject(UserSession.shared)
            .environmentObject(ThemeManager.shared)
    }
} 
