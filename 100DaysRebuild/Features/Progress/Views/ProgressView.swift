import SwiftUI
import Charts
import FirebaseFirestore
import FirebaseAuth
import Foundation

// Always be explicit about UserProgressViewModel type to avoid ambiguity
// Updated to reference ProgressDashboardViewModel to avoid conflicts
typealias UPViewModel = ProgressDashboardViewModel

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
    @EnvironmentObject var router: TabViewRouter
    @EnvironmentObject var userStatsService: UserStatsService
    
    @State private var showAnalytics = false
    @State private var loadTask: Task<Void, Never>? = nil
    @State private var hasLoadedOnce = false
    
    var body: some View {
        NavigationView {
            ProgressContentView(viewModel: viewModel, showAnalytics: $showAnalytics)
                .background(Color.theme.background.ignoresSafeArea())
                .navigationTitle("Progress")
        }
        .onAppear {
            // Cancel any existing task first to prevent multiple concurrent tasks
            loadTask?.cancel()
            loadTask = nil
            
            // Mark tab as changing when this view appears
            if router.selectedTab == 1 {
                router.tabIsChanging = true
                
                // Only load once unless forced refresh
                if !hasLoadedOnce {
                    // Load progress data when the view appears, but only if this tab is selected
                    loadTask = Task {
                        do {
                            // Add a small delay to prevent rapid reloading during tab switching
                            try await Task.sleep(nanoseconds: 300_000_000) // 0.3 second delay
                            
                            if !Task.isCancelled {
                                await viewModel.loadData(forceRefresh: false)
                                
                                if !Task.isCancelled {
                                    hasLoadedOnce = true
                                    
                                    // After data is loaded, mark tab as not changing
                                    if router.selectedTab == 1 {
                                        router.tabIsChanging = false
                                    }
                                }
                            }
                        } catch is CancellationError {
                            // Safely handle task cancellation - just ignore it
                            print("Progress loading task was cancelled")
                        } catch {
                            print("Error loading progress: \(error.localizedDescription)")
                            // Don't reset hasLoadedOnce on error to prevent repeated attempts
                        }
                    }
                } else {
                    // If already loaded once, just mark tab as not changing
                    router.tabIsChanging = false
                }
            }
        }
        .onDisappear {
            // When view disappears, cancel any loading tasks
            // Use async cancellation to avoid immediate termination
            Task {
                loadTask?.cancel()
                loadTask = nil
            }
            
            // If this tab is still selected but view is disappearing, 
            // make sure we cancel any ongoing view model tasks too
            if router.selectedTab == 1 {
                viewModel.cancelTasks()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ShowProgressAnalytics"))) { _ in
            showAnalytics = true
        }
        .sheet(isPresented: $showAnalytics) {
            ProgressAnalyticsView()
                .environmentObject(viewModel)
        }
    }
}

// MARK: - Content View
struct ProgressContentView: View {
    @ObservedObject var viewModel: UPViewModel
    @EnvironmentObject var subscriptionService: SubscriptionService
    @EnvironmentObject var notificationService: NotificationService
    @Binding var showAnalytics: Bool
    
    var body: some View {
        ZStack {
            // Background
            Color.theme.background.ignoresSafeArea()
            
            // Full screen loading view when initially loading
            if viewModel.isInitialLoad {
                fullScreenLoadingView
                    .transition(.opacity)
            } 
            // Main content
            else {
                ScrollView {
                    VStack(spacing: 24) {
                        if viewModel.hasData {
                            VStack(spacing: 24) {
                                // Stats Section
                                statsSection
                                
                                // Journey Carousel (Your Journey So Far)
                                JourneyCarouselView(viewModel: viewModel)

                                // Daily Spark
                                dailySparkSection
                                
                                // Projected Completion (Your Pace) - Pro Feature
                                projectedCompletionSection
                                
                                // Consistency Graph - Pro Feature
                                consistencyGraphSection
                                
                                // Activity Heatmap (Pro Feature)
                                heatmapSection
                                
                                // Badges Section
                                badgesSection
                                
                                // Add padding at the bottom for better scrolling
                                Spacer().frame(height: 20)
                            }
                            .transition(.opacity)
                        } else if let error = viewModel.errorMessage {
                            errorState(message: error)
                                .transition(.opacity)
                        } else {
                            emptyState
                                .transition(.opacity)
                        }
                    }
                    .padding(.vertical)
                }
                .refreshable {
                    await viewModel.loadData(forceRefresh: true)
                }
                .transition(.opacity)
            }
            
            // Overlay loading indicator when refreshing with existing data
            if viewModel.isLoading && viewModel.hasData && !viewModel.isInitialLoad {
                VStack {
                    SwiftUI.ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)
                        .padding()
                }
                .frame(width: 100, height: 100)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.theme.surface.opacity(0.8))
                        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.isInitialLoad) 
        .animation(.easeInOut(duration: 0.3), value: viewModel.isLoading)
        .animation(.easeInOut(duration: 0.3), value: viewModel.hasData)
        .animation(.easeInOut(duration: 0.3), value: viewModel.errorMessage != nil)
    }
    
    private var fullScreenLoadingView: some View {
        VStack {
            SwiftUI.ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.5)
                .padding()
            
            Text("Loading your progress...")
                .foregroundColor(.theme.subtext)
                .padding(.top, 8)
            
            // Add a tip about what's happening
            Text("This may take a moment as we gather your data.")
                .font(.caption)
                .foregroundColor(.theme.subtext)
                .padding(.top, 4)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
    
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your Progress")
                .font(.title2)
                .foregroundColor(.theme.text)
            
            HStack(spacing: 20) {
                AppProgressStatCard(title: "Current Streak", value: "\(viewModel.currentStreak)")
                AppProgressStatCard(title: "Longest Streak", value: "\(viewModel.longestStreak)")
            }
            
            HStack(spacing: 20) {
                AppProgressStatCard(title: "Completion", value: "\(Int(viewModel.completionPercentage * 100))%")
                AppProgressStatCard(title: "Challenges", value: "\(viewModel.totalChallenges)")
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
    
    private var heatmapSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Activity")
                .font(.title3)
                .foregroundColor(.theme.text)
            
            if subscriptionService.isProUser {
                if viewModel.dateIntensityMap.isEmpty {
                    Text("No activity data available yet")
                        .foregroundColor(.theme.subtext)
                        .frame(height: 140, alignment: .center)
                        .frame(maxWidth: .infinity)
                } else {
                    // Show the heatmap directly for Pro users
                    ActivityHeatmapView(dateIntensityMap: viewModel.dateIntensityMap)
                        .frame(height: 140)
                }
            } else {
                // Show locked view for free users
                ProLockedView {
                    ActivityHeatmapView(dateIntensityMap: viewModel.dateIntensityMap)
                        .frame(height: 140)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.theme.surface)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal)
    }
    
    private var badgesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Badges")
                .font(.title3)
                .foregroundColor(.theme.text)
            
            if viewModel.earnedBadges.isEmpty {
                Text("You haven't earned any badges yet")
                    .foregroundColor(.theme.subtext)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 16) {
                    ForEach(viewModel.earnedBadges) { badge in
                        ProgressBadgeCard(badge: badge)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.theme.surface)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal)
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 60))
                .foregroundColor(.theme.accent)
            
            Text("No Progress Data Yet")
                .font(.title2)
                .foregroundColor(.theme.text)
            
            Text("Start a challenge and check in daily to see your progress here")
                .font(.body)
                .foregroundColor(.theme.subtext)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Add a button to navigate to challenges
            NavigationLink(destination: ChallengesView()) {
                Text("Start a Challenge")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.theme.accent)
                    )
            }
            .padding(.top, 8)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
    
    private func errorState(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Couldn't Load Progress")
                .font(.title2)
                .foregroundColor(.theme.text)
            
            Text(message)
                .font(.body)
                .foregroundColor(.theme.subtext)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button {
                Task {
                    await viewModel.loadData(forceRefresh: true)
                }
            } label: {
                Text("Try Again")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.theme.accent)
                    )
            }
            .padding(.top, 8)
            
            // If not connected, show offline indicator
            if !viewModel.isNetworkConnected {
                HStack {
                    Image(systemName: "wifi.slash")
                    Text("You're offline")
                }
                .font(.caption)
                .foregroundColor(.red)
                .padding(.top, 8)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
    
    // Daily Spark Section
    private var dailySparkSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Daily Spark")
                .font(.title3)
                .foregroundColor(.theme.text)
            
            DailySparkView(currentStreak: viewModel.currentStreak, completionPercentage: viewModel.completionPercentage)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.theme.surface)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal)
    }
    
    // Projected Completion Section
    private var projectedCompletionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Pace")
                .font(.title3)
                .foregroundColor(.theme.text)
            
            if subscriptionService.isProUser {
                if let projectedDate = viewModel.projectedCompletionDate {
                    ProjectedCompletionView(
                        projectedDate: projectedDate,
                        currentPace: viewModel.currentPace,
                        completionPercentage: viewModel.completionPercentage
                    )
                } else {
                    Text("Not enough data to predict completion date yet")
                        .foregroundColor(.theme.subtext)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                }
            } else {
                // Show locked view for free users
                ProLockedView {
                    ProjectedCompletionView(
                        projectedDate: Date().addingTimeInterval(60*60*24*30), // Example date - 30 days from now
                        currentPace: "4.5 days/week",
                        completionPercentage: 0.35
                    )
                }
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
    
    // Consistency Graph Section
    private var consistencyGraphSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Consistency Graph")
                .font(.title3)
                .foregroundColor(.theme.text)
            
            if subscriptionService.isProUser {
                if viewModel.dailyCheckInsData.isEmpty {
                    Text("Not enough data to show consistency graph yet")
                        .foregroundColor(.theme.subtext)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                } else {
                    ConsistencyGraphView(dailyCheckIns: viewModel.dailyCheckInsData)
                        .frame(height: 200)
                }
            } else {
                // Show locked view for free users
                ProLockedView {
                    ConsistencyGraphView(dailyCheckIns: generateSampleCheckInData())
                        .frame(height: 200)
                }
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
    
    // Helper function to generate sample data for locked preview
    private func generateSampleCheckInData() -> [ProgressDailyCheckIn] {
        let calendar = Calendar.current
        var sampleData: [ProgressDailyCheckIn] = []
        
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: -i, to: Date()) {
                let count = Int.random(in: 0...3)
                sampleData.append(ProgressDailyCheckIn(date: date, count: count))
            }
        }
        
        return sampleData
    }
}

struct AppProgressStatCard: View {
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

struct ProgressBadgeCard: View {
    let badge: ProgressBadge
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: badge.iconName)
                .font(.system(size: 30))
                .foregroundColor(.theme.accent)
            
            Text(badge.title)
                .font(.caption)
                .foregroundColor(.theme.text)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.theme.surface)
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
}

@MainActor
class UserProgressViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var hasData = false
    @Published var errorMessage: String?
    
    // Free tier metrics
    @Published var totalChallenges = 0
    @Published var currentStreak = 0
    @Published var longestStreak = 0
    @Published var completionPercentage: Double = 0.0
    @Published var lastCheckInDate: Date? = nil
    
    // Pro tier data
    @Published var activityData: [Date] = []
    @Published var challengeProgressData: [ProgressChallengeItem] = []
    @Published var dailyCheckInsData: [ProgressDailyCheckIn] = []
    @Published var projectedCompletionDate: Date? = nil
    @Published var currentPace = "0 days/week"
    @Published var earnedBadges: [ProgressBadge] = []
    @Published var dateIntensityMap: [Date: Int] = [:]
    
    // Firestore reference
    private let firestore = Firestore.firestore()
    private var loadTask: Task<Void, Never>?
    private let timeoutDuration: TimeInterval = 10.0 // 10 second timeout
    
    deinit {
        loadTask?.cancel()
    }
    
    func loadData(forceRefresh: Bool = false) async {
        // Don't load data if already loading unless forced
        if isLoading && !forceRefresh {
            return
        }
        
        // Cancel any existing task
        loadTask?.cancel()
        
        // Start new loading task
        loadTask = Task { [weak self] in
            guard let self = self else { return }
            
            // Set up timeout
            let timeoutTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(self.timeoutDuration * 1_000_000_000))
                if self.isLoading {
                    await MainActor.run {
                        self.errorMessage = "Loading timed out. Please try again."
                        self.isLoading = false
                    }
                }
            }
            
            await MainActor.run {
                self.isLoading = true
                self.errorMessage = nil
            }
            
            // Verify the user is logged in
            guard let userId = Auth.auth().currentUser?.uid else {
                await MainActor.run {
                    self.errorMessage = "You must be logged in to view progress"
                    self.isLoading = false
                    self.hasData = false
                }
                timeoutTask.cancel()
                return
            }
            
            do {
                // Fetch challenges from Firestore
                let challengesQuery = firestore
                    .collection("users")
                    .document(userId)
                    .collection("challenges")
                
                let challengesSnapshot = try await challengesQuery.getDocuments()
                
                if Task.isCancelled { 
                    timeoutTask.cancel()
                    return 
                }
                
                // Convert to Challenge objects
                var challenges: [Challenge] = []
                
                for document in challengesSnapshot.documents {
                    if Task.isCancelled {
                        timeoutTask.cancel()
                        return
                    }
                    
                    if let challengeId = UUID(uuidString: document.documentID),
                       let title = document.data()["title"] as? String,
                       let ownerId = document.data()["ownerId"] as? String,
                       let startDateTimestamp = document.data()["startDate"] as? Timestamp,
                       let streakCount = document.data()["streakCount"] as? Int,
                       let daysCompleted = document.data()["daysCompleted"] as? Int,
                       let isArchived = document.data()["isArchived"] as? Bool {
                        
                        let startDate = startDateTimestamp.dateValue()
                        let lastCheckInDate = (document.data()["lastCheckInDate"] as? Timestamp)?.dateValue()
                        let lastModified = (document.data()["lastModified"] as? Timestamp)?.dateValue() ?? Date()
                        
                        // Determine if completed today by checking if lastCheckInDate is today
                        let isCompletedToday: Bool
                        if let lastCheckIn = lastCheckInDate {
                            isCompletedToday = Calendar.current.isDateInToday(lastCheckIn)
                        } else {
                            isCompletedToday = false
                        }
                        
                        let challenge = Challenge(
                            id: challengeId,
                            title: title,
                            startDate: startDate,
                            lastCheckInDate: lastCheckInDate,
                            streakCount: streakCount,
                            daysCompleted: daysCompleted,
                            isCompletedToday: isCompletedToday,
                            isArchived: isArchived,
                            ownerId: ownerId,
                            lastModified: lastModified
                        )
                        
                        challenges.append(challenge)
                    } else {
                        print("Error parsing challenge document: incomplete data")
                        continue
                    }
                }
                
                if Task.isCancelled { 
                    timeoutTask.cancel()
                    return 
                }
                
                // Calculate metrics
                let totalChallengesCount = challenges.count
                let currentStreakCount = calculateCurrentStreak(challenges)
                let longestStreakCount = calculateLongestStreak(challenges)
                let overallCompletionRate = calculateCompletionRate(challenges)
                
                // Generate data for heatmap from check-ins
                var intensityMap: [Date: Int] = [:]
                
                // Get check-ins for each challenge to build intensity map
                for challenge in challenges {
                    if Task.isCancelled {
                        timeoutTask.cancel()
                        return
                    }
                    
                    do {
                        // Validate the challenge data using throws
                        try validateChallengeData(challenge)
                        
                        // This is a throwing operation
                        let checkInsRef = firestore
                            .collection("users")
                            .document(userId)
                            .collection("challenges")
                            .document(challenge.id.uuidString)
                            .collection("checkIns")
                        
                        // Get check-ins from the last 6 months
                        let sixMonthsAgo = Calendar.current.date(
                            byAdding: .month,
                            value: -6,
                            to: Date()
                        )!
                        
                        let checkInsQuery = checkInsRef
                            .whereField("date", isGreaterThan: Timestamp(date: sixMonthsAgo))
                        
                        let checkInsSnapshot = try await checkInsQuery.getDocuments()
                        
                        if Task.isCancelled { 
                            timeoutTask.cancel()
                            return 
                        }
                        
                        // Process check-ins to build intensity map
                        for document in checkInsSnapshot.documents {
                            if let dateTimestamp = document.data()["date"] as? Timestamp {
                                let date = dateTimestamp.dateValue()
                                // Normalize date to beginning of day
                                let normalizedDate = Calendar.current.startOfDay(for: date)
                                // Increment intensity for this date
                                let currentIntensity = intensityMap[normalizedDate] ?? 0
                                intensityMap[normalizedDate] = currentIntensity + 1
                            }
                        }
                    } catch {
                        print("Error loading check-ins for challenge \(challenge.id): \(error.localizedDescription)")
                        continue
                    }
                }
                
                if Task.isCancelled { 
                    timeoutTask.cancel()
                    return 
                }
                
                // Calculate badges based on progress
                let earnedBadges = calculateEarnedBadges(challenges)
                
                // Update UI on main thread
                await MainActor.run {
                    self.totalChallenges = totalChallengesCount
                    self.currentStreak = currentStreakCount
                    self.longestStreak = longestStreakCount
                    self.completionPercentage = overallCompletionRate
                    self.dateIntensityMap = intensityMap
                    self.earnedBadges = earnedBadges
                    
                    self.hasData = totalChallengesCount > 0
                    self.isLoading = false
                    timeoutTask.cancel()
                }
            } catch {
                if !Task.isCancelled {
                    await MainActor.run {
                        self.errorMessage = "Failed to load progress data: \(error.localizedDescription)"
                        self.isLoading = false
                        // Set hasData to true if we had data before
                        // so we don't show empty state due to temporary error
                        self.hasData = self.totalChallenges > 0
                        timeoutTask.cancel()
                    }
                }
            }
        }
    }
    
    private func calculateCurrentStreak(_ challenges: [Challenge]) -> Int {
        // Get the maximum current streak across all active challenges
        let activeChallenges = challenges.filter { !$0.isArchived && !$0.isCompleted }
        if activeChallenges.isEmpty {
            return 0
        }
        
        // Find challenges with active streaks (checked in yesterday or today)
        let challengesWithActiveStreaks = activeChallenges.filter { challenge in
            guard let lastCheckIn = challenge.lastCheckInDate else { return false }
            let daysSinceLastCheckIn = Calendar.current.dateComponents([.day], from: lastCheckIn, to: Date()).day ?? 0
            return daysSinceLastCheckIn <= 1 // Streak is active if checked in today or yesterday
        }
        
        // Return the maximum streak count from active challenges
        return challengesWithActiveStreaks.map { $0.streakCount }.max() ?? 0
    }
    
    private func calculateLongestStreak(_ challenges: [Challenge]) -> Int {
        // Get the maximum streak from all challenges, including completed ones
        let allStreaks = challenges.map { $0.streakCount }
        return allStreaks.max() ?? 0
    }
    
    private func calculateCompletionRate(_ challenges: [Challenge]) -> Double {
        guard !challenges.isEmpty else { return 0.0 }
        
        let totalCompletedDays = challenges.reduce(0) { $0 + $1.daysCompleted }
        let totalPossibleDays = challenges.count * 100 // Each challenge has 100 days
        
        return min(1.0, Double(totalCompletedDays) / Double(totalPossibleDays))
    }
    
    private func calculateEarnedBadges(_ challenges: [Challenge]) -> [ProgressBadge] {
        var badges: [ProgressBadge] = []
        
        // Streak badges
        if longestStreak >= 7 {
            badges.append(ProgressBadge(id: 1, title: "7-Day Streak", iconName: "flame.fill"))
        }
        if longestStreak >= 30 {
            badges.append(ProgressBadge(id: 2, title: "30-Day Streak", iconName: "flame.fill"))
        }
        
        // Completion badges
        let completedChallengesCount = challenges.filter { $0.isCompleted }.count
        if completedChallengesCount > 0 {
            badges.append(ProgressBadge(id: 3, title: "First Completion", iconName: "checkmark.circle.fill"))
        }
        if completedChallengesCount >= 3 {
            badges.append(ProgressBadge(id: 4, title: "Triple Completion", iconName: "checkmark.circle.fill"))
        }
        
        // Progress badges
        if completionPercentage >= 0.25 {
            badges.append(ProgressBadge(id: 5, title: "25% Complete", iconName: "chart.bar.fill"))
        }
        if completionPercentage >= 0.50 {
            badges.append(ProgressBadge(id: 6, title: "50% Complete", iconName: "chart.bar.fill"))
        }
        if completionPercentage >= 0.75 {
            badges.append(ProgressBadge(id: 7, title: "75% Complete", iconName: "chart.bar.fill"))
        }
        
        // Consistency badge - only if at least one challenge and no expired streaks
        let hasExpiredStreak = challenges.contains { $0.hasStreakExpired }
        if !challenges.isEmpty && !hasExpiredStreak {
            badges.append(ProgressBadge(id: 8, title: "Perfect Consistency", iconName: "star.fill"))
        }
        
        return badges
    }
    
    /// Validates the challenge data to ensure it's properly formatted
    /// - Parameter challenge: The challenge to validate
    /// - Throws: Error if the challenge data is invalid
    private func validateChallengeData(_ challenge: Challenge) throws {
        // Validate the challenge ID
        guard challenge.id != UUID.init(uuid: UUID_NULL) else {
            throw NSError(domain: "ProgressViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid challenge ID"])
        }
        
        // Validate the title
        guard !challenge.title.isEmpty else {
            throw NSError(domain: "ProgressViewModel", code: 2, userInfo: [NSLocalizedDescriptionKey: "Challenge title is empty"])
        }
        
        // Validate date constraints
        let startDate = challenge.startDate
        let endDate = challenge.endDate
        
        // End date should be after start date
        guard endDate > startDate else {
            throw NSError(domain: "ProgressViewModel", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid date range for challenge"])
        }
            
        // Duration should be reasonable (between 1 and 365 days)
        let daysBetween = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        guard daysBetween >= 1 && daysBetween <= 365 else {
            throw NSError(domain: "ProgressViewModel", code: 4, userInfo: [NSLocalizedDescriptionKey: "Challenge duration is invalid"])
        }
        
        // Validate completion status consistency
        if challenge.isCompleted {
            guard challenge.daysCompleted == 100 else {
                throw NSError(domain: "ProgressViewModel", code: 5, userInfo: [NSLocalizedDescriptionKey: "Completion status inconsistency"])
            }
        }
    }
    
    func cancelTasks() {
        loadTask?.cancel()
    }
}

// MARK: - Preview
struct ProgressView_Previews: PreviewProvider {
    static var previews: some View {
        ProgressView()
            .environmentObject(SubscriptionService.shared)
            .environmentObject(NotificationService.shared)
    }
}

// Add this at the bottom of the file
struct ProgressAnalyticsView: View {
    @EnvironmentObject var viewModel: UPViewModel
    @Environment(\.dismiss) private var dismiss
    
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
                            StatCard(title: "Challenges", value: "\(viewModel.totalChallenges)")
                            StatCard(title: "Current Streak", value: "\(viewModel.currentStreak)")
                            StatCard(title: "Completion", value: "\(Int(viewModel.completionPercentage * 100))%")
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
                                .foregroundColor(.theme.subtext)
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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// Helper views for the analytics screen
struct StatCard: View {
    var title: String
    var value: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.theme.accent)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.theme.subtext)
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
                .foregroundColor(.theme.accent.opacity(0.3))
            
            Circle()
                .trim(from: 0.0, to: CGFloat(min(progress, 1.0)))
                .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                .foregroundColor(.theme.accent)
                .rotationEffect(Angle(degrees: 270.0))
                .animation(.linear, value: progress)
            
            VStack {
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.theme.text)
            }
        }
        .frame(width: size, height: size)
    }
}