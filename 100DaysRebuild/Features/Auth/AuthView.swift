import SwiftUI
import UIKit
import FirebaseAuth
import GoogleSignIn
import AuthenticationServices

// No need to import AuthAlert from Models since we're not using it directly in this file anymore

struct AuthView: View {
    @StateObject private var viewModel = AuthViewModel.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var isShowingSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var showingPasswordResetAlert = false
    @State private var passwordResetSent = false
    
    var body: some View {
        ZStack {
            // Background
            Color.theme.background
                .ignoresSafeArea()
            
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.theme.accent.opacity(0.2),
                    Color.theme.background
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 32) {
                    // Logo and Headline
                    headerView
                    
                    // Auth Form
                    VStack(spacing: 24) {
                        // Title
                        Text(isShowingSignUp ? "Ready to start your journey?" : "Welcome back")
                            .font(.title2.bold())
                            .foregroundColor(Color.theme.text)
                            .frame(maxWidth: .infinity, alignment: .center)
                        
                        // Form Fields
                        VStack(spacing: 24) {
                            if isShowingSignUp {
                                signUpForm
                            } else {
                                signInForm
                            }
                            
                            // Social Sign-In
                            socialSignInButtons
                            
                            // Toggle between Sign Up/Sign In
                            Button(action: { 
                                isShowingSignUp.toggle() 
                                // Clear fields when switching modes
                                email = ""
                                password = ""
                            }) {
                                Text(isShowingSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                                    .font(.subheadline)
                                    .foregroundColor(Color.theme.accent)
                                    .padding(.top, 8)
                            }
                            .buttonStyle(.scale)
                        }
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.theme.surface)
                            .shadow(
                                color: colorScheme == .dark 
                                    ? Color.black.opacity(0.3)
                                    : Color.primary.opacity(0.1),
                                radius: 16, 
                                x: 0, 
                                y: 8
                            )
                    )
                    .padding(.horizontal, 20)
                    
                    Spacer(minLength: 30)
                }
                .padding(.top, 60)
            }
            .dismissKeyboardOnTap()
        }
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
        // Password reset alert
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
        .overlay {
            if viewModel.isLoading {
                loadingOverlay
            }
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 24) {
            // Logo
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 70))
                .foregroundColor(Color.theme.accent)
                .background(
                    Circle()
                        .fill(Color.theme.surface.opacity(0.7))
                        .frame(width: 100, height: 100)
                        .shadow(
                            color: Color.theme.accent.opacity(0.3),
                            radius: 10,
                            x: 0,
                            y: 5
                        )
                )
            
            // Title and tagline
            VStack(spacing: 16) {
                Text("100Days")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(Color.theme.text)
                
                VStack(spacing: 8) {
                    Text("Build consistency and transform your life")
                        .font(.headline)
                        .foregroundColor(Color.theme.subtext)
                        .multilineTextAlignment(.center)
                    
                    Text("— one day at a time.")
                        .font(.headline)
                        .foregroundColor(Color.theme.accent)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }
    
    private var signInForm: some View {
        VStack(spacing: 20) {
            // Email Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Email")
                    .font(.subheadline.bold())
                    .foregroundColor(Color.theme.text)
                
                TextField("Your email address", text: $email)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(colorScheme == .dark 
                                ? Color(.secondarySystemBackground)
                                : Color(.systemBackground))
                            .shadow(
                                color: Color.primary.opacity(0.05),
                                radius: 3,
                                x: 0,
                                y: 2
                            )
                    )
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .submitLabel(.next)
            }
            
            // Password Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                    .font(.subheadline.bold())
                    .foregroundColor(Color.theme.text)
                
                SecureField("Your password", text: $password)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(colorScheme == .dark 
                                ? Color(.secondarySystemBackground)
                                : Color(.systemBackground))
                            .shadow(
                                color: Color.primary.opacity(0.05),
                                radius: 3,
                                x: 0,
                                y: 2
                            )
                    )
                    .textContentType(.password)
                    .submitLabel(.done)
            }
            
            // Forgot Password
            Button(action: {
                passwordResetSent = false
                showingPasswordResetAlert = true
            }) {
                Text("Forgot Password?")
                    .font(.subheadline)
                    .foregroundColor(Color.theme.accent)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.vertical, 4)
            .buttonStyle(.scale)
            
            // Sign In Button
            Button(action: signIn) {
                Text("Sign In")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.theme.accent,
                                        Color.theme.accent.opacity(0.8)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(
                                color: Color.theme.accent.opacity(0.3),
                                radius: 8,
                                x: 0,
                                y: 4
                            )
                    )
            }
            .buttonStyle(.scale)
            .padding(.top, 8)
        }
    }
    
    private var signUpForm: some View {
        VStack(spacing: 20) {
            // Email Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Email")
                    .font(.subheadline.bold())
                    .foregroundColor(Color.theme.text)
                
                TextField("Your email address", text: $email)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(colorScheme == .dark 
                                ? Color(.secondarySystemBackground)
                                : Color(.systemBackground))
                            .shadow(
                                color: Color.primary.opacity(0.05),
                                radius: 3,
                                x: 0,
                                y: 2
                            )
                    )
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .submitLabel(.next)
            }
            
            // Password Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                    .font(.subheadline.bold())
                    .foregroundColor(Color.theme.text)
                
                SecureField("Choose a password", text: $password)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(colorScheme == .dark 
                                ? Color(.secondarySystemBackground)
                                : Color(.systemBackground))
                            .shadow(
                                color: Color.primary.opacity(0.05),
                                radius: 3,
                                x: 0,
                                y: 2
                            )
                    )
                    .textContentType(.newPassword)
                    .submitLabel(.done)
            }
            
            // Sign Up Button
            Button(action: signUp) {
                Text("Create Account")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.theme.accent,
                                        Color.theme.accent.opacity(0.8)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(
                                color: Color.theme.accent.opacity(0.3),
                                radius: 8,
                                x: 0,
                                y: 4
                            )
                    )
            }
            .buttonStyle(.scale)
            .padding(.top, 8)
        }
    }
    
    private var socialSignInButtons: some View {
        VStack(spacing: 16) {
            Text("or continue with")
                .font(.subheadline)
                .foregroundColor(Color.theme.subtext)
            
            HStack(spacing: 16) {
                // Google Sign-In
                Button(action: signInWithGoogle) {
                    HStack {
                        Image(systemName: "g.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .foregroundColor(.red)
                        
                        Text("Google")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.theme.surface)
                            .shadow(
                                color: Color.primary.opacity(colorScheme == .dark ? 0.2 : 0.1),
                                radius: 4,
                                x: 0,
                                y: 2
                            )
                    )
                    .foregroundColor(Color.theme.text)
                }
                .buttonStyle(.scale)
                
                // Apple Sign-In
                Button(action: signInWithApple) {
                    HStack {
                        Image(systemName: "apple.logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                        
                        Text("Apple")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.theme.surface)
                            .shadow(
                                color: Color.primary.opacity(colorScheme == .dark ? 0.2 : 0.1),
                                radius: 4,
                                x: 0,
                                y: 2
                            )
                    )
                    .foregroundColor(Color.theme.text)
                }
                .buttonStyle(.scale)
            }
        }
    }
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                
                Text("Loading...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.theme.surface.opacity(0.9))
                    .shadow(
                        color: Color.white.opacity(0.2),
                        radius: 10,
                        x: 0,
                        y: 4
                    )
            )
        }
    }
    
    private func signInWithGoogle() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            return
        }
        
        Task {
            do {
                try await viewModel.signInWithGoogle(presenting: rootViewController)
            } catch {
                viewModel.error = error
            }
        }
    }
    
    private func signInWithApple() {
        Task {
            do {
                try await viewModel.signInWithApple()
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
    
    private func signUp() {
        Task {
            do {
                try await viewModel.signUp(email: email, password: password)
            } catch {
                viewModel.error = error
            }
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
}

// MARK: - Preview
struct AuthView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            AuthView()
                .preferredColorScheme(.light)
                .previewDisplayName("Light Mode")
            
            AuthView()
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
        }
    }
} 