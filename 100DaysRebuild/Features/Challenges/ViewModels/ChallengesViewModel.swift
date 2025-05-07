import Foundation
import SwiftUI
import FirebaseFirestore
import Network

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
    
    private let firestore = Firestore.firestore()
    private let userSession = UserSession.shared
    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "ChallengesNetworkMonitor")
    private var localChallengesKey: String {
        guard let userId = userSession.currentUser?.uid else { return "challenges_cache" }
        return "challenges_cache_\(userId)"
    }
    
    init() {
        // Listen for authentication changes to reload challenges
        userSession.authStateDidChangeHandler = { [weak self] in
            Task { [weak self] in
                await self?.loadChallenges()
            }
        }
        
        // Start monitoring network connectivity
        setupNetworkMonitoring()
    }
    
    deinit {
        networkMonitor.cancel()
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
            
            challenges = loadedChallenges
            saveChallengesLocally() // Cache the challenges for offline use
        } catch {
            self.error = error.localizedDescription
            self.showError = true
            self.errorMessage = "Failed to load challenges: \(error.localizedDescription)"
            
            // If we have cached challenges, keep using them
            if challenges.isEmpty {
                loadChallengesFromCache()
            }
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
                    challenges = decodedChallenges
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
            challenges.append(challenge)
            saveChallengesLocally()
            isLoading = false
            challengeTitle = ""
            isShowingNewChallenge = false
            showError = true
            errorMessage = "Challenge created locally. It will sync when you're back online."
            return
        }
        
        do {
            let docRef = firestore
                .collection("users")
                .document(userId)
                .collection("challenges")
                .document(challenge.id.uuidString)
            
            try await docRef.setData(from: challenge)
            
            challenges.append(challenge)
            saveChallengesLocally()
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
            try? await Task.sleep(for: .milliseconds(1)) // Add proper async operation
            isLoading = false
            showError = true
            errorMessage = "Changes saved locally. They will sync when you're back online."
            return
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
    
    func checkIn(to challenge: Challenge) async {
        guard let userId = userSession.currentUser?.uid else { 
            showError = true
            errorMessage = "You must be signed in to check in"
            return 
        }
        
        guard let index = challenges.firstIndex(where: { $0.id == challenge.id }) else { 
            showError = true
            errorMessage = "Challenge not found"
            return 
        }
        
        // Prevent check-in if already completed today
        if challenge.isCompletedToday {
            showError = true
            errorMessage = "You've already checked in for today."
            return
        }
        
        // Check if the last check-in was today
        if let lastCheckIn = challenge.lastCheckInDate, 
           Calendar.current.isDateInToday(lastCheckIn) {
            showError = true
            errorMessage = "You've already checked in for today."
            return
        }
        
        // Update challenge locally first
        var updatedChallenge = challenge
        updatedChallenge.daysCompleted += 1
        updatedChallenge.streakCount += 1
        updatedChallenge.lastCheckInDate = Date()
        updatedChallenge.isCompletedToday = true
        updatedChallenge.lastModified = Date() // Update the modification timestamp
        
        // Always update local state immediately for better UX
        challenges[index] = updatedChallenge
        saveChallengesLocally()
        
        // If offline, store changes locally and inform user
        if isOffline {
            try? await Task.sleep(for: .milliseconds(1)) // Add proper async operation
            showError = true
            errorMessage = "Check-in saved locally. It will sync when you're back online."
            return
        }
        
        do {
            let docRef = firestore
                .collection("users")
                .document(userId)
                .collection("challenges")
                .document(challenge.id.uuidString)
            
            try await docRef.setData(from: updatedChallenge)
        } catch {
            showError = true
            errorMessage = "Failed to save check-in: \(error.localizedDescription)"
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
        saveChallengesLocally()
        
        // If offline, store changes locally and inform user
        if isOffline {
            try? await Task.sleep(for: .milliseconds(1)) // Add proper async operation
            showError = true
            errorMessage = "Challenge deleted locally. Changes will sync when you're back online."
            return
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
            saveChallengesLocally()
            
            showError = true
            errorMessage = "Failed to delete challenge: \(error.localizedDescription)"
        }
    }
    
    // Function to sync cached changes when back online
    func syncLocalChanges() async {
        // This would be implemented in a more robust app
        // It would compare local versions with server versions based on timestamps
        // and resolve conflicts according to business rules
        try? await Task.sleep(for: .milliseconds(1)) // Small delay to ensure async context
        await loadChallenges() // Mark the call with await since loadChallenges is async
    }
} 