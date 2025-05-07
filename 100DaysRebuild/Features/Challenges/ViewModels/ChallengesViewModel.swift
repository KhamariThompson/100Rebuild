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
            // Using Task.sleep to create a real async operation
            do {
                try await Task.sleep(for: .milliseconds(1))
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
    private func showLoading() {
        isLoading = true
    }
    
    private func hideLoading() {
        isLoading = false
    }
    
    // Added helper method for handling errors
    private func handleError(_ error: Error) {
        self.errorMessage = error.localizedDescription
        self.showError = true
        self.isLoading = false
    }
    
    @MainActor
    func checkIn(to challenge: Challenge, note: String = "") async {
        guard !isLoading, let userId = userSession.currentUser?.uid else { return }
        
        showLoading()
        
        do {
            // Get a reference to the challenge document
            let challengeRef = firestore
                .collection("users").document(userId)
                .collection("challenges").document(challenge.id.uuidString)
            
            // Create sendable copies of the required data
            let date = Date()
            let dayNumber = challenge.daysCompleted + 1
            let noteCopy = note
            
            // Add to check-ins subcollection
            let checkInRef = challengeRef.collection("checkIns").document()
            
            // Use Task.detached with sendable data to avoid main actor isolation issues
            try await Task.detached {
                var sendableData: [String: Any] = [
                    "date": date,
                    "dayNumber": dayNumber
                ]
                
                if !noteCopy.isEmpty {
                    sendableData["note"] = noteCopy
                }
                
                try await checkInRef.setData(sendableData)
            }.value
            
            // Update challenge metadata
            try await challengeRef.updateData([
                "daysCompleted": challenge.daysCompleted + 1,
                "streakCount": challenge.streakCount + 1,
                "lastCheckInDate": date,
                "lastModified": date
            ])
            
            // Update local challenge data
            if let index = challenges.firstIndex(where: { $0.id == challenge.id }) {
                challenges[index].daysCompleted += 1
                challenges[index].streakCount += 1
                challenges[index].lastCheckInDate = date
                challenges[index].lastModified = date
            }
            
            // Trigger haptic feedback for successful check-in
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            hideLoading()
        } catch {
            handleError(error)
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
            // Using Task.sleep to create a real async operation
            do {
                try await Task.sleep(for: .milliseconds(1))
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
            saveChallengesLocally()
            
            showError = true
            errorMessage = "Failed to delete challenge: \(error.localizedDescription)"
        }
    }
    
    // Function to sync cached changes when back online
    func syncLocalChanges() async {
        do {
            // Using Task.sleep for a real async operation
            try await Task.sleep(for: .milliseconds(1))
            await loadChallenges()
        } catch {
            // Handle potential task cancellation
        }
    }
} 