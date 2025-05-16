import Foundation
import SwiftUI
import FirebaseFirestore
import Network
import Combine

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
    }
    
    deinit {
        timerCancellable?.cancel()
        subscriptions.removeAll()
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
        
        // Create the challenge with current timestamp
        let challenge = Challenge(
            title: title,
            ownerId: userId,
            lastModified: Date(),
            isTimed: isTimed
        )
        
        do {
            // Use the store to save the challenge
            try await challengeStore.saveChallenge(challenge)
            isLoading = false
            challengeTitle = ""
            isShowingNewChallenge = false
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
    
    /// Check in to a challenge
    func checkInToChallenge(_ challenge: Challenge) async -> Result<Challenge, Error> {
        do {
            let updatedChallenge = try await challengeService.checkIn(to: challenge)
            return .success(updatedChallenge)
        } catch {
            showError = true
            errorMessage = "Failed to check in: \(error.localizedDescription)"
            return .failure(error)
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
            return "0h 0m 0s"
        }
        
        let hours = Int(timeSinceLastCheckIn) / 3600
        let minutes = Int(timeSinceLastCheckIn) % 3600 / 60
        let seconds = Int(timeSinceLastCheckIn) % 60
        
        return "\(hours)h \(minutes)m \(seconds)s"
    }
} 