import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct FriendProfileView: View {
    let friendId: String
    let friendUsername: String
    
    @StateObject private var viewModel = FriendProfileViewModel()
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack {
            Color.theme.background.ignoresSafeArea()

            if viewModel.isLoading || viewModel.friendProfile == nil {
                loadingView
            } else {
                scrollContent
            }
        }
        .navigationTitle("@\(friendUsername)")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .id(friendId) // Enforce unique identity per friendId
        .onAppear {
            viewModel.loadFriendProfile(friendId: friendId)
        }
        .alert(isPresented: $viewModel.showError) {
            Alert(
                title: Text("Error"),
                message: Text(viewModel.errorMessage ?? "An unknown error occurred"),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: AppSpacing.m) {
            ProgressView()
                .scaleEffect(1.5)
                .padding()
            
            Text("Loading profile...")
                .font(AppTypography.subhead())
                .foregroundColor(.theme.subtext)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Scroll Content
    private var scrollContent: some View {
        ScrollView {
            VStack(spacing: AppSpacing.l) {
                // Profile Header
                profileHeaderSection
                
                // Stats Grid
                statsSection
                
                // Active Challenges
                activeChallengesSection
                
                // Recent Activity
                recentActivitySection
                
                Color.clear.frame(height: 100) // Bottom padding
            }
            .padding(.horizontal, AppSpacing.screenHorizontalPadding)
        }
        .refreshable {
            await viewModel.refreshProfile(friendId: friendId)
        }
    }
    
    // MARK: - Profile Header
    private var profileHeaderSection: some View {
        AppComponents.GradientCard(
            gradient: LinearGradient(
                colors: [Color.theme.accent.opacity(0.8), Color.theme.accent.opacity(0.4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        ) {
            VStack(spacing: AppSpacing.m) {
                // Profile Image
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Group {
                            if let photoURL = viewModel.friendProfile?.photoURL {
                                AsyncImage(url: photoURL) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                                .clipShape(Circle())
                            } else {
                                Text(String(friendUsername.prefix(1)).uppercased())
                                    .font(AppTypography.largeTitle(.bold))
                                    .foregroundColor(.white)
                            }
                        }
                    )
                
                // Name and Username
                VStack(spacing: AppSpacing.xs) {
                    if let displayName = viewModel.friendProfile?.displayName {
                        Text(displayName)
                            .font(AppTypography.title2())
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    
                    Text("@\(friendUsername)")
                        .font(AppTypography.subhead())
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                // Send Encouragement Button
                Button(action: {
                    Task {
                        await viewModel.sendEncouragement(to: friendId)
                    }
                }) {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "heart.fill")
                            .font(AppTypography.body(.medium))
                        
                        Text("Send Encouragement")
                            .font(AppTypography.subhead())
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.theme.accent)
                    .padding(.horizontal, AppSpacing.m)
                    .padding(.vertical, AppSpacing.s)
                    .background(
                        RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                            .fill(Color.white)
                    )
                }
                .buttonStyle(AppScaleButtonStyle())
                .disabled(viewModel.isLoading)
            }
        }
    }
    
    // MARK: - Stats Section
    private var statsSection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: AppSpacing.s) {
            StatCardView(
                title: "Current Streak",
                value: "\(viewModel.friendProfile?.currentStreak ?? 0)",
                subtitle: "days",
                icon: "flame.fill",
                color: .orange
            )
            
            StatCardView(
                title: "Total Check-ins",
                value: "\(viewModel.friendProfile?.totalCheckIns ?? 0)",
                subtitle: "completed",
                icon: "checkmark.circle.fill",
                color: .theme.success
            )
            
            StatCardView(
                title: "Challenges",
                value: "\(viewModel.friendProfile?.completedChallenges ?? 0)",
                subtitle: "finished",
                icon: "trophy.fill",
                color: .theme.accent
            )
            
            StatCardView(
                title: "Since",
                value: viewModel.friendProfile?.joinedDate.formatted(.dateTime.month().year()) ?? "--",
                subtitle: "member",
                icon: "calendar.badge.plus",
                color: .theme.subtext
            )
        }
    }
    
    // MARK: - Active Challenges
    private var activeChallengesSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            HStack {
                Text("Active Challenges")
                    .font(AppTypography.title3())
                    .fontWeight(.bold)
                    .foregroundColor(.theme.text)
                
                Spacer()
                
                if let count = viewModel.activeChallenges?.count, count > 0 {
                    AppComponents.Badge(
                        text: "\(count)",
                        color: .theme.accent,
                        style: .filled
                    )
                }
            }
            
            if let challenges = viewModel.activeChallenges, !challenges.isEmpty {
                LazyVStack(spacing: AppSpacing.s) {
                    ForEach(challenges) { challenge in
                        FriendChallengeCardView(challenge: challenge)
                    }
                }
            } else {
                AppComponents.Card {
                    VStack(spacing: AppSpacing.s) {
                        Image(systemName: "flag.slash")
                            .font(AppTypography.title2())
                            .foregroundColor(.theme.subtext)
                        
                        Text("No Active Challenges")
                            .font(AppTypography.subhead())
                            .fontWeight(.medium)
                            .foregroundColor(.theme.subtext)
                        
                        Text("This friend isn't currently working on any challenges")
                            .font(AppTypography.caption1())
                            .foregroundColor(.theme.subtext)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, AppSpacing.s)
                }
            }
        }
    }
    
    // MARK: - Recent Activity
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Text("Recent Activity")
                .font(AppTypography.title3())
                .fontWeight(.bold)
                .foregroundColor(.theme.text)
            
            if let activities = viewModel.recentActivities, !activities.isEmpty {
                LazyVStack(spacing: AppSpacing.s) {
                    ForEach(activities) { activity in
                        FriendActivityRowView(activity: activity)
                    }
                }
            } else {
                AppComponents.Card {
                    VStack(spacing: AppSpacing.s) {
                        Image(systemName: "clock.badge.xmark")
                            .font(AppTypography.title2())
                            .foregroundColor(.theme.subtext)
                        
                        Text("No Recent Activity")
                            .font(AppTypography.subhead())
                            .fontWeight(.medium)
                            .foregroundColor(.theme.subtext)
                        
                        Text("Check back later to see their progress")
                            .font(AppTypography.caption1())
                            .foregroundColor(.theme.subtext)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, AppSpacing.s)
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct StatCardView: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        AppComponents.Card {
            VStack(spacing: AppSpacing.s) {
                HStack {
                    Image(systemName: icon)
                        .font(AppTypography.title3(.semibold))
                        .foregroundColor(color)
                    
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(value)
                        .font(AppTypography.title2())
                        .fontWeight(.bold)
                        .foregroundColor(.theme.text)
                    
                    Text(subtitle)
                        .font(AppTypography.caption1())
                        .foregroundColor(.theme.subtext)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
                
                Text(title)
                    .font(AppTypography.caption1())
                    .fontWeight(.medium)
                    .foregroundColor(.theme.subtext)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(height: 100)
    }
}

struct FriendChallengeCardView: View {
    let challenge: FriendChallenge
    
    var body: some View {
        AppComponents.Card {
            HStack(spacing: AppSpacing.s) {
                // Progress Ring
                ZStack {
                    Circle()
                        .stroke(Color.theme.border.opacity(0.3), lineWidth: 3)
                        .frame(width: 40, height: 40)
                    
                    Circle()
                        .trim(from: 0, to: challenge.progress)
                        .stroke(Color.theme.accent, lineWidth: 3)
                        .frame(width: 40, height: 40)
                        .rotationEffect(.degrees(-90))
                    
                    Text("\(Int(challenge.progress * 100))%")
                        .font(AppTypography.caption2())
                        .fontWeight(.bold)
                        .foregroundColor(.theme.accent)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(challenge.title)
                        .font(AppTypography.subhead())
                        .fontWeight(.semibold)
                        .foregroundColor(.theme.text)
                        .lineLimit(1)
                    
                    Text("Day \(challenge.currentDay) of 100")
                        .font(AppTypography.caption1())
                        .foregroundColor(.theme.subtext)
                }
                
                Spacer()
                
                VStack {
                    Image(systemName: "flame.fill")
                        .font(AppTypography.body())
                        .foregroundColor(.orange)
                    
                    Text("\(challenge.streak)")
                        .font(AppTypography.caption1())
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                }
            }
        }
    }
}

struct FriendActivityRowView: View {
    let activity: FriendActivity
    
    var body: some View {
        AppComponents.Card {
            HStack(spacing: AppSpacing.s) {
                // Activity icon
                Circle()
                    .fill(activity.type.color.opacity(0.2))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: activity.type.icon)
                            .font(AppTypography.subhead(.semibold))
                            .foregroundColor(activity.type.color)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(activity.description)
                        .font(AppTypography.subhead())
                        .foregroundColor(.theme.text)
                        .lineLimit(2)
                    
                    Text(activity.timestamp.timeAgoDisplay())
                        .font(AppTypography.caption1())
                        .foregroundColor(.theme.subtext)
                }
                
                Spacer()
                
                if activity.type == .milestone {
                    Text("🎉")
                        .font(AppTypography.title2())
                }
            }
        }
    }
}

// MARK: - Preview
struct FriendProfileView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            FriendProfileView(friendId: "123", friendUsername: "john_doe")
                .environmentObject(SubscriptionService.shared)
        }
        .preferredColorScheme(.dark)
    }
} 