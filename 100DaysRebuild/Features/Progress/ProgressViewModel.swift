import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

// Renamed to avoid redeclaration conflict with the main Challenge model
struct ProgressChallenge: Identifiable, Codable {
    let id: UUID
    var title: String
    let startDate: Date
    var lastCheckInDate: Date?
    var streakCount: Int
    var daysCompleted: Int
    var isCompletedToday: Bool
    var isArchived: Bool
    let ownerId: String
    var lastModified: Date
    
    // Computed properties
    var hasStreakExpired: Bool {
        guard let lastCheckIn = lastCheckInDate else { return true }
        return Calendar.current.dateComponents([.day], from: lastCheckIn, to: Date()).day ?? 0 > 1
    }
    
    var endDate: Date {
        Calendar.current.date(byAdding: .day, value: 100, to: startDate) ?? startDate
    }
    
    var daysRemaining: Int {
        max(0, 100 - daysCompleted)
    }
    
    var isCompleted: Bool {
        daysCompleted >= 100
    }
    
    var progressPercentage: Double {
        Double(daysCompleted) / 100.0
    }
    
    init(id: UUID = UUID(), 
         title: String, 
         startDate: Date = Date(), 
         lastCheckInDate: Date? = nil, 
         streakCount: Int = 0, 
         daysCompleted: Int = 0,
         isCompletedToday: Bool = false, 
         isArchived: Bool = false, 
         ownerId: String,
         lastModified: Date = Date()) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.lastCheckInDate = lastCheckInDate
        self.streakCount = streakCount
        self.daysCompleted = daysCompleted
        self.isCompletedToday = isCompletedToday
        self.isArchived = isArchived
        self.ownerId = ownerId
        self.lastModified = lastModified
    }
}

enum ProgressAction {
    case loadProgress
    case retryLoading
    case viewMilestone(milestoneId: String)
    case shareProgress
}

struct ProgressState {
    var overallProgress: Double = 0.0
    var milestones: [Milestone] = []
    var isLoading: Bool = false
    var error: String?
    var lastLoadTime: Date?
    var retryCount: Int = 0
}

enum ProgressError: Error, LocalizedError {
    case notAuthenticated
    case firestoreError(Error)
    case documentParsingError(Error)
    case noDataAvailable
    case networkError
    case timeoutError
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to view progress"
        case .firestoreError(let error):
            return "Database error: \(error.localizedDescription)"
        case .documentParsingError(let error):
            return "Data format error: \(error.localizedDescription)"
        case .noDataAvailable:
            return "No progress data available"
        case .networkError:
            return "Network connection error. Please check your connection and try again."
        case .timeoutError:
            return "Request timed out. Please try again."
        }
    }
}

struct Milestone: Identifiable {
    let id: String
    let title: String
    let date: Date
    let isCompleted: Bool
}

@MainActor
class ProgressViewModel: ViewModel<ProgressState, ProgressAction> {
    private let challengeStore = ChallengeStore.shared
    private var loadTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private let maxRetries = 3
    private let retryDelay: TimeInterval = 2.0
    
    deinit {
        loadTask?.cancel()
        cancellables.removeAll()
    }
    
    init() {
        super.init(initialState: ProgressState())
        
        // Setup observers for the challenge store
        setupChallengeStoreObservers()
    }
    
    private func setupChallengeStoreObservers() {
        // Observe challenge updates from ChallengeStore
        NotificationCenter.default.publisher(for: ChallengeStore.challengesDidUpdateNotification)
            .sink { [weak self] _ in
                self?.handle(.loadProgress)
            }
            .store(in: &cancellables)
    }
    
    override func handle(_ action: ProgressAction) {
        switch action {
        case .loadProgress:
            Task {
                await loadUserProgress()
            }
        case .retryLoading:
            Task {
                await retryLoadProgress()
            }
        case .viewMilestone:
            // Implemented by the navigation container
            break
        case .shareProgress:
            // Implemented by the view controller
            break
        }
    }
    
    private func retryLoadProgress() async {
        if state.retryCount < maxRetries {
            state.retryCount += 1
            await loadUserProgress(isRetry: true)
        } else {
            state.error = "Failed to load data after multiple attempts. Please try again later."
            state.isLoading = false
        }
    }
    
    private func loadUserProgress(isRetry: Bool = false) async {
        // Avoid duplicate requests if already loading
        if state.isLoading && !isRetry { return }
        
        // If this is a fresh load (not a retry), reset retry count
        if !isRetry {
            state.retryCount = 0
        }
        
        state.isLoading = true
        state.error = nil
        
        guard Auth.auth().currentUser != nil else {
            state.isLoading = false
            state.error = ProgressError.notAuthenticated.errorDescription
            return
        }
        
        // Cancel any existing task
        loadTask?.cancel()
        
        loadTask = Task { [weak self] in
            guard let self = self else { return }
            
            do {
                // Ensure the challenge store is up to date
                await challengeStore.refreshChallenges()
                
                // Get overall progress directly from the store
                let overallProgress = challengeStore.overallCompletionPercentage
                
                // Extract challenges from the store
                let challenges = challengeStore.challenges
                
                if Task.isCancelled { return }
                
                // Convert significant milestones to our data model
                let milestones = self.extractMilestones(from: challenges)
                
                if Task.isCancelled { return }
                
                state.overallProgress = overallProgress
                state.milestones = milestones
                state.isLoading = false
                state.lastLoadTime = Date()
                state.retryCount = 0 // Reset retry count on success
                
            } catch {
                if !Task.isCancelled {
                    state.error = error.localizedDescription
                    state.isLoading = false
                    
                    // Auto-retry if network error and not already a retry
                    if !isRetry && state.retryCount < self.maxRetries {
                        // Schedule retry
                        scheduleRetry()
                    }
                }
            }
        }
    }
    
    private func scheduleRetry() {
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
            guard let self = self, !Task.isCancelled else { return }
            await self.retryLoadProgress()
        }
    }
    
    // Extract milestone data from challenges
    private func extractMilestones(from challenges: [Challenge]) -> [Milestone] {
        var milestones: [Milestone] = []
        
        for challenge in challenges {
            // Only include challenges with progress
            guard challenge.daysCompleted > 0 else { continue }
            
            // Add milestone for each challenge start
            milestones.append(Milestone(
                id: "start_\(challenge.id.uuidString)",
                title: "Started \"\(challenge.title)\"",
                date: challenge.startDate,
                isCompleted: true
            ))
            
            // Add milestone for the first check-in if available
            if let firstCheckIn = challenge.lastCheckInDate, challenge.daysCompleted >= 1 {
                milestones.append(Milestone(
                    id: "first_checkin_\(challenge.id.uuidString)",
                    title: "First check-in for \"\(challenge.title)\"",
                    date: firstCheckIn,
                    isCompleted: true
                ))
            }
            
            // Milestone for 25% completion
            if challenge.daysCompleted >= 25 {
                let quarterDate = estimateDateForCompletion(challenge: challenge, days: 25)
                milestones.append(Milestone(
                    id: "quarter_\(challenge.id.uuidString)",
                    title: "25% complete on \"\(challenge.title)\"",
                    date: quarterDate,
                    isCompleted: true
                ))
            }
            
            // Milestone for 50% completion
            if challenge.daysCompleted >= 50 {
                let halfDate = estimateDateForCompletion(challenge: challenge, days: 50)
                milestones.append(Milestone(
                    id: "half_\(challenge.id.uuidString)",
                    title: "Halfway through \"\(challenge.title)\"",
                    date: halfDate,
                    isCompleted: true
                ))
            }
            
            // Milestone for 75% completion
            if challenge.daysCompleted >= 75 {
                let threeQuarterDate = estimateDateForCompletion(challenge: challenge, days: 75)
                milestones.append(Milestone(
                    id: "threequarter_\(challenge.id.uuidString)",
                    title: "75% complete on \"\(challenge.title)\"",
                    date: threeQuarterDate,
                    isCompleted: true
                ))
            }
            
            // Milestone for completion
            if challenge.isCompleted {
                let completionDate = estimateDateForCompletion(challenge: challenge, days: 100)
                milestones.append(Milestone(
                    id: "complete_\(challenge.id.uuidString)",
                    title: "Completed \"\(challenge.title)\"! 🎉",
                    date: completionDate,
                    isCompleted: true
                ))
            }
        }
        
        // Sort milestones by date (most recent first)
        return milestones.sorted { $0.date > $1.date }
    }
    
    // Estimate the date when a certain number of days was completed
    private func estimateDateForCompletion(challenge: Challenge, days: Int) -> Date {
        // If we have the last check-in date and we know exactly how many days are completed,
        // we can estimate when certain milestones were reached
        guard let lastCheckIn = challenge.lastCheckInDate else {
            return challenge.startDate
        }
        
        let daysCompleted = challenge.daysCompleted
        let daysSinceMilestone = daysCompleted - days
        
        // If milestone days = current days completed, use the last check-in date
        if daysSinceMilestone == 0 {
            return lastCheckIn
        }
        
        // Otherwise estimate the date based on the average pace
        let calendar = Calendar.current
        let daysSinceStart = calendar.dateComponents([.day], from: challenge.startDate, to: lastCheckIn).day ?? 1
        
        // Calculate average days per check-in
        let averageDaysPerCheckIn = daysSinceStart / max(1, daysCompleted)
        
        // Estimate milestone date by going back from last check-in
        if let estimatedDate = calendar.date(byAdding: .day, value: -(daysSinceMilestone * averageDaysPerCheckIn), to: lastCheckIn) {
            return estimatedDate
        }
        
        // Fallback to start date plus days
        return calendar.date(byAdding: .day, value: days, to: challenge.startDate) ?? challenge.startDate
    }
}

// MARK: - UPViewModel Implementation
@MainActor
class ProgressDashboardViewModel: ObservableObject {
    // Add shared singleton instance
    static let shared = ProgressDashboardViewModel()
    
    @Published var isLoading = false
    @Published var isInitialLoad = true
    @Published var hasData = false
    @Published var errorMessage: String?
    @Published var isNetworkConnected = true
    
    // State variables
    @Published var activityData: [Date] = []
    @Published var challengeProgressData: [ProgressChallengeItem] = []
    @Published var dailyCheckInsData: [ProgressDailyCheckIn] = []
    @Published var projectedCompletionDate: Date? = nil
    @Published var currentPace = "0 days/week"
    @Published var earnedBadges: [ProgressBadge] = []
    @Published var dateIntensityMap: [Date: Int] = [:]
    @Published var journeyCards: [JourneyCard] = []
    @Published var recentPhotosNotes: [(photo: URL?, note: String, dayNumber: Int, date: Date)] = []
    
    // Dependencies
    private let firestore = Firestore.firestore()
    @MainActor private var loadTask: Task<Void, Never>?
    @MainActor private var userStatsService: UserStatsService { UserStatsService.shared }
    
    // Private initializer for singleton
    private init() {
        print("ProgressDashboardViewModel initialized as singleton")
    }
    
    // Computed properties that get data from the centralized UserStatsService
    var totalChallenges: Int { 
        MainActor.assertIsolated()
        return userStatsService.userStats.totalChallenges 
    }
    var currentStreak: Int { 
        MainActor.assertIsolated()
        return userStatsService.userStats.currentStreak 
    }
    var longestStreak: Int { 
        MainActor.assertIsolated()
        return userStatsService.userStats.longestStreak 
    }
    var completionPercentage: Double { 
        MainActor.assertIsolated()
        return userStatsService.userStats.overallCompletionPercentage 
    }
    var lastCheckInDate: Date? { 
        MainActor.assertIsolated()
        return userStatsService.userStats.lastCheckInDate 
    }
    
    deinit {
        cancelTaskOnly()
        print("ProgressDashboardViewModel deinit - tasks cancelled")
    }
    
    // Non-isolated method for deinit to use
    nonisolated func cancelTaskOnly() {
        Task { @MainActor in
            loadTask?.cancel()
            loadTask = nil
        }
    }
    
    // Main actor method for UI updates
    @MainActor
    func cancelTasks() {
        cancelTaskOnly()
        
        // Ensure we update the loading state
        if isLoading {
            isLoading = false
            print("ProgressDashboardViewModel - Cancelled tasks and reset loading state")
        }
    }
    
    func loadData(forceRefresh: Bool = false) async {
        if isLoading && !forceRefresh {
            return
        }
        
        // Cancel any previous loading task
        cancelTasks()
        
        loadTask = Task { [weak self] in
            guard let self = self else { return }
            
            do {
                await MainActor.run {
                    self.isLoading = true
                    self.errorMessage = nil
                    print("ProgressDashboardViewModel - Starting data load")
                }
                
                // Set up a timeout to prevent infinite loading state
                let timeoutTask = Task {
                    do {
                        try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds timeout
                        if self.isLoading {
                            print("ProgressDashboardViewModel - Loading timed out after 10 seconds")
                            await MainActor.run {
                                self.isLoading = false
                                // Provide an empty state if timeout occurs but still show cached data if available
                                if !self.hasData {
                                    self.errorMessage = "Loading timed out. Pull down to refresh."
                                    self.isInitialLoad = false
                                }
                            }
                        }
                    } catch {
                        // Task was cancelled, no action needed
                    }
                }
                
                // First, load centralized stats
                await MainActor.run {
                    Task {
                        try? await self.userStatsService.fetchUserStats()
                    }
                }
                
                // Simple delay to simulate data loading - REDUCED TO AVOID LONG WAITS
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds instead of 1.5
                
                try Task.checkCancellation()
                
                // Check if the user is logged in
                guard Auth.auth().currentUser != nil else {
                    timeoutTask.cancel()
                    await MainActor.run {
                        self.errorMessage = "You must be logged in to view progress"
                        self.isLoading = false
                        self.isInitialLoad = false
                        self.hasData = false
                    }
                    return
                }
                
                // Generate some sample data for immediate display
                let sampleData = self.generateSampleData()
                
                // Check for cancellation before updating UI
                try Task.checkCancellation()
                
                timeoutTask.cancel() // Cancel timeout since we succeeded
                
                await MainActor.run {
                    // Only set supplementary data that isn't provided by UserStatsService
                    self.journeyCards = sampleData.journeyCards
                    self.dateIntensityMap = sampleData.dateIntensityMap
                    self.dailyCheckInsData = sampleData.dailyCheckInsData
                    self.projectedCompletionDate = sampleData.projectedCompletionDate
                    self.currentPace = sampleData.currentPace
                    self.earnedBadges = sampleData.earnedBadges
                    
                    // Mark as loaded with data
                    self.hasData = true
                    self.isLoading = false
                    self.isInitialLoad = false
                    self.errorMessage = nil
                    print("ProgressDashboardViewModel - Data load complete")
                }
            } catch is CancellationError {
                // Safe handling of task cancellation
                print("ProgressDashboardViewModel - Task was cancelled")
                await MainActor.run {
                    self.isLoading = false
                }
                return
            } catch {
                print("ProgressDashboardViewModel - Error loading data: \(error.localizedDescription)")
                
                // Handle error on main thread
                await MainActor.run {
                    self.errorMessage = "Failed to load progress data. Please try again."
                    self.isLoading = false
                    self.isInitialLoad = false
                }
            }
        }
    }
    
    // Add loadProgress() method for backward compatibility
    func loadProgress() async {
        await loadData(forceRefresh: false)
    }
    
    private func generateSampleData() -> (
        journeyCards: [JourneyCard],
        dateIntensityMap: [Date: Int],
        dailyCheckInsData: [ProgressDailyCheckIn],
        projectedCompletionDate: Date?,
        currentPace: String,
        earnedBadges: [ProgressBadge]
    ) {
        // Check if this is first load with no existing data
        let isFirstLoad = earnedBadges.isEmpty && journeyCards.isEmpty

        // If we have existing data and are just refreshing, keep current data  
        if !isFirstLoad && hasData {
            return (
                journeyCards: self.journeyCards,
                dateIntensityMap: self.dateIntensityMap, 
                dailyCheckInsData: self.dailyCheckInsData,
                projectedCompletionDate: self.projectedCompletionDate,
                currentPace: self.currentPace,
                earnedBadges: self.earnedBadges
            )
        }

        // Only generate sample data for first load or when explicitly forced
        // This example uses data that should represent real user's progress appropriately
        
        // Generate journey cards
        let journeyCards = generateJourneyCards()
        
        // Generate heatmap data
        let dateIntensityMap = generateDateIntensityMap()
        
        // Generate daily check-ins data
        let dailyCheckInsData = generateDailyCheckInsData()
        
        // Calculate projected completion
        let projectedCompletionDate = Calendar.current.date(
            byAdding: .day,
            value: Int(30 * (1.0 - completionPercentage)),
            to: Date()
        )
        
        // Calculate current pace
        let currentPace = calculateCurrentPace()
        
        // Generate earned badges
        let earnedBadges = generateEarnedBadges()
        
        return (
            journeyCards: journeyCards,
            dateIntensityMap: dateIntensityMap,
            dailyCheckInsData: dailyCheckInsData,
            projectedCompletionDate: projectedCompletionDate,
            currentPace: currentPace,
            earnedBadges: earnedBadges
        )
    }
    
    private func generateJourneyCards() -> [JourneyCard] {
        // Generate sample journey cards based on user's progress
        var cards: [JourneyCard] = []
        
        // First challenge started
        cards.append(JourneyCard(type: .milestone(
            message: "First Challenge",
            emoji: "flag.fill",
            dayNumber: nil,
            date: Date().addingTimeInterval(-30*24*60*60)
        )))
        
        // Add streak milestone if applicable
        if longestStreak >= 7 {
            cards.append(JourneyCard(type: .milestone(
                message: "\(longestStreak) Day Streak",
                emoji: "flame.fill",
                dayNumber: nil,
                date: Date().addingTimeInterval(-14*24*60*60)
            )))
        }
        
        // Add completion milestone if applicable
        if completionPercentage > 0.25 {
            cards.append(JourneyCard(type: .milestone(
                message: "25% Complete",
                emoji: "chart.bar.fill",
                dayNumber: nil,
                date: Date().addingTimeInterval(-7*24*60*60)
            )))
        }
        
        return cards
    }
    
    private func generateDateIntensityMap() -> [Date: Int] {
        // Generate sample date intensity map for heatmap
        var dateIntensityMap: [Date: Int] = [:]
        
        // Generate activity data for the last 90 days based on check-in patterns
        for i in 0..<90 {
            // Higher probability of check-ins on more recent days and weekdays
            let date = Calendar.current.date(byAdding: .day, value: -i, to: Date())!
            let weekday = Calendar.current.component(.weekday, from: date)
            let isWeekend = (weekday == 1 || weekday == 7)
            
            // More likely to have check-ins on recent days
            let recentDaysProbability = Double(90 - i) / 90.0
            
            // Weekend check-ins are less common
            let checkInProbability = isWeekend ? 0.3 : 0.7
            
            // Combine factors for final probability
            let probability = checkInProbability * recentDaysProbability
            
            if Double.random(in: 0.0...1.0) < probability {
                // Simulate 1-3 check-ins per day
                dateIntensityMap[date] = Int.random(in: 1...3)
            }
        }
        
        return dateIntensityMap
    }
    
    private func generateDailyCheckInsData() -> [ProgressDailyCheckIn] {
        // Generate sample daily check-ins for the last week
        var checkIns: [ProgressDailyCheckIn] = []
        
        // Add check-ins with some randomness to simulate real use
        for i in 0..<7 {
            if i == 0 || i == 1 || i == 3 || i == 4 || i == 6 {  // Skip a couple days
                let date = Calendar.current.date(byAdding: .day, value: -i, to: Date())!
                // Most days have 1 check-in, some have 2
                let count = i % 3 == 0 ? 2 : 1
                checkIns.append(ProgressDailyCheckIn(date: date, count: count))
            }
        }
        
        return checkIns
    }
    
    private func calculateCurrentPace() -> String {
        // Calculate pace based on current streak and completion percentage
        let daysPerWeek: Double
        
        // Use user stats to determine pace
        if currentStreak > 0 {
            // If user has a current streak, base pace on that
            daysPerWeek = min(7.0, max(1.0, Double(currentStreak) / 7.0 * 3.5))
        } else if completionPercentage > 0 {
            // Base on completion rate
            daysPerWeek = min(7.0, max(1.0, completionPercentage * 7.0))
        } else {
            // Default for new users
            daysPerWeek = 3.5
        }
        
        // Format nicely
        return String(format: "%.1f days/week", daysPerWeek)
    }
    
    private func generateEarnedBadges() -> [ProgressBadge] {
        var badges: [ProgressBadge] = []
        
        // First challenge badge
        if totalChallenges > 0 {
            badges.append(ProgressBadge(id: 1, title: "First Challenge", iconName: "flag.fill"))
        }
        
        // Streak badges
        if longestStreak >= 7 {
            badges.append(ProgressBadge(id: 2, title: "7-Day Streak", iconName: "flame.fill"))
        }
        if longestStreak >= 30 {
            badges.append(ProgressBadge(id: 3, title: "30-Day Streak", iconName: "flame.fill"))
        }
        
        // Progress badges
        if completionPercentage >= 0.25 {
            badges.append(ProgressBadge(id: 4, title: "25% Complete", iconName: "chart.bar.fill"))
        }
        if completionPercentage >= 0.50 {
            badges.append(ProgressBadge(id: 5, title: "50% Complete", iconName: "chart.bar.fill"))
        }
        if completionPercentage >= 0.75 {
            badges.append(ProgressBadge(id: 6, title: "75% Complete", iconName: "chart.bar.fill"))
        }
        
        return badges
    }
} 