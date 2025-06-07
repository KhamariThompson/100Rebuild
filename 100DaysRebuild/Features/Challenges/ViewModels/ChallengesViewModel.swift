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
    
    // New properties for expired challenges
    @Published var expiredChallenges: [Challenge] = []
    @Published var showExpiredChallengeAlert = false
    @Published var currentExpiredChallenge: Challenge?
    
    // Add toast state for user feedback
    @Published var showSuccessToast = false
    @Published var successMessage = ""
    
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
        
        // Observe app becoming active to check for expired challenges
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        // Listen for notification to check for expired challenges
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCheckExpiredChallengesNotification),
            name: NSNotification.Name("CheckForExpiredChallenges"),
            object: nil
        )
        
        // Listen for notification to create a new challenge from other views
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCreateNewChallengeNotification),
            name: NSNotification.Name("CreateNewChallenge"),
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
    
    @objc private func handleAppBecomeActive() {
        // Check for expired challenges when app becomes active
        Task {
            await checkForExpiredChallenges()
        }
    }
    
    @objc private func handleCheckExpiredChallengesNotification() {
        // Check for expired challenges when notification is received
        Task {
            await checkForExpiredChallenges()
        }
    }
    
    @objc private func handleCreateNewChallengeNotification(_ notification: Notification) {
        // Extract challenge info from notification
        guard let userInfo = notification.userInfo,
              let title = userInfo["title"] as? String,
              let isTimed = userInfo["isTimed"] as? Bool else {
            return
        }
        
        // Create the challenge
        Task {
            await createChallenge(title: title, isTimed: isTimed)
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
        
        // First check if we already have challenges in memory
        if !challengeStore.challenges.isEmpty {
            // Use existing challenges immediately for instant UI response
            challenges = challengeStore.challenges.filter { !$0.isArchived }
            updateLastCheckInDate()
            isLoading = false
            isInitialLoad = false
        } else {
            // Mark as loading only if we don't have cached data
            isLoading = true
        }
        
        error = nil
        
        // Use a separate task for network operations to keep UI responsive
        Task {
            // This will trigger cache load immediately before network
            await challengeStore.refreshChallenges()
        }
    }
    
    func createChallenge(title: String, isTimed: Bool = false) async {
        guard let userId = userSession.currentUser?.uid else { 
            showError = true
            errorMessage = "You must be signed in to create a challenge"
            return 
        }
        
        print("Creating challenge: \(title)")
        
        // Immediately update the UI to hide the sheet before any async operations
        self.isShowingNewChallenge = false
        
        // Then proceed with the rest of the creation process
        isLoading = true
        error = nil
        
        do {
            // Use the challenge service to create challenge - it handles permissions and limits
            try await challengeService.createChallenge(title: title, userId: userId)
            
            // Ensure UI updates happen on the main thread
            await MainActor.run {
                print("Challenge created successfully")
            isLoading = false
            challengeTitle = ""
                
                // Explicitly post notification for UI refresh
                NotificationCenter.default.post(
                    name: ChallengeStore.challengesDidUpdateNotification,
                    object: nil
                )
            }
            
            // Refresh challenges after creation
            await loadChallenges()
        } catch {
            await MainActor.run {
                print("Failed to create challenge: \(error.localizedDescription)")
            isLoading = false
            self.error = error.localizedDescription
            self.showError = true
            self.errorMessage = "Failed to create challenge: \(error.localizedDescription)"
            }
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
            
            // Call CheckInService but don't await it
            // This creates a fire-and-forget background task
            Task.detached {
                do {
                    // Basic check-in - fast path for core update
                    try await CheckInService.shared.checkIn(for: challenge.id.uuidString)
                    
                    // Handle the photo and note in the background
                    if let image = image {
                        // Upload image directly using Firebase Storage
                        let storage = Storage.storage()
                        let storageRef = storage.reference()
                        let imagePath = "check-ins/\(challenge.id)/\(Date().timeIntervalSince1970).jpg"
                        let imageRef = storageRef.child(imagePath)
                        
                        // Compress the image
                        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
                            print("Failed to compress image for upload")
                            return
                        }
                        
                        // Upload the image
                        let metadata = StorageMetadata()
                        metadata.contentType = "image/jpeg"
                        
                        _ = try await imageRef.putDataAsync(imageData, metadata: metadata)
                    }
                    
                    if !note.isEmpty {
                        // Save the note in the background
                        let checkInsRef = Firestore.firestore()
                            .collection("users").document(userId)
                            .collection("challenges").document(challenge.id.uuidString)
                            .collection("checkIns")
                        
                        let today = Calendar.current.startOfDay(for: Date())
                        let todayQuery = checkInsRef.whereField("date", isGreaterThanOrEqualTo: today)
                            .whereField("date", isLessThan: Calendar.current.date(byAdding: .day, value: 1, to: today)!)
                            .limit(to: 1)
                        
                        let snapshot = try await todayQuery.getDocuments()
                        if let doc = snapshot.documents.first {
                            try await doc.reference.updateData(["note": note])
                        }
                    }
                    
                    // Update user stats in the background
                    // Remove these calls since they're not necessary and UserStatsService doesn't have these methods
                    // try? await UserStatsService.shared.incrementDailyStreak(userId: userId)
                    // try? await UserStatsService.shared.incrementTotalCheckIns(userId: userId)
                    
                    print("Background check-in complete for \(challenge.id)")
                } catch {
                    print("Background check-in failed: \(error)")
                }
            }
            
            // Return success immediately to update UI quickly
            isLoading = false
            return .success(())
            
        } catch {
            isLoading = false
            showError = true
            errorMessage = "Failed to check in: \(error.localizedDescription)"
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
            // await UserStatsService.shared.refreshUserStats()
            
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
    
    /// Prepare to edit a challenge
    func prepareToEditChallenge(_ challenge: Challenge) {
        // This method will be used to set up state and navigate to the edit challenge view
        NotificationCenter.default.post(
            name: NSNotification.Name("PrepareToEditChallenge"),
            object: nil,
            userInfo: ["challenge": challenge]
        )
    }
    
    /// Check for expired challenges and prompt user to restart if needed
    func checkForExpiredChallenges() async {
        guard let userId = userSession.currentUser?.uid else { return }
        
        do {
            // Use the challenge service to find expired challenges
            let expired = await challengeService.checkForExpiredChallenges()
            
            // Update UI on main thread
            await MainActor.run {
                self.expiredChallenges = expired
                
                // Show alert for first expired challenge if there are any
                if !expired.isEmpty {
                    self.currentExpiredChallenge = expired.first
                    self.showExpiredChallengeAlert = true
                }
            }
        } catch {
            print("Error checking for expired challenges: \(error.localizedDescription)")
        }
    }
    
    /// Handle refresh after challenge restart - used when a restart operation needs to be fully propagated
    func refreshAfterRestart(restartedChallengeId: UUID? = nil) async {
        print("🔄 Starting full refresh after challenge restart")
        
        if let challengeId = restartedChallengeId {
            // If we know which challenge was restarted, refresh just that one first
            print("🔄 Specifically refreshing restarted challenge: \(challengeId)")
            await challengeStore.refreshChallenge(id: challengeId)
        }
        
        // Refresh all challenges from the store
        await loadChallenges()
        
        // Check for any expired challenges again
        await checkForExpiredChallenges()
        
        // Force UI update for all views observing this model
        await MainActor.run {
            objectWillChange.send()
            
            // Notify that challenges have changed
            NotificationCenter.default.post(
                name: ChallengeStore.challengesDidUpdateNotification,
                object: nil,
                userInfo: restartedChallengeId != nil ? ["refreshedChallengeId": restartedChallengeId!] : [:]
            )
        }
        
        print("✅ Completed refresh after challenge restart")
    }
    
    /// Restart an expired challenge
    func restartExpiredChallenge(_ challenge: Challenge) async {
        isLoading = true
        print("Starting challenge restart process: \(challenge.id)")
        
        do {
            // Use the challenge service to restart the challenge
            let restartedChallenge = try await challengeService.restartChallenge(challenge)
            print("Challenge restarted successfully: \(restartedChallenge.id)")
            
            // Update UI on main thread
            await MainActor.run {
                isLoading = false
                
                // Immediately update the challenge in the local challenges array
                if let index = challenges.firstIndex(where: { $0.id == challenge.id }) {
                    challenges[index] = restartedChallenge
                    print("Updated challenge in local array with restarted version")
                } else {
                    // If not found (unlikely), add it
                    challenges.append(restartedChallenge)
                    print("Added restarted challenge to local array (not found in existing challenges)")
                }
                
                // Remove from expired challenges list
                expiredChallenges.removeAll { $0.id == challenge.id }
                
                if !expiredChallenges.isEmpty {
                    currentExpiredChallenge = expiredChallenges.first
                    showExpiredChallengeAlert = true
                } else {
                    showExpiredChallengeAlert = false
                    currentExpiredChallenge = nil
                }
                
                // Show success feedback
                showSuccessToast = true
                successMessage = "Challenge restarted successfully!"
                
                // Auto-hide the toast after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.showSuccessToast = false
                }
                
                // Force refresh all views by posting a notification
                print("📢 Posting notification for challenge restart from ViewModel")
                NotificationCenter.default.post(
                    name: ChallengeStore.challengesDidUpdateNotification,
                    object: nil,
                    userInfo: ["restartedChallengeId": challenge.id]
                )
                
                // Force an update to this view model
                self.objectWillChange.send()
            }
            
            // Use the new dedicated refresh method
            await refreshAfterRestart(restartedChallengeId: challenge.id)
            
        } catch {
            print("Failed to restart challenge: \(error.localizedDescription)")
            await MainActor.run {
                isLoading = false
                showError = true
                errorMessage = "Failed to restart challenge: \(error.localizedDescription)"
            }
        }
    }
    
    /// Archive an expired challenge
    func archiveExpiredChallenge(_ challenge: Challenge) async {
        isLoading = true
        print("Starting challenge archive process: \(challenge.id)")
        
        do {
            // Use the challenge service to archive the challenge
            try await challengeService.archiveChallenge(challenge)
            print("Challenge archived successfully: \(challenge.id)")
            
            // Update UI on main thread
            await MainActor.run {
                isLoading = false
                
                // Remove the challenge from active challenges immediately
                challenges.removeAll { $0.id == challenge.id }
                
                // Remove from expired challenges list
                if let index = expiredChallenges.firstIndex(where: { $0.id == challenge.id }) {
                    expiredChallenges.remove(at: index)
                }
                
                // Move to next expired challenge if there are more
                if !expiredChallenges.isEmpty {
                    currentExpiredChallenge = expiredChallenges.first
                    showExpiredChallengeAlert = true
                } else {
                    showExpiredChallengeAlert = false
                    currentExpiredChallenge = nil
                }
                
                // Show success feedback
                showSuccessToast = true
                successMessage = "Challenge archived successfully!"
                
                // Auto-hide the toast after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.showSuccessToast = false
                }
            }
            
            // Refresh challenges to update UI
            await loadChallenges()
        } catch {
            print("Failed to archive challenge: \(error.localizedDescription)")
            await MainActor.run {
                isLoading = false
                showError = true
                errorMessage = "Failed to archive challenge: \(error.localizedDescription)"
            }
        }
    }
    
    /// Dismiss the current expired challenge alert and move to the next one if available
    func dismissExpiredChallengeAlert() {
        // Remove current expired challenge
        if let currentChallenge = currentExpiredChallenge,
           let index = expiredChallenges.firstIndex(where: { $0.id == currentChallenge.id }) {
            expiredChallenges.remove(at: index)
        }
        
        // Move to next expired challenge if there are more
        if !expiredChallenges.isEmpty {
            currentExpiredChallenge = expiredChallenges.first
            showExpiredChallengeAlert = true
        } else {
            showExpiredChallengeAlert = false
            currentExpiredChallenge = nil
        }
    }
    
    // Helper to show success message
    private func showSuccess(message: String) {
        // This could be expanded to show a toast or other UI feedback
        print(message)
    }
} 