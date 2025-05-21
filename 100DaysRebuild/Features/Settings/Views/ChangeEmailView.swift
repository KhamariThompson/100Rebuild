import SwiftUI
import FirebaseAuth

struct ChangeEmailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var userSession: UserSession
    
    @State private var newEmail = ""
    @State private var password = ""
    @State private var isUpdating = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showSuccessMessage = false
    @State private var currentEmail: String = ""
    
    // Email validation state
    @State private var isValidEmail = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.theme.background.ignoresSafeArea()
                
                Form {
                    Section {
                        if !currentEmail.isEmpty {
                            HStack {
                                Text("Current:")
                                    .foregroundColor(Color.theme.subtext)
                                Text(currentEmail)
                                    .foregroundColor(Color.theme.text)
                                    .fontWeight(.medium)
                            }
                            .padding(.vertical, 8)
                        }
                        
                        TextField("New Email Address", text: $newEmail)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .submitLabel(.next)
                            .onChange(of: newEmail) { _, newValue in
                                validateEmail()
                            }
                        
                        SecureField("Current Password", text: $password)
                            .textContentType(.password)
                            .submitLabel(.done)
                    } header: {
                        Text("Email Address")
                    } footer: {
                        if !newEmail.isEmpty && !isValidEmail {
                            Text("Please enter a valid email address.")
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                    
                    Section {
                        Button(action: updateEmail) {
                            HStack {
                                Spacer()
                                
                                if isUpdating {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                } else {
                                    Text("Update Email")
                                        .fontWeight(.semibold)
                                        .foregroundColor(isFormValid ? Color.theme.accent : Color.gray)
                                }
                                
                                Spacer()
                            }
                        }
                        .disabled(!isFormValid || isUpdating)
                    } footer: {
                        Text("A verification link will be sent to the new email address. You'll need to verify it before the change takes effect.")
                            .font(.caption)
                            .foregroundColor(Color.theme.subtext)
                    }
                }
                .scrollDismissesKeyboard(.immediately)
            }
            .navigationTitle("Change Email")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Cancel") { dismiss() })
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .alert("Verification Sent", isPresented: $showSuccessMessage) {
                Button("OK", role: .cancel) { dismiss() }
            } message: {
                Text("A verification email has been sent to \(newEmail). Please check your inbox and follow the link to complete the email change.")
            }
            .onAppear {
                if let email = userSession.currentUser?.email {
                    currentEmail = email
                }
            }
        }
    }
    
    // Check if form is valid for submission
    private var isFormValid: Bool {
        !newEmail.isEmpty && 
        isValidEmail && 
        !password.isEmpty &&
        newEmail != currentEmail
    }
    
    private func validateEmail() {
        // Basic email validation using regex
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        isValidEmail = emailPredicate.evaluate(with: newEmail)
    }
    
    private func updateEmail() {
        guard isFormValid else { return }
        isUpdating = true
        
        Task {
            do {
                guard let user = Auth.auth().currentUser else {
                    throw NSError(domain: "App", code: 1, userInfo: [NSLocalizedDescriptionKey: "No user is signed in"])
                }
                
                // Step 1: Re-authenticate with current credentials
                let credential = EmailAuthProvider.credential(withEmail: currentEmail, password: password)
                try await user.reauthenticate(with: credential)
                
                // Step 2: Send verification email for the new address
                try await user.sendEmailVerification(beforeUpdatingEmail: newEmail)
                
                await MainActor.run {
                    isUpdating = false
                    showSuccessMessage = true
                }
            } catch {
                await MainActor.run {
                    isUpdating = false
                    
                    // Provide a more user-friendly error message
                    if let authError = error as? AuthErrorCode {
                        switch authError.code {
                        case .wrongPassword:
                            errorMessage = "Current password is incorrect. Please try again."
                        case .requiresRecentLogin:
                            errorMessage = "For security reasons, please sign out and sign back in before changing your email."
                        case .emailAlreadyInUse:
                            errorMessage = "This email address is already in use by another account."
                        default:
                            errorMessage = authError.localizedDescription
                        }
                    } else {
                        errorMessage = error.localizedDescription
                    }
                    
                    showingError = true
                }
            }
        }
    }
}

struct ChangeEmailView_Previews: PreviewProvider {
    static var previews: some View {
        ChangeEmailView()
            .withAppDependencies()
    }
} 