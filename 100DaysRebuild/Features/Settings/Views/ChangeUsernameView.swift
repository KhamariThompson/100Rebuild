import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ChangeUsernameView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var userSession: UserSession
    
    @State private var username = ""
    @State private var isUpdating = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showSuccessMessage = false
    
    // Cooldown state
    @State private var canChangeUsername = true
    @State private var nextChangeDate: Date?
    @State private var isCheckingEligibility = true
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.theme.background.ignoresSafeArea()
                
                Form {
                    Section {
                        if isCheckingEligibility {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                Spacer()
                            }
                            .padding()
                        } else {
                            TextField("New Username", text: $username)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .submitLabel(.done)
                                .onChange(of: username) { _, newValue in
                                    // Enforce username constraints (letters, numbers, underscores, no spaces)
                                    let filtered = newValue.filter { $0.isLetter || $0.isNumber || $0 == "_" }
                                    if filtered != newValue {
                                        username = filtered
                                    }
                                }
                            
                            if !canChangeUsername, let nextDate = nextChangeDate {
                                HStack {
                                    Image(systemName: "clock.fill")
                                        .foregroundColor(Color.theme.subtext)
                                    
                                    Text("Username can be changed again on \(nextDate.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.footnote)
                                        .foregroundColor(Color.theme.subtext)
                                }
                                .padding(.vertical, 8)
                            }
                        }
                    } header: {
                        Text("Enter New Username")
                    } footer: {
                        Text("Username can contain letters, numbers, and underscores only.")
                            .font(.caption)
                            .foregroundColor(Color.theme.subtext)
                    }
                    
                    Section {
                        Button(action: updateUsername) {
                            HStack {
                                Spacer()
                                
                                if isUpdating {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                } else {
                                    Text("Update Username")
                                        .fontWeight(.semibold)
                                        .foregroundColor(canChangeUsername ? Color.theme.accent : Color.gray)
                                }
                                
                                Spacer()
                            }
                        }
                        .disabled(username.isEmpty || isUpdating || !canChangeUsername || isCheckingEligibility)
                    }
                }
                .scrollDismissesKeyboard(.immediately)
            }
            .navigationTitle("Change Username")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Cancel") { dismiss() })
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .alert("Success", isPresented: $showSuccessMessage) {
                Button("OK", role: .cancel) { dismiss() }
            } message: {
                Text("Your username has been updated successfully.")
            }
            .onAppear {
                Task {
                    await checkUsernameChangeEligibility()
                }
            }
        }
    }
    
    private func checkUsernameChangeEligibility() async {
        isCheckingEligibility = true
        
        guard let userId = userSession.currentUser?.uid else {
            await MainActor.run {
                isCheckingEligibility = false
                canChangeUsername = true // Allow by default if not signed in (should not happen)
            }
            return
        }
        
        do {
            let db = Firestore.firestore()
            let document = try await db.collection("users").document(userId).getDocument()
            
            // Check both possible field names for backward compatibility
            let lastChangeTimestamp = document.data()?["lastUsernameChangeAt"] as? Timestamp 
                ?? document.data()?["lastUsernameChange"] as? Timestamp
            
            if let lastChange = lastChangeTimestamp {
                // Validate the timestamp - protect against invalid dates
                if lastChange.seconds < 0 {
                    print("Warning: Invalid timestamp detected for username change")
                    await MainActor.run {
                        canChangeUsername = true // Allow by default for invalid timestamps
                    }
                } else {
                    let cooldownPeriod: TimeInterval = 48 * 60 * 60 // 48 hours
                    let now = Date()
                    let lastChangeDate = lastChange.dateValue()
                    let timeSinceLastChange = now.timeIntervalSince(lastChangeDate)
                    
                    await MainActor.run {
                        canChangeUsername = timeSinceLastChange >= cooldownPeriod
                        
                        if !canChangeUsername {
                            nextChangeDate = lastChangeDate.addingTimeInterval(cooldownPeriod)
                        }
                    }
                }
            } else {
                // No timestamp found, allow username change
                await MainActor.run {
                    canChangeUsername = true
                }
            }
            
            // Set initial username value from current username
            if let currentUsername = document.data()?["username"] as? String {
                await MainActor.run {
                    username = currentUsername
                }
            }
            
            await MainActor.run {
                isCheckingEligibility = false
            }
        } catch {
            print("Error checking username change eligibility: \(error)")
            await MainActor.run {
                isCheckingEligibility = false
                canChangeUsername = true  // Allow by default on error - better UX than blocking
                errorMessage = "Could not verify eligibility: \(error.localizedDescription). You can proceed, but changes may fail."
                showingError = true
            }
        }
    }
    
    private func updateUsername() {
        guard !username.isEmpty && canChangeUsername && !isCheckingEligibility else { return }
        
        // Additional validation
        if username.count < 3 {
            errorMessage = "Username must be at least 3 characters."
            showingError = true
            return
        }
        
        if username.count > 15 {
            errorMessage = "Username must be at most 15 characters."
            showingError = true
            return
        }
        
        isUpdating = true
        
        Task {
            do {
                // Skip the uniqueness check if the username hasn't changed
                if username == userSession.username {
                    await MainActor.run {
                        isUpdating = false
                        dismiss()
                    }
                    return
                }
                
                // Check if username is already taken
                if try await isUsernameTaken(username) {
                    throw NSError(domain: "App", code: 1, userInfo: [NSLocalizedDescriptionKey: "This username is already taken"])
                }
                
                // Use UserSession to update the username
                // This will update Firestore and update the UserSession state properly
                try await userSession.updateUsername(username)
                
                await MainActor.run {
                    isUpdating = false
                    showSuccessMessage = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                    isUpdating = false
                }
            }
        }
    }
    
    private func isUsernameTaken(_ username: String) async throws -> Bool {
        let snapshot = try await Firestore.firestore()
            .collection("users")
            .whereField("username", isEqualTo: username)
            .getDocuments()
        
        // If the only document found belongs to the current user, then the username isn't taken
        if snapshot.documents.count == 1, 
           let docId = snapshot.documents.first?.documentID,
           docId == userSession.currentUser?.uid {
            return false
        }
        
        return !snapshot.documents.isEmpty
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