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
    @EnvironmentObject var subscriptionStore: SubscriptionStore
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
        // Note: showPaywall removed from SubscriptionStore
        // TODO: Implement paywall presentation via navigation state if needed
        // .sheet(isPresented: $showPaywall) {
        //     PaywallView()
        //         .environmentObject(subscriptionStore)
        // }
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
    
    // 1. Hero Summary Section - Enhanced with better centering
    private var heroSummarySection: some View {
        VStack(spacing: AppSpacing.m) {
            // Hero headline - centered
            VStack(spacing: AppSpacing.xs) {
                if viewModel.currentStreak > 0 {
                    Text("You've checked in \(viewModel.currentStreak) \(viewModel.currentStreak == 1 ? "day" : "days") in a row!")
                        .font(AppTypography.title2(.bold))
                        .foregroundColor(Color.theme.text)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Ready to build your streak!")
                        .font(AppTypography.title2(.bold))
                        .foregroundColor(Color.theme.text)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }

            // Radial progress ring - centered
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
                VStack(spacing: 4) {
                    Text("\(Int(userStatsService.userStats.overallCompletionPercentage * 100))%")
                        .font(AppTypography.largeTitle(.bold))
                        .foregroundColor(Color.theme.text)

                    Text("Complete")
                        .font(AppTypography.caption1())
                        .foregroundColor(Color.theme.subtext)
                }
            }
            .frame(width: 140, height: 140)
            .frame(maxWidth: .infinity, alignment: .center)

            // Stats grid - properly centered
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: AppSpacing.m),
                GridItem(.flexible(), spacing: AppSpacing.m)
            ], spacing: AppSpacing.m) {
                // Current Streak
                statCard(
                    icon: "flame.fill",
                    value: "\(viewModel.currentStreak)",
                    label: "Current Streak",
                    color: .orange
                )

                // Longest Streak
                statCard(
                    icon: "trophy.fill",
                    value: "\(viewModel.longestStreak)",
                    label: "Longest Streak",
                    color: .yellow
                )

                // Total Challenges
                statCard(
                    icon: "list.bullet.rectangle",
                    value: "\(viewModel.totalChallenges)",
                    label: "Total Challenges",
                    color: .blue
                )

                // Active Days
                statCard(
                    icon: "checkmark.circle.fill",
                    value: "\(viewModel.activeDaysThisYear)",
                    label: "Active Days",
                    color: .green
                )
            }

            // Momentum badge (feature gated) - centered
            if FeatureGateService.shared.isEnabled("momentum_predictor"),
               let momentum = MomentumService.shared.currentState {
                HStack(spacing: 8) {
                    Text(momentum.emoji)
                        .font(AppTypography.title3())
                    Text(momentum.label)
                        .font(AppTypography.body(.medium))
                        .foregroundColor(.theme.text)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.theme.accent.opacity(0.1))
                )
                .frame(maxWidth: .infinity, alignment: .center)
                .transition(.opacity)
            }
        }
        .padding(AppSpacing.m)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.theme.surface)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }

    // Helper for stat cards
    private func statCard(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(AppTypography.title2())
                .foregroundColor(color)

            Text(value)
                .font(AppTypography.title3(.bold))
                .foregroundColor(Color.theme.text)

            Text(label)
                .font(AppTypography.caption1())
                .foregroundColor(Color.theme.subtext)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.m)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.theme.background)
        )
    }
    
    // 2. Milestone & Badges Section
    private var badgesSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            // Improved section header with Pro badge and expand/collapse toggle
            HStack {
                // Header
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "trophy.fill")
                        .font(AppTypography.body())
                        .foregroundColor(.yellow)

                Text("Milestones & Badges")
                    .font(AppTypography.title3(.bold))
                    .foregroundColor(Color.theme.text)
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
                
                // Category filter menu
                Menu {
                    ForEach(BadgeCategory.allCases, id: \.self) { category in
                        Button(action: {
                            // Filter badges by category
                            // TODO: Implement category filtering
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
    
    // 4. Enhanced Advanced Analytics Section - Completely Redesigned
    private var advancedAnalyticsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            // Section header with refresh button
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(AppTypography.title3())
                        .foregroundColor(.theme.accent)

                    Text("Analytics & Insights")
                        .font(AppTypography.title3(.bold))
                        .foregroundColor(.theme.text)
                }

                Spacer()

                // Refresh button
                Button(action: {
                    let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
                    feedbackGenerator.impactOccurred()
                    Task {
                        await viewModel.refreshAnalyticsData()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(AppTypography.body())
                        .foregroundColor(.theme.accent)
                        .padding(8)
                        .background(Color.theme.accent.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, AppSpacing.m)
            .padding(.top, AppSpacing.s)

            // Performance Trend Insight Card
            performanceTrendCard

            // Key Metrics Grid
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: AppSpacing.m),
                GridItem(.flexible(), spacing: AppSpacing.m)
            ], spacing: AppSpacing.m) {
                // Weekly consistency
                enhancedMetricCard(
                    title: "This Week",
                    value: "\(Int(viewModel.weeklyCheckInRate * 100))%",
                    subtitle: "Check-in Rate",
                    icon: "calendar.badge.clock",
                    color: trendColor(for: viewModel.weeklyCheckInRate),
                    trend: getTrend(current: viewModel.weeklyCheckInRate, baseline: viewModel.monthlyCheckInRate)
                )

                // Monthly consistency
                enhancedMetricCard(
                    title: "This Month",
                    value: "\(Int(viewModel.monthlyCheckInRate * 100))%",
                    subtitle: "Check-in Rate",
                    icon: "calendar",
                    color: trendColor(for: viewModel.monthlyCheckInRate),
                    trend: getTrend(current: viewModel.monthlyCheckInRate, baseline: viewModel.totalCheckInRate)
                )

                // Active days this year
                enhancedMetricCard(
                    title: "Active Days",
                    value: "\(viewModel.activeDaysThisYear)",
                    subtitle: "This Year",
                    icon: "checkmark.circle.fill",
                    color: .green,
                    trend: nil
                )

                // Overall consistency
                enhancedMetricCard(
                    title: "Overall",
                    value: "\(Int(viewModel.totalCheckInRate * 100))%",
                    subtitle: "Consistency",
                    icon: "chart.pie.fill",
                    color: .purple,
                    trend: nil
                )
            }
            .padding(.horizontal, AppSpacing.m)

            // Insights Section
            insightsSection
                .padding(.horizontal, AppSpacing.m)

            // Additional Metrics
            VStack(spacing: AppSpacing.s) {
                // Best month
                if let bestMonth = viewModel.bestStreakMonth {
                    insightRow(
                        icon: "trophy.fill",
                        iconColor: .yellow,
                        title: "Best Month",
                        value: "\(bestMonth.month) • \(bestMonth.consistency)% consistency"
                    )
                }

                // Average check-in time
                if let avgTime = viewModel.averageCheckInTime {
                    insightRow(
                        icon: "clock.fill",
                        iconColor: .blue,
                        title: "Avg. Check-in Time",
                        value: avgTime
                    )
                }

                // Projected completion
                if let projectedDate = viewModel.projectedCompletionDate {
                    insightRow(
                        icon: "flag.checkered",
                        iconColor: .green,
                        title: "Projected Finish",
                        value: projectedDate.formatted(date: .abbreviated, time: .omitted)
                    )
                }
            }
            .padding(.horizontal, AppSpacing.m)
            .padding(.bottom, AppSpacing.s)
        }
        .padding(.vertical, AppSpacing.m)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.theme.surface)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }

    // Performance trend card with actionable insights
    private var performanceTrendCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                    .font(AppTypography.title3())
                    .foregroundColor(.theme.accent)

                Text("Performance Trend")
                    .font(AppTypography.headline(.bold))
                    .foregroundColor(.theme.text)

                Spacer()
            }

            // Trend analysis
            if viewModel.weeklyCheckInRate > viewModel.monthlyCheckInRate {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.right")
                        .foregroundColor(.green)

                    Text("Improving")
                        .font(AppTypography.body(.bold))
                        .foregroundColor(.green)

                    Spacer()
                }

                Text("You're \(Int((viewModel.weeklyCheckInRate - viewModel.monthlyCheckInRate) * 100))% more consistent this week than your monthly average!")
                    .font(AppTypography.subhead())
                    .foregroundColor(.theme.subtext)
                    .fixedSize(horizontal: false, vertical: true)
            } else if viewModel.weeklyCheckInRate < viewModel.monthlyCheckInRate && viewModel.monthlyCheckInRate > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.right")
                        .foregroundColor(.orange)

                    Text("Needs Attention")
                        .font(AppTypography.body(.bold))
                        .foregroundColor(.orange)

                    Spacer()
                }

                Text("Your consistency this week is below your average. Try to check in daily to rebuild momentum!")
                    .font(AppTypography.subhead())
                    .foregroundColor(.theme.subtext)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "equal")
                        .foregroundColor(.blue)

                    Text("Steady")
                        .font(AppTypography.body(.bold))
                        .foregroundColor(.blue)

                    Spacer()
                }

                Text("You're maintaining a consistent pace. Keep up the great work!")
                    .font(AppTypography.subhead())
                    .foregroundColor(.theme.subtext)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(AppSpacing.m)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.theme.accent.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.theme.accent.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal, AppSpacing.m)
    }

    // Insights section with actionable recommendations
    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .font(AppTypography.body())
                    .foregroundColor(.yellow)

                Text("Insights")
                    .font(AppTypography.headline(.bold))
                    .foregroundColor(.theme.text)
            }

            VStack(alignment: .leading, spacing: 8) {
                // Streak insight
                if viewModel.currentStreak > 0 {
                    insightBullet(
                        text: "You're on a \(viewModel.currentStreak)-day streak! Keep it going to earn more badges.",
                        icon: "flame.fill",
                        color: .orange
                    )
                } else {
                    insightBullet(
                        text: "Start a new streak today! Consistency is key to success.",
                        icon: "flag.fill",
                        color: .blue
                    )
                }

                // Completion insight
                if userStatsService.userStats.overallCompletionPercentage < 0.25 {
                    insightBullet(
                        text: "You're just getting started! Focus on building daily habits.",
                        icon: "arrow.up.forward",
                        color: .green
                    )
                } else if userStatsService.userStats.overallCompletionPercentage >= 0.75 {
                    insightBullet(
                        text: "Amazing progress! You're in the final stretch!",
                        icon: "trophy.fill",
                        color: .yellow
                    )
                } else {
                    insightBullet(
                        text: "Great momentum! You're over \(Int(userStatsService.userStats.overallCompletionPercentage * 100))% complete.",
                        icon: "chart.line.uptrend.xyaxis",
                        color: .purple
                    )
                }

                // Weekly check-in insight
                if viewModel.weeklyCheckInRate >= 0.85 {
                    insightBullet(
                        text: "Exceptional consistency this week! You're crushing it!",
                        icon: "star.fill",
                        color: .yellow
                    )
                } else if viewModel.weeklyCheckInRate < 0.5 && viewModel.weeklyCheckInRate > 0 {
                    insightBullet(
                        text: "Try to increase your check-ins this week for better results.",
                        icon: "target",
                        color: .orange
                    )
                }
            }
        }
        .padding(AppSpacing.m)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.theme.background)
        )
    }

    // Helper for insight bullet points
    private func insightBullet(text: String, icon: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(AppTypography.caption1())
                .foregroundColor(color)
                .frame(width: 20, height: 20)

            Text(text)
                .font(AppTypography.subhead())
                .foregroundColor(.theme.text)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }

    // Enhanced metric card with trend indicators
    private func enhancedMetricCard(title: String, value: String, subtitle: String, icon: String, color: Color, trend: TrendDirection?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(AppTypography.body())
                    .foregroundColor(color)

                Spacer()

                // Trend indicator
                if let trend = trend {
                    HStack(spacing: 2) {
                        Image(systemName: trend.icon)
                            .font(AppTypography.caption2(.bold))
                        Text(trend.label)
                            .font(AppTypography.caption2(.medium))
                    }
                    .foregroundColor(trend.color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(trend.color.opacity(0.15))
                    )
                }
            }

            Text(value)
                .font(AppTypography.title2(.bold))
                .foregroundColor(.theme.text)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTypography.caption1(.medium))
                    .foregroundColor(.theme.subtext)

                Text(subtitle)
                    .font(AppTypography.caption2())
                    .foregroundColor(.theme.subtext.opacity(0.7))
            }
        }
        .padding(AppSpacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.theme.background)
        )
    }

    // Helper for insight rows
    private func insightRow(icon: String, iconColor: Color, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(AppTypography.body())
                .foregroundColor(iconColor)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(iconColor.opacity(0.15))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTypography.subhead(.medium))
                    .foregroundColor(.theme.subtext)

                Text(value)
                    .font(AppTypography.body(.bold))
                    .foregroundColor(.theme.text)
            }

            Spacer()
        }
        .padding(AppSpacing.m)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.theme.background)
        )
    }

    // Helper to determine trend color
    private func trendColor(for rate: Double) -> Color {
        if rate >= 0.8 {
            return .green
        } else if rate >= 0.5 {
            return .blue
        } else if rate >= 0.3 {
            return .orange
        } else {
            return .red
        }
    }

    // Trend direction enum
    private enum TrendDirection {
        case up, down, stable

        var icon: String {
            switch self {
            case .up: return "arrow.up"
            case .down: return "arrow.down"
            case .stable: return "minus"
            }
        }

        var color: Color {
            switch self {
            case .up: return .green
            case .down: return .orange
            case .stable: return .blue
            }
        }

        var label: String {
            switch self {
            case .up: return "Up"
            case .down: return "Down"
            case .stable: return "Steady"
            }
        }
    }

    // Helper to calculate trend
    private func getTrend(current: Double, baseline: Double) -> TrendDirection {
        let difference = current - baseline
        if abs(difference) < 0.05 {
            return .stable
        } else if difference > 0 {
            return .up
        } else {
            return .down
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

                    Text("At this pace, you'll reach Day 100 on \(forecast.predictedDate.formatted(.dateTime.month().day()))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    // Trend chart
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
    @EnvironmentObject private var subscriptionStore: SubscriptionStore
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
        // Note: showPaywall removed from SubscriptionStore
        // TODO: Implement paywall presentation via navigation state if needed
        // .sheet(isPresented: $showPaywall) {
        //     PaywallView()
        //         .environmentObject(subscriptionStore)
        // }
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

 
