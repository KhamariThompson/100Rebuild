import Foundation
import SwiftUI
import FirebaseFirestore
import Network
import Combine
import Firebase
import FirebaseFirestore
import FirebaseStorage
import UIKit

// Using canonical Challenge model
// (No import needed as it will be accessed directly)

@MainActor
class ChallengesViewModel: ObservableObject {
    @Published var challenges: [Challenge] = []
    @Published var isLoading = false
    @Published var isInitialLoad = true
    @Published var error: String?
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var isShowingNewChallenge = false
    @Published var challengeTitle = ""
    @Published var isOffline = false
    
    // New properties for greeting and last check-in
    @Published var userName: String = ""
    @Published var userFirstName: String = ""
    @Published var lastCheckInDate: Date? = nil
    @Published var timeSinceLastCheckIn: TimeInterval = 0
    @Published var currentTimeOfDay: TimeOfDay = .morning
    
    // Timer for updating the time since last check-in
    private var timerCancellable: AnyCancellable?
    private var subscriptions = Set<AnyCancellable>()
    
    private let userSession = UserSession.shared
    private let challengeStore = ChallengeStore.shared
    private let challengeService = ChallengeService.shared
    private let networkMonitor = NetworkMonitor.shared
    
    // Enum for time of day greeting
    enum TimeOfDay {
        case morning
        case afternoon
        case evening
        
        var greeting: String {
            switch self {
            case .morning: return "Good morning"
            case .afternoon: return "Good afternoon"
            case .evening: return "Good evening"
            }
        }
        
        var emoji: String {
            switch self {
            case .morning: return "👋"
            case .afternoon: return "☀️"
            case .evening: return "🌙"
            }
        }
    }
    
    init() {
        // Set up subscriptions to ChallengeStore
        setupChallengeStoreSubscriptions()
        
        // Set the current time of day
        updateTimeOfDay()
        
        // Start timer to update the time since last check-in
        startTimer()
        
        // Initial data load
        Task {
            await loadUserProfile()
            await loadChallenges()
        }
        
        // Observe user profile updates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUserProfileUpdated),
            name: NSNotification.Name("UserProfileUpdated"),
            object: nil
        )
    }
    
    deinit {
        timerCancellable?.cancel()
        subscriptions.removeAll()
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleUserProfileUpdated(_ notification: Notification) {
        // Reload user profile to update name
        Task {
            await loadUserProfile()
        }
    }
    
    private func setupChallengeStoreSubscriptions() {
        // Subscribe to challenges updates from the store
        challengeStore.$challenges
            .receive(on: RunLoop.main)
            .sink { [weak self] storesChallenges in
                guard let self = self else { return }
                self.challenges = storesChallenges.filter { !$0.isArchived }
                self.updateLastCheckInDate()
                self.isLoading = false
                self.isInitialLoad = false
            }
            .store(in: &subscriptions)
        
        // Subscribe to store's loading state
        challengeStore.$isLoading
            .receive(on: RunLoop.main)
            .sink { [weak self] isLoading in
                self?.isLoading = isLoading
            }
            .store(in: &subscriptions)
        
        // Subscribe to store's error
        challengeStore.$error
            .compactMap { $0 }
            .receive(on: RunLoop.main)
            .sink { [weak self] error in
                self?.error = error.localizedDescription
                self?.showError = true
                self?.errorMessage = "Failed to load challenges: \(error.localizedDescription)"
            }
            .store(in: &subscriptions)
        
        // Subscribe to network status
        NotificationCenter.default.publisher(for: NetworkMonitor.networkStatusChanged)
            .compactMap { $0.userInfo?["isConnected"] as? Bool }
            .sink { [weak self] isConnected in
                self?.isOffline = !isConnected
                if isConnected {
                    // Refresh when back online
                    Task {
                        await self?.loadChallenges()
                    }
                }
            }
            .store(in: &subscriptions)
    }
    
    func loadChallenges() async {
        guard userSession.currentUser != nil else { 
            challenges = []
            return 
        }
        
        isLoading = true
        error = nil
        
        // Use the centralized store to load challenges
        await challengeStore.refreshChallenges()
    }
    
    func createChallenge(title: String, isTimed: Bool = false) async {
        guard let userId = userSession.currentUser?.uid else { 
            showError = true
            errorMessage = "You must be signed in to create a challenge"
            return 
        }
        
        isLoading = true
        error = nil
        
        do {
            // Use the challenge service to create challenge - it handles permissions and limits
            try await challengeService.createChallenge(title: title, userId: userId)
            
            isLoading = false
            challengeTitle = ""
            isShowingNewChallenge = false
            
            // Refresh challenges after creation
            await loadChallenges()
        } catch {
            isLoading = false
            self.error = error.localizedDescription
            self.showError = true
            self.errorMessage = "Failed to create challenge: \(error.localizedDescription)"
        }
    }
    
    func loadUserProfile() async {
        guard let userId = userSession.currentUser?.uid else { return }
        
        do {
            let profile = try await FirebaseService.shared.fetchUserProfile(userId: userId)
            userName = profile?.displayName ?? ""
            
            // Extract first name
            if let firstName = userName.components(separatedBy: " ").first, !firstName.isEmpty {
                userFirstName = firstName
            } else {
                userFirstName = userName
            }
        } catch {
            print("Failed to load user profile: \(error.localizedDescription)")
        }
    }
    
    func updateTimeOfDay() {
        let hour = Calendar.current.component(.hour, from: Date())
        
        switch hour {
        case 5..<12:
            currentTimeOfDay = .morning
        case 12..<18:
            currentTimeOfDay = .afternoon
        default:
            currentTimeOfDay = .evening
        }
    }
    
    private func startTimer() {
        // Update immediately then every minute
        updateTimeSinceLastCheckIn()
        
        timerCancellable = Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateTimeSinceLastCheckIn()
            }
    }
    
    private func updateTimeSinceLastCheckIn() {
        guard let lastCheckIn = lastCheckInDate else {
            timeSinceLastCheckIn = 0
            return
        }
        
        timeSinceLastCheckIn = Date().timeIntervalSince(lastCheckIn)
    }
    
    private func updateLastCheckInDate() {
        // Use the store's last check-in date
        lastCheckInDate = challengeStore.lastCheckInDate
        updateTimeSinceLastCheckIn()
    }
    
    func deleteChallenge(_ challenge: Challenge) async -> Result<Void, Error> {
        isLoading = true
        
        do {
            guard let userId = userSession.currentUser?.uid else {
                throw ChallengeError.userNotAuthenticated
            }
            
            // Use the store to delete the challenge
            try await challengeService.deleteChallenge(id: challenge.id, userId: userId)
            isLoading = false
            return .success(())
        } catch {
            isLoading = false
            self.error = error.localizedDescription
            self.showError = true
            self.errorMessage = "Failed to delete challenge: \(error.localizedDescription)"
            return .failure(error)
        }
    }
    
    func refreshChallenges() async {
        await loadChallenges()
    }
    
    // MARK: - Challenge Management Methods
    
    /// Archive a challenge
    func archiveChallenge(_ challenge: Challenge) async -> Result<Challenge, Error> {
        do {
            try await challengeService.archiveChallenge(challenge)
            return .success(challenge)
        } catch {
            showError = true
            errorMessage = "Failed to archive challenge: \(error.localizedDescription)"
            return .failure(error)
        }
    }
    
    /// Perform check-in to a challenge
    func checkInToChallenge(_ challenge: Challenge, note: String = "", image: UIImage? = nil) async -> Result<Void, Error> {
        isLoading = true
        
        do {
            // Start by performing the basic check-in using the CheckInService
            try await CheckInService.shared.checkIn(for: challenge.id.uuidString)
            
            // If there's a note, save it (implement separately if needed)
            if !note.isEmpty {
                // Note: Implement note saving logic directly here as needed
                print("Note for challenge: \(note)")
            }
            
            // If there's an image, upload it (implement separately if needed)
            if let image = image {
                // Note: Implement image upload logic directly here as needed
                print("Image provided for check-in")
            }
            
            // Update the local challenges data
            await loadChallenges()
            
            // Refresh user stats to ensure they're up to date
            await refreshUserStats()
            
            isLoading = false
            return .success(())
        } catch {
            isLoading = false
            return .failure(error)
        }
    }
    
    // Helper to refresh the user stats
    private func refreshUserStats() async {
        do {
            // Update the last check-in date locally
            updateLastCheckInDate()
            
            // Update UserStatsService to ensure consistency across the app
            await UserStatsService.shared.refreshUserStats()
            
            print("User stats updated successfully")
        } catch {
            print("Error updating user stats: \(error.localizedDescription)")
        }
    }
    
    /// Update a challenge
    func updateChallenge(id: UUID, title: String) async {
        guard let challenge = challenges.first(where: { $0.id == id }) else {
            showError = true
            errorMessage = "Challenge not found"
            return
        }
        
        isLoading = true
        
        var updatedChallenge = challenge
        updatedChallenge.title = title
        updatedChallenge.lastModified = Date()
        
        do {
            try await challengeService.updateChallenge(updatedChallenge)
            isLoading = false
        } catch {
            isLoading = false
            showError = true
            errorMessage = "Failed to update challenge: \(error.localizedDescription)"
        }
    }
    
    /// Get the greeting based on time of day and user's name
    func getGreeting() -> String {
        if userFirstName.isEmpty {
            return "\(currentTimeOfDay.greeting)!"
        } else {
            return "\(currentTimeOfDay.greeting), \(userFirstName)!"
        }
    }
    
    /// Format the time since last check-in
    func formattedTimeSinceLastCheckIn() -> String {
        guard let _ = lastCheckInDate else {
            return "0hr 0min 0sec"
        }
        
        let hours = Int(timeSinceLastCheckIn) / 3600
        let minutes = Int(timeSinceLastCheckIn) % 3600 / 60
        let seconds = Int(timeSinceLastCheckIn) % 60
        
        return "\(hours)hr \(minutes)min \(seconds)sec"
    }
    
    // MARK: - Helper Properties
    
    // Return the highest streak count from all challenges
    var maxStreak: Int {
        challenges.map(\.streakCount).max() ?? 0
    }
    
    /// Get the most urgent challenge (close to breaking streak)
    var mostUrgentChallenge: Challenge? {
        // Find challenges where:
        // 1. The challenge has not been completed today
        // 2. The challenge isn't completed (all 100 days)
        // 3. The streak is at risk (not checked in yesterday)
        // 4. Sort by highest streak count first to prioritize preserving longer streaks
        
        let urgentChallenges = challenges.filter { challenge in
            !challenge.isCompletedToday && 
            !challenge.isCompleted && 
            challenge.hasStreakExpired
        }
        
        return urgentChallenges.max(by: { $0.streakCount < $1.streakCount })
    }
    
    /// Check if the user has any active streaks
    var hasActiveStreaks: Bool {
        challenges.contains { $0.streakCount > 0 }
    }
} 