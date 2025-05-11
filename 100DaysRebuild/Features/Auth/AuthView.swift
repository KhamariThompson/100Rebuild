import SwiftUI
import UIKit
import FirebaseAuth
import GoogleSignIn
import AuthenticationServices
import Firebase

// No need to import AuthAlert from Models since we're not using it directly in this file anymore

// MARK: - Main Authentication View
struct AuthView: View {
    @StateObject private var viewModel = AuthViewModel.shared
    @EnvironmentObject var userSession: UserSession
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var focusedField: Field?
    
    enum Field: Hashable {
        case email, password, confirmPassword, username
    }
    
    // Simplified body with clean structure
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.theme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        // App logo and title
                        appHeader
                        
                        // Auth mode selector
                        AuthModeSelector(viewModel: viewModel)
                            .padding(.horizontal, 20)
                        
                        // Main authentication form
                        authForm
                        
                        // Social sign-in buttons
                        if viewModel.authMode != .forgotPassword {
                            socialSignInSection
                        }
                        
                        // Add extra space at bottom for keyboard
                        Spacer(minLength: 30)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 40)
                    .padding(.bottom, 30)
                }
                .scrollDismissesKeyboard(.interactively)
                .focusedDismissKeyboardOnTap()
                
                // Error notifications
                if viewModel.showError {
                    errorBanner
                }
                
                // Loading overlay
                if viewModel.isLoading {
                    loadingOverlay
                }
                
                // Network status
                if !viewModel.networkConnected {
                    networkStatusBanner
                }
            }
            .navigationBarTitle("", displayMode: .inline)
            .navigationBarHidden(true)
            .withSafeKeyboardHandling()
            .withSafeTextInput()
            .withSafeNavigation()
            .onAppear {
                // Reset focus state to ensure keyboard behavior is correct
                focusedField = nil
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // MARK: - Computed Properties
    
    private var isButtonEnabled: Bool {
        viewModel.validateForm() && !viewModel.isLoading && viewModel.networkConnected
    }
    
    // MARK: - Actions
    
    private func submitCredentials() {
        print("submitCredentials called - authMode: \(viewModel.authMode), email: \(viewModel.email), password length: \(viewModel.password.count)")
        
        // Clear keyboard
        focusedField = nil
        
        // Handle based on auth mode
        Task {
            switch viewModel.authMode {
            case .emailSignIn:
                print("Using AuthService for email sign in")
                await viewModel.signInWithEmail()
                
            case .emailSignUp:
                print("Using AuthService for email sign up")
                await viewModel.signUpWithEmail()
                
            case .forgotPassword:
                await viewModel.resetPassword(email: viewModel.email)
            }
        }
    }
    
    private func resetPassword() {
        print("resetPassword called for: \(viewModel.email)")
        submitCredentials() // Use the same submitCredentials function which handles all auth modes
    }
}

// MARK: - Auth Mode Selector
struct AuthModeSelector: View {
    @ObservedObject var viewModel: AuthViewModel
    
    var body: some View {
        HStack(spacing: 0) {
            // Sign In Button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.authMode = .emailSignIn
                    viewModel.confirmPassword = ""
                }
            }) {
                Text("Sign In")
                    .font(.headline)
                    .foregroundColor(viewModel.authMode == .emailSignIn ? .white : .theme.subtext)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(viewModel.authMode == .emailSignIn ? Color.theme.accent : Color.clear)
                    )
            }
            
            // Sign Up Button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.authMode = .emailSignUp
                }
            }) {
                Text("Sign Up")
                    .font(.headline)
                    .foregroundColor(viewModel.authMode == .emailSignUp ? .white : .theme.subtext)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(viewModel.authMode == .emailSignUp ? Color.theme.accent : Color.clear)
                    )
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.theme.background.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.theme.border.opacity(0.5), lineWidth: 1)
        )
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

// MARK: - Internal Component Extensions
private extension AuthView {
    // App header with logo and title
    var appHeader: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.theme.accent)
            
                Text("100Days")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.theme.text)
            
            Text("Track your 100-day challenges")
                .font(.subheadline)
                .foregroundColor(.theme.subtext)
        }
        .padding(.bottom, 20)
    }
    
    // Main authentication form
    var authForm: some View {
        VStack(spacing: 24) {
            // Email & Password fields based on auth mode
            switch viewModel.authMode {
            case .emailSignIn, .emailSignUp:
                emailPasswordForm
                
                // Sign In/Up button
                Button(action: submitCredentials) {
                    Text(viewModel.authMode == .emailSignIn ? "Sign In" : "Sign Up")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isButtonEnabled ? Color.theme.accent : Color.gray.opacity(0.5))
                        )
                }
                .disabled(!isButtonEnabled)
                
                // Forgot password link (sign in mode only)
                if viewModel.authMode == .emailSignIn {
                    Button("Forgot Password?") {
                        withAnimation {
                            viewModel.authMode = .forgotPassword
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.theme.accent)
                    .padding(.top, 4)
                }
                
            case .forgotPassword:
                forgotPasswordForm
            }
        }
    }
    
    // Email and password form fields
    var emailPasswordForm: some View {
        VStack(spacing: 16) {
            // Email field
            VStack(alignment: .leading, spacing: 8) {
                Text("Email")
                    .font(.subheadline.bold())
                    .foregroundColor(.theme.text)
                
                TextField("Your email address", text: $viewModel.email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding()
                    .background(Color.theme.surface)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.theme.border, lineWidth: 1)
                    )
                    .focused($focusedField, equals: Field.email)
                    .submitLabel(.next)
                    .onSubmit {
                        print("Email field submitted, moving to password")
                        focusedField = Field.password
                    }
                    .onChange(of: viewModel.email) { _, newValue in
                        if !newValue.isEmpty {
                            Task { @MainActor in
                                viewModel.updateValidationState()
                            }
                        }
                    }
                
                if let error = viewModel.emailError, !viewModel.email.isEmpty {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            // Password field
            VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                    .font(.subheadline.bold())
                    .foregroundColor(.theme.text)
                
                SecureField("Your password", text: $viewModel.password)
                    .textContentType(viewModel.authMode == .emailSignIn ? .password : .newPassword)
                    .autocorrectionDisabled()
                    .padding()
                    .background(Color.theme.surface)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.theme.border, lineWidth: 1)
                    )
                    .focused($focusedField, equals: Field.password)
                    .submitLabel(viewModel.authMode == .emailSignUp ? .next : .go)
                    .onSubmit {
                        if viewModel.authMode == .emailSignUp {
                            print("Password field submitted, moving to confirm password")
                            focusedField = Field.confirmPassword
                        } else {
                            print("Password field submitted, submitting credentials")
                            submitCredentials()
                        }
                    }
                    .onChange(of: viewModel.password) { _, newValue in
                        if !newValue.isEmpty {
                            Task { @MainActor in
                                viewModel.updateValidationState()
                            }
                        }
                    }
                
                if let error = viewModel.passwordError, !viewModel.password.isEmpty {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            // Confirm password field (sign up only)
            if viewModel.authMode == .emailSignUp {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Confirm Password")
                        .font(.subheadline.bold())
                        .foregroundColor(.theme.text)
                    
                    SecureField("Confirm your password", text: $viewModel.confirmPassword)
                        .textContentType(.newPassword)
                        .autocorrectionDisabled()
                        .padding()
                        .background(Color.theme.surface)
                        .cornerRadius(12)
                        .overlay(
                        RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.theme.border, lineWidth: 1)
                        )
                        .focused($focusedField, equals: Field.confirmPassword)
                        .submitLabel(.go)
                        .onSubmit {
                            submitCredentials()
                        }
                        .onChange(of: viewModel.confirmPassword) { _, newValue in
                            if !newValue.isEmpty {
                                Task { @MainActor in
                                    viewModel.updateValidationState()
                                }
                            }
                        }
                    
                    if let error = viewModel.confirmPasswordError, !viewModel.confirmPassword.isEmpty {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .onChange(of: focusedField) { _, newValue in
            print("Focus changed to: \(String(describing: newValue))")
        }
    }
    
    // Forgot password form
    var forgotPasswordForm: some View {
        VStack(spacing: 24) {
            Text("Reset Password")
                .font(.title3.bold())
                .foregroundColor(.theme.text)
            
            Text("Enter your email address and we'll send you a link to reset your password")
                .font(.subheadline)
                .foregroundColor(.theme.subtext)
                .multilineTextAlignment(.center)
                .padding(.bottom, 8)
            
            // Email field
            TextField("Your email address", text: $viewModel.email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                    .padding()
                .background(Color.theme.surface)
                    .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.theme.border, lineWidth: 1)
                )
                .focused($focusedField, equals: Field.email)
                .submitLabel(.go)
                    .onSubmit {
                    resetPassword()
                }
            
            // Reset button
            Button(action: resetPassword) {
                Text("Send Reset Link")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(!viewModel.email.isEmpty && viewModel.networkConnected ? 
                                Color.theme.accent : Color.gray.opacity(0.5))
                    )
            }
            .disabled(viewModel.email.isEmpty || !viewModel.networkConnected)
            
            // Back to sign in
            Button("Back to Sign In") {
                withAnimation {
                    viewModel.email = ""
                    viewModel.authMode = .emailSignIn
                }
            }
            .font(.subheadline)
            .foregroundColor(.theme.accent)
            .padding(.top, 8)
        }
        .padding(.horizontal, 20)
    }
    
    // Social sign in buttons section
    var socialSignInSection: some View {
        VStack(spacing: 20) {
            // "Or continue with" divider
            HStack {
                Rectangle()
                    .fill(Color.theme.subtext.opacity(0.3))
                    .frame(height: 1)
                
                Text("Or continue with")
                    .font(.footnote)
                    .foregroundColor(.theme.subtext)
                    .padding(.horizontal, 8)
                
                Rectangle()
                    .fill(Color.theme.subtext.opacity(0.3))
                    .frame(height: 1)
            }
            
            // Google sign-in
            Button {
                guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let rootViewController = windowScene.windows.first?.rootViewController else {
                    print("Failed to get root view controller")
                    return
                }
                
                viewModel.isLoading = true
                
                Task {
                    let success = await AuthService.shared.signInWithGoogle(viewController: rootViewController)
                    
                    await MainActor.run {
                        viewModel.isLoading = false
                        
                        if !success {
                            // AuthService already updated UserSession with error
                            if let errorMsg = userSession.errorMessage {
                                viewModel.errorMessage = errorMsg
                                viewModel.showError = true
                            } else {
                                viewModel.errorMessage = "Google sign-in failed. Please try again."
                                viewModel.showError = true
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Image("google_logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                    Text("Sign in with Google")
                        .font(.headline)
                        .foregroundColor(.theme.text)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.theme.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.theme.border, lineWidth: 1)
                )
            }
            .disabled(!viewModel.networkConnected)
            
            // Apple Sign In
            Button(action: {
                viewModel.isLoading = true
                
                Task {
                    await viewModel.signInWithApple()
                }
            }) {
                HStack {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 20))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                    
                    Text("Sign in with Apple")
                        .font(.headline)
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colorScheme == .dark ? Color.black : Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.theme.border, lineWidth: 1)
                )
            }
            .disabled(!viewModel.networkConnected)
        }
    }
    
    // Loading overlay component
    var loadingOverlay: some View {
            ZStack {
                // Semi-transparent background
                Color.black.opacity(0.5)
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 20) {
                    if viewModel.networkConnected {
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        
                        Text("Signing in...")
                            .font(.headline)
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                        
                        Text("Network unavailable")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("Waiting for connection...")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(30)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.black.opacity(0.7))
                )
                .shadow(radius: 10)
            }
        }
    
    // Error banner
    var errorBanner: some View {
        VStack {
            Spacer()
            
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.white)
                
                Text(viewModel.errorMessage)
                    .font(.subheadline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    viewModel.showError = false
                }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.white)
                }
            }
                        .padding()
            .background(Color.red.opacity(0.9))
            .cornerRadius(10)
            .padding(.horizontal)
            .padding(.bottom, 20)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .zIndex(100)
        .animation(.easeInOut, value: viewModel.showError)
    }
    
    // Network status banner
    var networkStatusBanner: some View {
            VStack {
                HStack {
                    Image(systemName: "wifi.slash")
                        .foregroundColor(.white)
                    
                    Text("No Internet Connection")
                        .font(.caption)
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.8))
                .cornerRadius(8)
            .padding(.horizontal, 20)
            .padding(.top, 5)
            
            Spacer()
        }
    }
} 