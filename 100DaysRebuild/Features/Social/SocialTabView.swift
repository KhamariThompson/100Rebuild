import SwiftUI

struct SocialTabView: View {
    @EnvironmentObject var subscriptionService: SubscriptionService
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                Spacer()
                
                // Coming soon message with illustration
                VStack(spacing: 24) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.gray.opacity(0.5))
                    
                    Text("Social Features Coming Soon")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Connect with friends, share your progress, and join community challenges in our upcoming update.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                // Feature preview cards
                VStack(spacing: 16) {
                    ComingSoonFeatureCard(
                        icon: "person.2.fill",
                        title: "Friend Challenges",
                        description: "Challenge friends and track progress together"
                    )
                    
                    ComingSoonFeatureCard(
                        icon: "globe.fill",
                        title: "Community Challenges",
                        description: "Join global challenges with other users"
                    )
                    
                    ComingSoonFeatureCard(
                        icon: "bell.fill",
                        title: "Activity Feed",
                        description: "See updates from friends and followers"
                    )
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .background(Color.theme.background.ignoresSafeArea())
            .navigationTitle("Social")
        }
    }
}

struct ComingSoonFeatureCard: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.gray)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(Color.theme.surface)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.theme.surface)
        )
    }
} 