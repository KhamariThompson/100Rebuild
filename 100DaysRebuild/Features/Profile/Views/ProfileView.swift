import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var userSession: UserSessionService
    @EnvironmentObject var subscriptionService: SubscriptionService
    @State private var showingEditUsername = false
    @State private var showingSettings = false
    @State private var isAnimating = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Profile Header
                VStack(spacing: 16) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.theme.accent)
                        .scaleEffect(isAnimating ? 1.0 : 0.8)
                        .opacity(isAnimating ? 1.0 : 0.0)
                    
                    VStack(spacing: 8) {
                        Text(userSession.username ?? "User")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.theme.text)
                        
                        Text(userSession.currentUser?.email ?? "")
                            .font(.subheadline)
                            .foregroundColor(.theme.subtext)
                        
                        if subscriptionService.isProUser {
                            HStack {
                                Image(systemName: "sparkles")
                                Text("Pro Member")
                            }
                            .font(.caption)
                            .foregroundColor(.theme.accent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.theme.accent.opacity(0.1))
                            )
                        }
                    }
                    .opacity(isAnimating ? 1.0 : 0.0)
                    .offset(y: isAnimating ? 0 : 20)
                }
                .padding(.top, 32)
                
                // Action Buttons
                VStack(spacing: 16) {
                    Button(action: { showingEditUsername = true }) {
                        HStack {
                            Image(systemName: "pencil")
                            Text("Edit Username")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                        }
                        .font(.headline)
                        .foregroundColor(.theme.text)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.theme.surface)
                                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                        )
                    }
                    
                    Button(action: { showingSettings = true }) {
                        HStack {
                            Image(systemName: "gear")
                            Text("Settings")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                        }
                        .font(.headline)
                        .foregroundColor(.theme.text)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.theme.surface)
                                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                        )
                    }
                }
                .padding(.horizontal)
                .opacity(isAnimating ? 1.0 : 0.0)
                .offset(y: isAnimating ? 0 : 20)
                
                Spacer()
            }
        }
        .background(Color.theme.background.ignoresSafeArea())
        .sheet(isPresented: $showingEditUsername) {
            EditUsernameView()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2)) {
                isAnimating = true
            }
        }
    }
}

struct EditUsernameView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var userSession: UserSessionService
    @State private var newUsername = ""
    @State private var isUpdating = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                TextField("New Username", text: $newUsername)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                
                Button(action: updateUsername) {
                    if isUpdating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Update Username")
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.theme.accent)
                )
                .padding(.horizontal)
                .disabled(newUsername.isEmpty || isUpdating)
            }
            .padding()
            .navigationTitle("Edit Username")
            .navigationBarItems(trailing: Button("Cancel") { dismiss() })
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func updateUsername() {
        isUpdating = true
        Task {
            do {
                try await userSession.updateUsername(newUsername)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
            isUpdating = false
        }
    }
} 