import SwiftUI

struct UsernameSetupView: View {
    @StateObject private var viewModel = UsernameSetupViewModel()
    @EnvironmentObject var userSession: UserSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isUsernameFocused: Bool
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.theme.accent.opacity(0.1),
                    Color.theme.background
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Text("Choose Your Username")
                        .font(.title2.bold())
                        .foregroundColor(Color.theme.text)
                    
                    Text("This will be your display name in the app")
                        .font(.subheadline)
                        .foregroundColor(Color.theme.subtext)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 24)
                
                VStack(spacing: 8) {
                    TextField("Username", text: $viewModel.username)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(colorScheme == .dark 
                                    ? Color(.secondarySystemBackground) 
                                    : Color(.systemBackground))
                                .shadow(
                                    color: Color.primary.opacity(0.05),
                                    radius: 3,
                                    x: 0,
                                    y: 2
                                )
                        )
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .focused($isUsernameFocused)
                        .submitLabel(.done)
                        .onChange(of: viewModel.username) { oldValue, newValue in
                            if !newValue.isEmpty {
                                viewModel.validateUsername()
                            }
                        }
                        .onSubmit {
                            Task {
                                await viewModel.saveUsername()
                                if viewModel.showSuccess {
                                    dismiss()
                                }
                            }
                        }
                    
                    if let error = viewModel.error {
                        Text(error)
                            .foregroundColor(Color.theme.error)
                            .font(.caption)
                            .padding(.top, 4)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                Button(action: {
                    Task {
                        await viewModel.saveUsername()
                        if viewModel.showSuccess {
                            // Slight delay to show success animation
                            try? await Task.sleep(nanoseconds: 1_000_000_000)
                            dismiss()
                        }
                    }
                }) {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    } else if viewModel.showSuccess {
                        HStack {
                            Text("Username Set!")
                            Image(systemName: "checkmark.circle.fill")
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.theme.success)
                                .shadow(
                                    color: Color.theme.success.opacity(0.3),
                                    radius: 8,
                                    x: 0,
                                    y: 4
                                )
                        )
                    } else {
                        Text("Continue")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(
                                        viewModel.isValid
                                            ? LinearGradient(
                                                gradient: Gradient(colors: [
                                                    Color.theme.accent,
                                                    Color.theme.accent.opacity(0.8)
                                                ]),
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                            : LinearGradient(
                                                gradient: Gradient(colors: [
                                                    Color.gray.opacity(0.6),
                                                    Color.gray.opacity(0.4)
                                                ]),
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                    )
                                    .shadow(
                                        color: viewModel.isValid 
                                            ? Color.theme.accent.opacity(0.3) 
                                            : Color.clear,
                                        radius: 8,
                                        x: 0,
                                        y: 4
                                    )
                            )
                    }
                }
                .buttonStyle(AppScaleButtonStyle())
                .disabled(viewModel.username.isEmpty || viewModel.isLoading || !viewModel.isValid)
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
        .onAppear {
            // Auto-focus the username field when view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isUsernameFocused = true
            }
        }
    }
}

struct UsernameSetupView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            UsernameSetupView()
                .environmentObject(UserSession.shared)
                .preferredColorScheme(.light)
                .previewDisplayName("Light Mode")
            
            UsernameSetupView()
                .environmentObject(UserSession.shared)
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
        }
    }
} 