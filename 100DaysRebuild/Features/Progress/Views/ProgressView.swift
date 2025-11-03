import SwiftUI
import Charts
import FirebaseFirestore
import FirebaseAuth
import Foundation

// Import components from the renamed file

// Always be explicit about UserProgressViewModel type to avoid ambiguity
// Updated to reference ProgressDashboardViewModel to avoid conflicts
typealias UPViewModel = ProgressDashboardViewModel

// No additional imports needed - TabViewRouter is now unambiguous

// Define the models needed for the view - renamed to avoid conflicts
struct ProgressViewChallenge {
    let id: String
    var title: String
    var description: String
    var isCompleted: Bool
    var hasStreakExpired: Bool
    
    init(id: String, title: String, description: String, isCompleted: Bool = false, hasStreakExpired: Bool = false) {
        self.id = id
        self.title = title
        self.description = description
        self.isCompleted = isCompleted
        self.hasStreakExpired = hasStreakExpired
    }
}

// Define the ProgressBadge struct directly here to avoid import issues
struct ProgressBadge: Identifiable {
    let id: Int
    let title: String
    let iconName: String
    
    init(id: Int, title: String, iconName: String) {
        self.id = id
        self.title = title
        self.iconName = iconName
    }
}

// Define the ProgressChallengeItem struct directly here to avoid import issues
struct ProgressChallengeItem: Identifiable {
    let id = UUID()
    let title: String
    let completionPercentage: Int
    
    init(title: String, completionPercentage: Int) {
        self.title = title
        self.completionPercentage = completionPercentage
    }
}

// Define the ProgressDailyCheckIn struct directly here to avoid import issues
struct ProgressDailyCheckIn: Identifiable {
    let id = UUID()
    let date: Date
    let count: Int
    
    init(date: Date, count: Int) {
        self.date = date
        self.count = count
    }
}

// MARK: - Main View
struct ProgressView: View {
    @EnvironmentObject var viewModel: ProgressDashboardViewModel
    @EnvironmentObject var subscriptionService: SubscriptionService
    @EnvironmentObject var notificationService: NotificationService
    @EnvironmentObject var router: NavigationRouter
    @EnvironmentObject var userStatsService: UserStatsService
    @EnvironmentObject var badgeService: BadgeService
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var loadTask: Task<Void, Never>? = nil
    @State private var hasLoadedOnce = false
    @State private var scrollOffset: CGFloat = 0
    @State private var selectedBadge: ProgressBadge? = nil
    @State private var lastRefreshTime: Date = Date()
    @State private var isRefreshing = false
    @State private var badgesSectionExpanded = false // State for badges section expand/collapse
    @State private var shouldSkipInitialLoading = false // Skip loading state if navigating from auth
    
    // Gradient for progress title
    private let progressGradient = LinearGradient(
        gradient: Gradient(colors: [Color.theme.accent, Color.theme.accent.opacity(0.7)]),
        startPoint: .leading,
        endPoint: .trailing
    )
    
    private func shouldRefresh() -> Bool {
        let timeSinceLastRefresh = Date().timeIntervalSince(lastRefreshTime)
        return timeSinceLastRefresh >= 5.0 // Only refresh every 5 seconds
    }
    
    private func refreshData() async {
        // Cancel any existing task first
        cancelCurrentTask()
        
        guard shouldRefresh() && !isRefreshing else {
            print("ProgressView - Skipping refresh (too soon or already refreshing)")
            return
        }
        
        isRefreshing = true
        lastRefreshTime = Date()
        
        print("ProgressView - Refreshing data from all sources")
        loadTask = Task {
            // Add a timeout to prevent hanging
            try? await withTimeout(seconds: 5) {
                await viewModel.loadData(forceRefresh: true)
            }
            
            // Ensure isRefreshing is reset even if there's an error
            if !Task.isCancelled {
                isRefreshing = false
            }
        }
    }
    
    // Helper timeout function
    private func withTimeout<T: Sendable>(seconds: Double, operation: @escaping @Sendable () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw CancellationError()
            }

            // Return first result or throw first error
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.theme.background
                .ignoresSafeArea()
            
            // Main content
            ScrollView {
                VStack(spacing: AppSpacing.m) {
                    // Title with action button inside ScrollView
                    HStack(alignment: .top) {
                        // Title with gradient
                        Text("Progress")
                            .font(AppTypography.largeTitle(.bold))
                            .foregroundStyle(progressGradient)
                            .opacity(router.tabIsChanging ? 0 : 1) // Hide title during transitions
                        
                        Spacer()
                        
                        // Analytics button removed
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                    .padding(.top, AppSpacing.m)
                    
                    // Content based on state
                    // Skip loading state if we just logged in (data loading in background)
                    if viewModel.isLoading && !hasLoadedOnce && !shouldSkipInitialLoading {
                        self.loadingView
                            .transaction { transaction in
                                transaction.animation = nil // Disable animation for initial load
                            }
                    } else if let errorMessage = viewModel.errorMessage, !viewModel.hasData {
                        errorView(message: errorMessage)
                    } else if viewModel.hasData {
                        redesignedProgressContent
                    } else {
                        emptyStateView
                    }
                }
            }
            // Apply the tab transition modifier to prevent flashing during tab switches
            .withTabTransition(router: router)
        }
        .navigationTitle("") // Empty to prevent navigation title
        .navigationBarHidden(true) // Hide navigation bar since we have our own header
        .refreshable {
            print("ProgressView - Manual refresh triggered")
            await refreshData()
        }
        .onChange(of: subscriptionService.isProUser) { isPro in
            // Refresh data when user upgrades to Pro to ensure analytics are accurate
            if isPro {
                Task {
                    print("ProgressView - User upgraded to Pro, refreshing analytics")
                    await refreshData()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: BadgeService.badgesDidUpdateNotification)) { _ in
            // Force refresh when badges are updated
            Task {
                print("ProgressView - Badges were updated, refreshing data")
                await refreshData()
            }
        }
        .onAppear {
            // Check if we're navigating from auth (data is already loading in App.swift)
            // Skip the loading state to prevent flashing
            if !viewModel.hasData && viewModel.isLoading {
                shouldSkipInitialLoading = true
            }

            // Load data when view appears if we haven't loaded recently
            if shouldRefresh() {
                Task {
                    print("ProgressView - onAppear, loading data")
                    await refreshData()
                }
            }

            // Mark as having loaded once to avoid showing loading spinner again
            hasLoadedOnce = viewModel.hasData
        }
        .onChange(of: userStatsService.userStats) { newValue in
            if hasLoadedOnce {
                print("ProgressView - UserStatsService updated")
                Task {
                    await refreshData()
                }
            }
        }
        .onDisappear {
            print("ProgressView - onDisappear")
            cancelCurrentTask()
        }
        .sheet(item: $selectedBadge) { badge in
            BadgeDetailView(badge: badge)
        }
        .badgeUnlockCelebration(badge: viewModel.newlyUnlockedBadge, isPresented: $viewModel.showingBadgeUnlock)
        .modifier(NavigationDebugModifier())
        .sheet(isPresented: $viewModel.showProUpgradeSheet) {
            ProUpgradeSheetView(
                title: "Filter Badges by Category",
                description: "Upgrade to Pro to unlock advanced badge filtering and insights",
                features: [
                    "Filter badges by any category",
                    "Track badge progress over time",
                    "Receive personalized badge recommendations"
                ],
                onUpgrade: {
                    // Handle upgrade action
                    viewModel.showProUpgradeSheet = false
                },
                onDismiss: {
                    viewModel.showProUpgradeSheet = false
                }
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: ChallengeStore.challengesDidUpdateNotification)) { _ in
            // Update data when we receive notifications about challenge store changes
            if !viewModel.isLoading {
                Task {
                    await refreshData()
                }
            }
        }
        .sheet(isPresented: $subscriptionService.showPaywall, onDismiss: {
            // Check subscription status when paywall is dismissed
            Task {
                await subscriptionService.refreshSubscriptionStatus()
            }
        }) {
            PaywallView()
                .environmentObject(subscriptionService)
        }
    }
    
    // New redesigned progress content based on requirements
    private var redesignedProgressContent: some View {
        VStack(spacing: AppSpacing.m) {
            // 1. Hero Summary Section
            heroSummarySection
            
            // 2. Milestone & Badges Section 
            badgesSection
            
            // 3. Consistency Heatmap
            consistencyHeatmapSection
            
            // 4. Advanced Analytics Section (consolidated)
            advancedAnalyticsSection
            
            // 5. Daily Spark Section
            dailySparkSection
            
            Spacer(minLength: CalAIDesignTokens.spacingXL)
        }
        .padding(.horizontal)
    }
    
    // 1. Hero Summary Section
    private var heroSummarySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            // Hero headline
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                Text("You've checked in \(viewModel.currentStreak) days in a row!")
                    .font(AppTypography.title2(.bold))
                    .foregroundColor(Color.theme.text)
                    .padding(.horizontal, AppSpacing.s)
                    .multilineTextAlignment(.leading)
            }
            
            // Stats in a horizontal layout
            HStack(spacing: AppSpacing.m) {
                // Streak with flame emoji
                VStack(alignment: .center, spacing: 4) {
                    HStack(spacing: 4) {
                        Text("🔥")
                            .font(AppTypography.title3())
                        Text("\(viewModel.currentStreak)")
                            .font(AppTypography.title3(.bold))
                            .foregroundColor(Color.theme.text)
                    }
                    Text("Current Streak")
                        .font(AppTypography.caption1())
                        .foregroundColor(Color.theme.subtext)
                }
                .frame(maxWidth: .infinity)

                // Momentum badge (feature gated)
                if FeatureGateService.shared.isEnabled("momentum_predictor"),
                   let momentum = MomentumService.shared.currentState {
                    VStack(alignment: .center, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(momentum.emoji)
                            Text(momentum.label)
                                .font(AppTypography.caption1())
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 4)
                    .transition(.opacity)
                    .frame(maxWidth: .infinity)
                }
                
                // Percent complete - use global completion percentage from userStatsService
                VStack(alignment: .center, spacing: 4) {
                    Text("\(Int(userStatsService.userStats.overallCompletionPercentage * 100))%")
                        .font(AppTypography.title3(.bold))
                        .foregroundColor(Color.theme.text)
                    Text("Complete")
                        .font(AppTypography.caption1())
                        .foregroundColor(Color.theme.subtext)
                }
                .frame(maxWidth: .infinity)
                
                // Days active
                VStack(alignment: .center, spacing: 4) {
                    Text("\(viewModel.totalChallenges)")
                        .font(AppTypography.title3(.bold))
                        .foregroundColor(Color.theme.text)
                    Text("Challenges")
                        .font(AppTypography.caption1())
                        .foregroundColor(Color.theme.subtext)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, AppSpacing.s)
            
            // Optional radial ring progress chart - update to use global completion percentage
            ZStack {
                // Background ring
                Circle()
                    .stroke(lineWidth: 16)
                    .opacity(0.2)
                    .foregroundColor(Color.theme.accent)
                
                // Progress ring
                Circle()
                    .trim(from: 0.0, to: CGFloat(min(userStatsService.userStats.overallCompletionPercentage, 1.0)))
                    .stroke(style: StrokeStyle(lineWidth: 16, lineCap: .round, lineJoin: .round))
                    .foregroundColor(Color.theme.accent)
                    .rotationEffect(Angle(degrees: 270.0))
                    .animation(.easeInOut(duration: 1.0), value: userStatsService.userStats.overallCompletionPercentage)
                
                // Center content
                VStack(spacing: 0) {
                    Text("\(Int(userStatsService.userStats.overallCompletionPercentage * 100))%")
                        .font(AppTypography.title1(.bold))
                        .foregroundColor(Color.theme.text)

                    Text("complete")
                        .font(AppTypography.caption1())
                        .foregroundColor(Color.theme.subtext)
                }
            }
            .frame(width: 130, height: 130)
            .padding(.top, AppSpacing.s)
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.theme.surface)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
    
    // 2. Milestone & Badges Section
    private var badgesSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            // Improved section header with Pro badge and expand/collapse toggle
            HStack {
                // Header with optional PRO badge
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "trophy.fill")
                        .font(AppTypography.body())
                        .foregroundColor(.yellow)

                Text("Milestones & Badges")
                    .font(AppTypography.title3(.bold))
                    .foregroundColor(Color.theme.text)
                    
                    if subscriptionService.isProUser {
                        Text("PRO")
                            .font(AppTypography.caption2(.bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.theme.accent, Color.theme.accent.opacity(0.8)]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(6)
                    }
                }
                
                Spacer()
                
                // Expand/Collapse toggle
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        badgesSectionExpanded.toggle()
                    }
                }) {
                    HStack(spacing: 4) {
                        Text(badgesSectionExpanded ? "Collapse" : "Expand")
                            .font(AppTypography.caption1(.medium))
                            .foregroundColor(.theme.accent)

                        Image(systemName: badgesSectionExpanded ? "chevron.up" : "chevron.down")
                            .font(AppTypography.caption1(.semibold))
                            .foregroundColor(.theme.accent)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.theme.accent.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // Category filter menu (Pro feature teaser)
                Menu {
                    ForEach(BadgeCategory.allCases, id: \.self) { category in
                        Button(action: {
                            // This would be implemented as a Pro feature
                            if !subscriptionService.isProUser {
                                viewModel.showProUpgradeSheet = true
                            }
                        }) {
                            Label(category.rawValue, systemImage: category.icon)
                        }
                    }
                    
                    Divider()
                    
                    Button(action: {
                        // Reset filter
                    }) {
                        Label("Show All", systemImage: "tray.full")
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .foregroundColor(.theme.accent)
                        .font(AppTypography.title3())
                }
                .disabled(!subscriptionService.isProUser)
            }
            
            // Milestone badges section - always visible (collapsed view)
            VStack(spacing: AppSpacing.m) {
            if let nextMilestoneBadge = getMilestoneProgressBadge() {
                HStack {
                    Text("Milestone Progress")
                        .font(AppTypography.caption1())
                        .foregroundColor(.theme.subtext)
                        .padding(.leading, 2)
                    
                    Spacer()
                }
                .padding(.top, 4)
                
                milestoneProgressView(badge: nextMilestoneBadge)
                        .padding(.bottom, AppSpacing.xs)
                        .transition(.opacity)
            }
            
            // Show "Next Badge to Unlock" teaser banner
            if let nextBadge = badgeService.getNextBadgeToUnlock() {
                nextBadgeTeaser(nextBadge)
                        .padding(.bottom, AppSpacing.xs)
                        .transition(.opacity)
                }
            }
            
            // Expanded view - all badges
            if badgesSectionExpanded {
                VStack(spacing: AppSpacing.m) {
            if badgeService.getUnlockedBadges().isEmpty {
                // Empty state
                VStack(spacing: AppSpacing.m) {
                    Image(systemName: "trophy")
                        .font(AppTypography.display())
                        .foregroundColor(.theme.subtext.opacity(0.5))
                    
                    Text("Complete challenges to earn badges!")
                        .font(AppTypography.body(.medium))
                        .foregroundColor(Color.theme.subtext)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, AppSpacing.l)
                        .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                // Use our BadgeGridView component with filter for newest badges
                if let recentlyUnlockedBadges = getRecentlyUnlockedBadges(), !recentlyUnlockedBadges.isEmpty {
                    HStack {
                        Text("Recently Unlocked")
                            .font(AppTypography.caption1())
                            .foregroundColor(.theme.subtext)
                            .padding(.leading, 2)
                        
                        Spacer()
                    }
                    .padding(.top, 4)
                    
                    BadgeGridView(
                        badges: recentlyUnlockedBadges,
                        columns: 3,
                        showLocked: false,
                        onTap: { badge in
                            selectedBadge = convertToProgressBadge(badge)
                        }
                    )
                    .padding(.bottom, 8)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                // Display all badges
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            HStack {
                                Text("All Badges")
                                    .font(AppTypography.caption1())
                                    .foregroundColor(.theme.subtext)
                                    .padding(.leading, 2)
                                
                                Spacer()
                            }
                            
                BadgeGridView(
                    badges: badgeService.badges,
                    columns: 3,
                    showLocked: true,
                    onTap: { badge in
                        selectedBadge = convertToProgressBadge(badge)
                    }
                )
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.theme.surface)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .overlay(
            // Enhanced visual treatment for Pro users
            Group {
                if subscriptionService.isProUser {
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.yellow.opacity(0.4), Color.yellow.opacity(0.1)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                }
            }
        )
    }
    
    // New helper function to get the next milestone badge to unlock
    private func getMilestoneProgressBadge() -> Badge? {
        let milestoneBadges = badgeService.badges.filter { $0.category == .milestone || $0.category == .consistency }
        
        // Find the first milestone badge that's not unlocked yet
        return milestoneBadges
            .filter { !$0.isUnlocked }
            .sorted { $0.requiredValue < $1.requiredValue }
            .first
    }
    
    // New helper function to get recently unlocked badges (within the last 7 days)
    private func getRecentlyUnlockedBadges() -> [Badge]? {
        let calendar = Calendar.current
        let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        
        let recentBadges = badgeService.badges.filter { badge in
            if let unlockDate = badge.unlockedAt?.dateValue() {
                return unlockDate > oneWeekAgo
            }
            return false
        }
        
        return recentBadges.isEmpty ? nil : recentBadges
    }
    
    // New component to display milestone progress
    private func milestoneProgressView(badge: Badge) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                // Badge icon
                ZStack {
                    Circle()
                        .fill(badge.category.color.opacity(0.15))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: badge.iconName)
                        .font(AppTypography.title2())
                        .foregroundColor(badge.category.color)
                }
                
                // Badge details
                VStack(alignment: .leading, spacing: 4) {
                    Text(badge.name)
                        .font(AppTypography.body(.bold))
                        .foregroundColor(.theme.text)

                    Text("\(badge.currentProgress) of \(badge.requiredValue) days")
                        .font(AppTypography.subhead())
                        .foregroundColor(.theme.subtext)
                }
                
                Spacer()
                
                // Progress percentage
                Text("\(Int(badge.progressPercentage * 100))%")
                    .font(AppTypography.body(.bold))
                    .foregroundColor(badge.category.color)
            }
            
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                    
                    // Filled portion
                    RoundedRectangle(cornerRadius: 4)
                        .fill(badge.category.color)
                        .frame(width: max(4, geo.size.width * badge.progressPercentage), height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.theme.background)
        )
    }
    
    // Next badge teaser banner
    private func nextBadgeTeaser(_ badge: Badge) -> some View {
        HStack(spacing: 16) {
            // Badge icon
            ZStack {
                Circle()
                    .fill(badge.category.color.opacity(0.15))
                    .frame(width: 56, height: 56)
                
                Image(systemName: badge.iconName)
                    .font(AppTypography.title3())
                    .foregroundColor(badge.category.color)
                
                // Progress ring
                Circle()
                    .trim(from: 0, to: badge.progressPercentage)
                    .stroke(
                        badge.category.color.opacity(0.5),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 56, height: 56)
            }
            
            // Badge details
            VStack(alignment: .leading, spacing: 4) {
                Text("Next Badge to Unlock")
                    .font(AppTypography.subhead(.medium))
                    .foregroundColor(.theme.subtext)

                Text(badge.name)
                    .font(AppTypography.headline(.bold))
                    .foregroundColor(.theme.text)

                Text("\(badge.currentProgress)/\(badge.requiredValue) progress")
                    .font(AppTypography.subhead())
                    .foregroundColor(.theme.subtext)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.theme.background)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(badge.category.color.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // 3. Consistency Heatmap
    private var consistencyHeatmapSection: some View {
        ConsistencyHeatmapView(
            dateIntensityMap: viewModel.dateIntensityMap,
            weeksToShow: 4
        )
        .padding(.vertical, 0) // No vertical padding needed as the component has its own internal padding
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.theme.surface)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
    
    // New 4. Advanced Analytics Section (combines previous sections)
    private var advancedAnalyticsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            // Enhanced header
            HStack(spacing: AppSpacing.s) {
                // Analytics icon
                Image(systemName: "chart.xyaxis.line")
                    .font(AppTypography.title2(.semibold))
                    .foregroundColor(.theme.accent)

                Text("Advanced Analytics")
                    .font(AppTypography.headline(.bold))
                    .foregroundColor(.theme.text)

                Spacer()

                // Refresh button for all users
                Button(action: {
                    // Refresh analytics data
                    let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
                    feedbackGenerator.impactOccurred()

                    Task {
                        await viewModel.refreshAnalyticsData()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(AppTypography.body())
                        .foregroundColor(.theme.accent)
                }
                .padding(.trailing, 8)
            }
            .padding(.horizontal, AppSpacing.s)

            // Show analytics for all users
            VStack(spacing: AppSpacing.m) {
                    // Check-in rates - row 1
                    HStack(spacing: AppSpacing.m) {
                        // Weekly check-in rate
                        metricCard(
                            title: "Last 7 Days",
                            value: "\(Int(viewModel.weeklyCheckInRate * 100))%",
                            icon: "calendar.badge.clock",
                            color: .blue
                        )
                        
                        // Monthly check-in rate
                        metricCard(
                            title: "Last 30 Days",
                            value: "\(Int(viewModel.monthlyCheckInRate * 100))%",
                            icon: "calendar",
                            color: .green
                        )
                    }
                    
                    // Streaks - row 2
                    HStack(spacing: AppSpacing.m) {
                        // Longest streak ever
                        metricCard(
                            title: "Longest Streak",
                            value: "\(viewModel.longestStreak) days",
                            icon: "flame.fill",
                            color: .orange
                        )
                        
                        // Total active days this year
                        metricCard(
                            title: "Active Days (Year)",
                            value: "\(viewModel.activeDaysThisYear)",
                            icon: "checkmark.circle.fill",
                            color: .theme.accent
                        )
                    }
                    
                    // Overall check-in rate - row 3
                    HStack(spacing: AppSpacing.m) {
                        // Overall rate
                        metricCard(
                            title: "Overall Consistency",
                            value: "\(Int(viewModel.totalCheckInRate * 100))%",
                            icon: "chart.pie.fill",
                            color: .purple
                        )
                    }
                    
                    // Row 3 - Special metrics
                    VStack(spacing: AppSpacing.s) {
                        // Projected completion
                        HStack(spacing: AppSpacing.s) {
                            Image(systemName: "calendar.badge.clock")
                                .foregroundColor(.blue)
                                .font(AppTypography.headline())
                                .frame(width: 24, height: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                            Text("Projected Completion")
                                .font(AppTypography.subhead(.medium))
                                .foregroundColor(.theme.subtext)

                            if let projectedDate = viewModel.projectedCompletionDate {
                                Text(projectedDate, style: .date)
                                        .font(AppTypography.body(.bold))
                                    .foregroundColor(.theme.text)
                            } else {
                                Text("Set a goal to see projection")
                                    .font(AppTypography.body(.medium))
                                    .foregroundColor(.theme.text)
                            }
                        }
                        
                        Spacer()
                        }
                        .padding()
                        .background(Color.theme.surface.opacity(0.6))
                        .cornerRadius(12)
                        
                        // Average check-in time
                        if let avgTime = viewModel.averageCheckInTime {
                            HStack(spacing: AppSpacing.s) {
                                Image(systemName: "clock.fill")
                                    .foregroundColor(.purple)
                                    .font(AppTypography.headline())
                                    .frame(width: 24, height: 24)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Average Check-in Time")
                                .font(AppTypography.subhead(.medium))
                                .foregroundColor(.theme.subtext)

                                    Text(avgTime)
                                        .font(AppTypography.body(.bold))
                                .foregroundColor(.theme.text)
                        }
                                
                                Spacer()
                            }
                            .padding()
                            .background(Color.theme.surface.opacity(0.6))
                            .cornerRadius(12)
                        }
                        
                        // Best streak month
                        if let bestMonth = viewModel.bestStreakMonth {
                            HStack(spacing: AppSpacing.s) {
                                Image(systemName: "trophy.fill")
                                    .foregroundColor(.yellow)
                                    .font(AppTypography.headline())
                                    .frame(width: 24, height: 24)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Best Streak Month")
                            .font(AppTypography.subhead(.medium))
                            .foregroundColor(.theme.subtext)

                                    Text("\(bestMonth.month), \(bestMonth.consistency)% consistency")
                                        .font(AppTypography.body(.bold))
                                        .foregroundColor(.theme.text)
                                }
                                
                                    Spacer()
                                }
                            .padding()
                            .background(Color.theme.surface.opacity(0.6))
                            .cornerRadius(12)
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                    .fill(Color.theme.surface)
                    .shadow(color: Color.theme.shadow.opacity(0.1), radius: 8, x: 0, y: 4)
                )
        }
    }

    // 4.5 Progress Forecast Card (feature gated)
    private var progressForecastCard: some View {
        Group {
            if FeatureGateService.shared.isEnabled("progress_forecast"),
               let forecast = ForecastService.shared.latest {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundColor(.blue)
                        Text("Progress Forecast")
                            .font(.headline)
                        Spacer()
                        Text("Confidence: \(Int(forecast.confidence * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text("At this pace, you’ll reach Day 100 on \(forecast.predictedDate.formatted(.dateTime.month().day()))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    if subscriptionService.isProUser {
                        // Chart for Pro users
                        let trend = ForecastService.shared.trendPointsSync(limitDays: 30)
                        Chart {
                            ForEach(trend) { p in
                                LineMark(
                                    x: .value("Day", p.day),
                                    y: .value("Completion", p.percent)
                                )
                            }
                        }
                        .frame(height: 120)
                        .chartYScale(domain: 0...1)
                        .chartXAxis(.hidden)
                    }
                }
                .padding()
                .background(DS.Colors.surface)
                .cornerRadius(DS.Spacing.cardCornerRadius)
                .transition(.opacity)
            }
        }
    }
    
    // Small feature item for Pro preview
    private func advancedFeatureItem(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(AppTypography.caption1())
                .foregroundColor(.theme.accent)
            
            Text(text)
                .font(AppTypography.caption1(.medium))
                .foregroundColor(.theme.subtext)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.theme.accent.opacity(0.1))
        )
    }
    
    // Helper for consistent metric cards
    private func metricCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(AppTypography.body())
                
                Text(title)
                    .font(AppTypography.subhead(.medium))
                    .foregroundColor(.theme.subtext)
            }
            
            Text(value)
                .font(AppTypography.title3(.bold))
                .foregroundColor(.theme.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        .background(Color.theme.surface.opacity(0.6))
        .cornerRadius(12)
    }
    
    // Placeholder for blurred metrics (free users)
    private func metricCardPlaceholder() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 16, height: 16)
                
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 80, height: 14)
            }
            
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 60, height: 20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.theme.surface.opacity(0.6))
        .cornerRadius(12)
    }
    
    // 5. Daily Spark Section
    private var dailySparkSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            // Use explicit parameter names to avoid ambiguity and remove Timer
            DailySparkView(
                currentStreak: viewModel.currentStreak,
                completionPercentage: viewModel.completionPercentage
            )
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }
    
    // Badge card view
    private struct BadgeCard: View {
        let badge: ProgressBadge
        @State private var animate = false
        
        var body: some View {
            VStack(spacing: AppSpacing.s) {
                // Icon with glow effect
                ZStack {
                    // Glow effect
                    Circle()
                        .fill(Color.theme.accent.opacity(0.25))
                        .frame(width: 70, height: 70)
                        .blur(radius: animate ? 8 : 4)
                        .opacity(animate ? 0.8 : 0.4)
                    
                    // Badge icon
                    Image(systemName: badge.iconName)
                        .font(AppTypography.largeTitle(.semibold))
                        .foregroundColor(Color.theme.accent)
                        .frame(width: 60, height: 60)
                        .background(
                            Circle()
                                .fill(Color.theme.surface)
                                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 3)
                        )
                }
                .scaleEffect(animate ? 1.05 : 1.0)
                
                // Badge title
                Text(badge.title)
                    .font(AppTypography.subhead(.medium))
                    .foregroundColor(Color.theme.text)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.theme.surface)
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 3)
            )
            .onAppear {
                withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    animate = true
                }
            }
        }
    }
    
    // Badge detail view
    private struct BadgeDetailView: View {
        let badge: ProgressBadge
        @Environment(\.dismiss) private var dismiss
        
        var body: some View {
            VStack(spacing: AppSpacing.l) {
                // Close button
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(AppTypography.title2())
                            .foregroundColor(Color.theme.subtext)
                    }
                    .padding()
                }
                
                Spacer()
                
                // Badge icon
                ZStack {
                    Circle()
                        .fill(Color.theme.accent.opacity(0.15))
                        .frame(width: 140, height: 140)
                        .blur(radius: 10)
                    
                    Image(systemName: badge.iconName)
                        .font(AppTypography.displayXL(.semibold))
                        .foregroundColor(Color.theme.accent)
                }
                .padding(.bottom, AppSpacing.l)
                
                // Badge info
                Text(badge.title)
                    .font(AppTypography.title1(.bold))
                    .foregroundColor(Color.theme.text)
                    .multilineTextAlignment(.center)

                Text("You've earned this badge by demonstrating consistency and dedication to your goals.")
                    .font(AppTypography.body())
                    .foregroundColor(Color.theme.subtext)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
                
                Spacer()
                
                // Share button
                Button {
                    // Handle share
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share Achievement")
                    }
                    .padding()
                    .background(Color.theme.accent)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.bottom, AppSpacing.xl)
            }
            .background(Color.theme.background.ignoresSafeArea())
        }
    }
    
    // Helper method to cancel any running task
    private func cancelCurrentTask() {
        loadTask?.cancel()
        loadTask = nil
        isRefreshing = false
    }

    // Loading view with progress indicator
    private var loadingView: some View {
        VStack(spacing: 20) {
            // Use ActivityIndicator instead of ProgressView to avoid ambiguity
            ActivityIndicator()
                .scaleEffect(1.5)
            
            Text("Loading your progress...")
                .font(AppTypography.headline())
                .foregroundColor(Color.theme.text)

            Text("Hold tight as we fetch your latest data")
                .font(AppTypography.subhead())
                .foregroundColor(Color.theme.subtext)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.top, 40)
    }
    
    // Standard activity indicator to use instead of SwiftUI.ProgressView
    private struct ActivityIndicator: UIViewRepresentable {
        func makeUIView(context: Context) -> UIActivityIndicatorView {
            let view = UIActivityIndicatorView(style: .medium)
            view.startAnimating()
            view.color = UIColor(Color.theme.accent)
            return view
        }
        
        func updateUIView(_ uiView: UIActivityIndicatorView, context: Context) {}
    }
    
    // Error view with retry button
    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(AppTypography.font(size: 50, weight: .bold))
                .foregroundColor(.yellow)
            
            Text(message)
                .font(AppTypography.headline())
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if NetworkMonitor.shared.isConnected {
                Button("Try Again") {
                    Task { 
                        await refreshData()
                    }
                }
                .buttonStyle(.borderedProminent)
            } else {
                HStack {
                    Image(systemName: "wifi.slash")
                    Text("You're offline")
                }
                .font(AppTypography.caption1())
                .foregroundColor(.secondary)
                .padding(.top)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
    
    // Empty state when no data is available
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.bar")
                .font(AppTypography.font(size: 50, weight: .bold))
                .foregroundColor(Color.theme.accent.opacity(0.7))
            
            Text("No progress data yet")
                .font(AppTypography.title3(.semibold))
                .foregroundColor(Color.theme.text)

            Text("Complete challenges to see your progress.")
                .font(AppTypography.subhead())
                .foregroundColor(Color.theme.subtext)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button("Start a Challenge") {
                withAnimation {
                    // Switch to challenges tab
                    router.changeTab(to: 0)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.theme.accent)
            .foregroundColor(colorScheme == .dark ? .black : .white)
            .cornerRadius(12)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
    
    // Helper function to convert Badge to ProgressBadge
    private func convertToProgressBadge(_ badge: Badge) -> ProgressBadge {
        return ProgressBadge(
            id: Int(badge.id.hashValue),
            title: badge.name,
            iconName: badge.iconName
        )
    }
}

// MARK: - Preview
// Removed preview code that was using mock data for submission to Apple

// Helper views for the analytics screen
struct ProgressAnalyticsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: ProgressDashboardViewModel
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @State private var isRefreshing = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                // Pull to refresh functionality
                PullToRefresh(isRefreshing: $isRefreshing) {
                    Task {
                        isRefreshing = true
                        await viewModel.refreshAnalyticsData()
                        isRefreshing = false
                    }
                }
                VStack(spacing: 24) {
                    // Progress Summary Card
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Progress Analytics")
                            .font(AppTypography.title2(.bold))
                        
                        // Basic stats in horizontal layout
                        HStack(spacing: 16) {
                            AnalyticsStatCard(title: "Challenges", value: "\(viewModel.totalChallenges)")
                            AnalyticsStatCard(title: "Current Streak", value: "\(viewModel.currentStreak)")
                            AnalyticsStatCard(title: "Completion", value: "\(Int(viewModel.completionPercentage * 100))%")
                        }
                        
                        // Circular progress indicator
                        HStack {
                            Spacer()
                            ProgressCircleView(progress: viewModel.completionPercentage, size: 200, lineWidth: 20)
                            Spacer()
                        }
                        .padding(.top, 8)
                    }
                    .padding()
                    .background(Color.theme.surface)
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                    
                    // Activity Chart
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Activity Heatmap")
                            .font(AppTypography.title2(.bold))
                        
                        // Placeholder for heatmap
                        HStack {
                            Spacer()
                            Text("Activity visualization available in a future update")
                                .font(AppTypography.subhead())
                                .foregroundColor(Color.theme.subtext)
                                .multilineTextAlignment(.center)
                                .padding(.vertical, 60)
                            Spacer()
                        }
                    }
                    .padding()
                    .background(Color.theme.surface)
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                }
                .padding()
            }
            .navigationTitle("Analytics")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top) {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                            .foregroundColor(Color.theme.accent)
                            .font(AppTypography.body(.medium))
                    }
                    .padding(.trailing)
                    .padding(.top, 8)
                }
                .frame(height: 44)
                .background(Color.clear)
            }
        }
        .sheet(isPresented: $subscriptionService.showPaywall, onDismiss: {
            // Check subscription status when paywall is dismissed
            Task {
                await subscriptionService.refreshSubscriptionStatus()
            }
        }) {
            PaywallView()
                .environmentObject(subscriptionService)
        }
    }
}

// Helper views for the analytics screen
struct AnalyticsStatCard: View {
    var title: String
    var value: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(AppTypography.title1(.bold))
                .foregroundColor(Color.theme.accent)

            Text(title)
                .font(AppTypography.caption1())
                .foregroundColor(Color.theme.subtext)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.theme.surface.opacity(0.5))
        .cornerRadius(8)
    }
}

struct ProgressCircleView: View {
    var progress: Double
    var size: CGFloat
    var lineWidth: CGFloat
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: lineWidth)
                .opacity(0.3)
                .foregroundColor(Color.theme.accent.opacity(0.3))
            
            Circle()
                .trim(from: 0.0, to: CGFloat(min(progress, 1.0)))
                .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                .foregroundColor(Color.theme.accent)
                .rotationEffect(Angle(degrees: 270.0))
                .animation(.linear, value: progress)
            
            VStack {
                Text("\(Int(progress * 100))%")
                    .font(AppTypography.display(.bold))
                    .foregroundColor(Color.theme.text)
            }
        }
        .frame(width: size, height: size)
    }
}

// Helper components for loading screen

// NOTE: LoadingStepIndicator and FallbackButton moved to ProgressComponents.swift

 
