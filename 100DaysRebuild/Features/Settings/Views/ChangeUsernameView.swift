import SwiftUI
import FirebaseFirestore

struct ChangeUsernameView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ChangeUsernameViewModel()
    @EnvironmentObject var userSession: UserSession
    
    // UI State
    @State private var showSuccessToast = false
    
    var body: some View {
        NavigationView {
            Form {
                usernameSection
                
                cooldownSection
                
                infoSection
            }
            .navigationTitle("Change Username")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await viewModel.saveUsername()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(!viewModel.canSaveUsername)
                }
            }
            .onAppear {
                Task {
                    await viewModel.loadUserData()
                }
            }
            .alert(isPresented: $viewModel.showError) {
                Alert(
                    title: Text("Error"),
                    message: Text(viewModel.errorMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            .overlay {
                if viewModel.isLoading {
                    LoadingView()
                }
                
                if showSuccessToast {
                    VStack {
                        Spacer()
                        SuccessToastView(message: "Username updated successfully")
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .padding(.bottom, 40)
                    }
                    .animation(.spring(), value: showSuccessToast)
                    .zIndex(100)
                }
            }
            .onChange(of: viewModel.usernameUpdated) { updated in
                if updated {
                    showSuccessToast = true
                    // Hide toast after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showSuccessToast = false
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var usernameSection: some View {
        Section {
            TextField("Username", text: $viewModel.newUsername)
                .disableAutocorrection(true)
                .autocapitalization(.none)
                .font(.system(.body, design: .monospaced))
                .onChange(of: viewModel.newUsername) { oldValue, newValue in
                    viewModel.validateUsername()
                }
                .disabled(viewModel.isInCooldownPeriod)
            
            if !viewModel.validationMessage.isEmpty {
                Text(viewModel.validationMessage)
                    .font(.caption)
                    .foregroundColor(viewModel.isValidUsername ? .green : .red)
                    .padding(.top, 4)
            }
        } header: {
            Text("Your Username")
        } footer: {
            if viewModel.isInCooldownPeriod {
                Text("Username can't be changed during the cooldown period.")
                    .font(.caption)
            }
        }
    }
    
    private var cooldownSection: some View {
        Group {
            if viewModel.isInCooldownPeriod {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Cooldown Period")
                            .font(.headline)
                            .foregroundColor(.theme.text)
                        
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(.theme.accent)
                                .font(.system(size: 18))
                            
                            Text("You can change your username again in")
                                .foregroundColor(.theme.text)
                            
                            Spacer()
                            
                            Text(viewModel.formattedTimeRemaining)
                                .bold()
                                .foregroundColor(.theme.accent)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
    
    private var infoSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.theme.accent)
                        .font(.system(size: 18))
                    
                    Text("You can only change your username once every 48 hours to maintain consistency across the platform.")
                        .font(.callout)
                        .foregroundColor(.theme.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                HStack(alignment: .top) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                        .font(.system(size: 18))
                    
                    Text("Usernames must be 3-20 characters and can only contain letters and numbers. No spaces or special characters are allowed.")
                        .font(.callout)
                        .foregroundColor(.theme.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 8)
        } header: {
            Text("Username Guidelines")
        }
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

#Preview {
    ChangeUsernameView()
        .environmentObject(UserSession.shared)
} 