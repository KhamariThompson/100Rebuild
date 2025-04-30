import SwiftUI

struct MainAppView: View {
    var body: some View {
        TabView {
            ChallengesView()
                .tabItem {
                    Label("Challenges", systemImage: "checkmark.circle")
                }
            
            UserProgressView()
                .tabItem {
                    Label("Progress", systemImage: "chart.bar")
                }
            
            ReminderTabView()
                .tabItem {
                    Label("Reminders", systemImage: "bell")
                }
            
            SocialTabView()
                .tabItem {
                    Label("Social", systemImage: "person.2")
                }
        }
        .tint(.theme.accent)
    }
}

// Preview provider
struct MainAppView_Previews: PreviewProvider {
    static var previews: some View {
        MainAppView()
    }
}

struct UserProgressView: View {
    var body: some View {
        Text("Progress View")
            .navigationTitle("Progress")
    }
}

struct SocialTabView: View {
    var body: some View {
        Text("Social View")
            .navigationTitle("Social")
    }
}

struct ReminderTabView: View {
    var body: some View {
        Text("Reminders View")
            .navigationTitle("Reminders")
    }
} 