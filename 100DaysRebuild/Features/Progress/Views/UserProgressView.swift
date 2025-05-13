import SwiftUI

struct UserProgressView: View {
    @StateObject private var viewModel = UserProgressViewMock()
    @EnvironmentObject var subscriptionService: SubscriptionService
    
    var body: some View {
        NavigationView {
            UserProgressContent(viewModel: viewModel)
                .background(Color.theme.background.ignoresSafeArea())
                .navigationTitle("Progress")
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// A mock view model to avoid conflicts with the main progress view model
class UserProgressViewMock: ObservableObject {
    // Add any properties or methods needed for this view
}

// Separate content view to simplify structure
struct UserProgressContent: View {
    let viewModel: UserProgressViewMock
    @EnvironmentObject var subscriptionService: SubscriptionService
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                ProgressStatsView()
                ProgressChartView()
            }
            .padding(.vertical)
        }
    }
}

// Stats section with no dependencies on ViewModel
struct ProgressStatsView: View {
    // Use hard-coded data instead of depending on the viewModel
    private var currentStreak: Int = 7
    private var longestStreak: Int = 14
    private var totalChallenges: Int = 3
    private var completedChallenges: Int = 1
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Your Progress")
                .font(.title2)
                .foregroundColor(.theme.text)
            
            HStack(spacing: 20) {
                ProgressStatCard(title: "Current Streak", value: "\(currentStreak)")
                ProgressStatCard(title: "Longest Streak", value: "\(longestStreak)")
            }
            
            HStack(spacing: 20) {
                ProgressStatCard(title: "Challenges", value: "\(totalChallenges)")
                ProgressStatCard(title: "Completed", value: "\(completedChallenges)")
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.theme.surface)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal)
    }
}

// Chart section
struct ProgressChartView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Progress Chart")
                .font(.title3)
                .foregroundColor(.theme.text)
            
            // Add your progress chart here
            Rectangle()
                .fill(Color.theme.accent.opacity(0.2))
                .frame(height: 200)
                .cornerRadius(12)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.theme.surface)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal)
    }
}

struct ProgressStatCard: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.title)
                .foregroundColor(.theme.accent)
            Text(title)
                .font(.subheadline)
                .foregroundColor(.theme.subtext)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.theme.surface)
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
}

struct UserProgressView_Previews: PreviewProvider {
    static var previews: some View {
        UserProgressView()
            .environmentObject(SubscriptionService.shared)
    }
} 