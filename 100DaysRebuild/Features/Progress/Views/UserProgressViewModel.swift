import SwiftUI
import Combine
import FirebaseFirestore
import FirebaseAuth

// Renamed to avoid conflict with the UserProgressViewModel in ProgressView.swift
@MainActor
class UserProgressViewModelImpl: ObservableObject {
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
    private var networkMonitor = NetworkMonitor.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupNetworkMonitoring()
    }
    
    deinit {
        loadTask?.cancel()
        cancellables.forEach { $0.cancel() }
    }
    
    private func setupNetworkMonitoring() {
        networkMonitor.connectionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                self?.isNetworkConnected = isConnected
                
                // If we come back online and had an error, try loading again
                if isConnected && self?.errorMessage != nil {
                    Task {
                        await self?.loadData(forceRefresh: true)
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    func loadData(forceRefresh: Bool = false) async {
        // Don't load if already loading unless forced
        if isLoading && !forceRefresh { return }
        
        // Cancel existing task if any
        loadTask?.cancel()
        
        loadTask = Task { [weak self] in
            guard let self = self else { return }
            
            // Setup timeout
            let timeoutTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(15 * 1_000_000_000)) // 15 second timeout
                if self.isLoading {
                    self.errorMessage = "Request timed out. Please try again."
                    self.isLoading = false
                }
            }
            
            self.isLoading = true
            self.errorMessage = nil
            
            // Verify user authentication
            guard let userId = Auth.auth().currentUser?.uid else {
                self.errorMessage = "You must be logged in to view progress"
                self.isLoading = false
                timeoutTask.cancel()
                return
            }
            
            // Check network connectivity
            if !self.isNetworkConnected && !self.hasData {
                self.errorMessage = "You're offline. Connect to the internet to load your progress."
                self.isLoading = false
                timeoutTask.cancel()
                return
            }
            
            do {
                // Load challenges and check-ins with better error handling
                var challenges: [Challenge] = []
                
                do {
                    let challengesQuery = firestore
                        .collection("users")
                        .document(userId)
                        .collection("challenges")
                    
                    let source: FirestoreSource = self.isNetworkConnected ? .default : .cache
                    let challengesSnapshot = try await challengesQuery.getDocuments(source: source)
                    
                    if Task.isCancelled {
                        timeoutTask.cancel()
                        return
                    }
                    
                    // Parse challenges
                    for document in challengesSnapshot.documents {
                        if Task.isCancelled {
                            timeoutTask.cancel()
                            return
                        }
                        
                        do {
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
                                
                                // Determine if completed today
                                let isCompletedToday: Bool
                                if let lastCheckIn = lastCheckInDate {
                                    isCompletedToday = Calendar.current.isDateInToday(lastCheckIn)
                                } else {
                                    isCompletedToday = false
                                }
                                
                                // Make this parsing potentially throw to make the catch block valid
                                try Task.checkCancellation()
                                
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
                            }
                        } catch {
                            print("Error parsing challenge: \(error.localizedDescription)")
                            continue
                        }
                    }
                } catch {
                    print("Error loading challenges: \(error.localizedDescription)")
                    if !self.isNetworkConnected {
                        self.errorMessage = "You're offline. Connect to the internet to load your progress."
                    } else {
                        self.errorMessage = "Failed to load challenges: \(error.localizedDescription)"
                    }
                    self.isLoading = false
                    timeoutTask.cancel()
                    return
                }
                
                if challenges.isEmpty {
                    // No data available
                    self.hasData = false
                    self.isLoading = false
                    timeoutTask.cancel()
                    return
                }
                
                // Calculate metrics
                let totalChallengesCount = challenges.count
                let currentStreakCount = self.calculateCurrentStreak(challenges)
                let longestStreakCount = self.calculateLongestStreak(challenges)
                let overallCompletionRate = self.calculateCompletionRate(challenges)
                
                // Generate data for heatmap from check-ins
                var intensityMap: [Date: Int] = [:]
                
                // Get check-ins for heatmap
                if self.isNetworkConnected || forceRefresh {
                    for challenge in challenges {
                        if Task.isCancelled {
                            timeoutTask.cancel()
                            return
                        }
                        
                        do {
                            let checkInsRef = self.firestore
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
                            
                            let source: FirestoreSource = self.isNetworkConnected ? .default : .cache
                            let checkInsSnapshot = try await checkInsQuery.getDocuments(source: source)
                            
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
                            // Continue with other challenges
                        }
                    }
                }
                
                // Calculate badges
                let earnedBadges = self.calculateEarnedBadges(challenges)
                
                if Task.isCancelled {
                    timeoutTask.cancel()
                    return
                }
                
                // Generate journey cards
                let journeyCards = await self.generateJourneyCards(challenges: challenges, userId: userId)
                
                // Update UI
                self.totalChallenges = totalChallengesCount
                self.currentStreak = currentStreakCount
                self.longestStreak = longestStreakCount
                self.completionPercentage = overallCompletionRate
                self.dateIntensityMap = intensityMap
                self.earnedBadges = earnedBadges
                self.journeyCards = journeyCards
                
                // Add a potentially throwing function call to make the catch block reachable
                try Task.checkCancellation()
                
                self.hasData = true
                self.isLoading = false
                self.errorMessage = nil
                timeoutTask.cancel()
            } catch {
                if !Task.isCancelled {
                    print("Error in progress data loading: \(error.localizedDescription)")
                    // Keep existing data if we had it
                    if !self.hasData {
                        self.errorMessage = "Failed to load progress data: \(error.localizedDescription)"
                    }
                    self.isLoading = false
                    timeoutTask.cancel()
                }
            }
        }
    }
    
    // Add the missing calculation methods
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
        let hasExpiredStreak = challenges.contains { challenge in
            guard let lastCheckIn = challenge.lastCheckInDate else { return true }
            return Calendar.current.dateComponents([.day], from: lastCheckIn, to: Date()).day ?? 0 > 1
        }
        if !challenges.isEmpty && !hasExpiredStreak {
            badges.append(ProgressBadge(id: 8, title: "Perfect Consistency", iconName: "star.fill"))
        }
        
        return badges
    }
    
    // Add this method to generate journey cards
    private func generateJourneyCards(challenges: [Challenge], userId: String) async -> [JourneyCard] {
        var cards: [JourneyCard] = []
        var recentPhotosAndNotes: [(photo: URL?, note: String, dayNumber: Int, date: Date)] = []
        let calendar = Calendar.current
        
        // First attempt to get photos and notes from check-ins
        for challenge in challenges {
            do {
                let checkInsRef = firestore
                    .collection("users")
                    .document(userId)
                    .collection("challenges")
                    .document(challenge.id.uuidString)
                    .collection("checkIns")
                    .order(by: "date", descending: true)
                    .limit(to: 10)
                
                let checkInsSnapshot = try await checkInsRef.getDocuments()
                
                if Task.isCancelled { return [] }
                
                for document in checkInsSnapshot.documents {
                    if let dateTimestamp = document.data()["date"] as? Timestamp,
                       let dayNumber = document.data()["dayNumber"] as? Int {
                        let date = dateTimestamp.dateValue()
                        let note = document.data()["note"] as? String ?? ""
                        let photoUrl = document.data()["photoUrl"] as? String
                        
                        // Only add entries with notes or photos
                        if !note.isEmpty || photoUrl != nil {
                            let url = photoUrl != nil ? URL(string: photoUrl!) : nil
                            recentPhotosAndNotes.append((photo: url, note: note, dayNumber: dayNumber, date: date))
                        }
                    }
                }
            } catch {
                print("Error loading check-ins for journey cards: \(error.localizedDescription)")
                continue
            }
        }
        
        // Update the published property for photos and notes
        await MainActor.run {
            self.recentPhotosNotes = recentPhotosAndNotes
        }
        
        // Generate photo/note cards if we have them
        for (index, item) in recentPhotosAndNotes.prefix(10).enumerated() {
            let card = JourneyCard.photoNoteCard(
                photo: item.photo,
                note: item.note,
                dayNumber: item.dayNumber,
                date: item.date
            )
            cards.append(card)
            
            // Limit to max 5 photo cards
            if index >= 4 {
                break
            }
        }
        
        // Generate milestone cards based on progress
        let completedDaysTotal = challenges.reduce(0) { $0 + $1.daysCompleted }
        let milestoneIntervals = [1, 10, 25, 30, 50, 75, 90, 100]
        
        // Add milestone day cards
        for milestone in milestoneIntervals {
            let matchingChallenges = challenges.filter { $0.daysCompleted >= milestone }
            
            if !matchingChallenges.isEmpty, let challenge = matchingChallenges.first {
                // Get approximate date when this milestone was reached
                guard let lastCheckInDate = challenge.lastCheckInDate else { continue }
                
                let daysToSubtract = challenge.daysCompleted - milestone
                guard let estimatedDate = calendar.date(byAdding: .day, value: -daysToSubtract, to: lastCheckInDate) else { continue }
                
                cards.append(JourneyCard.milestoneCard(dayNumber: milestone, date: estimatedDate))
            }
        }
        
        // Add streak cards
        if let maxStreakChallenge = challenges.max(by: { $0.streakCount < $1.streakCount }),
           maxStreakChallenge.streakCount >= 7 {
            // Add streak card if streak is significant
            cards.append(JourneyCard.streakCard(streakDays: maxStreakChallenge.streakCount, date: Date()))
        }
        
        // Add week completion cards
        let maxWeek = completedDaysTotal / 7
        if maxWeek > 0 {
            // Add week completion for latest complete week
            cards.append(JourneyCard.weekCompleteCard(weekNumber: maxWeek, date: Date()))
        }
        
        // If we still don't have enough cards, add some generic encouragement cards
        if cards.count < 3 {
            // Add a "keep going" card
            cards.append(JourneyCard.milestoneCard(
                dayNumber: completedDaysTotal + 1,
                date: Date()
            ))
            
            // Add a "next milestone" card if appropriate
            let nextMilestone = milestoneIntervals.first(where: { $0 > completedDaysTotal }) ?? 100
            if nextMilestone > completedDaysTotal {
                let daysToNextMilestone = nextMilestone - completedDaysTotal
                let message = "Only \(daysToNextMilestone) days until your next milestone!"
                let card = JourneyCard(type: .milestone(
                    message: message,
                    emoji: "🏁",
                    dayNumber: nextMilestone,
                    date: Date()
                ))
                cards.append(card)
            }
        }
        
        // Calculate average check-in frequency and projected completion
        if challenges.count > 0 && completedDaysTotal >= 3 {
            let firstChallenge = challenges.min { $0.startDate < $1.startDate }
            if let firstChallenge = firstChallenge, let firstDate = calendar.date(byAdding: .day, value: -firstChallenge.daysCompleted, to: Date()) {
                let daysSinceStart = calendar.dateComponents([.day], from: firstDate, to: Date()).day ?? 1
                
                if daysSinceStart > 0 {
                    // Calculate pace as average check-ins per week
                    let weeksActive = max(1, Double(daysSinceStart) / 7.0)
                    let checkinsPace = Double(completedDaysTotal) / weeksActive
                    let formattedPace = String(format: "%.1f", checkinsPace)
                    
                    // Calculate projected completion date
                    let daysRemaining = 100 - completedDaysTotal
                    let projectedDaysToComplete = Int(Double(daysRemaining) / (checkinsPace / 7.0))
                    let projectedDate = calendar.date(byAdding: .day, value: projectedDaysToComplete, to: Date())
                    
                    await MainActor.run {
                        self.currentPace = "\(formattedPace) days/week"
                        self.projectedCompletionDate = projectedDate
                    }
                }
            }
        }
        
        // Create weekly check-ins data for consistency graph
        var dailyCheckInsArray: [ProgressDailyCheckIn] = []
        
        // Get the last 8 weeks
        let today = Date()
        let _ = calendar.date(byAdding: .day, value: -56, to: today)! // 8 weeks
        
        for day in 0..<56 {
            if let date = calendar.date(byAdding: .day, value: day - 56, to: today) {
                let normalizedDate = calendar.startOfDay(for: date)
                let count = self.dateIntensityMap[normalizedDate] ?? 0
                dailyCheckInsArray.append(ProgressDailyCheckIn(date: normalizedDate, count: count))
            }
        }
        
        await MainActor.run {
            self.dailyCheckInsData = dailyCheckInsArray
        }
        
        // Sort cards by relevance/date and return
        return cards.sorted { lhs, rhs in
            // Helper function to get date from card
            func getDate(from card: JourneyCard) -> Date {
                switch card.type {
                case .photoNote(_, _, _, let date):
                    return date
                case .milestone(_, _, _, let date):
                    return date
                }
            }
            
            // Sort by most recent first
            return getDate(from: lhs) > getDate(from: rhs)
        }
    }
} 