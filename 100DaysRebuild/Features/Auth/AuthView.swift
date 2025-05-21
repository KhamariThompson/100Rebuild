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
    @State private var showTerms = false
    @State private var showPrivacy = false
    
    enum Field: Hashable {
        case email, password, confirmPassword, username
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.theme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: CalAIDesignTokens.screenPadding) {
                        // App logo and title
                        appHeader
                        
                        // Auth mode selector
                        if viewModel.authMode != .forgotPassword {
                            AuthModeSelector(viewModel: viewModel)
                                .padding(.top, 10)
                        }
                        
                        // Main authentication form
                        authForm
                        
                        // Social sign-in buttons
                        if viewModel.authMode != .forgotPassword {
                            socialSignInSection
                        }
                        
                        // Terms and privacy links
                        termsAndPrivacyLinks
                        
                        // Add extra space at bottom for keyboard
                        Spacer(minLength: 30)
                    }
                    .padding(.horizontal, CalAIDesignTokens.screenPadding)
                    .padding(.top, 60)
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
            .fullScreenCover(isPresented: $showTerms) {
                TermsAndPrivacyView(mode: .terms)
            }
            .fullScreenCover(isPresented: $showPrivacy) {
                TermsAndPrivacyView(mode: .privacy)
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
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(viewModel.authMode == .emailSignIn ? .white : .theme.subtext)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: CalAIDesignTokens.buttonRadius)
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
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(viewModel.authMode == .emailSignUp ? .white : .theme.subtext)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: CalAIDesignTokens.buttonRadius)
                            .fill(viewModel.authMode == .emailSignUp ? Color.theme.accent : Color.clear)
                    )
            }
        }
        .background(
            RoundedRectangle(cornerRadius: CalAIDesignTokens.buttonRadius)
                .fill(Color.theme.surface)
                .shadow(color: Color.theme.shadow.opacity(0.04), radius: 3, x: 0, y: 1)
        )
    }
}

// MARK: - Launch Screen View
struct LaunchScreenView: View {
    @State private var opacity = 0.0
    @State private var scale = 0.8
    @State private var showAuth = false
    
    var body: some View {
        ZStack {
            Color.theme.background.ignoresSafeArea()
            
            if !showAuth {
                VStack(spacing: 20) {
                    // Large app icon with animation
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 90))
                        .foregroundColor(.theme.accent)
                    
                    // App name with large bold font
                    Text("100Days")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundColor(.theme.text)
                }
                .scaleEffect(scale)
                .opacity(opacity)
                .onAppear {
                    // Simple animation sequence
                    withAnimation(.easeOut(duration: 0.8)) {
                        opacity = 1.0
                        scale = 1.0
                    }
                    
                    // Transition to auth screen after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                        withAnimation(.easeIn(duration: 0.4)) {
                            opacity = 0.0
                            scale = 1.1
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            showAuth = true
                        }
                    }
                }
            } else {
                AuthView()
                    .transition(.opacity)
            }
        }
    }
}

// MARK: - Launch Screen Preview
struct LaunchScreenView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            LaunchScreenView()
                .preferredColorScheme(.light)
                .previewDisplayName("Light Mode")
                
            LaunchScreenView()
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
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

// MARK: - Internal Component Extensions
private extension AuthView {
    // App header with logo and title
    var appHeader: some View {
        VStack(spacing: 18) {
            // Logo mark with subtle shadow
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 70))
                .foregroundColor(.theme.accent)
                .shadow(color: Color.theme.accent.opacity(0.2), radius: 10, x: 0, y: 4)
                .padding(.bottom, 5)
            
            // App title
            Text("100Days")
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundColor(.theme.text)
            
            // Tagline
            Text("Build consistency, transform your life")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.theme.subtext)
                .padding(.top, -5)
        }
        .padding(.bottom, 30)
        .padding(.top, 20)
        .opacity(0.95)
    }
    
    // Main authentication form
    var authForm: some View {
        VStack(spacing: 28) {
            // Email & Password fields based on auth mode
            switch viewModel.authMode {
            case .emailSignIn, .emailSignUp:
                emailPasswordForm
                
                // Sign In/Up button
                Button(action: submitCredentials) {
                    HStack(spacing: 12) {
                        Text(viewModel.authMode == .emailSignIn ? "Sign In" : "Sign Up")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                        
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: CalAIDesignTokens.buttonHeight)
                    .background(
                        RoundedRectangle(cornerRadius: CalAIDesignTokens.buttonRadius)
                            .fill(isButtonEnabled ? Color.theme.accent : Color.gray.opacity(0.3))
                            .shadow(color: isButtonEnabled ? Color.theme.accent.opacity(0.15) : Color.clear, radius: 4, x: 0, y: 1)
                    )
                }
                .disabled(!isButtonEnabled)
                .padding(.top, 4)
                
                // Forgot password link (sign in mode only)
                if viewModel.authMode == .emailSignIn {
                    Button("Forgot Password?") {
                        withAnimation {
                            viewModel.authMode = .forgotPassword
                        }
                    }
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.theme.accent)
                    .padding(.top, 8)
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
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.theme.text)
                
                TextField("Your email address", text: $viewModel.email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding()
                    .frame(height: CalAIDesignTokens.buttonHeight)
                    .background(Color.theme.surface)
                    .cornerRadius(CalAIDesignTokens.buttonRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: CalAIDesignTokens.buttonRadius)
                            .stroke(Color.theme.border.opacity(0.3), lineWidth: 1)
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
                        .font(.system(size: 13))
                        .foregroundColor(.red)
                }
            }
            
            // Password field
            VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.theme.text)
                
                SecureField("Your password", text: $viewModel.password)
                    .textContentType(viewModel.authMode == .emailSignIn ? .password : .newPassword)
                    .autocorrectionDisabled()
                    .padding()
                    .frame(height: CalAIDesignTokens.buttonHeight)
                    .background(Color.theme.surface)
                    .cornerRadius(CalAIDesignTokens.buttonRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: CalAIDesignTokens.buttonRadius)
                            .stroke(Color.theme.border.opacity(0.3), lineWidth: 1)
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
                        .font(.system(size: 13))
                        .foregroundColor(.red)
                }
            }
            
            // Confirm password field (sign up only)
            if viewModel.authMode == .emailSignUp {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Confirm Password")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.theme.text)
                    
                    SecureField("Confirm your password", text: $viewModel.confirmPassword)
                        .textContentType(.newPassword)
                        .autocorrectionDisabled()
                        .padding()
                        .frame(height: CalAIDesignTokens.buttonHeight)
                        .background(Color.theme.surface)
                        .cornerRadius(CalAIDesignTokens.buttonRadius)
                        .overlay(
                        RoundedRectangle(cornerRadius: CalAIDesignTokens.buttonRadius)
                                .stroke(Color.theme.border.opacity(0.3), lineWidth: 1)
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
                            .font(.system(size: 13))
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
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundColor(.theme.text)
            
            Text("Enter your email address and we'll send you a link to reset your password")
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundColor(.theme.subtext)
                .multilineTextAlignment(.center)
                .padding(.bottom, 8)
            
            // Email field
            VStack(alignment: .leading, spacing: 8) {
                Text("Email")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.theme.text)
                
                TextField("Your email address", text: $viewModel.email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding()
                    .frame(height: CalAIDesignTokens.buttonHeight)
                    .background(Color.theme.surface)
                    .cornerRadius(CalAIDesignTokens.buttonRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: CalAIDesignTokens.buttonRadius)
                            .stroke(Color.theme.border.opacity(0.3), lineWidth: 1)
                    )
                    .focused($focusedField, equals: Field.email)
                    .submitLabel(.go)
                    .onSubmit {
                        resetPassword()
                    }
            }
            
            // Reset button
            Button(action: resetPassword) {
                Text("Send Reset Link")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: CalAIDesignTokens.buttonHeight)
                    .background(
                        RoundedRectangle(cornerRadius: CalAIDesignTokens.buttonRadius)
                            .fill(!viewModel.email.isEmpty && viewModel.networkConnected ? 
                                Color.theme.accent : Color.gray.opacity(0.3))
                            .shadow(color: !viewModel.email.isEmpty && viewModel.networkConnected ? 
                                Color.theme.accent.opacity(0.15) : Color.clear, radius: 4, x: 0, y: 1)
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
            .font(.system(size: 15, weight: .medium, design: .rounded))
            .foregroundColor(.theme.accent)
            .padding(.top, 8)
        }
        .padding(.horizontal, 20)
    }
    
    // Social sign in buttons section
    var socialSignInSection: some View {
        VStack(spacing: 24) {
            // "Or continue with" divider
            HStack {
                Rectangle()
                    .fill(Color.theme.border.opacity(0.5))
                    .frame(height: 1)
                
                Text("Or continue with")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.theme.subtext)
                    .padding(.horizontal, 12)
                
                Rectangle()
                    .fill(Color.theme.border.opacity(0.5))
                    .frame(height: 1)
            }
            .padding(.top, 8)
            
            // Social auth buttons
            VStack(spacing: 14) {
                // Apple Sign In
                SignInWithAppleButton(text: .continueWith, onRequest: configureAppleRequest, onCompletion: handleAppleSignIn)
                    .frame(maxWidth: .infinity, minHeight: CalAIDesignTokens.buttonHeight)
                    .cornerRadius(CalAIDesignTokens.buttonRadius) // Force correct corner radius
                    .shadow(color: Color.theme.shadow.opacity(0.08), radius: 4, x: 0, y: 2)
                    .id("appleSignInButton")
                    .accessibility(identifier: "appleSignInButton")
                    .onAppear {
                        // Fix Apple button constraints on appear
                        DispatchQueue.main.async {
                            AppFixes.shared.applyAllFixes()
                        }
                    }
                
                // Google sign-in
                Button {
                    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                          let _ = windowScene.windows.first?.rootViewController else {
                        print("Failed to get root view controller")
                        return
                    }
                    
                    viewModel.isLoading = true
                    
                    Task {
                        await viewModel.signInWithGoogle()
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image("google_logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                        
                        Text("Continue with Google")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.theme.text)
                        
                        Spacer()
                    }
                    .padding(.leading, 16)
                    .frame(maxWidth: .infinity)
                    .frame(height: CalAIDesignTokens.buttonHeight)
                    .background(
                        RoundedRectangle(cornerRadius: CalAIDesignTokens.buttonRadius)
                            .fill(Color.theme.surface)
                            .shadow(color: Color.theme.shadow.opacity(0.08), radius: 4, x: 0, y: 2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: CalAIDesignTokens.buttonRadius)
                            .stroke(Color.theme.border.opacity(0.5), lineWidth: 1)
                    )
                }
                .buttonStyle(AppScaleButtonStyle(scale: 0.98))
                .disabled(!viewModel.networkConnected)
            }
        }
    }
    
    // Apple Sign In configuration methods
    private func configureAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
        // Create and store a new nonce for this sign-in session
        let nonce = viewModel.randomNonceString()
        viewModel.appleNonce = nonce
        request.nonce = viewModel.sha256(nonce)
    }
    
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                guard viewModel.appleNonce != nil else {
                    viewModel.setError(NSError(domain: "AppleSignIn", code: 1002, 
                                            userInfo: [NSLocalizedDescriptionKey: "Invalid state: Missing nonce"]))
                    return
                }
                
                // Set the credentials on the view model
                viewModel.appleIDCredential = appleIDCredential
                
                // Call sign in method
                Task {
                    await viewModel.signInWithApple()
                }
            }
        case .failure(let error):
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                viewModel.setError(error)
            }
        }
    }
    
    // Loading overlay component
    var loadingOverlay: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                if viewModel.networkConnected {
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    
                    Text("Signing in...")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                    
                    Text("Network unavailable")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Waiting for connection...")
                        .font(.system(size: 14, weight: .regular, design: .rounded))
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
                    .font(.system(size: 14, weight: .medium, design: .rounded))
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
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.red.opacity(0.85))
            )
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
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.red.opacity(0.8))
            )
            .padding(.horizontal, 20)
            .padding(.top, 8)
            
            Spacer()
        }
    }
    
    // Terms and privacy links at the bottom
    var termsAndPrivacyLinks: some View {
        VStack(spacing: 8) {
            Text("By continuing, you agree to our")
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundColor(.theme.subtext)
            
            HStack(spacing: 4) {
                Button("Terms of Service") {
                    showTerms = true
                }
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.theme.accent)
                
                Text("and")
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(.theme.subtext)
                
                Button("Privacy Policy") {
                    showPrivacy = true
                }
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.theme.accent)
            }
        }
        .padding(.top, 20)
    }
}

// Helper to create a better Apple Sign In button that avoids constraint issues
struct SignInWithAppleButton: UIViewRepresentable {
    enum ButtonText {
        case signIn
        case signUp
        case continueWith
        
        var localizedText: String {
            switch self {
            case .signIn: return "Sign in with Apple"
            case .signUp: return "Sign up with Apple"
            case .continueWith: return "Continue with Apple"
            }
        }
    }
    
    let text: ButtonText
    let onRequest: (ASAuthorizationAppleIDRequest) -> Void
    let onCompletion: (Result<ASAuthorization, Error>) -> Void
    
    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let style: ASAuthorizationAppleIDButton.Style = colorScheme == .dark ? .white : .black
        let type: ASAuthorizationAppleIDButton.ButtonType
        
        switch text {
        case .signIn:
            type = .signIn
        case .signUp:
            type = .signUp
        case .continueWith:
            type = .continue
        }
        
        let button = ASAuthorizationAppleIDButton(authorizationButtonType: type, authorizationButtonStyle: style)
        
        // Remove fixed width constraints that cause conflicts
        button.translatesAutoresizingMaskIntoConstraints = false
        
        // Set up the content hugging and compression resistance
        button.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        button.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        
        return button
    }
    
    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {
        // Configuration happens in makeUIView, nothing to update
        // Ensure any current fixed width constraints are removed
        for constraint in uiView.constraints {
            if constraint.firstAttribute == .width && constraint.constant == 380 {
                uiView.removeConstraint(constraint)
            }
        }
    }
    
    @Environment(\.colorScheme) private var colorScheme
} 