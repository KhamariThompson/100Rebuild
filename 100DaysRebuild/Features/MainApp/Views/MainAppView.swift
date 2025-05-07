import SwiftUI

struct MainAppView: View {
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var subscriptionService: SubscriptionService
    @EnvironmentObject var notificationService: NotificationService
    
    var body: some View {
        NavigationView {
            TabView {
                ChallengesView()
                    .tabItem {
                        Label("Challenges", systemImage: "checkmark.circle")
                    }
                
                ProgressView()
                    .tabItem {
                        Label("Progress", systemImage: "chart.bar")
                    }
                
                ReminderTabView()
                    .tabItem {
                        Label("Reminders", systemImage: "bell")
                    }
                
                ProfileView()
                    .tabItem {
                        Label("Profile", systemImage: "person.fill")
                    }
            }
            .tint(.theme.accent)
            .environmentObject(userSession)
            .environmentObject(subscriptionService)
            .environmentObject(notificationService)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            // Fix for NavigationView layout constraint issues
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(Color.theme.background)
            appearance.shadowColor = nil // Remove shadow line
            
            // Use this appearance for all navigation bars
            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
            UINavigationBar.appearance().compactAppearance = appearance
        }
    }
}

struct MainAppView_Previews: PreviewProvider {
    static var previews: some View {
        MainAppView()
            .environmentObject(SubscriptionService.shared)
            .environmentObject(UserSession.shared)
    }
}



