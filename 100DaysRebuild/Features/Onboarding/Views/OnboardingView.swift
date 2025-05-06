import SwiftUI
import AuthenticationServices
import GoogleSignIn
import UIKit

// Main Onboarding View broken into smaller components
struct OnboardingView: View {
    @StateObject private var viewModel = AuthViewModel.shared
    @State private var isShowingSignUp = false
    @State private var isShowingUsernameSelection = false
    
    var body: some View {
        NavigationView {
            OnboardingContent(
                viewModel: viewModel,
                isShowingSignUp: $isShowingSignUp,
                isShowingUsernameSelection: $isShowingUsernameSelection
            )
        }
    }
}

// Content View to break up complex rendering
struct OnboardingContent: View {
    @ObservedObject var viewModel: AuthViewModel
    @Binding var isShowingSignUp: Bool
    @Binding var isShowingUsernameSelection: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            // Logo and Title
            LogoView()
            
            // Auth Options
            VStack(spacing: 16) {
                if isShowingSignUp {
                    SignUpForm(viewModel: viewModel)
                } else {
                    SignInForm(viewModel: viewModel)
                }
                
                // Social Sign-In
                SocialSignInButtons(viewModel: viewModel)
                
                // Toggle Sign Up/Sign In
                ToggleAuthButton(isShowingSignUp: $isShowingSignUp)
            }
            
            Spacer()
        }
        .background(Color.theme.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .alert(item: .constant(viewModel.error.map { AuthAlert(message: $0.localizedDescription) })) { alert in
            Alert(
                title: Text("Error"),
                message: Text(alert.message),
                dismissButton: .default(Text("OK")) {
                    viewModel.error = nil
                }
            )
        }
        .overlay {
            if viewModel.isLoading {
                LoadingOverlay()
            }
        }
        .onChange(of: viewModel.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                isShowingUsernameSelection = true
            }
        }
    }
}

// Separate components
struct LogoView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.theme.accent)
            
            Text("100Days")
                .font(.largeTitle)
                .foregroundColor(.theme.text)
        }
        .padding(.top, 60)
    }
}

struct LoadingOverlay: View {
    var body: some View {
        ProgressView()
            .scaleEffect(1.5)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.theme.background.opacity(0.5))
    }
}

struct AuthAlert: Identifiable {
    let id = UUID()
    let message: String
}

struct ToggleAuthButton: View {
    @Binding var isShowingSignUp: Bool
    
    var body: some View {
        Button(action: { isShowingSignUp.toggle() }) {
            Text(isShowingSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                .font(.subheadline)
                .foregroundColor(.theme.accent)
        }
    }
}

struct SocialSignInButtons: View {
    @ObservedObject var viewModel: AuthViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            Text("or continue with")
                .font(.subheadline)
                .foregroundColor(.theme.subtext)
            
            HStack(spacing: 16) {
                // Google Sign-In
                Button(action: signInWithGoogle) {
                    HStack {
                        Image("google_logo")
                            .resizable()
                            .frame(width: 24, height: 24)
                        Text("Google")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .foregroundColor(.black)
                    .cornerRadius(12)
                }
                
                // Apple Sign-In
                SignInWithAppleButton(
                    onRequest: configureAppleRequest,
                    onCompletion: handleAppleSignIn
                )
                .signInWithAppleButtonStyle(.white)
                .frame(height: 50)
                .cornerRadius(12)
            }
        }
        .padding(.horizontal)
    }
    
    private func signInWithGoogle() {
        Task {
            do {
                // Get the current active window scene
                guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let rootViewController = windowScene.windows.first?.rootViewController else {
                    return
                }
                try await viewModel.signInWithGoogle(presenting: rootViewController)
            } catch {
                viewModel.error = error
            }
        }
    }
    
    private func configureAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
        // Create and store a new nonce for this sign-in session
        let nonce = viewModel.randomNonceString()
        viewModel.currentNonce = nonce
        request.nonce = viewModel.sha256(nonce)
    }
    
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success:
            // The credential is handled directly in the viewModel
            Task {
                do {
                    try await viewModel.signInWithApple()
                } catch {
                    viewModel.error = error
                }
            }
        case .failure(let error):
            viewModel.error = error
        }
    }
}

// MARK: - Sign In Form
struct SignInForm: View {
    @ObservedObject var viewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    
    var body: some View {
        VStack(spacing: 16) {
            // Email Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Email")
                    .font(.subheadline)
                    .foregroundColor(.theme.text)
                
                TextField("Enter your email", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
            }
            
            // Password Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                    .font(.subheadline)
                    .foregroundColor(.theme.text)
                
                SecureField("Enter your password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.password)
            }
            
            // Forgot Password
            Button(action: forgotPassword) {
                Text("Forgot Password?")
                    .font(.subheadline)
                    .foregroundColor(.theme.accent)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            
            // Sign In Button
            Button(action: signIn) {
                Text("Sign In")
            }
            .buttonStyle(.primary)
        }
        .padding(.horizontal)
    }
    
    private func forgotPassword() {
        Task {
            do {
                try await viewModel.resetPassword(email: email)
            } catch {
                viewModel.error = error
            }
        }
    }
    
    private func signIn() {
        Task {
            do {
                try await viewModel.signIn(email: email, password: password)
            } catch {
                viewModel.error = error
            }
        }
    }
}

// MARK: - Sign Up Form
struct SignUpForm: View {
    @ObservedObject var viewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var emailError: String?
    @State private var passwordError: String?
    @State private var confirmPasswordError: String?
    
    var body: some View {
        VStack(spacing: 16) {
            // Email Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Email")
                    .font(.subheadline)
                    .foregroundColor(.theme.text)
                
                TextField("Enter your email", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .onChange(of: email) { _, newValue in
                        emailError = validateEmail(newValue)
                    }
                
                if let error = emailError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.theme.error)
                }
            }
            
            // Password Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                    .font(.subheadline)
                    .foregroundColor(.theme.text)
                
                SecureField("Enter your password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.newPassword)
                    .onChange(of: password) { _, newValue in
                        passwordError = validatePassword(newValue)
                    }
                
                if let error = passwordError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.theme.error)
                }
            }
            
            // Confirm Password Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Confirm Password")
                    .font(.subheadline)
                    .foregroundColor(.theme.text)
                
                SecureField("Confirm your password", text: $confirmPassword)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.newPassword)
                    .onChange(of: confirmPassword) { _, newValue in
                        confirmPasswordError = validateConfirmPassword(password, newValue)
                    }
                
                if let error = confirmPasswordError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.theme.error)
                }
            }
            
            // Sign Up Button
            Button(action: signUp) {
                Text("Sign Up")
            }
            .buttonStyle(.primary)
            .disabled(!isValid)
        }
        .padding(.horizontal)
    }
    
    private var isValid: Bool {
        return emailError == nil && 
               passwordError == nil && 
               confirmPasswordError == nil &&
               !email.isEmpty && 
               !password.isEmpty && 
               !confirmPassword.isEmpty
    }
    
    private func validateEmail(_ email: String) -> String? {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email) ? nil : "Please enter a valid email"
    }
    
    private func validatePassword(_ password: String) -> String? {
        return password.count >= 6 ? nil : "Password must be at least 6 characters"
    }
    
    private func validateConfirmPassword(_ password: String, _ confirmPassword: String) -> String? {
        return password == confirmPassword ? nil : "Passwords do not match"
    }
    
    private func signUp() {
        Task {
            do {
                try await viewModel.signUp(email: email, password: password)
            } catch {
                viewModel.error = error
            }
        }
    }
}

// MARK: - Username Selection
struct UsernameSelectionView: View {
    @ObservedObject var viewModel: AuthViewModel
    @State private var username = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            // Title
            Text("Choose a Username")
                .font(.title2)
                .foregroundColor(.theme.text)
            
            // Username Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Username")
                    .font(.subheadline)
                    .foregroundColor(.theme.text)
                
                TextField("Enter your username", text: $username)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.username)
                    .autocapitalization(.none)
            }
            .padding(.horizontal)
            
            // Continue Button
            Button(action: setUsername) {
                Text("Continue")
            }
            .buttonStyle(.primary)
            .padding(.horizontal)
            
            Spacer()
        }
        .background(Color.theme.background.ignoresSafeArea())
        .navigationBarHidden(true)
    }
    
    private func setUsername() {
        Task {
            do {
                try await viewModel.setUsername(username: username)
                dismiss()
            } catch {
                viewModel.error = error
            }
        }
    }
}

// MARK: - Preview
struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
    }
} 