import SwiftUI

struct MainAppView: View {
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var subscriptionService: SubscriptionService
    @EnvironmentObject var notificationService: NotificationService
    
    var body: some View {
        TabView {
            NavigationView {
                ChallengesView()
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .tabItem {
                Label("Challenges", systemImage: "checkmark.circle")
            }
            .environmentObject(userSession)
            .environmentObject(subscriptionService)
            .environmentObject(notificationService)
            
            NavigationView {
                ProgressView()
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .tabItem {
                Label("Progress", systemImage: "chart.bar")
            }
            .environmentObject(userSession)
            .environmentObject(subscriptionService)
            .environmentObject(notificationService)
            
            NavigationView {
                ReminderTabView()
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .tabItem {
                Label("Reminders", systemImage: "bell")
            }
            .environmentObject(userSession)
            .environmentObject(subscriptionService)
            .environmentObject(notificationService)
            
            NavigationView {
                ProfileView()
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .tabItem {
                Label("Profile", systemImage: "person.fill")
            }
            .environmentObject(userSession)
            .environmentObject(subscriptionService)
            .environmentObject(notificationService)
        }
        .tint(.theme.accent)
        .onAppear {
            // Fix for NavigationView layout constraint issues
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(Color.theme.background)
            
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



