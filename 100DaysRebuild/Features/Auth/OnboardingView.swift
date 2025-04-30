import SwiftUI
import AuthenticationServices
import GoogleSignIn

struct OnboardingView: View {
    @StateObject private var viewModel = AuthViewModel()
    @State private var isShowingSignUp = false
    @State private var isShowingUsernameSelection = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Logo and Title
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.theme.accent)
                    
                    Text("100Days")
                        .font(.largeTitle)
                        .foregroundColor(.theme.text)
                }
                .padding(.top, 60)
                
                // Auth Options
                VStack(spacing: 16) {
                    if isShowingSignUp {
                        SignUpForm(viewModel: viewModel)
                    } else {
                        SignInForm(viewModel: viewModel)
                    }
                    
                    // Social Sign-In
                    VStack(spacing: 12) {
                        Text("or continue with")
                            .font(.subheadline)
                            .foregroundColor(.theme.subtext)
                        
                        HStack(spacing: 16) {
                            // Google Sign-In
                            Button(action: { viewModel.handle(.signInWithGoogle) }) {
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
                                onRequest: { request in
                                    request.requestedScopes = [.fullName, .email]
                                    viewModel.currentNonce = viewModel.randomNonceString()
                                    request.nonce = viewModel.currentNonce
                                },
                                onCompletion: { result in
                                    switch result {
                                    case .success(let authResults):
                                        if let appleIDCredential = authResults.credential as? ASAuthorizationAppleIDCredential {
                                            viewModel.handle(.signInWithApple(credential: appleIDCredential))
                                        }
                                    case .failure(let error):
                                        viewModel.state.error = error.localizedDescription
                                    }
                                }
                            )
                            .signInWithAppleButtonStyle(.white)
                            .frame(height: 50)
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Toggle Sign Up/Sign In
                    Button(action: { isShowingSignUp.toggle() }) {
                        Text(isShowingSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                            .font(.subheadline)
                            .foregroundColor(.theme.accent)
                    }
                }
                
                Spacer()
            }
            .background(Color.theme.background.ignoresSafeArea())
            .navigationBarHidden(true)
            .alert("Error", isPresented: .constant(viewModel.state.error != nil)) {
                Button("OK") {
                    viewModel.state.error = nil
                }
            } message: {
                Text(viewModel.state.error ?? "")
            }
            .overlay {
                if viewModel.state.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.theme.background.opacity(0.5))
                }
            }
            .navigationDestination(isPresented: $isShowingUsernameSelection) {
                UsernameSelectionView(viewModel: viewModel)
            }
            .onChange(of: viewModel.state.isAuthenticated) { isAuthenticated in
                if isAuthenticated {
                    isShowingUsernameSelection = true
                }
            }
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
            Button(action: { viewModel.handle(.resetPassword(email: email)) }) {
                Text("Forgot Password?")
                    .font(.subheadline)
                    .foregroundColor(.theme.accent)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            
            // Sign In Button
            Button(action: {
                viewModel.handle(.signInWithEmail(email: email, password: password))
            }) {
                Text("Sign In")
            }
            .buttonStyle(.primary)
        }
        .padding(.horizontal)
    }
}

// MARK: - Sign Up Form
struct SignUpForm: View {
    @ObservedObject var viewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    
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
                    .onChange(of: email) { newValue in
                        viewModel.state.formState.emailError = viewModel.validateEmail(newValue)
                    }
                
                if let error = viewModel.state.formState.emailError {
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
                    .onChange(of: password) { newValue in
                        viewModel.state.formState.passwordError = viewModel.validatePassword(newValue)
                    }
                
                if let error = viewModel.state.formState.passwordError {
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
                    .onChange(of: confirmPassword) { newValue in
                        viewModel.state.formState.confirmPasswordError = viewModel.validateConfirmPassword(password, newValue)
                    }
                
                if let error = viewModel.state.formState.confirmPasswordError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.theme.error)
                }
            }
            
            // Sign Up Button
            Button(action: {
                viewModel.handle(.signUpWithEmail(email: email, password: password))
            }) {
                Text("Sign Up")
            }
            .buttonStyle(.primary)
            .disabled(!viewModel.state.formState.isValid)
        }
        .padding(.horizontal)
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
            Button(action: {
                viewModel.handle(.setUsername(username: username))
                dismiss()
            }) {
                Text("Continue")
            }
            .buttonStyle(.primary)
            .padding(.horizontal)
            
            Spacer()
        }
        .background(Color.theme.background.ignoresSafeArea())
        .navigationBarHidden(true)
    }
}

// MARK: - Preview
struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
    }
} 