import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var userSession: UserSession
    @State private var isShowingEditUsername = false
    @State private var isShowingSettings = false
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading) {
                            Text(userSession.username ?? "No username")
                                .font(.title2)
                                .bold()
                            
                            Text(userSession.currentUser?.email ?? "")
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section {
                    Button(action: { isShowingEditUsername = true }) {
                        Label("Edit Username", systemImage: "pencil")
                    }
                    
                    Button(action: { isShowingSettings = true }) {
                        Label("Settings", systemImage: "gear")
                    }
                }
                
                Section {
                    Button(role: .destructive, action: {
                        Task {
                            try? await userSession.signOut()
                        }
                    }) {
                        Label("Sign Out", systemImage: "arrow.right.square")
                    }
                }
            }
            .navigationTitle("Profile")
            .sheet(isPresented: $isShowingEditUsername) {
                UsernameSetupView()
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView()
            }
        }
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
            .environmentObject(UserSession.shared)
    }
} 