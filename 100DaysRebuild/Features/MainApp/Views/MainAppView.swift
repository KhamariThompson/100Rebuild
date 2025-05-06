import SwiftUI

struct MainAppView: View {
    @EnvironmentObject var subscriptionService: SubscriptionService
    
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

struct MainAppView_Previews: PreviewProvider {
    static var previews: some View {
        MainAppView()
            .environmentObject(SubscriptionService.shared)
    }
}



