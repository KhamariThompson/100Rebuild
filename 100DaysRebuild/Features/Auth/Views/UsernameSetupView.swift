import SwiftUI

struct UsernameSetupView: View {
    @StateObject private var viewModel = UsernameSetupViewModel()
    @EnvironmentObject var userSession: UserSession
    
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
                .padding()
            
            if let error = viewModel.error {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            Button(action: {
                Task {
                    await viewModel.saveUsername()
                }
            }) {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                } else {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.username.isEmpty || viewModel.isLoading)
            .padding()
        }
        .padding()
    }
}

struct UsernameSetupView_Previews: PreviewProvider {
    static var previews: some View {
        UsernameSetupView()
            .environmentObject(UserSession.shared)
    }
} 