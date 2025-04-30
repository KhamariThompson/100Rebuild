import SwiftUI

@main
struct App100Days: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            Group {
                if appState.isAuthenticated {
                    MainTabView()
                } else {
                    AuthView()
                }
            }
            .environmentObject(appState)
        }
    }
}

class AppState: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: User?
    
    init() {
        // TODO: Check authentication state
    }
}

struct User {
    let id: String
    let email: String
    let displayName: String?
    let photoURL: URL?
}

struct MainTabView: View {
    var body: some View {
        TabView {
            ChallengesView()
                .tabItem {
                    Label("Challenges", systemImage: "checkmark.circle")
                }
            
            ProgressView()
                .tabItem {
                    Label("Progress", systemImage: "chart.bar")
                }
            
            RemindersView()
                .tabItem {
                    Label("Reminders", systemImage: "bell")
                }
            
            SocialView()
                .tabItem {
                    Label("Social", systemImage: "person.2")
                }
        }
        .tint(.theme.accent)
    }
} 