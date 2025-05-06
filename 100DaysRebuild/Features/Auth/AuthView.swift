import SwiftUI
import UIKit

struct AuthView: View {
    @ObservedObject private var viewModel = AuthViewModel.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Button(action: signInWithGoogle) {
                        HStack {
                            Image(systemName: "g.circle.fill")
                            Text("Sign in with Google")
                        }
                    }
                    
                    Button(action: signInWithApple) {
                        HStack {
                            Image(systemName: "apple.logo")
                            Text("Sign in with Apple")
                        }
                    }
                }
                
                Section {
                    TextField("Email", text: $viewModel.email)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                    
                    SecureField("Password", text: $viewModel.password)
                        .textContentType(.password)
                    
                    Button(action: signIn) {
                        Text("Sign In")
                    }
                    .disabled(viewModel.email.isEmpty || viewModel.password.isEmpty)
                }
                
                Section {
                    Button(action: signUp) {
                        Text("Create Account")
                    }
                }
            }
            .navigationTitle("Welcome")
            .navigationBarItems(trailing: Button("Cancel") { dismiss() })
            .alert("Error", isPresented: Binding(
                get: { viewModel.error != nil },
                set: { if !$0 { viewModel.error = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                if let error = viewModel.error {
                    Text(error.localizedDescription)
                }
            }
        }
    }
    
    private func signInWithGoogle() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            return
        }
        
        Task {
            do {
                try await viewModel.signInWithGoogle(presenting: rootViewController)
            } catch {
                viewModel.error = error
            }
        }
    }
    
    private func signInWithApple() {
        Task {
            do {
                try await viewModel.signInWithApple()
            } catch {
                viewModel.error = error
            }
        }
    }
    
    private func signIn() {
        Task {
            do {
                try await viewModel.signIn(email: viewModel.email, password: viewModel.password)
            } catch {
                viewModel.error = error
            }
        }
    }
    
    private func signUp() {
        Task {
            do {
                try await viewModel.signUp(email: viewModel.email, password: viewModel.password)
            } catch {
                viewModel.error = error
            }
        }
    }
}

// MARK: - Preview
struct AuthView_Previews: PreviewProvider {
    static var previews: some View {
        AuthView()
    }
} 