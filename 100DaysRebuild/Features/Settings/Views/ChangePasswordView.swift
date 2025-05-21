import SwiftUI
import FirebaseAuth

struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var userSession: UserSession
    
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isUpdating = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    
    // Password validation state
    @State private var hasMinimumLength = false
    @State private var hasLetterAndNumber = false
    @State private var passwordsMatch = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.theme.background.ignoresSafeArea()
                
                Form {
                    Section {
                        SecureField("Current Password", text: $currentPassword)
                            .textContentType(.password)
                            .autocapitalization(.none)
                            .submitLabel(.next)
                    } header: {
                        Text("Current Password")
                    }
                    
                    Section {
                        SecureField("New Password", text: $newPassword)
                            .textContentType(.newPassword)
                            .autocapitalization(.none)
                            .submitLabel(.next)
                            .onChange(of: newPassword) { _, newValue in
                                validatePassword()
                            }
                        
                        SecureField("Confirm New Password", text: $confirmPassword)
                            .textContentType(.newPassword)
                            .autocapitalization(.none)
                            .submitLabel(.done)
                            .onChange(of: confirmPassword) { _, newValue in
                                validatePassword()
                            }
                        
                        // Password strength indicators
                        PasswordRequirementRow(
                            text: "At least 8 characters",
                            isMet: hasMinimumLength
                        )
                        
                        PasswordRequirementRow(
                            text: "Contains letters and numbers",
                            isMet: hasLetterAndNumber
                        )
                        
                        PasswordRequirementRow(
                            text: "Passwords match",
                            isMet: passwordsMatch
                        )
                    } header: {
                        Text("New Password")
                    } footer: {
                        Text("Choose a strong password that is at least 8 characters long with letters and numbers.")
                            .font(.caption)
                            .foregroundColor(Color.theme.subtext)
                    }
                    
                    Section {
                        Button(action: updatePassword) {
                            HStack {
                                Spacer()
                                
                                if isUpdating {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                } else {
                                    Text("Update Password")
                                        .fontWeight(.semibold)
                                        .foregroundColor(isFormValid ? Color.theme.accent : Color.gray)
                                }
                                
                                Spacer()
                            }
                        }
                        .disabled(!isFormValid || isUpdating)
                    }
                }
                .scrollDismissesKeyboard(.immediately)
            }
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Cancel") { dismiss() })
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .alert("Success", isPresented: $showSuccess) {
                Button("OK", role: .cancel) { dismiss() }
            } message: {
                Text("Your password has been updated successfully.")
            }
        }
    }
    
    // Check if form is valid for submission
    private var isFormValid: Bool {
        !currentPassword.isEmpty && 
        hasMinimumLength && 
        hasLetterAndNumber && 
        passwordsMatch
    }
    
    private func validatePassword() {
        // Check if password meets minimum length requirement
        hasMinimumLength = newPassword.count >= 8
        
        // Check if password contains both letters and numbers
        let letters = CharacterSet.letters
        let digits = CharacterSet.decimalDigits
        let hasLetters = newPassword.unicodeScalars.contains { letters.contains($0) }
        let hasDigits = newPassword.unicodeScalars.contains { digits.contains($0) }
        hasLetterAndNumber = hasLetters && hasDigits
        
        // Check if passwords match
        passwordsMatch = !newPassword.isEmpty && newPassword == confirmPassword
    }
    
    private func updatePassword() {
        guard isFormValid else { return }
        isUpdating = true
        
        Task {
            do {
                guard let user = Auth.auth().currentUser, let email = user.email else {
                    throw NSError(domain: "App", code: 1, userInfo: [NSLocalizedDescriptionKey: "No user is signed in"])
                }
                
                // Step 1: Re-authenticate with current credentials
                let credential = EmailAuthProvider.credential(withEmail: email, password: currentPassword)
                try await user.reauthenticate(with: credential)
                
                // Step 2: Update password
                try await user.updatePassword(to: newPassword)
                
                await MainActor.run {
                    isUpdating = false
                    showSuccess = true
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
                            errorMessage = "For security reasons, please sign out and sign back in before changing your password."
                        case .weakPassword:
                            errorMessage = "The password is too weak. Please choose a stronger password."
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

// Reusable component for password requirement indicators
struct PasswordRequirementRow: View {
    let text: String
    let isMet: Bool
    
    var body: some View {
        HStack {
            Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isMet ? .green : Color.theme.subtext)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(isMet ? Color.theme.text : Color.theme.subtext)
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct ChangePasswordView_Previews: PreviewProvider {
    static var previews: some View {
        ChangePasswordView()
            .withAppDependencies()
    }
} 