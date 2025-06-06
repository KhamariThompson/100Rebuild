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
    @Published var showUpgradePrompt = false
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
        
        // Observe sign-out preparation
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePreSignOut),
            name: NSNotification.Name("PreparingForSignOut"),
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
    
    @objc private func handlePreSignOut() {
        // Cancel any ongoing tasks
        Task { @MainActor in
            // Reset all state
            challenges = []
            isLoading = false
            isInitialLoad = true
            error = nil
            showError = false
            errorMessage = ""
            isShowingNewChallenge = false
            challengeTitle = ""
            showUpgradePrompt = false
            isOffline = false
            userName = ""
            userFirstName = ""
            lastCheckInDate = nil
            timeSinceLastCheckIn = 0
            currentTimeOfDay = .morning
            
            // Cancel timer
            timerCancellable?.cancel()
            
            // Clear subscriptions
            subscriptions.removeAll()
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
            
            // First try to get the display name from the profile
            userName = profile?.displayName ?? ""
            
            // If display name is empty, try the one from UserSession
            if userName.isEmpty {
                userName = userSession.displayName ?? ""
            }
            
            // If still empty, fall back to username as last resort
            if userName.isEmpty {
                userName = userSession.username ?? ""
            }
            
            // Extract first name
            if let firstName = userName.components(separatedBy: " ").first, !firstName.isEmpty {
                userFirstName = firstName
            } else {
                userFirstName = userName
            }
        } catch {
            print("Failed to load user profile: \(error.localizedDescription)")
            
            // Even if there's an error, try to use the displayName or username from UserSession
            if let displayName = userSession.displayName, !displayName.isEmpty {
                userName = displayName
                userFirstName = displayName.components(separatedBy: " ").first ?? displayName
            } else if let username = userSession.username {
                userName = username
                userFirstName = username.components(separatedBy: " ").first ?? username
            }
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
        // Add MainActor.run to ensure this runs on the main thread
        Task { @MainActor in
            // Safely unwrap lastCheckInDate with nil-coalescing
            lastCheckInDate = challengeStore.lastCheckInDate
            // Only call updateTimeSinceLastCheckIn after we have set the date
            updateTimeSinceLastCheckIn()
        }
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
            guard let userId = userSession.currentUser?.uid else {
                throw NSError(domain: "CheckInError", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
            }
            
            // 1. Perform the basic check-in using the CheckInService to update challenge metadata
            try await CheckInService.shared.checkIn(for: challenge.id.uuidString)
            
            // 2. Prepare standardized check-in data structure to support future consistency heatmap
            let date = Date()
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateString = dateFormatter.string(from: date)
            
            // Get a reference to Firestore
            let firestore = Firestore.firestore()
            
            // Create a reference to the structured check-in document
            let checkInRef = firestore
                .collection("users").document(userId)
                .collection("checkIns").document(dateString)
            
            // Base check-in data
            var checkInData: [String: Any] = [
                "date": date,
                "dayNumber": challenge.daysCompleted + 1,
                "challengeId": challenge.id.uuidString,
                "challengeTitle": challenge.title,
                "timestamp": FieldValue.serverTimestamp()
            ]
            
            // 3. Add journal note if provided
            if !note.isEmpty {
                checkInData["note"] = note
            }
            
            // 4. Handle image upload if provided
            if let image = image {
                // Create a storage reference with a standardized path
                let storageRef = Storage.storage().reference()
                let photoId = UUID().uuidString
                let photoRef = storageRef.child("users/\(userId)/checkIns/\(dateString)/\(photoId).jpg")
                
                // Compress the image for better performance
                guard let imageData = image.jpegData(compressionQuality: 0.7) else {
                    throw NSError(domain: "CheckInError", code: 400, userInfo: [
                        NSLocalizedDescriptionKey: "Failed to process image"
                    ])
                }
                
                // Upload the image
                let metadata = StorageMetadata()
                metadata.contentType = "image/jpeg"
                
                let _ = try await photoRef.putDataAsync(imageData, metadata: metadata)
                
                // Get download URL
                let downloadURL = try await photoRef.downloadURL()
                
                // Add photo URL to check-in data
                checkInData["photoURL"] = downloadURL.absoluteString
            }
            
            // 5. Save structured check-in data
            try await checkInRef.setData(checkInData, merge: true)
            
            // 6. Update the local challenges data
            await loadChallenges()
            
            // 7. Refresh user stats to ensure they're up to date
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
            // Update the last check-in date locally - safely on the main thread
            await MainActor.run {
                // Only try to access lastCheckInDate if it's safe to do so
                if let _ = challengeStore.lastCheckInDate {
                    updateLastCheckInDate()
                }
            }
            
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
        let calendar = Calendar.current
        let now = Date()
        
        // Calculate midnight tonight
        guard let tomorrowDate = calendar.date(byAdding: .day, value: 1, to: now) else {
            return nil
        }
        let midnight = calendar.startOfDay(for: tomorrowDate)
        
        // Calculate the cutoff time (2 hours before midnight)
        guard let twoPreviousHours = calendar.date(byAdding: .hour, value: -2, to: midnight) else {
            return nil
        }
        
        // Only show the alert if we're within 2 hours of midnight
        if now < twoPreviousHours {
            return nil
        }
        
        // Find challenges where:
        // 1. The challenge has not been completed today
        // 2. The challenge isn't completed (all 100 days)
        // 3. Has an active streak (> 0)
        let urgentChallenges = challenges.filter { challenge in
            !challenge.isCompletedToday && 
            !challenge.isCompleted && 
            challenge.streakCount > 0 &&
            !challenge.hasStreakExpired  // Only include challenges where streak is still active
        }
        
        return urgentChallenges.max(by: { $0.streakCount < $1.streakCount })
    }
    
    /// Check if the user has any active streaks
    var hasActiveStreaks: Bool {
        challenges.contains { $0.streakCount > 0 }
    }
    
    // MARK: - Navigation Methods
    
    /// Initialize the check-in process for a challenge
    func initializeCheckIn(for challenge: Challenge) {
        // This method will be used to set up state and navigate to the check-in view
        // For example, this might involve setting a selected challenge and showing a sheet
        NotificationCenter.default.post(
            name: NSNotification.Name("InitializeCheckIn"),
            object: nil,
            userInfo: ["challenge": challenge]
        )
    }
    
    /// Prepare to edit a challenge
    func prepareToEditChallenge(_ challenge: Challenge) {
        // This method will be used to set up state and navigate to the edit challenge view
        NotificationCenter.default.post(
            name: NSNotification.Name("PrepareToEditChallenge"),
            object: nil,
            userInfo: ["challenge": challenge]
        )
    }
} 