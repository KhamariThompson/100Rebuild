import SwiftUI

// This is the main implementation
struct MainAppChallengesTabView: View {
    @StateObject private var viewModel = ChallengesViewModel()
    @EnvironmentObject private var router: TabViewRouter
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @EnvironmentObject private var notificationService: NotificationService
    @EnvironmentObject private var userStatsService: UserStatsService
    @State private var scrollOffset: CGFloat = 0
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .top) {
                // Main content with scroll tracking
                ZStack {
                    // Background
                    Color.theme.background
                        .ignoresSafeArea()
                    
                    // Content based on state
                    ScrollView {
                        VStack(spacing: 0) {
                            // Spacer to push content below the header
                            Color.clear
                                .frame(height: 110)
                            
                            // Conditionally show appropriate content
                            if viewModel.isInitialLoad {
                                loadingView
                                    .transition(.opacity)
                            } else if viewModel.isLoading && viewModel.challenges.isEmpty {
                                loadingView
                                    .transition(.opacity)
                            } else if viewModel.challenges.isEmpty {
                                emptyStateView
                                    .transition(.opacity)
                            } else {
                                challengeListView
                                    .transition(.opacity)
                            }
                        }
                        .trackScrollOffset($scrollOffset)
                    }
                    .animation(.easeInOut(duration: 0.3), value: viewModel.isInitialLoad)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.isLoading)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.challenges.isEmpty)
                }
                
                // Overlay the dynamic header
                ScrollAwareHeaderView(
                    title: "Challenges",
                    scrollOffset: $scrollOffset
                ) {
                    // Optional additional content for the header
                    if !viewModel.isInitialLoad && !viewModel.challenges.isEmpty {
                        HStack(spacing: 12) {
                            Text("Active: \(viewModel.challenges.count)")
                                .font(.caption)
                                .foregroundColor(Color.theme.subtext)
                            
                            if let currentStreak = viewModel.challenges.map({ $0.streakCount }).max(), currentStreak > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "flame.fill")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                    Text("Streak: \(currentStreak)")
                                        .font(.caption)
                                        .foregroundColor(Color.theme.subtext)
                                }
                            }
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { viewModel.isShowingNewChallenge = true }) {
                            Label("New Challenge", systemImage: "plus")
                        }
                        
                        if !viewModel.challenges.isEmpty {
                            Button(action: refreshChallenges) {
                                Label("Refresh", systemImage: "arrow.clockwise")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 18, weight: .semibold))
                    }
                }
            }
            .sheet(isPresented: $viewModel.isShowingNewChallenge) {
                NewChallengeView(isPresented: $viewModel.isShowingNewChallenge, challengeTitle: $viewModel.challengeTitle) { title, isTimed in
                    Task {
                        await viewModel.createChallenge(title: title, isTimed: isTimed)
                        await userStatsService.refreshUserStats()
                    }
                }
            }
            .alert(isPresented: $viewModel.showError) {
                Alert(
                    title: Text("Oops!"),
                    message: Text(viewModel.errorMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            // Mark tab as changing when this view appears
            if router.selectedTab == 0 {
                router.tabIsChanging = true
            }
            
            Task {
                await viewModel.loadChallenges()
                await viewModel.loadUserProfile()
                
                // After data is loaded, mark tab as not changing
                if router.selectedTab == 0 {
                    router.tabIsChanging = false
                }
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(Color.theme.accent)
            
            Text("Loading challenges...")
                .font(.headline)
                .foregroundColor(Color.theme.text)
            
            Text("Hold tight as we fetch your latest data")
                .font(.subheadline)
                .foregroundColor(Color.theme.subtext)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.top, 40)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "flag.fill")
                .font(.system(size: 50))
                .foregroundColor(Color.theme.accent.opacity(0.7))
            
            Text("No challenges yet")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(Color.theme.text)
            
            Text("Create your first challenge to track your 100-day journey")
                .font(.subheadline)
                .foregroundColor(Color.theme.subtext)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: { viewModel.isShowingNewChallenge = true }) {
                Label("Create Challenge", systemImage: "plus")
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.theme.accent)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .buttonStyle(ChallengesScaleButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.top, 40)
    }
    
    private var challengeListView: some View {
        VStack(spacing: 24) {
            if viewModel.isOffline {
                ChallengesOfflineBannerView()
                    .padding(.horizontal)
            }
            
            VStack(spacing: 16) {
                ForEach(viewModel.challenges) { challenge in
                    ChallengesCardView(challenge: challenge, viewModel: viewModel)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    private func refreshChallenges() {
        Task {
            await viewModel.loadChallenges()
            await userStatsService.refreshUserStats()
        }
    }
}

// MARK: - Supporting Views

struct ChallengesCardView: View {
    let challenge: Challenge
    @ObservedObject var viewModel: ChallengesViewModel
    @State private var showActionSheet = false
    
    var body: some View {
        // Keep your existing ChallengeCard implementation here
        // or update it if needed
        Text("Challenge card for: \(challenge.title)")
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.theme.surface)
            )
    }
}

struct ChallengesOfflineBannerView: View {
    var body: some View {
        HStack {
            Image(systemName: "wifi.slash")
                .foregroundColor(.yellow)
            Text("You're offline. Some features may be limited.")
                .font(.footnote)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(Color(.systemGray6))
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

struct ChallengesScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

// For backward compatibility - using a typealias instead of a separate struct
typealias ChallengesTabView = MainAppChallengesTabView

// Preview
struct MainAppChallengesTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainAppChallengesTabView()
    }
} 