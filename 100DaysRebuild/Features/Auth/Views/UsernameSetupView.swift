import SwiftUI

struct UsernameSetupView: View {
    @StateObject private var viewModel = UsernameSetupViewModel()
    @EnvironmentObject var userSession: UserSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isUsernameFocused: Bool
    
    var body: some View {
        ZStack {
            // Clean minimal background
            Color.theme.background.ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Header section with icon
                VStack(spacing: 16) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 70))
                        .foregroundColor(.theme.accent)
                        .padding(.bottom, 5)
                    
                    Text("Choose Your Username")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(Color.theme.text)
                    
                    Text("This will be your display name in the app")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(Color.theme.subtext)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                // Username input with clean styling
                VStack(alignment: .leading, spacing: 8) {
                    Text("Username")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.theme.text)
                    
                    TextField("Choose a unique username", text: $viewModel.username)
                        .font(.system(size: 16, design: .rounded))
                        .padding()
                        .frame(height: CalAIDesignTokens.buttonHeight)
                        .background(Color.theme.surface)
                        .cornerRadius(CalAIDesignTokens.buttonRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: CalAIDesignTokens.buttonRadius)
                                .stroke(Color.theme.border.opacity(0.3), lineWidth: 1)
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
                            .font(.system(size: 13))
                            .foregroundColor(Color.theme.error)
                            .padding(.top, 4)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                
                Spacer()
                
                // Continue button with consistent styling
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
                            .frame(height: CalAIDesignTokens.buttonHeight)
                    } else if viewModel.showSuccess {
                        HStack {
                            Text("Username Set!")
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                            Image(systemName: "checkmark.circle.fill")
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: CalAIDesignTokens.buttonHeight)
                        .background(
                            RoundedRectangle(cornerRadius: CalAIDesignTokens.buttonRadius)
                                .fill(Color.theme.success)
                                .shadow(
                                    color: Color.theme.success.opacity(0.15),
                                    radius: 4,
                                    x: 0,
                                    y: 1
                                )
                        )
                    } else {
                        Text("Continue")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: CalAIDesignTokens.buttonHeight)
                            .background(
                                RoundedRectangle(cornerRadius: CalAIDesignTokens.buttonRadius)
                                    .fill(
                                        viewModel.isValid
                                            ? Color.theme.accent
                                            : Color.gray.opacity(0.3)
                                    )
                                    .shadow(
                                        color: viewModel.isValid 
                                            ? Color.theme.accent.opacity(0.15) 
                                            : Color.clear,
                                        radius: 4,
                                        x: 0,
                                        y: 1
                                    )
                            )
                    }
                }
                .buttonStyle(AppScaleButtonStyle(scale: 0.98))
                .disabled(viewModel.username.isEmpty || viewModel.isLoading || !viewModel.isValid)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
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