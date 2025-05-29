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
    
    @State private var loadTask: Task<Void, Never>? = nil
    @State private var hasLoadedOnce = false
    @State private var scrollOffset: CGFloat = 0
    @State private var selectedBadge: ProgressBadge? = nil
    @State private var lastRefreshTime: Date = Date()
    @State private var isRefreshing = false
    
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
    private func withTimeout<T>(seconds: Double, operation: @escaping () async throws -> T) async throws -> T {
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
                            .font(.largeTitle)
                            .bold()
                            .foregroundStyle(progressGradient)
                            .opacity(router.tabIsChanging ? 0 : 1) // Hide title during transitions
                        
                        Spacer()
                        
                        // Analytics button removed
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                    .padding(.top, AppSpacing.m)
                    
                    // Content based on state
                    if viewModel.isLoading && !hasLoadedOnce {
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
        .onAppear {
            if !hasLoadedOnce {
                print("ProgressView - Initial load")
                Task {
                    await refreshData()
                    hasLoadedOnce = true
                }
            }
            setupSignOutListener()
        }
        .onChange(of: userStatsService.userStats) { _, _ in
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
            removeSignOutListener()
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
            
            // 4. Consolidated Pro Preview
            consolidatedProPreviewSection
            
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
                    .font(.system(size: 26, weight: .bold, design: .rounded))
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
                            .font(.system(size: 22))
                        Text("\(viewModel.currentStreak)")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(Color.theme.text)
                    }
                    Text("Current Streak")
                        .font(.caption)
                        .foregroundColor(Color.theme.subtext)
                }
                .frame(maxWidth: .infinity)
                
                // Percent complete
                VStack(alignment: .center, spacing: 4) {
                    Text("\(Int(viewModel.completionPercentage * 100))%")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color.theme.text)
                    Text("Complete")
                        .font(.caption)
                        .foregroundColor(Color.theme.subtext)
                }
                .frame(maxWidth: .infinity)
                
                // Days active
                VStack(alignment: .center, spacing: 4) {
                    Text("\(viewModel.totalChallenges)")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color.theme.text)
                    Text("Challenges")
                        .font(.caption)
                        .foregroundColor(Color.theme.subtext)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, AppSpacing.s)
            
            // Optional radial ring progress chart
            ZStack {
                // Background ring
                Circle()
                    .stroke(lineWidth: 16)
                    .opacity(0.2)
                    .foregroundColor(Color.theme.accent)
                
                // Progress ring
                Circle()
                    .trim(from: 0.0, to: CGFloat(min(viewModel.completionPercentage, 1.0)))
                    .stroke(style: StrokeStyle(lineWidth: 16, lineCap: .round, lineJoin: .round))
                    .foregroundColor(Color.theme.accent)
                    .rotationEffect(Angle(degrees: 270.0))
                    .animation(.easeInOut(duration: 1.0), value: viewModel.completionPercentage)
                
                // Center content
                VStack(spacing: 0) {
                    Text("\(Int(viewModel.completionPercentage * 100))%")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(Color.theme.text)
                    
                    Text("complete")
                        .font(.caption)
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
            // Improved section header with filter option
            HStack {
                Text("Milestones & Badges")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(Color.theme.text)
                
                Spacer()
                
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
                        // This would be implemented as a Pro feature
                        if !subscriptionService.isProUser {
                            viewModel.showProUpgradeSheet = true
                        }
                    }) {
                        Label("Show All", systemImage: "list.bullet")
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .foregroundColor(.theme.accent)
                        .font(.system(size: 20))
                }
                .disabled(!subscriptionService.isProUser)
            }
            
            // Milestone badges section - specifically highlighting streak achievements
            if let nextMilestoneBadge = getMilestoneProgressBadge() {
                HStack {
                    Text("Milestone Progress")
                        .font(.caption)
                        .foregroundColor(.theme.subtext)
                        .padding(.leading, 2)
                    
                    Spacer()
                }
                .padding(.top, 4)
                
                milestoneProgressView(badge: nextMilestoneBadge)
                    .padding(.bottom, AppSpacing.s)
            }
            
            // Show "Next Badge to Unlock" teaser banner
            if let nextBadge = badgeService.getNextBadgeToUnlock() {
                nextBadgeTeaser(nextBadge)
                    .padding(.bottom, AppSpacing.s)
            }
            
            if badgeService.getUnlockedBadges().isEmpty {
                // Empty state
                VStack(spacing: AppSpacing.m) {
                    Image(systemName: "trophy")
                        .font(.system(size: 40))
                        .foregroundColor(.theme.subtext.opacity(0.5))
                    
                    Text("Complete challenges to earn badges!")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.theme.subtext)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, AppSpacing.l)
            } else {
                // Use our BadgeGridView component with filter for newest badges
                if let recentlyUnlockedBadges = getRecentlyUnlockedBadges(), !recentlyUnlockedBadges.isEmpty {
                    HStack {
                        Text("Recently Unlocked")
                            .font(.caption)
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
                }
                
                // Display all badges
                BadgeGridView(
                    badges: badgeService.badges,
                    columns: 3,
                    showLocked: true,
                    onTap: { badge in
                        selectedBadge = convertToProgressBadge(badge)
                    }
                )
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
                        .font(.system(size: 22))
                        .foregroundColor(badge.category.color)
                }
                
                // Badge details
                VStack(alignment: .leading, spacing: 4) {
                    Text(badge.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.theme.text)
                    
                    Text("\(badge.currentProgress) of \(badge.requiredValue) days")
                        .font(.system(size: 14))
                        .foregroundColor(.theme.subtext)
                }
                
                Spacer()
                
                // Progress percentage
                Text("\(Int(badge.progressPercentage * 100))%")
                    .font(.system(size: 16, weight: .bold))
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
                    .font(.system(size: 24))
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
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.theme.subtext)
                
                Text(badge.name)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.theme.text)
                
                Text("\(badge.currentProgress)/\(badge.requiredValue) progress")
                    .font(.system(size: 14))
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
    
    // 3. Consistency Heatmap Section
    private var consistencyHeatmapSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            // Section header with better styling
            HStack {
                Text("Consistency")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(Color.theme.text)
                
                Spacer()
                
                // Info button with tooltip
                Button(action: {
                    // Future implementation: show information about consistency tracking
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                }) {
                    Image(systemName: "info.circle")
                        .foregroundColor(Color.theme.subtext)
                        .font(.system(size: 16))
                }
                .buttonStyle(AppScaleButtonStyle())
            }
            .padding(.bottom, 4)
            
            // Calendar view with proper centering
            ConsistencyCalendarView(dateIntensityMap: viewModel.dateIntensityMap)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, AppSpacing.s)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.theme.surface)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
    
    // 4. Consolidated Pro Preview
    private var consolidatedProPreviewSection: some View {
        ProLockedView {
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                Text("Advanced Analytics")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.theme.text)
                
                // Enhanced pro analytics preview
                VStack(spacing: AppSpacing.m) {
                    // Projected completion with clear visual styling
                    HStack(spacing: AppSpacing.l) {
                        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                            Text("Projected Completion")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.theme.subtext)
                            
                            if let projectedDate = viewModel.projectedCompletionDate {
                                Text(projectedDate, style: .date)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.theme.text)
                            } else {
                                Text("Set a goal to see projection")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.theme.text)
                            }
                        }
                        
                        Spacer()
                        
                        // Current pace indicator
                        VStack(alignment: .trailing, spacing: AppSpacing.xxs) {
                            Text("Current Pace")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.theme.subtext)
                            
                            Text(viewModel.currentPace)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.theme.text)
                        }
                    }
                    .padding(.horizontal, AppSpacing.s)
                    
                    // Preview graph with enhanced visual style
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        Text("Activity Trend")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.theme.subtext)
                            .padding(.horizontal, AppSpacing.s)
                        
                        // Simulated chart with enhanced visual fidelity
                        ZStack {
                            // Background grid
                            VStack(spacing: 0) {
                                ForEach(0..<4) { _ in
                                    Divider()
                                        .background(Color.theme.subtext.opacity(0.2))
                                    Spacer()
                                }
                            }
                            
                            // Chart bars
                            HStack(alignment: .bottom, spacing: 8) {
                                ForEach(0..<7) { index in
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    Color.theme.accent,
                                                    Color.theme.accent.opacity(0.7)
                                                ]),
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                        .frame(height: CGFloat([30, 60, 45, 70, 50, 80, 65][index % 7]))
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, AppSpacing.s)
                            .padding(.bottom, AppSpacing.s)
                            .padding(.top, AppSpacing.l)
                        }
                        .frame(height: 120)
                    }
                }
                .padding(AppSpacing.m)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.theme.surface)
                        .shadow(color: Color.theme.shadow.opacity(0.1), radius: 4, x: 0, y: 2)
                )
            }
            .padding()
        }
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
                        .font(.system(size: 36, weight: .semibold))
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
                    .font(.system(size: 14, weight: .medium))
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
                            .font(.system(size: 24))
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
                        .font(.system(size: 80, weight: .semibold))
                        .foregroundColor(Color.theme.accent)
                }
                .padding(.bottom, AppSpacing.l)
                
                // Badge info
                Text(badge.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(Color.theme.text)
                    .multilineTextAlignment(.center)
                
                Text("You've earned this badge by demonstrating consistency and dedication to your goals.")
                    .font(.system(size: 16))
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

    // Add a notification listener for sign-out preparation
    private func setupSignOutListener() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("PreparingForSignOut"),
            object: nil,
            queue: .main
        ) { _ in
            print("ProgressView - Received sign-out notification, cleaning up")
            self.cancelCurrentTask()
        }
    }

    // Remove the observer when the view disappears
    private func removeSignOutListener() {
        NotificationCenter.default.removeObserver(
            self,
            name: NSNotification.Name("PreparingForSignOut"),
            object: nil
        )
    }
    
    // Loading view with progress indicator
    private var loadingView: some View {
        VStack(spacing: 20) {
            // Use ActivityIndicator instead of ProgressView to avoid ambiguity
            ActivityIndicator()
                .scaleEffect(1.5)
            
            Text("Loading your progress...")
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
                .font(.system(size: 50))
                .foregroundColor(.yellow)
            
            Text(message)
                .font(.headline)
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
                .font(.caption)
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
                .font(.system(size: 50))
                .foregroundColor(Color.theme.accent.opacity(0.7))
            
            Text("No progress data yet")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(Color.theme.text)
            
            Text("Complete challenges to see your progress.")
                .font(.subheadline)
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
            .foregroundColor(.white)
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
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Progress Summary Card
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Progress Analytics")
                            .font(.title2)
                            .fontWeight(.bold)
                        
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
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        // Placeholder for heatmap
                        HStack {
                            Spacer()
                            Text("Activity visualization available in a future update")
                                .font(.subheadline)
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
                            .fontWeight(.medium)
                    }
                    .padding(.trailing)
                    .padding(.top, 8)
                }
                .frame(height: 44)
                .background(Color.clear)
            }
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
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(Color.theme.accent)
            
            Text(title)
                .font(.caption)
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
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(Color.theme.text)
            }
        }
        .frame(width: size, height: size)
    }
}

// Helper components for loading screen

// NOTE: LoadingStepIndicator and FallbackButton moved to ProgressComponents.swift

 
