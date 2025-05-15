import SwiftUI

struct MainAppView: View {
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var subscriptionService: SubscriptionService
    @EnvironmentObject var notificationService: NotificationService
    @StateObject private var progressViewModel = ProgressDashboardViewModel()
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack {
            // Main TabView 
            TabView(selection: $selectedTab) {
                // Each tab now contains a NavigationStack/View within the content
                ChallengesTabView()
                    .tabItem {
                        Label("Challenges", systemImage: "checkmark.circle")
                    }
                    .tag(0)
                
                ProgressTabView()
                    .environmentObject(progressViewModel)
                    .tabItem {
                        Label("Progress", systemImage: "chart.bar")
                    }
                    .tag(1)
                
                MainApp_SocialTabView()
                    .tabItem {
                        Label("Social", systemImage: "person.2")
                    }
                    .tag(2)
                
                ProfileTabView()
                    .tabItem {
                        Label("Profile", systemImage: "person.fill")
                    }
                    .tag(3)
            }
            .accentColor(.theme.accent)
            .onAppear {
                setupTabBarAppearance()
            }
        }
        .environmentObject(userSession)
        .environmentObject(subscriptionService)
        .environmentObject(notificationService)
        .environmentObject(progressViewModel)
    }
    
    private func setupTabBarAppearance() {
        // Configure tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithDefaultBackground()
        
        // Fix tab bar appearance for iOS 15 and later
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        }
        
        // Apply to standard appearance
        UITabBar.appearance().standardAppearance = tabBarAppearance
        
        // Set tint color for tab bar items
        UITabBar.appearance().tintColor = UIColor(Color.theme.accent)
        
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

// These wrapper views ensure each tab has its own navigation context
struct ChallengesTabView: View {
    var body: some View {
        NavigationView {
            ChallengesView()
                .navigationTitle("Challenges")
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct ProgressTabView: View {
    @EnvironmentObject var progressViewModel: ProgressDashboardViewModel
    
    var body: some View {
        NavigationView {
            ProgressView()
                .environmentObject(progressViewModel)
                .navigationTitle("Progress")
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct MainApp_SocialTabView: View {
    var body: some View {
        NavigationView {
            SocialView()
                .navigationTitle("Social")
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct ProfileTabView: View {
    var body: some View {
        NavigationView {
            ProfileView()
                .navigationTitle("Profile")
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct MainAppView_Previews: PreviewProvider {
    static var previews: some View {
        MainAppView()
            .environmentObject(SubscriptionService.shared)
            .environmentObject(UserSession.shared)
    }
}



