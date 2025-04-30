import SwiftUI

struct AuthView: View {
    @StateObject private var viewModel = AuthViewModel()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Logo and Title
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.theme.accent)
                    
                    Text("100Days")
                        .font(.largeTitle)
                        .foregroundColor(.theme.text)
                }
                .padding(.top, 60)
                
                // Auth Buttons
                VStack(spacing: 16) {
                    Button(action: { viewModel.handle(.signIn) }) {
                        Text("Sign In")
                    }
                    .buttonStyle(.primary)
                    
                    Button(action: { viewModel.handle(.signUp) }) {
                        Text("Create Account")
                    }
                    .buttonStyle(.secondary)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .background(Color.theme.background.ignoresSafeArea())
        }
    }
}

// MARK: - Preview
struct AuthView_Previews: PreviewProvider {
    static var previews: some View {
        AuthView()
    }
} 