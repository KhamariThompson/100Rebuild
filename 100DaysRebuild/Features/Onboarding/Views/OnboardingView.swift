import SwiftUI
import FirebaseAuth
import GoogleSignIn
import AuthenticationServices
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
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// Content View to break up complex rendering
struct OnboardingContent: View {
    @ObservedObject var viewModel: AuthViewModel
    @Binding var isShowingSignUp: Bool
    @Binding var isShowingUsernameSelection: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack {
            // Background
            Color.theme.background.ignoresSafeArea()
            
            VStack(spacing: 32) {
                // Logo and Title
                LogoView()
                
                // Auth Form Card
                VStack(spacing: 24) {
                    // Form Title
                    Text(isShowingSignUp ? "Ready to start your journey?" : "Welcome back")
                        .font(.title2.bold())
                        .foregroundColor(.theme.text)
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    // Auth Options
                    VStack(spacing: 24) {
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
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.theme.surface)
                        .shadow(
                            color: Color.primary.opacity(colorScheme == .dark ? 0.2 : 0.1),
                            radius: 12, x: 0, y: 8
                        )
                )
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .padding(.top, 40)
            .dismissKeyboardOnTap()
        }
        .navigationBarHidden(true)
        // Alert shown when viewModel.error is not nil
        .alert(
            "Error",
            isPresented: Binding(
                get: { viewModel.error != nil },
                set: { if !$0 { viewModel.error = nil } }
            ),
            actions: { Button("OK", role: .cancel) { } },
            message: { Text(viewModel.error?.localizedDescription ?? "") }
        )
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
        VStack(spacing: 24) {
            // Logo
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 70))
                .foregroundColor(.theme.accent)
            
            // Title and tagline
            VStack(spacing: 16) {
            Text("100Days")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.theme.text)
                
                VStack(spacing: 8) {
                    Text("Build consistency and transform your life")
                        .font(.headline)
                        .foregroundColor(.theme.text)
                        .multilineTextAlignment(.center)
                    
                    Text("— one day at a time.")
                        .font(.headline)
                .foregroundColor(.theme.text)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(.top, 60)
        .padding(.bottom, 30)
    }
}

struct LoadingOverlay: View {
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack {
            Color.primary.opacity(colorScheme == .dark ? 0.7 : 0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
        ProgressView()
            .scaleEffect(1.5)
                    .tint(colorScheme == .dark ? .white : .primary)
                
                Text("Loading...")
                    .font(.headline)
                    .foregroundColor(colorScheme == .dark ? .white : .primary)
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.theme.surface.opacity(0.8))
                    .shadow(color: Color.primary.opacity(0.2), radius: 8, x: 0, y: 4)
            )
        }
    }
}

struct ToggleAuthButton: View {
    @Binding var isShowingSignUp: Bool
    
    var body: some View {
        Button(action: { isShowingSignUp.toggle() }) {
            Text(isShowingSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                .font(.subheadline)
                .foregroundColor(.theme.accent)
                .padding(.top, 8)
        }
        .buttonStyle(.scale)
    }
}

struct SocialSignInButtons: View {
    @ObservedObject var viewModel: AuthViewModel
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 16) {
            Text("or continue with")
                .font(.subheadline)
                .foregroundColor(.theme.subtext)
            
            HStack(spacing: 16) {
                // Google Sign-In
                Button(action: signInWithGoogle) {
                    HStack {
                        Group {
                            if UIImage(named: "google_logo") != nil {
                        Image("google_logo")
                            .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20)
                            } else {
                                // Fallback to system icon
                                Image(systemName: "globe")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20)
                                    .foregroundColor(.theme.accent)
                            }
                        }
                        
                        Text("Google")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(colorScheme == .dark ? Color(.systemGray6) : .white)
                            .shadow(
                                color: Color.primary.opacity(0.1),
                                radius: 4, x: 0, y: 2
                            )
                    )
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                }
                
                // Apple Sign-In
                SignInWithAppleButton(
                    onRequest: configureAppleRequest,
                    onCompletion: handleAppleSignIn
                )
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(
                    color: Color.primary.opacity(0.1),
                    radius: 4, x: 0, y: 2
                )
            }
        }
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
    @State private var showingPasswordResetAlert = false
    @State private var passwordResetSent = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Email Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Email")
                    .font(.subheadline.bold())
                    .foregroundColor(.theme.text)
                
                TextField("Your email address", text: $email)
                    .padding()
                    .background(Color.theme.surface)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.separator), lineWidth: 1)
                    )
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
            }
            
            // Password Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                    .font(.subheadline.bold())
                    .foregroundColor(.theme.text)
                
                SecureField("Your password", text: $password)
                    .padding()
                    .background(Color.theme.surface)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.separator), lineWidth: 1)
                    )
                    .textContentType(.password)
            }
            
            // Forgot Password
            Button(action: {
                passwordResetSent = false
                showingPasswordResetAlert = true
            }) {
                Text("Forgot Password?")
                    .font(.subheadline)
                    .foregroundColor(.theme.accent)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.vertical, 4)
            .alert(
                passwordResetSent ? "Password Reset Email Sent" : "Reset Password",
                isPresented: $showingPasswordResetAlert,
                actions: {
                    if passwordResetSent {
                        Button("OK", role: .cancel) {
                            passwordResetSent = false
                        }
                    } else {
                        TextField("Your email address", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        Button("Cancel", role: .cancel) { }
                        Button("Send Reset Link") {
                            sendPasswordReset()
                        }
                        .disabled(email.isEmpty)
                    }
                },
                message: {
                    passwordResetSent 
                    ? Text("Password reset instructions have been sent to \(email). Please check your email.")
                    : Text("Enter your email address to receive a password reset link")
                }
            )
            
            // Sign In Button
            Button(action: signIn) {
                Text("Sign In")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.theme.accent)
                    )
            }
            .padding(.top, 8)
        }
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
    
    private func sendPasswordReset() {
        Task {
            do {
                try await viewModel.resetPassword(email: email)
                await MainActor.run {
                    passwordResetSent = true
                }
            } catch {
                await MainActor.run {
                    viewModel.error = error
                    showingPasswordResetAlert = false
                }
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
        VStack(spacing: 20) {
            // Email Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Email")
                    .font(.subheadline.bold())
                    .foregroundColor(.theme.text)
                
                TextField("Your email address", text: $email)
                    .padding()
                    .background(Color.theme.surface)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.separator), lineWidth: 1)
                    )
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
                        .padding(.top, 4)
                }
            }
            
            // Password Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                    .font(.subheadline.bold())
                    .foregroundColor(.theme.text)
                
                SecureField("Your password", text: $password)
                    .padding()
                    .background(Color.theme.surface)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.separator), lineWidth: 1)
                    )
                    .textContentType(.newPassword)
                    .onChange(of: password) { _, newValue in
                        passwordError = validatePassword(newValue)
                    }
                
                if let error = passwordError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.theme.error)
                        .padding(.top, 4)
                }
            }
            
            // Confirm Password Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Confirm Password")
                    .font(.subheadline.bold())
                    .foregroundColor(.theme.text)
                
                SecureField("Confirm your password", text: $confirmPassword)
                    .padding()
                    .background(Color.theme.surface)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.separator), lineWidth: 1)
                    )
                    .textContentType(.newPassword)
                    .onChange(of: confirmPassword) { _, newValue in
                        confirmPasswordError = validateConfirmPassword(password, newValue)
                    }
                
                if let error = confirmPasswordError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.theme.error)
                        .padding(.top, 4)
                }
            }
            
            // Sign Up Button
            Button(action: signUp) {
                Text("Sign Up")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isValid ? Color.theme.accent : Color(.systemGray4))
                    )
            }
            .disabled(!isValid)
            .padding(.top, 8)
        }
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
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack {
            // Background
            Color.theme.background.ignoresSafeArea()
            
            VStack(spacing: 32) {
                // Logo
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 70))
                    .foregroundColor(.theme.accent)
                    .padding(.top, 60)
                
                // Form Card
                VStack(spacing: 24) {
                    // Title
                    Text("Choose a Username")
                        .font(.title2.bold())
                        .foregroundColor(.theme.text)
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    Text("This will be displayed to other users")
                        .font(.subheadline)
                        .foregroundColor(.theme.subtext)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 8)
                    
                    // Username Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Username")
                            .font(.subheadline.bold())
                            .foregroundColor(.theme.text)
                        
                        TextField("Enter your username", text: $username)
                            .padding()
                            .background(Color.theme.surface)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(.separator), lineWidth: 1)
                            )
                            .textContentType(.username)
                            .autocapitalization(.none)
                    }
                    
                    // Continue Button
                    Button(action: setUsername) {
                        Text("Continue")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(username.isEmpty ? Color(.systemGray4) : Color.theme.accent)
                            )
                    }
                    .disabled(username.isEmpty)
                    .padding(.top, 16)
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.theme.surface)
                        .shadow(
                            color: Color.primary.opacity(colorScheme == .dark ? 0.2 : 0.1),
                            radius: 12, x: 0, y: 8
                        )
                )
                .padding(.horizontal, 20)
                
                Spacer()
            }
        }
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