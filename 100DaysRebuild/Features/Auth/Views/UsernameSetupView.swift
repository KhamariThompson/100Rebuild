import SwiftUI

struct UsernameSetupView: View {
    @StateObject private var viewModel = UsernameSetupViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Username Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Choose a Username")
                        .font(.headline)
                        .foregroundColor(.theme.text)
                    
                    TextField("Username", text: $viewModel.username)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                // Submit Button
                Button(action: {
                    Task {
                        await viewModel.submitUsername()
                    }
                }) {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Continue")
                            .font(.headline)
                    }
                }
                .buttonStyle(.primary)
                .disabled(!viewModel.isValid || viewModel.isLoading)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Welcome!")
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }
}

// Preview provider
struct UsernameSetupView_Previews: PreviewProvider {
    static var previews: some View {
        UsernameSetupView()
    }
} 