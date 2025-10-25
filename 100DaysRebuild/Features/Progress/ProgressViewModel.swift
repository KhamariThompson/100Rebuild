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
        print("✅ Singleton released: \(Self.self)")
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
    
    // Add a nonisolated method for deinit to use
    nonisolated func cancelTaskOnly() {
        Task { @MainActor in
            loadTask?.cancel()
            loadTask = nil
        }
    }
}

// MARK: - UPViewModel Implementation
@MainActor
class ProgressDashboardViewModel: ObservableObject {
    // Use shared singleton instance to prevent recreation between tab switches
    static let shared = ProgressDashboardViewModel()
    
    @Published var isLoading = false
    @Published var isInitialLoad = true
    @Published var hasData = false
    @Published var errorMessage: String? = nil
    @Published var networkConnected = true
    @Published var showingBadgeUnlock = false
    @Published var newlyUnlockedBadge: Badge? = nil
    @Published var showProUpgradeSheet = false
    
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
    
    // Challenge statistics
    @Published var totalChallenges: Int = 0
    @Published var completedChallenges: Int = 0
    @Published var totalCompletedChallenges: Int = 0
    @Published var activeChallenges: Int = 0
    @Published var completionPercentage: Double = 0.0
    @Published var currentStreak: Int = 0
    
    // New advanced analytics properties for Pro users
    @Published var weeklyCheckInRate: Double = 0.0  // 0.0 to 1.0
    @Published var monthlyCheckInRate: Double = 0.0 // 0.0 to 1.0
    @Published var totalCheckInRate: Double = 0.0   // 0.0 to 1.0 (100 days)
    @Published var activeDaysThisYear: Int = 0
    @Published var averageCheckInTime: String? = nil
    @Published var bestStreakMonth: BestMonth? = nil
    
    // Structure to represent best streak month data
    struct BestMonth {
        let month: String
        let consistency: Int
    }
    
    // Dependencies
    private let firestore = Firestore.firestore()
    @MainActor private var loadTask: Task<Void, Never>?
    @MainActor private var userStatsService: UserStatsService { UserStatsService.shared }
    @MainActor private var challengeStore: ChallengeStore { ChallengeStore.shared }
    @MainActor private var badgeService: BadgeService { BadgeService.shared }
    
    // Add Combine cancellables for subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // Add debounce timer
    private var refreshDebounceTimer: Timer?
    private let refreshDebounceInterval: TimeInterval = 2.0
    
    // Private initializer for singleton
    private init() {
        print("ProgressDashboardViewModel initialized as singleton")
        
        // Subscribe to UserStatsService changes for immediate updates
        setupUserStatsSubscription()
        
        // Also listen for network status changes
        setupNetworkMonitoring()
        
        // Listen for auth state changes
        setupAuthStateListener()
    }
    
    /// Reset all state to initial values
    @MainActor
    func reset() {
        // Cancel any running tasks
        loadTask?.cancel()
        loadTask = nil
        
        // Reset all published properties
        isLoading = false
        isInitialLoad = true
        hasData = false
        errorMessage = nil
        networkConnected = true
        showingBadgeUnlock = false
        newlyUnlockedBadge = nil
        showProUpgradeSheet = false
        
        // Clear all data arrays
        activityData = []
        challengeProgressData = []
        dailyCheckInsData = []
        projectedCompletionDate = nil
        currentPace = "0 days/week"
        earnedBadges = []
        dateIntensityMap = [:]
        journeyCards = []
        recentPhotosNotes = []
        
        // Reset badge properties
        newlyUnlockedBadge = nil
        showingBadgeUnlock = false
        
        // Cancel any pending timer
        refreshDebounceTimer?.invalidate()
        refreshDebounceTimer = nil
        
        print("ProgressDashboardViewModel - Reset complete")
    }
    
    // Set up subscription to UserStatsService
    private func setupUserStatsSubscription() {
        // Subscribe to userStats changes with debouncing
        UserStatsService.shared.$userStats
            .dropFirst() // Skip initial empty value
            .receive(on: RunLoop.main)
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] stats in
                guard let self = self else { return }
                
                // Update hasData based on whether stats has meaningful data
                let hasUserStats = stats.totalChallenges > 0
                
                // Only update if data status would change or if we have data
                if self.hasData != hasUserStats || hasUserStats {
                    self.hasData = hasUserStats
                    print("ProgressDashboardViewModel updated from UserStatsService - hasData: \(hasUserStats)")
                }
            }
            .store(in: &cancellables)
        
        // Listen for badge unlock notifications
        NotificationCenter.default.publisher(for: BadgeService.badgeUnlockedNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                guard let self = self, let badge = notification.object as? Badge else { return }
                print("ProgressDashboardViewModel received badge unlock notification for \(badge.name)")
                
                // Show badge unlock celebration
                self.newlyUnlockedBadge = badge
                self.showingBadgeUnlock = true
            }
            .store(in: &cancellables)
        
        // Subscribe to loading state changes with debouncing
        UserStatsService.shared.$isLoading
            .receive(on: RunLoop.main)
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] isLoading in
                guard let self = self else { return }
                // Only update our loading state if UserStatsService is loading
                // and we're not already loading something else
                if isLoading && !self.isLoading {
                    self.isLoading = true
                    print("ProgressDashboardViewModel - Loading state updated from UserStatsService")
                }
            }
            .store(in: &cancellables)
        
        // Subscribe to notifications about stats updates with debouncing
        NotificationCenter.default.publisher(for: UserStatsService.userStatsDidUpdateNotification)
            .receive(on: RunLoop.main)
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                print("ProgressDashboardViewModel received userStatsDidUpdateNotification")
                
                // Mark as having data if UserStatsService has meaningful stats
                if UserStatsService.shared.userStats.totalChallenges > 0 {
                    self.hasData = true
                    self.isInitialLoad = false
                }
                
                // If we were loading, finish loading state
                if self.isLoading {
                    self.isLoading = false
                }
            }
            .store(in: &cancellables)
            
        // Subscribe to challenge store updates with debouncing
        NotificationCenter.default.publisher(for: ChallengeStore.challengesDidUpdateNotification)
            .receive(on: RunLoop.main)
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                print("ProgressDashboardViewModel received challenge updates - refreshing consistency calendar")
                
                // Update calendar data with fresh check-in information
                Task { [self] in
                    // Generate new check-in data for the consistency calendar
                    let newCheckInData = self.generateCheckInMapFromChallenges()
                    
                    // Update the map on the main thread
                    await MainActor.run {
                        self.dateIntensityMap = newCheckInData
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // Set up network monitoring
    private func setupNetworkMonitoring() {
        // Subscribe to network status changes
        NotificationCenter.default.publisher(for: NetworkMonitor.networkStatusChanged)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                guard let self = self else { return }
                // Extract the isConnected parameter from the notification
                if let userInfo = notification.userInfo,
                   let isConnected = userInfo["isConnected"] as? Bool {
                    // Update our local network status
                    self.networkConnected = isConnected
                }
            }
            .store(in: &cancellables)
    }
    
    // Add debounced refresh method
    private func debouncedRefresh() {
        refreshDebounceTimer?.invalidate()
        refreshDebounceTimer = Timer.scheduledTimer(withTimeInterval: refreshDebounceInterval, repeats: false) { [weak self] _ in
            Task { [weak self] in
                await self?.loadData(forceRefresh: true)
            }
        }
    }
    
    // Update loadData method to use debouncing
    @MainActor
    func loadData(forceRefresh: Bool = false) async {
        if isLoading && !forceRefresh {
            print("ProgressDashboardViewModel: Already loading data, skipping")
            return
        }
        
        // Cancel any existing task to avoid race conditions
        loadTask?.cancel()
        
        loadTask = Task {
            do {
                isLoading = true
                
                // First load all user challenges to get the data we need
                try await loadUserChallenges()
                
                // Then load user stats which will be used for progress calculations
                try await loadUserStats()
                
                // Additional data for UI components
                try await fetchAdditionalData()
                
                // Set hasData to true if we have fetched data
                if !Task.isCancelled {
                    hasData = true
                    errorMessage = nil
                    isInitialLoad = false
                }
                
                print("ProgressDashboardViewModel: Data loading completed")
            } catch {
                if !Task.isCancelled {
                    print("ProgressDashboardViewModel: Error loading data: \(error.localizedDescription)")
                    errorMessage = "Could not load progress data: \(error.localizedDescription)"
                }
            }
            
            if !Task.isCancelled {
                isLoading = false
            }
            
            loadTask = nil
        }
    }
    
    // Helper function to format user-friendly error messages
    private func formatErrorMessage(_ error: Error) -> String {
        // Network connectivity issues
        if let nsError = error as? NSError {
            // Check for common network errors
            if nsError.domain == NSURLErrorDomain {
                switch nsError.code {
                case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
                    return "No internet connection. Please check your network settings and try again."
                case NSURLErrorTimedOut:
                    return "Request timed out. Please try again later."
                default:
                    return "Network error: \(nsError.localizedDescription)"
                }
            }
        }
        
        // Firebase errors
        if error.localizedDescription.contains("permission") {
            return "You don't have permission to access this data. Please sign in again."
        }
        
        // Generic fallback
        return "Failed to load progress data. Please try again later."
    }
    
    // Separate method to fetch additional data that's not in UserStatsService
    private func fetchAdditionalData() async throws {
        // Generate data for UI display
        let sampleData = self.generateSampleData()
        
        // Generate check-in data for the consistency calendar directly from challenges
        let checkInData = generateCheckInMapFromChallenges()
        
        // Calculate advanced analytics for Pro users
        await calculateAdvancedAnalytics()
        
        // Only update specific fields on main actor
        await MainActor.run {
            self.journeyCards = sampleData.journeyCards
            self.dateIntensityMap = checkInData
            self.dailyCheckInsData = sampleData.dailyCheckInsData
            self.projectedCompletionDate = sampleData.projectedCompletionDate
            self.currentPace = sampleData.currentPace
            self.earnedBadges = sampleData.earnedBadges
        }
    }
    
    /// Generate consistency calendar check-in data from actual challenge records
    private func generateCheckInMapFromChallenges() -> [Date: Int] {
        let calendar = Calendar.current
        var dateIntensityMap: [Date: Int] = [:]
        
        // Get all challenges from the store
        let challenges = challengeStore.challenges
        
        // Process each challenge to extract check-in dates
        for challenge in challenges {
            // Skip archived challenges
            if challenge.isArchived { continue }
            
            // Look at the check-in history (which is stored in lastCheckInDate)
            if let lastCheckIn = challenge.lastCheckInDate {
                // Normalize to start of day to ensure dates match
                let normalizedDate = calendar.startOfDay(for: lastCheckIn)
                
                // Increment intensity for this date (allowing multiple check-ins to accumulate)
                if let currentIntensity = dateIntensityMap[normalizedDate] {
                    dateIntensityMap[normalizedDate] = min(currentIntensity + 1, 5) // Cap at intensity 5
                } else {
                    dateIntensityMap[normalizedDate] = 1
                }
            }
        }
        
        return dateIntensityMap
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
    
    deinit {
        print("✅ Released: ProgressDashboardViewModel")
        loadTask?.cancel()
        refreshDebounceTimer?.invalidate()
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }
    
    // Main actor method for UI updates
    @MainActor
    func cancelTasks() {
        // Cancel any running task
        loadTask?.cancel()
        loadTask = nil
        
        // Ensure we update the loading state
        if isLoading {
            isLoading = false
            print("ProgressDashboardViewModel - Cancelled tasks and reset loading state")
        }
    }
    
    // Computed properties that get data from the centralized UserStatsService
    var longestStreak: Int { 
        MainActor.assertIsolated()
        return userStatsService.userStats.longestStreak 
    }
    var lastCheckInDate: Date? { 
        MainActor.assertIsolated()
        return userStatsService.userStats.lastCheckInDate 
    }

    // Non-isolated method for deinit to use
    nonisolated func cancelTaskOnly() {
        Task { @MainActor in
            loadTask?.cancel()
            loadTask = nil
        }
    }

    // Add this method to properly prepare for sign-out
    @MainActor
    func prepareForSignOut() {
        print("ProgressDashboardViewModel - Preparing for sign-out")
        
        // Cancel any active tasks first
        cancelTasks()
        
        // Cancel any pending timer
        refreshDebounceTimer?.invalidate()
        refreshDebounceTimer = nil
        
        // Clear all data to prevent stale data from appearing during sign-out
        activityData = []
        challengeProgressData = []
        dailyCheckInsData = []
        projectedCompletionDate = nil
        currentPace = "0 days/week"
        earnedBadges = []
        dateIntensityMap = [:]
        journeyCards = []
        recentPhotosNotes = []
        
        // Reset loading state
        isLoading = false
        isInitialLoad = true
        hasData = false
        
        // Reset badge properties
        newlyUnlockedBadge = nil
        showingBadgeUnlock = false
        showProUpgradeSheet = false
        
        print("ProgressDashboardViewModel - Sign-out preparation complete")
    }
    
    // MARK: - Advanced Analytics Methods
    
    // Calculate check-in rates and other Pro analytics
    private func calculateAdvancedAnalytics() async {
        guard !dateIntensityMap.isEmpty else { return }
        
        let calendar = Calendar.current
        let today = Date()
        
        // Get dates for different time periods
        let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: today)!
        let oneMonthAgo = calendar.date(byAdding: .day, value: -30, to: today)!
        let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: today))!
        
        // Calculate check-in rates
        var weekDaysCount = 0
        var weekCheckIns = 0
        
        var monthDaysCount = 0
        var monthCheckIns = 0
        
        var yearDaysCount = 0
        var yearCheckIns = 0
        
        // Dictionary to track check-ins by month
        var monthlyCheckins: [Int: Int] = [:]
        var monthlyPossibleDays: [Int: Int] = [:]
        
        // Track check-in times for average calculation
        var checkInTimes: [Int] = [] // Store hours of day (0-23)
        
        // Process each date in the intensity map
        for (date, intensity) in dateIntensityMap {
            let month = calendar.component(.month, from: date)
            
            // Only count dates up to today
            if date <= today {
                // Track monthly data for best month calculation
                if !monthlyCheckins.keys.contains(month) {
                    monthlyCheckins[month] = 0
                    monthlyPossibleDays[month] = 0
                }
                
                if intensity > 0 {
                    monthlyCheckins[month]! += 1
                    
                    // Extract the hour component for average check-in time
                    let hour = calendar.component(.hour, from: date)
                    checkInTimes.append(hour)
                }
                
                monthlyPossibleDays[month]! += 1
                
                // Weekly calculation
                if date >= oneWeekAgo {
                    weekDaysCount += 1
                    if intensity > 0 {
                        weekCheckIns += 1
                    }
                }
                
                // Monthly calculation
                if date >= oneMonthAgo {
                    monthDaysCount += 1
                    if intensity > 0 {
                        monthCheckIns += 1
                    }
                }
                
                // Yearly calculation
                if date >= startOfYear {
                    yearDaysCount += 1
                    if intensity > 0 {
                        yearCheckIns += 1
                    }
                }
            }
        }
        
        // Calculate rates
        let weeklyRate = weekDaysCount > 0 ? Double(weekCheckIns) / Double(weekDaysCount) : 0.0
        let monthlyRate = monthDaysCount > 0 ? Double(monthCheckIns) / Double(monthDaysCount) : 0.0
        let totalRate = yearDaysCount > 0 ? Double(yearCheckIns) / Double(yearDaysCount) : 0.0
        
        // Synchronize with global user stats data
        await synchronizeWithGlobalStats()
        
        // Find best month
        var bestMonthNumber = 1
        var bestConsistency = 0.0
        
        for (month, checkIns) in monthlyCheckins {
            if let possibleDays = monthlyPossibleDays[month], possibleDays > 0 {
                let consistency = Double(checkIns) / Double(possibleDays)
                if consistency > bestConsistency && possibleDays >= 7 { // At least a week of data
                    bestConsistency = consistency
                    bestMonthNumber = month
                }
            }
        }
        
        // Calculate average check-in time
        var averageTimeString: String? = nil
        if !checkInTimes.isEmpty {
            let totalHours = checkInTimes.reduce(0, +)
            let avgHour = totalHours / checkInTimes.count
            
            // Format the time string
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            let dateWithHour = calendar.date(bySettingHour: avgHour, minute: 0, second: 0, of: Date())!
            averageTimeString = formatter.string(from: dateWithHour)
        }
        
        // Format month name
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM"
        let monthDate = calendar.date(from: DateComponents(year: 2023, month: bestMonthNumber, day: 1))!
        let monthName = dateFormatter.string(from: monthDate)
        
        // Update published properties on main thread
        await MainActor.run {
            self.weeklyCheckInRate = weeklyRate
            self.monthlyCheckInRate = monthlyRate
            self.totalCheckInRate = totalRate
            self.activeDaysThisYear = yearCheckIns
            self.averageCheckInTime = averageTimeString
            
            if bestConsistency > 0 {
                self.bestStreakMonth = BestMonth(
                    month: monthName,
                    consistency: Int(bestConsistency * 100)
                )
            }
        }
    }
    
    // New method to ensure analytics are synchronized with global user statistics
    private func synchronizeWithGlobalStats() async {
        await MainActor.run {
            // Get stats from the services
            let stats = userStatsService.userStats
            let challenges = challengeStore.challenges
            
            // Update our view model with the service data
            self.totalChallenges = stats.totalChallenges
            self.currentStreak = stats.currentStreak
            
            // Since longestStreak is a computed property that reads from userStatsService,
            // we don't need to update it directly
            
            // Calculate active challenges
            let activeChallenges = challenges.filter { !$0.isArchived }
            self.activeChallenges = activeChallenges.count
            
            // Update completed challenges
            self.completedChallenges = stats.completedChallenges
            self.totalCompletedChallenges = stats.completedChallenges
            
            // Update the completion percentage based on latest data
            let totalCount = self.totalChallenges > 0 ? self.totalChallenges : 100
            self.completionPercentage = Double(self.totalCompletedChallenges) / Double(totalCount)
        }
    }
    
    // Add the necessary methods for loading data
    private func loadUserChallenges() async throws {
        // Use the challenge store to load challenges
        await challengeStore.refreshChallenges()
        
        // Get the challenges from the store
        let challenges = challengeStore.challenges
        
        // Process challenges for ProgressViewModel
        await MainActor.run {
            self.totalChallenges = challenges.count
            
            // Only count non-archived challenges for active challenges
            let activeChallenges = challenges.filter { !$0.isArchived }
            self.activeChallenges = activeChallenges.count
            
            // Update completion percentage
            if self.totalChallenges > 0 {
                self.completionPercentage = Double(self.totalCompletedChallenges) / Double(self.totalChallenges)
            } else {
                self.completionPercentage = 0.0
            }
        }
    }

    // Expose helper to trigger feature computations when data updates
    @MainActor
    func triggerFeatureComputations() {
        // Recompute momentum and forecast when challenge data updates
        MomentumService.shared.computeInBackground()
        ForecastService.shared.computeIfNeeded()
    }
    
    // Load user stats directly from UserStatsService
    private func loadUserStats() async throws {
        // First, get the stats from the service
        let stats = userStatsService.userStats
        
        await MainActor.run {
            // Basic challenge statistics
            self.totalChallenges = stats.totalChallenges
            self.completedChallenges = stats.completedChallenges
            
            // Calculate active challenges directly from challengeStore
            let activeChallenges = challengeStore.challenges.filter { !$0.isArchived }
            self.activeChallenges = activeChallenges.count
            
            self.currentStreak = stats.currentStreak
            
            // Calculate overall completion percentage across all challenges
            if stats.totalChallenges > 0 {
                // Calculate total completed days across all challenges
                let totalDaysCompleted = challengeStore.challenges.reduce(0) { $0 + $1.daysCompleted }
                
                // Total possible days (100 days per challenge)
                let totalPossibleDays = stats.totalChallenges * 100
                
                // Calculate percentage
                if totalPossibleDays > 0 {
                    self.totalCompletedChallenges = totalDaysCompleted
                    self.completionPercentage = Double(totalDaysCompleted) / Double(totalPossibleDays)
                    print("Progress stats updated: \(totalDaysCompleted) days completed out of \(totalPossibleDays) possible days (\(self.completionPercentage * 100)%)")
                } else {
                    self.totalCompletedChallenges = 0
                    self.completionPercentage = 0.0
                }
            } else {
                self.totalCompletedChallenges = 0
                self.completionPercentage = 0.0
            }
        }
    }
    
    // Add a method to setup auth state listener
    private func setupAuthStateListener() {
        NotificationCenter.default
            .publisher(for: NSNotification.Name("AuthStateChanged"))
            .sink { [weak self] _ in
                Task { @MainActor in
                    if Auth.auth().currentUser != nil {
                        // User is logged in, reload data
                        print("ProgressDashboardViewModel - Auth state changed, reloading data")
                        if self?.isInitialLoad == true || self?.hasData == false {
                            await self?.loadData(forceRefresh: true)
                        }
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // Add a public method to refresh analytics data specifically for Pro users
    @MainActor
    func refreshAnalyticsData() async {
        print("ProgressDashboardViewModel: Refreshing analytics data for Pro users")
        
        do {
            // Generate check-in data for the consistency calendar directly from challenges
            let checkInData = generateCheckInMapFromChallenges()
            
            // Update the date intensity map
            self.dateIntensityMap = checkInData
            
            // Calculate advanced analytics
            await calculateAdvancedAnalytics()
            
            // Synchronize with global stats
            await synchronizeWithGlobalStats()
            
            print("ProgressDashboardViewModel: Analytics data refresh completed")
        } catch {
            print("ProgressDashboardViewModel: Error refreshing analytics data: \(error.localizedDescription)")
        }
    }
} 