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
                // Configure Firestore for this specific request
                let db = self.firestore
                
                let challenges = try await self.loadChallenges(for: userId, db: db)
                
                if Task.isCancelled { 
                    timeoutTask.cancel()
                    return 
                }
                
                // Calculate overall progress
                let overallProgress = self.calculateOverallProgress(challenges)
                
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
    @Published var journeyCards: [JourneyCard] = []
    @Published var recentPhotosNotes: [(photo: URL?, note: String, dayNumber: Int, date: Date)] = []
    
    // Firestore reference
    private let firestore = Firestore.firestore()
    private var loadTask: Task<Void, Never>?
    
    deinit {
        loadTask?.cancel()
    }
    
    func loadData(forceRefresh: Bool = false) async {
        if isLoading && !forceRefresh {
            return
        }
        
        // Cancel any previous loading task
        loadTask?.cancel()
        
        loadTask = Task { [weak self] in
            guard let self = self else { return }
            
            await MainActor.run {
                self.isLoading = true
                self.errorMessage = nil
            }
            
            // Simple delay to simulate data loading
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            
            if Task.isCancelled { return }
            
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
            
            await MainActor.run {
                // Set the sample data
                self.totalChallenges = sampleData.totalChallenges
                self.currentStreak = sampleData.currentStreak
                self.longestStreak = sampleData.longestStreak
                self.completionPercentage = sampleData.completionPercentage
                self.journeyCards = sampleData.journeyCards
                self.dateIntensityMap = sampleData.dateIntensityMap
                self.dailyCheckInsData = sampleData.dailyCheckInsData
                self.projectedCompletionDate = sampleData.projectedCompletionDate
                self.currentPace = sampleData.currentPace
                self.earnedBadges = sampleData.earnedBadges
                
                // Mark as loaded with data
                self.hasData = true
                self.isLoading = false
            }
        }
    }
    
    private func generateSampleData() -> (
        totalChallenges: Int,
        currentStreak: Int,
        longestStreak: Int,
        completionPercentage: Double,
        journeyCards: [JourneyCard],
        dateIntensityMap: [Date: Int],
        dailyCheckInsData: [ProgressDailyCheckIn],
        projectedCompletionDate: Date?,
        currentPace: String,
        earnedBadges: [ProgressBadge]
    ) {
        // Generate some reasonable sample data
        let totalChallenges = Int.random(in: 1...3)
        let currentStreak = Int.random(in: 1...15)
        let longestStreak = max(currentStreak, Int.random(in: 10...30))
        let completionPercentage = Double.random(in: 0.1...0.6)
        
        // Journey cards
        var journeyCards: [JourneyCard] = []
        
        // Add milestone cards
        for i in 1...5 {
            let dayNumber = i * 10
            let daysAgo = 30 - (i * 5)
            let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
            journeyCards.append(JourneyCard.milestoneCard(dayNumber: dayNumber, date: date))
        }
        
        // Heat map data
        var dateIntensityMap: [Date: Int] = [:]
        for i in 0..<30 {
            if Bool.random() && i % 3 != 0 {
                let date = Calendar.current.date(byAdding: .day, value: -i, to: Date()) ?? Date()
                let startOfDay = Calendar.current.startOfDay(for: date)
                dateIntensityMap[startOfDay] = Int.random(in: 1...3)
            }
        }
        
        // Daily check-ins for graph
        var dailyCheckInsData: [ProgressDailyCheckIn] = []
        for i in 0..<7 {
            let date = Calendar.current.date(byAdding: .day, value: -i, to: Date()) ?? Date()
            let count = Int.random(in: 0...3)
            dailyCheckInsData.append(ProgressDailyCheckIn(date: date, count: count))
        }
        
        // Projected completion
        let projectedCompletionDate = Calendar.current.date(byAdding: .day, value: Int.random(in: 30...90), to: Date())
        let currentPace = String(format: "%.1f days/week", Double.random(in: 3.0...6.5))
        
        // Badges
        var earnedBadges: [ProgressBadge] = []
        earnedBadges.append(ProgressBadge(id: 1, title: "7-Day Streak", iconName: "flame.fill"))
        
        if longestStreak >= 14 {
            earnedBadges.append(ProgressBadge(id: 2, title: "14-Day Streak", iconName: "flame.fill"))
        }
        
        earnedBadges.append(ProgressBadge(id: 3, title: "First Challenge", iconName: "flag.fill"))
        
        if completionPercentage >= 0.25 {
            earnedBadges.append(ProgressBadge(id: 4, title: "25% Complete", iconName: "chart.bar.fill"))
        }
        
        return (
            totalChallenges: totalChallenges,
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            completionPercentage: completionPercentage,
            journeyCards: journeyCards,
            dateIntensityMap: dateIntensityMap,
            dailyCheckInsData: dailyCheckInsData,
            projectedCompletionDate: projectedCompletionDate,
            currentPace: currentPace,
            earnedBadges: earnedBadges
        )
    }
} 