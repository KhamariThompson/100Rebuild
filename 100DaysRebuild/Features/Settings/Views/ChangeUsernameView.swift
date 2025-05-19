import SwiftUI
import FirebaseFirestore

struct ChangeUsernameView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var userSession: UserSession
    
    @State private var newUsername = ""
    @State private var isAvailable = false
    @State private var isChecking = false
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var isSaving = false
    
    var body: some View {
        Form {
            Section {
                TextField("New Username", text: $newUsername)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .onChange(of: newUsername) { _, newValue in
                        checkUsernameAvailability()
                    }
                
                if isChecking {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if !newUsername.isEmpty {
                    if isAvailable {
                        HStack {
                            Spacer()
                            Label("Username available", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Spacer()
                        }
                    } else {
                        HStack {
                            Spacer()
                            Label(errorMessage.isEmpty ? "Username unavailable" : errorMessage, 
                                systemImage: "xmark.circle.fill")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                }
            }
            
            Section {
                Button(action: saveUsername) {
                    if isSaving {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else {
                        Text("Save")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(newUsername.isEmpty || !isAvailable ? .gray : .theme.accent)
                    }
                }
                .disabled(newUsername.isEmpty || !isAvailable || isSaving)
                
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.red)
            }
        }
        .navigationTitle("Change Username")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            if let username = userSession.username {
                newUsername = username
            }
        }
    }
    
    private func checkUsernameAvailability() {
        isChecking = true
        errorMessage = ""
        isAvailable = false
        
        // Implement the logic to check username availability
        // This is a placeholder and should be replaced with actual implementation
        
        isChecking = false
    }
    
    private func saveUsername() {
        isSaving = true
        errorMessage = ""
        
        // Implement the logic to save the new username
        // This is a placeholder and should be replaced with actual implementation
        
        isSaving = false
        dismiss()
    }
}

// MARK: - Supporting Views

struct LoadingView: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                
                Text("Updating username...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.theme.surface.opacity(0.9))
            )
        }
    }
}

struct SuccessToastView: View {
    let message: String
    
    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.white)
                .font(.headline)
            
            Text(message)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.theme.accent)
                .shadow(radius: 5)
        )
        .padding(.horizontal)
    }
}

struct ChangeUsernameView_Previews: PreviewProvider {
    static var previews: some View {
        ChangeUsernameView()
            .withAppDependencies()
    }
} 