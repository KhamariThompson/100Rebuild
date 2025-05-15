import Foundation
import FirebaseFirestore
import FirebaseAuth

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

class ProgressViewModel: ViewModel<ProgressState, ProgressAction> {
    private let firestore = Firestore.firestore()
    private let challengeDaysTarget = 100
    private var loadTask: Task<Void, Never>?
    private let maxRetries = 3
    private let retryDelay: TimeInterval = 2.0
    @MainActor private var userStatsService: UserStatsService { UserStatsService.shared }
    
    deinit {
        loadTask?.cancel()
    }
    
    init() {
        super.init(initialState: ProgressState())
    }
    
    override func handle(_ action: ProgressAction) {
        switch action {
        case .loadProgress:
            loadUserProgress()
        case .retryLoading:
            retryLoadProgress()
        case .viewMilestone:
            // Implemented by the navigation container
            break
        case .shareProgress:
            // Implemented by the view controller
            break
        }
    }
    
    private func retryLoadProgress() {
        if state.retryCount < maxRetries {
            state.retryCount += 1
            loadUserProgress(isRetry: true)
        } else {
            state.error = "Failed to load data after multiple attempts. Please try again later."
            state.isLoading = false
        }
    }
    
    private func loadUserProgress(isRetry: Bool = false) {
        // Avoid duplicate requests if already loading
        if state.isLoading && !isRetry { return }
        
        // If this is a fresh load (not a retry), reset retry count
        if !isRetry {
            state.retryCount = 0
        }
        
        state.isLoading = true
        state.error = nil
        
        guard let userId = Auth.auth().currentUser?.uid else {
            state.isLoading = false
            state.error = ProgressError.notAuthenticated.errorDescription
            return
        }
        
        // Cancel any existing task
        loadTask?.cancel()
        
        loadTask = Task { [weak self] in
            guard let self = self else { return }
            
            // Add a timeout mechanism
            let timeoutTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(15 * 1_000_000_000)) // 15 second timeout
                
                if self.state.isLoading {
                    await MainActor.run {
                        self.state.error = ProgressError.timeoutError.errorDescription
                        self.state.isLoading = false
                        print("Progress data loading timed out")
                    }
                }
            }
            
            do {
                // First, use the UserStatsService to fetch progress data
                let overallProgress = await MainActor.run {
                    let statsService = UserStatsService.shared
                    Task {
                        await statsService.fetchUserStats()
                    }
                    return statsService.userStats.overallCompletionPercentage
                }
                
                // We still need to load challenges to extract milestones
                // Configure Firestore for this specific request
                let db = self.firestore
                
                let challenges = try await self.loadChallenges(for: userId, db: db)
                
                if Task.isCancelled { 
                    timeoutTask.cancel()
                    return 
                }
                
                // Convert significant milestones to our data model
                let milestones = self.extractMilestones(from: challenges)
                
                if Task.isCancelled { 
                    timeoutTask.cancel()
                    return 
                }
                
                await MainActor.run {
                    if !Task.isCancelled {
                        timeoutTask.cancel()
                        self.state.overallProgress = overallProgress
                        self.state.milestones = milestones
                        self.state.isLoading = false
                        self.state.lastLoadTime = Date()
                        self.state.retryCount = 0 // Reset retry count on success
                    }
                }
            } catch let error as ProgressError {
                if !Task.isCancelled {
                    timeoutTask.cancel()
                    await MainActor.run {
                        self.state.error = error.errorDescription
                        self.state.isLoading = false
                        
                        // Auto-retry on certain errors if not already a retry
                        if !isRetry && self.state.retryCount < self.maxRetries {
                            if case .networkError = error {
                                print("Network error loading progress, will retry in \(self.retryDelay) seconds")
                                self.scheduleRetry()
                            }
                        }
                    }
                }
            } catch {
                if !Task.isCancelled {
                    timeoutTask.cancel()
                    await MainActor.run {
                        self.state.error = ProgressError.firestoreError(error).errorDescription
                        self.state.isLoading = false
                        
                        // Consider auto-retrying for generic errors too
                        if !isRetry && self.state.retryCount < self.maxRetries {
                            print("Error loading progress, will retry in \(self.retryDelay) seconds")
                            self.scheduleRetry()
                        }
                    }
                }
            }
        }
    }
    
    private func scheduleRetry() {
        // Wait a bit before retrying to give network time to recover
        Task { [weak self] in
            guard let self = self else { return }
            try await Task.sleep(nanoseconds: UInt64(self.retryDelay * 1_000_000_000))
            self.retryLoadProgress()
        }
    }
    
    private func loadChallenges(for userId: String, db: Firestore) async throws -> [ProgressChallenge] {
        let snapshot = try await db
            .collection("users")
            .document(userId)
            .collection("challenges")
            .getDocuments(source: .default) // Allow Firestore to use cache if network fails
        
        let challenges = snapshot.documents.compactMap { document in
            // Try to parse the document as our custom type
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
                
                return ProgressChallenge(
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
            }
            return nil
        }
        
        return challenges
    }
    
    // This function is kept for historical milestone extraction, but now the overall progress 
    // comes from the centralized UserStatsService
    private func calculateOverallProgress(_ challenges: [ProgressChallenge]) -> Double {
        guard !challenges.isEmpty else { return 0.0 }
        
        let totalCompletedDays = challenges.reduce(0) { $0 + $1.daysCompleted }
        let totalPossibleDays = challenges.count * challengeDaysTarget
        
        return min(1.0, Double(totalCompletedDays) / Double(totalPossibleDays))
    }
    
    private func extractMilestones(from challenges: [ProgressChallenge]) -> [Milestone] {
        var milestones: [Milestone] = []
        
        // Don't process if there are no challenges
        if challenges.isEmpty {
            return milestones
        }
        
        // Significant milestones from challenges
        for challenge in challenges {
            // Add the start of each challenge as a milestone
            milestones.append(Milestone(
                id: "start-\(challenge.id.uuidString)",
                title: "Started \(challenge.title)",
                date: challenge.startDate,
                isCompleted: true
            ))
            
            // Add completion milestone if applicable
            if challenge.isCompleted {
                milestones.append(Milestone(
                    id: "complete-\(challenge.id.uuidString)",
                    title: "Completed \(challenge.title)",
                    date: challenge.lastCheckInDate ?? challenge.startDate,
                    isCompleted: true
                ))
            }
            
            // Add milestone for reaching 25%, 50%, 75% if applicable
            let progressThresholds = [25, 50, 75]
            for threshold in progressThresholds {
                if challenge.daysCompleted >= threshold {
                    milestones.append(Milestone(
                        id: "milestone-\(threshold)-\(challenge.id.uuidString)",
                        title: "Reached \(threshold)% in \(challenge.title)",
                        date: challenge.lastCheckInDate ?? challenge.startDate,
                        isCompleted: true
                    ))
                }
            }
        }
        
        // Sort milestones by date
        return milestones.sorted(by: { $0.date > $1.date })
    }
}

// MARK: - UPViewModel Implementation
@MainActor
class ProgressDashboardViewModel: ObservableObject {
    @Published var isLoading = false
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
            
            await MainActor.run {
                self.isLoading = true
                self.errorMessage = nil
                print("ProgressDashboardViewModel - Starting data load")
            }
            
            // First, load centralized stats
            await MainActor.run {
                let _ = Task {
                    await self.userStatsService.fetchUserStats()
                }
            }
            
            // Simple delay to simulate data loading
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            
            if Task.isCancelled { 
                print("ProgressDashboardViewModel - Task was cancelled during delay")
                return 
            }
            
            // Check if the user is logged in
            guard Auth.auth().currentUser != nil else {
                await MainActor.run {
                    self.errorMessage = "You must be logged in to view progress"
                    self.isLoading = false
                    self.hasData = false
                }
                return
            }
            
            // Generate some sample data for immediate display
            let sampleData = self.generateSampleData()
            
            // Check for cancellation before updating UI
            if Task.isCancelled {
                print("ProgressDashboardViewModel - Task was cancelled before UI update")
                return
            }
            
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
                print("ProgressDashboardViewModel - Data load complete")
            }
        }
    }
    
    private func generateSampleData() -> (
        journeyCards: [JourneyCard],
        dateIntensityMap: [Date: Int],
        dailyCheckInsData: [ProgressDailyCheckIn],
        projectedCompletionDate: Date?,
        currentPace: String,
        earnedBadges: [ProgressBadge]
    ) {
        // Generate some sample journey cards
        let journeyCards: [JourneyCard] = [
            JourneyCard(type: .milestone(
                message: "First Challenge",
                emoji: "flag.fill",
                dayNumber: nil,
                date: Date().addingTimeInterval(-30*24*60*60)
            )),
            JourneyCard(type: .milestone(
                message: "One Week Streak",
                emoji: "flame.fill",
                dayNumber: nil,
                date: Date().addingTimeInterval(-14*24*60*60)
            ))
        ]
        
        // Generate sample date intensity map (for heat map)
        var dateIntensityMap: [Date: Int] = [:]
        for i in 0..<90 {
            if Bool.random() && i % 3 != 0 {
                let date = Calendar.current.date(byAdding: .day, value: -i, to: Date())!
                dateIntensityMap[date] = Int.random(in: 1...3)
            }
        }
        
        // Generate sample daily check-ins
        let dailyCheckIns: [ProgressDailyCheckIn] = [
            ProgressDailyCheckIn(date: Date().addingTimeInterval(-1*24*60*60), count: 1),
            ProgressDailyCheckIn(date: Date().addingTimeInterval(-2*24*60*60), count: 1),
            ProgressDailyCheckIn(date: Date().addingTimeInterval(-4*24*60*60), count: 2),
            ProgressDailyCheckIn(date: Date().addingTimeInterval(-5*24*60*60), count: 1)
        ]
        
        // Generate sample projected completion date
        let projectedDate = Calendar.current.date(byAdding: .day, value: 45, to: Date())
        
        // Sample current pace
        let pace = "4.5 days/week"
        
        // Sample badges
        let badges: [ProgressBadge] = [
            ProgressBadge(id: 1, title: "First Day", iconName: "checkmark.circle.fill"),
            ProgressBadge(id: 2, title: "Week Streak", iconName: "flame.fill")
        ]
        
        return (
            journeyCards: journeyCards,
            dateIntensityMap: dateIntensityMap,
            dailyCheckInsData: dailyCheckIns,
            projectedCompletionDate: projectedDate,
            currentPace: pace,
            earnedBadges: badges
        )
    }
} 