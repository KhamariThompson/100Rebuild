import SwiftUI
import FirebaseAuth

struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var userSession: UserSession
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isPerformingAction = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Current Password")) {
                    SecureField("Enter current password", text: $currentPassword)
                }
                
                Section(header: Text("New Password")) {
                    SecureField("Enter new password", text: $newPassword)
                    SecureField("Confirm new password", text: $confirmPassword)
                }
                
                Section {
                    Button(action: changePassword) {
                        if isPerformingAction {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Change Password")
                        }
                    }
                    .disabled(isPerformingAction || !isValid)
                }
            }
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private var isValid: Bool {
        !currentPassword.isEmpty && !newPassword.isEmpty && !confirmPassword.isEmpty && newPassword == confirmPassword
    }
    
    private func changePassword() {
        guard isValid else { return }
        
        isPerformingAction = true
        
        Task {
            do {
                try await updatePasswordWithUserSession()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
            
            isPerformingAction = false
        }
    }
    
    private func updatePasswordWithUserSession() async throws {
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "App", code: 1, userInfo: [NSLocalizedDescriptionKey: "No user is signed in"])
        }
        
        // Check if passwords match
        if newPassword != confirmPassword {
            throw NSError(domain: "App", code: 1, userInfo: [NSLocalizedDescriptionKey: "New passwords do not match"])
        }
        
        // Reauthenticate user
        let credential = EmailAuthProvider.credential(withEmail: user.email ?? "", password: currentPassword)
        try await user.reauthenticate(with: credential)
        
        // Update password
        try await user.updatePassword(to: newPassword)
    }
}

#Preview {
    ChangePasswordView()
        .withAppDependencies()
} 