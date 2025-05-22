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
    @EnvironmentObject var viewModel: UPViewModel
    @EnvironmentObject var subscriptionService: SubscriptionService
    @EnvironmentObject var notificationService: NotificationService
    @EnvironmentObject var router: NavigationRouter
    @EnvironmentObject var userStatsService: UserStatsService
    
    @State private var showAnalytics = false
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
        guard shouldRefresh() && !isRefreshing else {
            print("ProgressView - Skipping refresh (too soon or already refreshing)")
            return
        }
        
        isRefreshing = true
        lastRefreshTime = Date()
        
        print("ProgressView - Refreshing data from all sources")
        await viewModel.loadData(forceRefresh: true)
        
        isRefreshing = false
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
                        
                        Spacer()
                        
                        // Analytics button
                        Button {
                            // Add haptic feedback for responsiveness
                            let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
                            feedbackGenerator.impactOccurred()
                            
                            showAnalytics = true
                        } label: {
                            Image(systemName: "chart.xyaxis.line")
                                .font(.system(size: AppSpacing.iconSizeMedium, weight: .semibold))
                                .foregroundColor(Color.theme.accent)
                        }
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
        }
        .fixedSheet(isPresented: $showAnalytics) {
            if #available(iOS 16.0, *) {
                ProgressAnalyticsView(viewModel: viewModel)
            } else {
                Text("Advanced analytics requires iOS 16 or later.")
                    .padding()
            }
        }
        .sheet(item: $selectedBadge) { badge in
            BadgeDetailView(badge: badge)
        }
        .modifier(NavigationDebounceModifier())
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
            Text("Milestones & Badges")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(Color.theme.text)
            
            if viewModel.earnedBadges.isEmpty {
                Text("Complete challenges to earn badges!")
                    .foregroundColor(Color.theme.subtext)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, AppSpacing.l)
            } else {
                // Horizontal scrolling badge cards
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.m) {
                        ForEach(viewModel.earnedBadges) { badge in
                            BadgeCard(badge: badge)
                                .frame(width: 120, height: 150)
                                .onTapGesture {
                                    // Placeholder for badge detail
                                    let generator = UIImpactFeedbackGenerator(style: .medium)
                                    generator.impactOccurred()
                                    selectedBadge = badge
                                }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, AppSpacing.s)
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
    
    // 4. Consolidated Pro Preview Section
    private var consolidatedProPreviewSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            if !subscriptionService.isProUser {
                ZStack {
                    // Blurred background
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.theme.accent.opacity(0.7),
                                    Color.theme.accent.opacity(0.3)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .blur(radius: 8)
                        .opacity(0.5)
                    
                    VStack(spacing: AppSpacing.m) {
                        // Lock icon and title
                        HStack {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 18))
                                .foregroundColor(Color.theme.accent)
                            
                            Text("Pro Feature")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(Color.theme.accent)
                            
                            Spacer()
                        }
                        
                        // Pro features description
                        Text("Unlock trends, pace, and detailed insights with Pro")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(Color.theme.text)
                            .multilineTextAlignment(.center)
                            .padding(.vertical, AppSpacing.s)
                        
                        // Buttons
                        VStack(spacing: AppSpacing.s) {
                            Button {
                                // Navigate to subscription page
                            } label: {
                                Text("Upgrade to Pro")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, AppSpacing.l)
                                    .padding(.vertical, AppSpacing.m)
                                    .background(Color.theme.accent)
                                    .cornerRadius(12)
                                    .shadow(color: Color.theme.accent.opacity(0.3), radius: 5, x: 0, y: 3)
                            }
                            
                            Button {
                                // Dismiss or hide the pro preview
                            } label: {
                                Text("Maybe later")
                                    .font(.subheadline)
                                    .foregroundColor(Color.theme.subtext)
                            }
                        }
                    }
                    .padding()
                }
            } else {
                // Pro user content - empty spacer or alternative content
                EmptyView()
            }
        }
        .padding(.vertical, subscriptionService.isProUser ? 0 : AppSpacing.m)
        .opacity(subscriptionService.isProUser ? 0 : 1)
        .frame(height: subscriptionService.isProUser ? 0 : nil)
    }
    
    // 5. Daily Spark Section
    private var dailySparkSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            // Use explicit parameter names to avoid ambiguity
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
        if let task = loadTask {
            task.cancel()
            loadTask = nil
            print("ProgressView - Cancelled existing task")
        }
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
}

// MARK: - Preview
// Removed preview code that was using mock data for submission to Apple

// Helper views for the analytics screen
struct ProgressAnalyticsView: View {
    let viewModel: UPViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(viewModel: UPViewModel) {
        self.viewModel = viewModel
    }
    
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

 
