import SwiftUI
import UIKit
import FirebaseAuth
import GoogleSignIn
import AuthenticationServices

// No need to import AuthAlert from Models since we're not using it directly in this file anymore

struct AuthView: View {
    @StateObject private var viewModel = AuthViewModel.shared
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingSignUp = false
    @State private var email = ""
    @State private var password = ""
    
    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 32) {
                    // Logo and Headline
                    headerView
                    
                    // Auth Form
                    VStack(spacing: 24) {
                        // Title
                        Text(isShowingSignUp ? "Ready to start your journey?" : "Welcome back")
                            .font(.title2.bold())
                            .foregroundColor(.white)
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
                            Button(action: { isShowingSignUp.toggle() }) {
                                Text(isShowingSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                                    .padding(.top, 8)
                            }
                        }
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(UIColor.systemGray6))
                            .shadow(color: Color.white.opacity(0.1), radius: 12, x: 0, y: 8)
                    )
                    .padding(.horizontal, 20)
                    
                    Spacer(minLength: 30)
                }
                .padding(.top, 60)
            }
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
                .foregroundColor(.white)
            
            // Title and tagline
            VStack(spacing: 16) {
                Text("100Days")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.white)
                
                VStack(spacing: 8) {
                    Text("Build consistency and transform your life")
                        .font(.headline)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text("— one day at a time.")
                        .font(.headline)
                        .foregroundColor(.white)
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
                    .foregroundColor(Color(UIColor.label))
                
                TextField("Your email address", text: $email)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
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
                    .foregroundColor(Color(UIColor.label))
                
                SecureField("Your password", text: $password)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    .textContentType(.password)
                    .submitLabel(.done)
            }
            
            // Forgot Password
            Button(action: forgotPassword) {
                Text("Forgot Password?")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.vertical, 4)
            
            // Sign In Button
            Button(action: signIn) {
                Text("Sign In")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue)
                    )
            }
            .padding(.top, 8)
        }
    }
    
    private var signUpForm: some View {
        VStack(spacing: 20) {
            // Email Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Email")
                    .font(.subheadline.bold())
                    .foregroundColor(Color(UIColor.label))
                
                TextField("Your email address", text: $email)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
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
                    .foregroundColor(Color(UIColor.label))
                
                SecureField("Choose a password", text: $password)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
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
                            .fill(Color.blue)
                    )
            }
            .padding(.top, 8)
        }
    }
    
    private var socialSignInButtons: some View {
        VStack(spacing: 16) {
            Text("or continue with")
                .font(.subheadline)
                .foregroundColor(Color(UIColor.secondaryLabel))
            
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
                            .fill(Color(UIColor.tertiarySystemBackground))
                    )
                    .foregroundColor(Color(UIColor.label))
                }
                
                // Apple Sign-In
                Button(action: signInWithApple) {
                    HStack {
                        Image(systemName: "apple.logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                        
                        Text("Apple")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(UIColor.tertiarySystemBackground))
                    )
                    .foregroundColor(Color(UIColor.label))
                }
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
                    .fill(Color(UIColor.systemGray6).opacity(0.8))
                    .shadow(color: Color.white.opacity(0.2), radius: 8, x: 0, y: 4)
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
}

// MARK: - Preview
struct AuthView_Previews: PreviewProvider {
    static var previews: some View {
        AuthView()
    }
} 