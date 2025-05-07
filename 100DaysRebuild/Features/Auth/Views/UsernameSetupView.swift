import SwiftUI

struct UsernameSetupView: View {
    @StateObject private var viewModel = UsernameSetupViewModel()
    @EnvironmentObject var userSession: UserSession
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isUsernameFocused: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Choose Your Username")
                .font(.title)
                .bold()
            
            Text("This will be your display name in the app")
                .foregroundColor(.gray)
            
            TextField("Username", text: $viewModel.username)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .focused($isUsernameFocused)
                .submitLabel(.done)
                .padding()
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
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.top, -12)
            }
            
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
                        .padding(.vertical, 12)
                } else if viewModel.showSuccess {
                    HStack {
                        Text("Username Set!")
                        Image(systemName: "checkmark.circle.fill")
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .cornerRadius(10)
                } else {
                    Text("Continue")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            viewModel.isValid ? Color.theme.accent : Color.gray.opacity(0.5)
                        )
                        .cornerRadius(10)
                }
            }
            .disabled(viewModel.username.isEmpty || viewModel.isLoading || !viewModel.isValid)
            .padding()
        }
        .padding()
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
        UsernameSetupView()
            .environmentObject(UserSession.shared)
    }
} 