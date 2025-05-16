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
    @Published private(set) var activeChallenges: Int = 0
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
        
        isLoading = true
        error = nil
        
        // First load from cache for immediate response
        loadChallengesFromCache()
        
        // Return if offline but we have cached data
        if networkMonitor.isConnected == false {
            isLoading = false
            updateMetrics()
            return
        }
        
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
        guard let userId = userSession.currentUser?.uid else {
            throw ChallengeError.userNotAuthenticated
        }
        
        // Update to Firestore
        let challengeRef = firestore
            .collection("users")
            .document(userId)
            .collection("challenges")
            .document(challenge.id.uuidString)
        
        try await challengeRef.setData(challenge.asDictionary())
        
        // Update local challenges array
        await updateLocalChallenges(challenge)
        
        // Notify observers
        NotificationCenter.default.post(name: Self.challengesDidUpdateNotification, object: nil)
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
        challenges.filter { !$0.isArchived }
    }
    
    /// Get archived challenges
    func getArchivedChallenges() -> [Challenge] {
        challenges.filter { $0.isArchived }
    }
    
    /// Get a specific challenge by ID
    func getChallenge(id: UUID) -> Challenge? {
        challenges.first { $0.id == id }
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
        // Count metrics
        totalChallenges = challenges.count
        activeChallenges = challenges.filter { !$0.isArchived }.count
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
            let totalCompletedDays = challenges.reduce(0) { $0 + $1.daysCompleted }
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
    }
    
    /// Load challenges from local cache
    private func loadChallengesFromCache() {
        guard let data = UserDefaults.standard.data(forKey: localChallengesKey) else { return }
        
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
            }
        } catch {
            print("Error loading challenges from cache: \(error)")
        }
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