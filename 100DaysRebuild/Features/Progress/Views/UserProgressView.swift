import SwiftUI

struct UserProgressView: View {
    @StateObject private var viewModel = ProgressViewModel()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Progress Stats
                    VStack(spacing: 16) {
                        Text("Your Progress")
                            .font(.title2)
                            .foregroundColor(.theme.text)
                        
                        HStack(spacing: 20) {
                            StatCard(title: "Current Streak", value: "\(viewModel.currentStreak)")
                            StatCard(title: "Longest Streak", value: "\(viewModel.longestStreak)")
                        }
                        
                        HStack(spacing: 20) {
                            StatCard(title: "Challenges", value: "\(viewModel.totalChallenges)")
                            StatCard(title: "Completed", value: "\(viewModel.completedChallenges)")
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.theme.surface)
                            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                    )
                    .padding(.horizontal)
                    
                    // Progress Chart
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
                .padding(.vertical)
            }
            .background(Color.theme.background.ignoresSafeArea())
            .navigationTitle("Progress")
        }
    }
}

struct StatCard: View {
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
    }
} 