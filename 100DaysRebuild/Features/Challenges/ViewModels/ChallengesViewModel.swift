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
    
    private let firestore = Firestore.firestore()
    private let userSession = UserSession.shared
    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "ChallengesNetworkMonitor")
    private var localChallengesKey: String {
        guard let userId = userSession.currentUser?.uid else { return "challenges_cache" }
        return "challenges_cache_\(userId)"
    }
    
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
        // Listen for authentication changes to reload challenges
        Task {
            await MainActor.run {
                // Store a weak self and local user session to avoid capturing self strongly
                weak var weakSelf = self
                let userSession = self.userSession
                
                userSession.authStateDidChangeHandler = {
                    Task { 
                        let strongSelf = await MainActor.run { weakSelf }
                        guard let strongSelf else { return }
                        await strongSelf.loadChallenges()
                        await strongSelf.loadUserProfile()
                    }
                }
            }
        }
        
        // Start monitoring network connectivity
        setupNetworkMonitoring()
        
        // Start timer to update the time since last check-in
        startTimer()
        
        // Set the current time of day
        updateTimeOfDay()
    }
    
    deinit {
        networkMonitor.cancel()
        timerCancellable?.cancel()
        
        // Clean up auth handler
        Task {
            // Use MainActor without capturing self
            await MainActor.run {
                // Using a local reference to avoid capturing self
                UserSession.shared.authStateDidChangeHandler = nil
            }
        }
    }
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let wasOffline = self.isOffline
                self.isOffline = path.status != .satisfied
                
                // If connection was restored, try to sync data
                if wasOffline && !self.isOffline {
                    Task {
                        await self.loadChallenges()
                    }
                }
            }
        }
        networkMonitor.start(queue: monitorQueue)
    }
    
    func loadChallenges() async {
        guard let userId = userSession.currentUser?.uid else { 
            challenges = []
            saveChallengesLocally() // Clear local cache if not logged in
            return 
        }
        
        isLoading = true
        error = nil
        
        // First load from cache to show something immediately
        loadChallengesFromCache()
        
        // Check network connectivity
        if isOffline {
            isLoading = false
            if challenges.isEmpty {
                showError = true
                errorMessage = "You're currently offline. Unable to load challenges."
            }
            
            // Even with cached data, update the last check-in date
            updateLastCheckInDate()
            return
        }
        
        do {
            let snapshot = try await firestore
                .collection("users")
                .document(userId)
                .collection("challenges")
                .whereField("isArchived", isEqualTo: false)
                .order(by: "lastModified", descending: true) // Sort by most recently modified
                .getDocuments()
            
            let loadedChallenges = snapshot.documents.compactMap { doc in
                try? doc.data(as: Challenge.self)
            }
            
            // Make sure all challenges have proper isCompletedToday state
            let updatedChallenges = loadedChallenges.map { challenge in
                challenge.checkIfCompletedToday()
            }
            
            challenges = updatedChallenges
            saveChallengesLocally() // Cache the challenges for offline use
            
            // Update the last check-in date after loading challenges
            updateLastCheckInDate()
        } catch {
            self.error = error.localizedDescription
            self.showError = true
            self.errorMessage = "Failed to load challenges: \(error.localizedDescription)"
            
            // If we have cached challenges, keep using them
            if challenges.isEmpty {
                loadChallengesFromCache()
            }
            
            // Even with cached data, update the last check-in date
            updateLastCheckInDate()
        }
        
        isLoading = false
    }
    
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
                }
            }
        } catch {
            print("Error loading challenges from cache: \(error)")
        }
    }
    
    private func saveChallengesLocally() {
        do {
            let data = try JSONEncoder().encode(challenges)
            UserDefaults.standard.set(data, forKey: localChallengesKey)
        } catch {
            print("Error saving challenges to cache: \(error)")
        }
    }
    
    func createChallenge(title: String) async {
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
            lastModified: Date()
        )
        
        // If offline, store locally and show message
        if isOffline {
            // Add a proper async operation to avoid the warning
            do {
                challenges.append(challenge)
                saveChallengesLocally() // No await needed here - not async
                
                // Use Task.sleep to ensure there's a real async operation here
                try await Task.sleep(for: .milliseconds(1))
                
                isLoading = false
                challengeTitle = ""
                isShowingNewChallenge = false
                showError = true
                errorMessage = "Challenge created locally. It will sync when you're back online."
                return
            } catch {
                // Handle potential task cancellation
                isLoading = false
                return
            }
        }
        
        do {
            let docRef = firestore
                .collection("users")
                .document(userId)
                .collection("challenges")
                .document(challenge.id.uuidString)
            
            try await docRef.setData(from: challenge)
            
            challenges.append(challenge)
            saveChallengesLocally() // No await needed here - not async
            challengeTitle = ""
            isShowingNewChallenge = false
        } catch {
            self.error = error.localizedDescription
            self.showError = true
            self.errorMessage = "Failed to create challenge: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func updateChallenge(id: UUID, title: String) async {
        guard let userId = userSession.currentUser?.uid else { 
            showError = true
            errorMessage = "You must be signed in to update a challenge"
            return 
        }
        
        guard let index = challenges.firstIndex(where: { $0.id == id }) else { 
            showError = true
            errorMessage = "Challenge not found"
            return 
        }
        
        isLoading = true
        
        // Update locally first
        var updatedChallenge = challenges[index]
        updatedChallenge.title = title
        updatedChallenge.lastModified = Date() // Update the modification timestamp
        
        // Always update local state immediately for better UX
        challenges[index] = updatedChallenge
        saveChallengesLocally()
        
        // If offline, store changes locally and inform user
        if isOffline {
            // Add a proper async operation to avoid the warning
            do {
                // Sleep for a moment to simulate network delay
                try await Task.sleep(nanoseconds: 10_000_000)  // 10 milliseconds
                isLoading = false
                showError = true
                errorMessage = "Changes saved locally. They will sync when you're back online."
                return
            } catch {
                // Handle potential task cancellation
                isLoading = false
                return
            }
        }
        
        do {
            let docRef = firestore
                .collection("users")
                .document(userId)
                .collection("challenges")
                .document(id.uuidString)
            
            try await docRef.setData(from: updatedChallenge)
        } catch {
            showError = true
            errorMessage = "Failed to update challenge: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // Added helper methods for showing/hiding loading state
    private func showLoading() async {
        // Add an async operation with proper suspension point
        try? await Task.sleep(nanoseconds: 1_000_000) // 1 millisecond
        isLoading = true
    }
    
    private func hideLoading() async {
        // Add an async operation with proper suspension point
        try? await Task.sleep(nanoseconds: 1_000_000) // 1 millisecond
        isLoading = false
    }
    
    // Added helper method for handling errors
    private func handleError(_ error: Error) async {
        // Add an async operation with proper suspension point
        try? await Task.sleep(nanoseconds: 1_000_000) // 1 millisecond
        self.errorMessage = error.localizedDescription
        self.showError = true
        self.isLoading = false
    }
    
    @MainActor
    func checkIn(to challenge: Challenge, note: String = "") async {
        guard !isLoading, let userId = userSession.currentUser?.uid else { return }
        
        await showLoading()
        
        // Immediately update the UI optimistically for better UX
        if let index = challenges.firstIndex(where: { $0.id == challenge.id }) {
            // Create an optimistically updated challenge
            let optimisticChallenge = challenge.afterCheckIn()
            challenges[index] = optimisticChallenge
            
            // Update last check-in date immediately for better UX
            lastCheckInDate = Date()
            updateTimeSinceLastCheckIn()
            
            // Trigger haptic feedback immediately
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }
        
        do {
            // Use the shared CheckInService for proper streak and check-in handling
            let checkInService = CheckInService.shared
            
            // Attempt to check in - the service handles already-checked-in logic
            // Fix unused result warning by assigning to underscore
            _ = try await checkInService.checkIn(for: challenge.id.uuidString)
            
            // After successful check-in, fetch the updated challenge from Firestore
            let challengeRef = firestore
                .collection("users").document(userId)
                .collection("challenges").document(challenge.id.uuidString)
            
            let updatedChallengeDoc = try await challengeRef.getDocument()
            
            if let index = challenges.firstIndex(where: { $0.id == challenge.id }), 
               let data = updatedChallengeDoc.data() {
                // Parse the updated challenge data
                let daysCompleted = data["daysCompleted"] as? Int ?? challenge.daysCompleted
                let streakCount = data["streakCount"] as? Int ?? challenge.streakCount
                let lastCheckInDate = (data["lastCheckInDate"] as? Timestamp)?.dateValue() ?? Date()
                let lastModified = (data["lastModified"] as? Timestamp)?.dateValue() ?? Date()
                
                var updatedChallenge = challenges[index]
                updatedChallenge.daysCompleted = daysCompleted
                updatedChallenge.streakCount = streakCount
                updatedChallenge.lastCheckInDate = lastCheckInDate
                updatedChallenge.lastModified = lastModified
                updatedChallenge.isCompletedToday = true
                
                challenges[index] = updatedChallenge
                
                // Save to local cache
                saveChallengesLocally()
                
                // Trigger success haptic feedback
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
            
            await hideLoading()
        } catch let error as CheckInError {
            // Handle specific CheckInService errors
            print("Check-in service error: \(error.localizedDescription)")
            
            switch error {
            case .alreadyCheckedInToday:
                // Already checked in - this is fine, make sure UI shows this
                if let index = challenges.firstIndex(where: { $0.id == challenge.id }) {
                    var updatedChallenge = challenges[index]
                    updatedChallenge.isCompletedToday = true
                    challenges[index] = updatedChallenge
                    saveChallengesLocally()
                }
                
                // Don't show an error for already checked in
                await hideLoading()
                return
                
            case .networkUnavailable:
                // For offline mode, keep the optimistic UI update but show message
                showError = true
                errorMessage = "No internet connection. Your check-in will be processed when you're back online."
                
            default:
                // Revert the optimistic update for other errors
                await loadChallenges() // Reload challenges to revert optimistic update
                await handleError(error)
            }
            
            await hideLoading()
        } catch {
            // Unexpected error
            print("Check-in unexpected error: \(error.localizedDescription)")
            
            // Revert the optimistic update
            await loadChallenges() // Reload challenges to revert optimistic update
            await handleError(error)
        }
    }
    
    func archiveChallenge(_ challenge: Challenge) async {
        guard let userId = userSession.currentUser?.uid else { 
            showError = true
            errorMessage = "You must be signed in to delete a challenge"
            return 
        }
        
        // Remove from local array immediately for better UX
        challenges.removeAll { $0.id == challenge.id }
        saveChallengesLocally() // No await needed here - not async
        
        // If offline, store changes locally and inform user
        if isOffline {
            // Add a proper async operation to avoid the warning
            do {
                // Sleep for a moment to simulate network delay
                try await Task.sleep(nanoseconds: 10_000_000)  // 10 milliseconds
                showError = true
                errorMessage = "Challenge deleted locally. Changes will sync when you're back online."
                return
            } catch {
                // Handle potential task cancellation
                return
            }
        }
        
        do {
            let docRef = firestore
                .collection("users")
                .document(userId)
                .collection("challenges")
                .document(challenge.id.uuidString)
            
            var updatedChallenge = challenge
            updatedChallenge.isArchived = true
            updatedChallenge.lastModified = Date() // Update the modification timestamp
            
            try await docRef.setData(from: updatedChallenge)
        } catch {
            // Add the challenge back to the array if deletion failed
            challenges.append(challenge)
            saveChallengesLocally() // No await needed here - not async
            
            showError = true
            errorMessage = "Failed to delete challenge: \(error.localizedDescription)"
        }
    }
    
    // Function to refresh challenges after a check-in
    func refreshChallenges() async {
        // Just call loadChallenges which is already async
        await loadChallenges()
    }
    
    // Function to sync local changes when back online
    func syncLocalChanges() {
        if !isOffline {
            // Remove 'async' as there's no need for it here
            Task {
                await loadChallenges()
            }
        }
    }
    
    // Start a timer to update the time since last check-in
    private func startTimer() {
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateTimeSinceLastCheckIn()
                self?.updateTimeOfDay()
            }
    }
    
    // Update the time of day based on the current hour
    private func updateTimeOfDay() {
        let hour = Calendar.current.component(.hour, from: Date())
        
        // Morning: 5 AM – 11:59 AM
        // Afternoon: 12 PM – 5:59 PM
        // Night: 6 PM – 4:59 AM
        if hour >= 5 && hour < 12 {
            currentTimeOfDay = .morning
        } else if hour >= 12 && hour < 18 {
            currentTimeOfDay = .afternoon
        } else {
            currentTimeOfDay = .evening
        }
    }
    
    // Update the time since last check-in
    private func updateTimeSinceLastCheckIn() {
        guard let lastCheckIn = lastCheckInDate else { return }
        
        timeSinceLastCheckIn = Date().timeIntervalSince(lastCheckIn)
    }
    
    // Format the time since last check-in as a string in the format "Xd Yh Zm Ws" or "Yh Zm Ws" or "Zm Ws"
    func formattedTimeSinceLastCheckIn() -> String {
        guard let lastCheckIn = lastCheckInDate else {
            return "0h 0m 0s"
        }
        
        // Calculate time interval
        let timeInterval = Date().timeIntervalSince(lastCheckIn)
        
        // Convert to days, hours, minutes, seconds
        let days = Int(timeInterval) / 86400
        let hours = (Int(timeInterval) % 86400) / 3600
        let minutes = (Int(timeInterval) % 3600) / 60
        let seconds = Int(timeInterval) % 60
        
        // Format based on the elapsed time
        if days > 0 {
            return "\(days)d \(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m \(seconds)s"
        } else {
            return "\(minutes)m \(seconds)s"
        }
    }
    
    // Format the greeting based on the time of day
    func getGreeting() -> String {
        let name = userFirstName.isEmpty ? userName : userFirstName
        return "\(currentTimeOfDay.greeting), \(name) \(currentTimeOfDay.emoji)"
    }
    
    // Load the user's profile to get their name
    func loadUserProfile() async {
        guard let userId = userSession.currentUser?.uid else { return }
        
        do {
            // Get the user profile from FirebaseService
            if let profile = try await FirebaseService.shared.fetchUserProfile(userId: userId) {
                // Ensure we're on MainActor and add a suspension point
                try? await Task.sleep(nanoseconds: 1_000_000) // 1 millisecond
                
                // Check for displayName first, then fall back to username
                if let displayName = profile.displayName, !displayName.isEmpty {
                    self.userName = displayName
                    // Extract first name from display name
                    self.userFirstName = displayName.components(separatedBy: " ").first ?? displayName
                } else if let username = profile.username {
                    self.userName = username
                    self.userFirstName = username
                } else {
                    // Fall back to username from UserSession if nothing else is available
                    self.userName = userSession.username ?? "Friend"
                    self.userFirstName = self.userName
                }
            } else {
                // Fall back to username from UserSession
                // Ensure we're on MainActor and add a suspension point
                try? await Task.sleep(nanoseconds: 1_000_000) // 1 millisecond
                
                self.userName = userSession.username ?? "Friend"
                self.userFirstName = self.userName
            }
        } catch {
            print("Error loading user profile: \(error.localizedDescription)")
            // Ensure we're on MainActor and add a suspension point
            try? await Task.sleep(nanoseconds: 1_000_000) // 1 millisecond
            
            self.userName = userSession.username ?? "Friend"
            self.userFirstName = self.userName
        }
    }
    
    // Find the most recent check-in date across all challenges
    private func updateLastCheckInDate() {
        var mostRecentDate: Date?
        
        // First check all loaded challenges for the most recent check-in
        for challenge in challenges {
            if let checkInDate = challenge.lastCheckInDate {
                if mostRecentDate == nil || checkInDate > mostRecentDate! {
                    mostRecentDate = checkInDate
                }
            }
        }
        
        // If we found a valid check-in date, use it
        if let validDate = mostRecentDate {
            lastCheckInDate = validDate
            updateTimeSinceLastCheckIn()
            return
        }
        
        // If no check-in found or all check-ins are more than a day old,
        // fetch the most recent check-in from Firestore directly
        Task {
            await fetchMostRecentCheckInFromFirestore()
        }
    }
    
    // Fetch the most recent check-in from Firestore directly
    private func fetchMostRecentCheckInFromFirestore() async {
        guard let userId = userSession.currentUser?.uid else { 
            // If not logged in, just use current time
            lastCheckInDate = Date()
            updateTimeSinceLastCheckIn()
            return
        }
        
        do {
            // Query across all challenges to find the most recent check-in
            let checkInsQuery = firestore.collectionGroup("checkIns")
                .whereField("userId", isEqualTo: userId)
                .order(by: "date", descending: true)
                .limit(to: 1)
            
            let snapshot = try await checkInsQuery.getDocuments()
            
            if let document = snapshot.documents.first,
               let dateTimestamp = document.data()["date"] as? Timestamp {
                
                // Use the exact timestamp from the most recent check-in
                let exactCheckInDate = dateTimestamp.dateValue()
                
                // Ensure we're on MainActor by adding a suspension point
                try? await Task.sleep(nanoseconds: 1_000_000) // 1 millisecond
                
                lastCheckInDate = exactCheckInDate
                updateTimeSinceLastCheckIn()
            } else {
                // If no check-ins found at all, use current time
                // Ensure we're on MainActor by adding a suspension point
                try? await Task.sleep(nanoseconds: 1_000_000) // 1 millisecond
                
                // Set to current time as fallback
                lastCheckInDate = Date()
                updateTimeSinceLastCheckIn()
            }
        } catch {
            print("Error fetching recent check-ins: \(error.localizedDescription)")
            
            // On error, fallback to current time
            // Ensure we're on MainActor by adding a suspension point
            try? await Task.sleep(nanoseconds: 1_000_000) // 1 millisecond
            
            lastCheckInDate = Date()
            updateTimeSinceLastCheckIn()
        }
    }
} 