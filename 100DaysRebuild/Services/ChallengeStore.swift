import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Combine

/// Central store for all challenge-related data to ensure consistency across the app
@MainActor
class ChallengeStore: ObservableObject {
    // Singleton instance
    static let shared = ChallengeStore()
    
    // Published challenge data
    @Published private(set) var challenges: [Challenge] = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastRefreshTime: Date? = nil
    @Published private(set) var error: Error? = nil
    @Published private(set) var activeChallenge: Challenge? = nil
    
    // Challenge data metrics
    @Published private(set) var totalChallenges: Int = 0
    @Published private(set) var completedChallenges: Int = 0
    @Published private(set) var currentStreak: Int = 0
    @Published private(set) var longestStreak: Int = 0
    @Published private(set) var overallCompletionPercentage: Double = 0
    @Published private(set) var lastCheckInDate: Date? = nil
    
    // Dependencies
    private let firestore = Firestore.firestore()
    private var loadTask: Task<Void, Never>? = nil
    private var cancellables = Set<AnyCancellable>()
    private let userSession = UserSession.shared
    private let networkMonitor = NetworkMonitor.shared
    
    // Challenge update notification
    static let challengesDidUpdateNotification = Notification.Name("challengesDidUpdate")
    
    // Cache key for storing challenges locally
    private var localChallengesKey: String {
        guard let userId = userSession.currentUser?.uid else { return "challenges_cache" }
        return "challenges_cache_\(userId)"
    }
    
    private init() {
        // Listen for auth changes to refresh challenges
        userSession.$currentUser
            .sink { [weak self] user in
                if user != nil {
                    Task { [weak self] in
                        await self?.refreshChallenges()
                    }
                } else {
                    // Clear challenges when logged out
                    self?.challenges = []
                    self?.updateMetrics()
                    self?.saveChallengesLocally()
                }
            }
            .store(in: &cancellables)
        
        // Listen for network status changes
        NotificationCenter.default.publisher(for: NetworkMonitor.networkStatusChanged)
            .compactMap { $0.userInfo?["isConnected"] as? Bool }
            .filter { $0 } // Only care when network is restored
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.refreshChallenges()
                }
            }
            .store(in: &cancellables)
    }
    
    deinit {
        loadTask?.cancel()
        cancellables.removeAll()
    }
    
    /// Refresh challenges from Firestore
    func refreshChallenges() async {
        guard let userId = userSession.currentUser?.uid else { 
            challenges = []
            updateMetrics()
            saveChallengesLocally()
            return 
        }
        
        // Cancel any existing task
        loadTask?.cancel()
        
        // First load from cache for immediate response
        let hasCachedData = loadChallengesFromCache()
        
        // Set loading state only if we don't have cached data
        if !hasCachedData {
            isLoading = true
        }
        
        error = nil
        
        // Return early if offline but we have cached data
        if networkMonitor.isConnected == false {
            isLoading = false
            updateMetrics()
            return
        }
        
        // Use separate task for network operations to keep UI responsive
        loadTask = Task { [weak self] in
            guard let self = self else { return }
            
            do {
                let snapshot = try await firestore
                    .collection("users")
                    .document(userId)
                    .collection("challenges")
                    .getDocuments()
                
                if Task.isCancelled { return }
                
                let fetchedChallenges = snapshot.documents.compactMap { doc -> Challenge? in
                    try? doc.data(as: Challenge.self)
                }
                
                // Update challenges with proper isCompletedToday state
                let updatedChallenges = fetchedChallenges.map { challenge in
                    challenge.checkIfCompletedToday()
                }
                
                // Sort challenges by lastModified (most recent first) and active before archived
                let sortedChallenges = updatedChallenges.sorted { (a, b) -> Bool in
                    if a.isArchived != b.isArchived {
                        return !a.isArchived
                    }
                    return a.lastModified > b.lastModified
                }
                
                await MainActor.run {
                    self.challenges = sortedChallenges
                    self.updateMetrics()
                    self.lastRefreshTime = Date()
                    self.saveChallengesLocally()
                    self.isLoading = false
                    
                    // Notify observers that challenges have been updated
                    NotificationCenter.default.post(name: Self.challengesDidUpdateNotification, object: nil)
                    // Trigger feature recomputations (momentum & forecast)
                    ProgressDashboardViewModel.shared.triggerFeatureComputations()
                }
            } catch {
                if !Task.isCancelled {
                    await MainActor.run {
                        self.error = error
                        self.isLoading = false
                        print("Error loading challenges: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    /// Save a challenge (create or update)
    func saveChallenge(_ challenge: Challenge) async throws {
        print("🔄 Starting saveChallenge for: \(challenge.id), title: \(challenge.title), isArchived: \(challenge.isArchived)")
        
        guard let userId = userSession.currentUser?.uid else {
            print("❌ ERROR: User not authenticated when saving challenge")
            throw ChallengeError.userNotAuthenticated
        }
        
        print("👤 User authenticated: \(userId)")
        
        do {
            // Update to Firestore
            let challengeRef = firestore
                .collection("users")
                .document(userId)
                .collection("challenges")
                .document(challenge.id.uuidString)
            
            let challengeData = challenge.asDictionary()
            print("📝 Challenge data prepared for Firestore")
            
            try await challengeRef.setData(challengeData)
            print("✅ Challenge saved to Firestore successfully: \(challenge.id)")
            
            // Update local challenges array
            await updateLocalChallenges(challenge)
            print("📱 Local challenges updated with: \(challenge.id)")
            
            // Notify observers
            NotificationCenter.default.post(name: Self.challengesDidUpdateNotification, object: nil)
            print("📢 Notification sent for challenge update")
            
            return
        } catch {
            print("❌ ERROR saving challenge: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Delete a challenge
    func deleteChallenge(id: UUID) async throws {
        guard let userId = userSession.currentUser?.uid else {
            throw ChallengeError.userNotAuthenticated
        }
        
        // Delete from Firestore
        let challengeRef = firestore
            .collection("users")
            .document(userId)
            .collection("challenges")
            .document(id.uuidString)
        
        try await challengeRef.delete()
        
        // Update local challenges array
        await MainActor.run {
            challenges.removeAll { $0.id == id }
            updateMetrics()
            saveChallengesLocally()
            
            // Notify observers
            NotificationCenter.default.post(name: Self.challengesDidUpdateNotification, object: nil)
        }
    }
    
    /// Check-in to a challenge
    func checkIn(to challengeId: UUID) async throws -> Challenge {
        guard let challenge = challenges.first(where: { $0.id == challengeId }) else {
            throw ChallengeError.notFound
        }
        
        // Prevent check-in if challenge is completed
        guard !challenge.isCompleted else {
            throw ChallengeError.challengeCompleted
        }
        
        let effectiveDate = ChallengeService.shared.effectiveCheckInDate()
        
        // Prevent multiple check-ins per day
        if let lastCheckIn = challenge.lastCheckInDate,
           Calendar.current.isDate(lastCheckIn, inSameDayAs: effectiveDate) {
            throw ChallengeError.alreadyCheckedIn
        }
        
        // Update challenge with check-in
        let updatedChallenge = challenge.afterCheckIn()
        
        // Save to Firestore
        try await saveChallenge(updatedChallenge)
        
        return updatedChallenge
    }
    
    /// Get active challenges (not archived)
    func getActiveChallenges() -> [Challenge] {
        let activeOnes = challenges.filter { !$0.isArchived }
        print("ChallengeStore: getActiveChallenges found \(activeOnes.count) active challenges")
        
        if activeOnes.isEmpty {
            print("ChallengeStore: Warning - No active challenges found!")
        } else {
            // Print first 3 challenges for debugging
            for (index, challenge) in activeOnes.prefix(3).enumerated() {
                print("ChallengeStore: Active challenge #\(index+1): \(challenge.title), ID: \(challenge.id)")
            }
        }
        
        return activeOnes
    }
    
    /// Get archived challenges
    func getArchivedChallenges() -> [Challenge] {
        challenges.filter { $0.isArchived }
    }
    
    /// Get a specific challenge by ID
    func getChallenge(id: UUID) -> Challenge? {
        challenges.first { $0.id == id }
    }
    
    /// Update a challenge locally for optimistic UI updates before Firebase sync completes
    @MainActor
    func updateLocalChallengeForOptimisticUI(challengeId: UUID) throws {
        // Find the challenge in the local array
        guard let index = challenges.firstIndex(where: { $0.id == challengeId }) else {
            throw ChallengeError.notFound
        }
        
        // Get a copy of the challenge
        var challenge = challenges[index]
        
        // Skip if already completed today or fully completed
        if challenge.isCompletedToday || challenge.isCompleted {
            return
        }
        
        // Apply the same logic as in Challenge.afterCheckIn() but directly here for speed
        let now = Date()
        let calendar = Calendar.current
        var newStreakCount = challenge.streakCount
        
        if let lastCheckIn = challenge.lastCheckInDate {
            let today = calendar.startOfDay(for: now)
            let lastCheckInDay = calendar.startOfDay(for: lastCheckIn)
            let daysBetween = calendar.dateComponents([.day], from: lastCheckInDay, to: today).day ?? 0
            
            if daysBetween == 1 {
                // Checked in yesterday, continue streak
                newStreakCount += 1
            } else if daysBetween > 1 {
                // Streak broken, start new streak
                newStreakCount = 1
            }
        } else {
            // First check-in
            newStreakCount = 1
        }
        
        // Update challenge properties
        challenge.lastCheckInDate = now
        challenge.isCompletedToday = true
        challenge.streakCount = newStreakCount
        challenge.daysCompleted += 1
        challenge.lastModified = now
        
        // Update in the local array
        challenges[index] = challenge
        
        // Update derived metrics
        updateMetrics()
        
        // Post notification to update UI
        NotificationCenter.default.post(name: Self.challengesDidUpdateNotification, object: nil)
    }
    
    /// Refresh a specific challenge by ID
    func refreshChallenge(id: UUID) async {
        guard let userId = userSession.currentUser?.uid else { return }
        
        do {
            print("🔄 Starting refresh for specific challenge: \(id)")
            
            // Fetch the challenge from Firestore
            let challengeRef = firestore
                .collection("users")
                .document(userId)
                .collection("challenges")
                .document(id.uuidString)
            
            let document = try await challengeRef.getDocument()
            
            if document.exists, let data = document.data() {
                // Convert to Challenge
                do {
                    let refreshedChallenge = try document.data(as: Challenge.self)
                    print("✅ Successfully fetched challenge \(id) from Firestore")
                    
                    // Update in the local array
                    await updateLocalChallenges(refreshedChallenge)
                    
                    // Post notification with specifics about which challenge was updated
                    await MainActor.run {
                        print("📢 Posting notification that challenge \(id) was refreshed")
                        NotificationCenter.default.post(
                            name: Self.challengesDidUpdateNotification, 
                            object: nil,
                            userInfo: ["refreshedChallengeId": id]
                        )
                    }
                } catch {
                    print("❌ Error parsing challenge: \(error.localizedDescription)")
                }
            } else {
                print("⚠️ Challenge \(id) not found in Firestore")
            }
        } catch {
            print("❌ Error refreshing challenge \(id): \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Methods
    
    /// Update local challenges array with a new or modified challenge
    private func updateLocalChallenges(_ challenge: Challenge) async {
        await MainActor.run {
            // Find the index of the challenge with the same ID if it exists
            if let index = challenges.firstIndex(where: { $0.id == challenge.id }) {
                // Replace the existing challenge
                challenges[index] = challenge
            } else {
                // Add new challenge
                challenges.append(challenge)
            }
            
            // Sort challenges by lastModified and active status
            challenges.sort { (a, b) -> Bool in
                if a.isArchived != b.isArchived {
                    return !a.isArchived
                }
                return a.lastModified > b.lastModified
            }
            
            updateMetrics()
            saveChallengesLocally()
        }
    }
    
    /// Update metrics based on current challenges
    private func updateMetrics() {
        // Count metrics - only count active challenges, not archived ones
        totalChallenges = challenges.filter { !$0.isArchived }.count
        // activeChallenges is now calculated dynamically via getActiveChallenges()
        completedChallenges = challenges.filter { $0.isCompleted }.count
        
        // Find current streak
        let activeStreaks = challenges
            .filter { !$0.isArchived && $0.isStreakActive() }
            .map { $0.streakCount }
        currentStreak = activeStreaks.max() ?? 0
        
        // Find longest streak
        longestStreak = challenges.map { $0.streakCount }.max() ?? 0
        
        // Calculate overall completion percentage
        if totalChallenges > 0 {
            let totalCompletedDays = challenges.filter { !$0.isArchived }.reduce(0) { $0 + $1.daysCompleted }
            let totalPossibleDays = totalChallenges * 100
            overallCompletionPercentage = min(1.0, Double(totalCompletedDays) / Double(totalPossibleDays))
        } else {
            overallCompletionPercentage = 0.0
        }
        
        // Find last check-in date
        lastCheckInDate = challenges
            .compactMap { $0.lastCheckInDate }
            .max()
        
        // Identify the most recent active challenge
        activeChallenge = challenges
            .filter { !$0.isArchived }
            .sorted { $0.lastModified > $1.lastModified }
            .first
            
        // Notify observers about the updated metrics
        NotificationCenter.default.post(name: Self.challengesDidUpdateNotification, object: nil)
    }
    
    /// Load challenges from local cache
    private func loadChallengesFromCache() -> Bool {
        guard let data = UserDefaults.standard.data(forKey: localChallengesKey) else { return false }
        
        do {
            let decodedChallenges = try JSONDecoder().decode([Challenge].self, from: data)
            if !decodedChallenges.isEmpty {
                // Only use cache if we don't already have challenges loaded
                if challenges.isEmpty {
                    // Make sure all challenges have proper isCompletedToday state
                    challenges = decodedChallenges.map { challenge in
                        challenge.checkIfCompletedToday()
                    }
                    updateMetrics()
                }
                return true
            }
        } catch {
            print("Error loading challenges from cache: \(error)")
        }
        return false
    }
    
    /// Save challenges to local cache
    private func saveChallengesLocally() {
        do {
            let data = try JSONEncoder().encode(challenges)
            UserDefaults.standard.set(data, forKey: localChallengesKey)
        } catch {
            print("Error saving challenges to cache: \(error)")
        }
    }
} 