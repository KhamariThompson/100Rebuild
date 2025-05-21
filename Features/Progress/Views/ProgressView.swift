import SwiftUI
import Firebase
import FirebaseFirestoreSwift

// MARK: - CheckIn Model for Progress View
struct CheckIn: Identifiable, Codable {
    let id: String
    let date: Date
    let dayNumber: Int
    var note: String?
    var photoURL: URL?
    var timerDuration: Int?
    
    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct ProgressView: View {
    @StateObject private var viewModel = UserProgressViewModel()
    @EnvironmentObject private var userStatsService: UserStatsService
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @EnvironmentObject private var router: AppRouter
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var selectedDate: Date? = nil
    @State private var showJournalView = false
    @State private var showAnalytics = false
    @State private var selectedBadge: ProgressBadge? = nil
    @State private var scrollOffset: CGFloat = 0
    @State private var hasLoadedOnce = false
    @State private var loadTask: Task<Void, Never>?
    
    // Gradient for progress header styling
    private let progressGradient = LinearGradient(
        colors: [Color.theme.accent, Color.theme.accent.opacity(0.8)],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    private func cancelCurrentTask() {
        loadTask?.cancel()
        loadTask = nil
    }
    
    private func refreshData() async {
        await viewModel.loadData()
        await viewModel.loadCheckIns()
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // Background
            Color.theme.background
                .ignoresSafeArea()
            
            // Main scrollable content
            ScrollView {
                VStack(spacing: AppSpacing.l) {
                    // Spacer to push content below the header
                    Color.clear
                        .frame(height: 60)
                    
                    // Content based on state
                    if viewModel.isLoading {
                        loadingView
                            .transition(.opacity)
                    } else if let errorMessage = viewModel.errorMessage {
                        errorView(message: errorMessage)
                            .transition(.opacity)
                    } else if viewModel.hasData {
                        redesignedProgressContent
                            .transition(.opacity)
                    } else {
                        emptyStateView
                            .transition(.opacity)
                    }
                }
                .trackScrollOffset($scrollOffset)
            }
            .animation(.easeInOut(duration: 0.3), value: viewModel.isLoading)
            .animation(.easeInOut(duration: 0.3), value: viewModel.errorMessage)
            .animation(.easeInOut(duration: 0.3), value: viewModel.hasData)
            
            // Use our new AppHeader component
            AppHeader(
                title: "Progress",
                accentGradient: progressGradient,
                trailingIcon: (
                    symbol: "chart.xyaxis.line",
                    action: {
                        // Add haptic feedback for responsiveness
                        let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
                        feedbackGenerator.impactOccurred()
                        
                        showAnalytics = true
                    }
                )
            )
            .stickyHeader()
        }
        .navigationTitle("Progress") // Only set the title, don't create navigation bar
        .navigationBarTitleDisplayMode(.inline) // Use inline to minimize height issues
        .refreshable {
            await refreshData()
        }
        .onAppear {
            print("ProgressView - onAppear")
            // Cancel any existing task first to prevent multiple concurrent tasks
            cancelCurrentTask()
            
            // First, check if userStatsService already has data we can use immediately
            if userStatsService.userStats.totalChallenges > 0 && !hasLoadedOnce {
                print("ProgressView - Using existing userStatsService data")
                
                // UserStatsService already has data, so mark viewModel as having data too
                if !viewModel.hasData {
                    viewModel.hasData = true
                }
                
                // Mark tab as not changing since we have data immediately
                router.tabIsChanging = false
                hasLoadedOnce = true
            }
            
            // Then start a new task to load fresh data
            loadTask = Task {
                // Check if we need to refresh data
                if !userStatsService.isLoading && (!hasLoadedOnce || NetworkMonitor.shared.isConnected) {
                    print("ProgressView - Loading fresh data from userStatsService")
                    
                    // First refresh central data source
                    await userStatsService.refreshUserStats()
                    
                    // Then load view-specific data
                    await viewModel.loadData()
                    
                    // Mark as loaded once
                    if !Task.isCancelled {
                        hasLoadedOnce = true
                        router.tabIsChanging = false
                    }
                } else {
                    print("ProgressView - Using cached data, no refresh needed")
                    router.tabIsChanging = false
                    hasLoadedOnce = true
                }
            }
        }
        .onDisappear {
            print("ProgressView - onDisappear")
            cancelCurrentTask()
        }
        .fixedSheet(isPresented: $showAnalytics) {
            if #available(iOS 16.0, *) {
                ProgressAnalyticsView()
            } else {
                Text("Advanced analytics requires iOS 16 or later.")
                    .padding()
            }
        }
        .sheet(item: $selectedBadge) { badge in
            BadgeDetailView(badge: badge)
        }
        .fixNavigationLayout()
    }
    
    // New redesigned progress content based on requirements
    private var redesignedProgressContent: some View {
        VStack(spacing: AppSpacing.m) {
            // 1. Hero Summary Card - use our new component
            HeroSummaryCard(
                headline: getHeadlineText(),
                progress: viewModel.completionPercentage,
                streakCount: viewModel.currentStreak,
                completionPercentage: viewModel.completionPercentage,
                challengeCount: viewModel.totalChallenges
            )
            
            // 2. Badges Horizontal Scroll View - use our new component
            BadgesHorizontalScrollView(
                badges: viewModel.earnedBadges,
                showLockedBadges: true,
                onBadgeTapped: { badge in
                    selectedBadge = badge
                }
            )
            
            // 3. Consistency Heatmap - use our new component
            ConsistencyHeatmapView(
                dateIntensityMap: viewModel.dateIntensityMap,
                weeksToShow: 12
            )
            
            // 4. Consolidated Pro Preview - only show for non-Pro users
            if !subscriptionService.isProUser {
                ProFeatureCard(
                    title: "Unlock Detailed Analytics",
                    description: "Track your trends, predict completion, and get personalized insights",
                    onUpgrade: {
                        // Navigate to subscription view
                        router.navigateTo(.subscription)
                    },
                    onDismiss: {
                        // Dismiss the pro preview
                        // This would typically set a preference to hide this temporarily
                    }
                ) {
                    // Preview content showing what they're missing
                    VStack(spacing: AppSpacing.s) {
                        HStack(spacing: AppSpacing.m) {
                            ForEach(0..<3) { _ in
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.theme.accent.opacity(0.7))
                                    .frame(height: 30)
                            }
                        }
                        
                        HStack(spacing: AppSpacing.s) {
                            ForEach(0..<2) { _ in
                                VStack {
                                    Circle()
                                        .fill(Color.theme.accent.opacity(0.5))
                                        .frame(width: 40, height: 40)
                                    Text("Stat")
                                        .font(.caption)
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            
            // 5. Daily Spark Section
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                Text("Daily Spark")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.theme.text)
                
                Text(getDailyQuote())
                    .font(.body)
                    .foregroundColor(.theme.subtext)
                    .italic()
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                            .fill(Color.theme.surface)
                    )
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                    .fill(Color.theme.surface)
                    .shadow(color: Color.theme.shadow.opacity(0.1), radius: 8, x: 0, y: 4)
            )
            
            Spacer(minLength: AppSpacing.xl)
        }
        .padding(.horizontal)
    }
    
    // Helper to get an appropriate headline based on user stats
    private func getHeadlineText() -> String {
        if viewModel.currentStreak == 0 {
            return "Ready to start your first streak!"
        } else if viewModel.currentStreak == 1 {
            return "You've checked in 1 day so far!"
        } else if viewModel.currentStreak < 5 {
            return "You've checked in \(viewModel.currentStreak) days in a row!"
        } else if viewModel.currentStreak >= 5 && viewModel.currentStreak < 10 {
            return "Great streak of \(viewModel.currentStreak) days!"
        } else {
            return "Impressive \(viewModel.currentStreak)-day streak!"
        }
    }
    
    // Helper to get a daily quote (would normally rotate based on date)
    private func getDailyQuote() -> String {
        let quotes = [
            "Consistency is the key to achieving and maintaining momentum.",
            "Small daily improvements lead to significant results over time.",
            "The secret to getting ahead is getting started.",
            "Success is the sum of small efforts repeated day in and day out.",
            "Your only limit is the one you set yourself."
        ]
        
        // Get a consistent quote for each day based on the date
        let today = Calendar.current.startOfDay(for: Date())
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: today) ?? 0
        return quotes[dayOfYear % quotes.count]
    }
    
    // Loading view with progress indicator
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading your progress...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .padding(.top, 80)
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
        .padding(.top, 80)
    }
    
    // Empty state when no data is available
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.bar")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text("No progress data yet")
                .font(.headline)
            
            Text("Complete challenges to see your progress.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.top, 80)
    }
}

// Preview
struct ProgressView_Previews: PreviewProvider {
    static var previews: some View {
        ProgressView()
            .environmentObject(UserStatsService())
            .environmentObject(SubscriptionService())
            .environmentObject(AppRouter())
    }
}

// MARK: - View Model

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
    
    // Weekly calendar data
    @Published var calendarDays: [Date] = []
    @Published var checkInsByDate: [Date: CheckIn] = [:]
    
    // Firestore reference
    private let firestore = Firestore.firestore()
    private var loadDataTask: Task<Void, Never>?
    private var retryCount = 0
    private let maxRetries = 3
    
    // Cancel any running tasks when the view model is deinitialized
    deinit {
        loadDataTask?.cancel()
    }
    
    // Initialize the calendar data
    func initializeCalendarData() {
        // Generate dates for the last 14 days and next 14 days
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        let pastDates = (1...14).compactMap { days in
            calendar.date(byAdding: .day, value: -days, to: today)
        }.reversed()
        
        let futureDates = (0...14).compactMap { days in
            calendar.date(byAdding: .day, value: days, to: today)
        }
        
        calendarDays = Array(pastDates) + Array(futureDates)
    }
    
    // Load check-ins data from Firestore
    func loadCheckIns() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("DEBUG: Progress - no user ID, aborting check-ins load")
            return
        }
        
        // Initialize calendar days if empty
        if calendarDays.isEmpty {
            initializeCalendarData()
        }
        
        do {
            // Clear existing check-ins data
            checkInsByDate = [:]
            
            // Query all user's check-ins across all challenges
            let challengesRef = firestore
                .collection("users")
                .document(userId)
                .collection("challenges")
                .whereField("isArchived", isEqualTo: false)
            
            let challengesSnapshot = try await challengesRef.getDocuments()
            
            // For each challenge, get its check-ins
            for challengeDoc in challengesSnapshot.documents {
                let challengeId = challengeDoc.documentID
                
                let checkInsRef = firestore
                    .collection("users")
                    .document(userId)
                    .collection("challenges")
                    .document(challengeId)
                    .collection("checkIns")
                
                let checkInsSnapshot = try await checkInsRef.getDocuments()
                
                // Process check-ins
                for checkInDoc in checkInsSnapshot.documents {
                    let data = checkInDoc.data()
                    
                    // Extract check-in data
                    guard let timestamp = data["date"] as? Timestamp else { continue }
                    let dayNumber = data["dayNumber"] as? Int ?? 0
                    let note = data["note"] as? String
                    let photoURLString = data["photoURL"] as? String
                    let timerDuration = data["durationInMinutes"] as? Int
                    
                    let date = timestamp.dateValue()
                    let photoURL = photoURLString != nil ? URL(string: photoURLString!) : nil
                    
                    // Create CheckIn object
                    let checkIn = CheckIn(
                        id: checkInDoc.documentID,
                        date: date,
                        dayNumber: dayNumber,
                        note: note,
                        photoURL: photoURL,
                        timerDuration: timerDuration
                    )
                    
                    // Store by date for easy lookup
                    let startOfDay = calendar.startOfDay(for: date)
                    checkInsByDate[startOfDay] = checkIn
                }
            }
            
            print("DEBUG: Progress - loaded \(checkInsByDate.count) check-ins")
            
        } catch {
            print("ERROR: Failed to load check-ins: \(error.localizedDescription)")
        }
    }
    
    // Load data from Firestore with proper async handling and timeouts
    func loadData() async {
        // Cancel any previous task
        loadDataTask?.cancel()
        errorMessage = nil
        
        // Check Firebase availability first
        let firebaseReady = await FirebaseAvailabilityService.shared.waitForFirebase()
        if !firebaseReady {
            await MainActor.run {
                self.errorMessage = "Firebase services unavailable. Please try again later."
                self.isLoading = false
            }
            return
        }
        
        // Check authentication
        guard let userId = Auth.auth().currentUser?.uid else {
            print("DEBUG: Progress - no user ID, aborting load")
            await MainActor.run {
                self.errorMessage = "You need to be signed in to view progress."
                self.isLoading = false
            }
            return
        }
        
        print("DEBUG: Progress - starting data load (attempt \(retryCount + 1))")
        await MainActor.run { self.isLoading = true }
        
        loadDataTask = Task {
            do {
                // Create timeout task
                let timeoutTask = Task {
                    do {
                        try await Task.sleep(nanoseconds: 8_000_000_000) // 8 second timeout
                        if !Task.isCancelled {
                            print("DEBUG: Progress - load operation timed out")
                            if retryCount < maxRetries {
                                retryCount += 1
                                print("DEBUG: Progress - retrying (\(retryCount)/\(maxRetries))")
                                await loadData() // Retry
                            } else {
                                loadDataTask?.cancel()
                                await MainActor.run {
                                    self.loadFallbackData()
                                    self.errorMessage = "Unable to load data after several attempts."
                                    self.isLoading = false
                                }
                            }
                        }
                    } catch {
                        // Handle potential task cancellation
                        print("DEBUG: Progress - timeout task cancelled")
                    }
                }
                
                // Try to load actual data from Firestore
                print("DEBUG: Progress - querying Firestore")
                let challengesRef = firestore
                    .collection("users")
                    .document(userId)
                    .collection("challenges")
                    .whereField("isArchived", isEqualTo: false)
                
                // Add network condition check
                if !NetworkMonitor.shared.isConnected {
                    print("DEBUG: Progress - network offline, trying cached data")
                }
                
                // Perform the actual Firestore query
                let snapshot = try await challengesRef.getDocuments()
                
                // Cancel the timeout task since we got a response
                timeoutTask.cancel()
                
                if Task.isCancelled { return }
                
                // Process the challenge data
                let challenges = snapshot.documents.compactMap { doc -> Challenge? in
                    try? doc.data(as: Challenge.self)
                }
                
                print("DEBUG: Progress - loaded \(challenges.count) challenges")
                
                if Task.isCancelled { return }
                
                // Calculate stats
                let totalChallenges = challenges.count
                let currentStreak = calculateCurrentStreak(challenges)
                let longestStreak = calculateLongestStreak(challenges)
                let completionPercentage = calculateCompletionRate(challenges)
                let badges = calculateBadges(challenges)
                
                if Task.isCancelled { return }
                
                // Update the UI on the main thread
                await MainActor.run {
                    self.totalChallenges = totalChallenges
                    self.currentStreak = currentStreak
                    self.longestStreak = longestStreak
                    self.completionPercentage = completionPercentage
                    self.earnedBadges = badges
                    
                    // Initialize calendar data
                    if self.calendarDays.isEmpty {
                        self.initializeCalendarData()
                    }
                    
                    self.hasData = true
                    self.isLoading = false
                }
                
                // Reset retry count on success
                retryCount = 0
                
                print("DEBUG: Progress - data processed successfully")
            } catch let error as NSError {
                if !Task.isCancelled {
                    print("ERROR: Progress - Firestore query failed: \(error.localizedDescription)")
                    
                    // Handle different error types
                    if error.domain == FirestoreErrorDomain {
                        switch error.code {
                        case 7: // Unavailable 
                            if retryCount < maxRetries {
                                retryCount += 1
                                // Exponential backoff
                                try? await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(retryCount))) * 1_000_000_000)
                                await loadData() // Retry with backoff
                                return
                            }
                        default:
                            break
                        }
                    }
                    
                    // Fall back to sample data for any error after retries
                    await MainActor.run {
                        self.loadFallbackData()
                        self.errorMessage = "Could not load your progress data: \(error.localizedDescription)"
                        self.isLoading = false
                    }
                }
            }
        }
    }
    
    // Helper to load fallback data when Firestore fails
    private func loadFallbackData() {
        print("DEBUG: Progress - loading fallback data")
        
        // Set minimal sample data
        totalChallenges = 0
        currentStreak = 0
        longestStreak = 0
        completionPercentage = 0.0
        
        // Empty badges array
        earnedBadges = []
        
        // Initialize calendar data
        if calendarDays.isEmpty {
            initializeCalendarData()
        }
        
        // Set hasData to true to avoid loading spinner
        hasData = true
    }
    
    // Calculate current streak from challenge data
    private func calculateCurrentStreak(_ challenges: [Challenge]) -> Int {
        // Get max streak from active challenges
        let activeStreaks = challenges.filter { !$0.hasStreakExpired }
        return activeStreaks.map { $0.streakCount }.max() ?? 0
    }
    
    // Calculate longest streak from challenge data
    private func calculateLongestStreak(_ challenges: [Challenge]) -> Int {
        return challenges.map { $0.streakCount }.max() ?? 0
    }
    
    // Calculate completion rate
    private func calculateCompletionRate(_ challenges: [Challenge]) -> Double {
        guard challenges.count > 0 else { return 0.0 }
        
        let totalCompletedDays = challenges.reduce(0) { $0 + $1.daysCompleted }
        let totalPossibleDays = challenges.count * 100
        
        return Double(totalCompletedDays) / Double(totalPossibleDays)
    }
    
    // Calculate badges from Challenge objects
    private func calculateBadges(_ challenges: [Challenge]) -> [ProgressBadge] {
        var badges: [ProgressBadge] = []
        
        // Streak badges
        if longestStreak >= 7 {
            badges.append(ProgressBadge(id: 1, title: "7-Day Streak", iconName: "flame.fill"))
        }
        if longestStreak >= 30 {
            badges.append(ProgressBadge(id: 2, title: "30-Day Streak", iconName: "flame.fill"))
        }
        
        // Completion badges
        let completedChallenges = challenges.filter { $0.isCompleted }.count
        if completedChallenges > 0 {
            badges.append(ProgressBadge(id: 3, title: "First Completion", iconName: "checkmark.circle.fill"))
        }
        if completedChallenges >= 3 {
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
        
        // Consistency badge
        if totalChallenges > 0 && !challenges.contains(where: { $0.hasStreakExpired }) {
            badges.append(ProgressBadge(id: 8, title: "Perfect Consistency", iconName: "star.fill"))
        }
        
        return badges
    }
    
    // Calculate date intensity map for heatmap
    func generateDateIntensityMap() -> [Date: Int] {
        var intensityMap: [Date: Int] = [:]
        let calendar = Calendar.current
        
        // Iterate through check-ins and calculate intensity based on activity
        for (date, _) in checkInsByDate {
            // Get the start of day for consistent date comparison
            let dayStart = calendar.startOfDay(for: date)
            
            // Check for streak on this day
            let isStreakDay = isDateInStreak(date)
            
            // Assign intensity value (1-5) based on activity level
            // 1-2: Normal activity
            // 3-4: Active day with multiple check-ins
            // 5: Streak day
            
            let baseIntensity = 2 // Base intensity for a check-in
            let streakBonus = isStreakDay ? 3 : 0 // Bonus if part of a streak
            
            intensityMap[dayStart] = min(5, baseIntensity + streakBonus)
        }
        
        return intensityMap
    }
    
    // Helper to check if a date is part of an active streak
    private func isDateInStreak(_ date: Date) -> Bool {
        // For simplicity, we'll consider consecutive days as streaks
        // In a real app, this would use more sophisticated streak detection
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: date)!
        let yesterdayStart = calendar.startOfDay(for: yesterday)
        
        return checkInsByDate[yesterdayStart] != nil
    }
    
    // Access the date intensity map through a computed property
    var dateIntensityMap: [Date: Int] {
        return generateDateIntensityMap()
    }
}

// MARK: - Model Types

struct ProgressBadge: Identifiable {
    let id: Int
    let title: String
    let iconName: String
}

struct ProgressChallengeItem: Identifiable {
    let id: String
    let title: String
    let daysCompleted: Int
    let totalDays: Int
    let isActive: Bool
}

struct ProgressDailyCheckIn: Identifiable {
    let id: String
    let date: Date
    let challengeCount: Int
}

// MARK: - Color Theme Extension

extension Color {
    static let theme = ColorTheme()
}

struct ColorTheme {
    let accent = Color("AccentColor")
    let background = Color("Background")
    let surface = Color("Surface")
    let text = Color("Text")
    let subtext = Color("Subtext")
    let border = Color("Border")
    let shadow = Color("Shadow")
} 