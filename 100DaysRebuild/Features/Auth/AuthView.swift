import SwiftUI
import UIKit
import FirebaseAuth
import GoogleSignIn
import AuthenticationServices

// No need to import AuthAlert from Models since we're not using it directly in this file anymore

struct AuthView: View {
    @StateObject private var viewModel = AuthViewModel.shared
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) private var colorScheme
    @State private var isShowingSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var showingPasswordResetAlert = false
    @State private var passwordResetSent = false
    @State private var keyboardHeight: CGFloat = 0
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.theme.background.ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 12) {
                        // Logo and header
                        Spacer(minLength: 50)
                        
                        Text("100Days")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.theme.text)
                            .padding(.bottom, 10)
                            .accessibilityAddTraits(.isHeader)
                        
                        Text("Track your 100-day challenges")
                            .font(.subheadline)
                            .foregroundColor(.theme.subtext)
                            .padding(.bottom, 40)
                        
                        // Auth mode selector
                        AuthModeSelector(viewModel: viewModel)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 30)
                        
                        // Email & Password Fields
                        if viewModel.authMode == .emailSignIn || viewModel.authMode == .emailSignUp {
                            VStack(spacing: 16) {
                                EmailPasswordForm(
                                    email: $viewModel.email,
                                    password: $viewModel.password,
                                    confirmPassword: $viewModel.confirmPassword,
                                    isSignUp: viewModel.authMode == .emailSignUp
                                )
                                
                                // Sign In / Sign Up button
                                Button(action: {
                                    // Dismiss keyboard first then submit
                                    dismissKeyboard()
                                    
                                    if viewModel.authMode == .emailSignIn {
                                        Task {
                                            await viewModel.signInWithEmail()
                                        }
                                    } else {
                                        Task {
                                            await viewModel.signUpWithEmail()
                                        }
                                    }
                                }) {
                                    Text(viewModel.authMode == .emailSignIn ? "Sign In" : "Sign Up")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color.theme.accent)
                                        )
                                }
                                .disabled(!viewModel.isFormValid || viewModel.isLoading)
                                .opacity((!viewModel.isFormValid || viewModel.isLoading) ? 0.6 : 1.0)
                                .padding(.top, 10)
                                
                                if viewModel.authMode == .emailSignIn {
                                    Button("Forgot Password?") {
                                        viewModel.authMode = .forgotPassword
                                    }
                                    .font(.footnote)
                                    .foregroundColor(.theme.accent)
                                    .padding(.top, 8)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Forgot Password Form
                        if viewModel.authMode == .forgotPassword {
                            VStack(spacing: 16) {
                                Text("Reset Password")
                                    .font(.headline)
                                    .foregroundColor(.theme.text)
                                    .padding(.bottom, 8)
                                
                                Text("Enter your email and we'll send you a link to reset your password")
                                    .font(.subheadline)
                                    .foregroundColor(.theme.subtext)
                                    .multilineTextAlignment(.center)
                                    .padding(.bottom, 16)
                                
                                TextField("Email", text: $viewModel.email)
                                    .padding()
                                    .background(Color.theme.background)
                                    .cornerRadius(12)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    .onSubmit {
                                        dismissKeyboard()
                                        Task {
                                            await viewModel.resetPassword()
                                        }
                                    }
                                
                                Button(action: {
                                    dismissKeyboard()
                                    Task {
                                        await viewModel.resetPassword()
                                    }
                                }) {
                                    Text("Send Reset Link")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(viewModel.email.isEmpty ? Color.gray : Color.theme.accent)
                                        )
                                }
                                .disabled(viewModel.email.isEmpty || viewModel.isLoading)
                                .opacity((viewModel.email.isEmpty || viewModel.isLoading) ? 0.6 : 1.0)
                                
                                Button("Back to Sign In") {
                                    viewModel.authMode = .emailSignIn
                                }
                                .font(.footnote)
                                .foregroundColor(.theme.accent)
                                .padding(.top, 8)
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Or continue with
                        if viewModel.authMode != .forgotPassword {
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
                            .padding(.horizontal, 20)
                            .padding(.vertical, 20)
                            
                            // Social sign-in buttons
                            SocialSignInButtons(viewModel: viewModel)
                                .padding(.horizontal, 20)
                        }
                        
                        Spacer(minLength: 50)
                    }
                    .padding(.vertical, 20)
                    .frame(minHeight: UIScreen.main.bounds.height - 150)
                }
                .scrollDismissesKeyboard(.immediately)
                .dismissKeyboardOnTap()
                .withSafeKeyboardHandling()
                
                // Loading overlay
                if viewModel.isLoading {
                    LoadingOverlay()
                }
            }
            .navigationBarTitle("", displayMode: .inline)
            .navigationBarHidden(true)
            .alert(isPresented: $viewModel.showError) {
                Alert(
                    title: Text("Error"),
                    message: Text(viewModel.errorMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
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
                    .background(Color.theme.background)
                    .cornerRadius(12)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .onSubmit {
                        dismissKeyboard()
                    }
                    .frame(height: 50)
            }
            
            // Password Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                    .font(.subheadline.bold())
                    .foregroundColor(Color.theme.text)
                
                SecureField("Your password", text: $password)
                    .padding()
                    .background(Color.theme.background)
                    .cornerRadius(12)
                    .textContentType(.password)
                    .onSubmit {
                        // Dismiss keyboard and attempt sign in
                        dismissKeyboard()
                        signIn()
                    }
                    .frame(height: 50)
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
            
            // Sign In Button with explicit highlighting when tapped
            Button(action: {
                // Dismiss keyboard and attempt sign in
                dismissKeyboard()
                signIn()
            }) {
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
                    .background(Color.theme.background)
                    .cornerRadius(12)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .onSubmit {
                        dismissKeyboard()
                    }
                    .frame(height: 50)
            }
            
            // Password Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                    .font(.subheadline.bold())
                    .foregroundColor(Color.theme.text)
                
                SecureField("Choose a password", text: $password)
                    .padding()
                    .background(Color.theme.background)
                    .cornerRadius(12)
                    .textContentType(.newPassword)
                    .onSubmit {
                        // Dismiss keyboard and attempt sign up
                        dismissKeyboard()
                        signUp()
                    }
                    .frame(height: 50)
            }
            
            // Sign Up Button
            Button(action: {
                // Dismiss keyboard and attempt sign up
                dismissKeyboard()
                signUp()
            }) {
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
    
    private func signInWithGoogle() {
        // Guard against multiple simultaneous auth operations
        guard !viewModel.isLoading else { return }
        
        // Set loading state to prevent multiple auth attempts - this is redundant as it's handled in viewModel.signInWithGoogle()
        // but keeping it here for consistency with signInWithApple
        viewModel.isLoading = true
        
        Task {
            await viewModel.signInWithGoogle()
        }
    }
    
    private func signInWithApple() {
        // Guard against multiple simultaneous auth operations
        guard !viewModel.isLoading else { return }
        
        // Set loading state to prevent multiple auth attempts
        viewModel.isLoading = true
        
        // Give time for any current view transitions to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            Task {
                await viewModel.signInWithApple()
            }
        }
    }
    
    private func signIn() {
        // Ensure we have valid credentials before attempting sign in
        guard !email.isEmpty, !password.isEmpty else {
            viewModel.setError(NSError(domain: "AuthError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Email and password are required"]))
            return
        }
        
        // Dismiss keyboard
        dismissKeyboard()
        
        Task {
            await viewModel.signInWithEmail(email: email, password: password)
        }
    }
    
    private func signUp() {
        // Ensure we have valid credentials before attempting sign up
        guard !email.isEmpty, !password.isEmpty else {
            viewModel.setError(NSError(domain: "AuthError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Email and password are required"]))
            return
        }
        
        // Dismiss keyboard
        dismissKeyboard()
        
        Task {
            await viewModel.signUpWithEmail(email: email, password: password)
        }
    }
    
    private func forgotPassword() {
        // Dismiss keyboard
        dismissKeyboard()
        
        Task {
            await viewModel.resetPassword(email: email)
        }
    }
    
    private func sendPasswordReset() {
        // Dismiss keyboard
        dismissKeyboard()
        
        Task {
            await viewModel.resetPassword(email: email)
            await MainActor.run {
                passwordResetSent = true
            }
        }
    }
    
    private struct SocialSignInButtons: View {
        @ObservedObject var viewModel: AuthViewModel
        @Environment(\.colorScheme) private var colorScheme
        
        var body: some View {
            VStack(spacing: 12) {
                // Apple Sign In
                Button(action: {
                    Task {
                        await viewModel.signInWithApple()
                    }
                }) {
                    HStack {
                        Image(systemName: "apple.logo")
                            .font(.title3)
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                        
                        Text("Continue with Apple")
                            .font(.headline)
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.theme.background.opacity(0.6))
                    )
                }
                .disabled(viewModel.isLoading)
                
                // Google Sign In
                Button(action: {
                    Task {
                        await viewModel.signInWithGoogle()
                    }
                }) {
                    HStack {
                        Image("google_logo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                        
                        Text("Continue with Google")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                    )
                }
                .disabled(viewModel.isLoading)
            }
        }
    }
    
    private struct LoadingOverlay: View {
        var body: some View {
            ZStack {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    
                    Text("Loading...")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .padding(30)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.7))
                )
            }
        }
    }
    
    // Helper method to safely dismiss keyboard from any thread
    private func dismissKeyboard() {
        if Thread.isMainThread {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        } else {
            DispatchQueue.main.async {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
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
    }
}

// MARK: - Email & Password Form
struct EmailPasswordForm: View {
    @Binding var email: String
    @Binding var password: String
    @Binding var confirmPassword: String
    let isSignUp: Bool
    
    // Add a helper method to safely dismiss keyboard from any thread
    private func dismissKeyboard() {
        if Thread.isMainThread {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        } else {
            DispatchQueue.main.async {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            TextField("Email", text: $email)
                .padding()
                .background(Color.theme.background)
                .cornerRadius(12)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .onSubmit {
                    dismissKeyboard()
                }
            
            SecureField("Password", text: $password)
                .padding()
                .background(Color.theme.background)
                .cornerRadius(12)
                .onSubmit {
                    dismissKeyboard()
                }
            
            if isSignUp {
                SecureField("Confirm Password", text: $confirmPassword)
                    .padding()
                    .background(Color.theme.background)
                    .cornerRadius(12)
                    .onSubmit {
                        dismissKeyboard()
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