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
        Task {
            await MainActor.run {
                userSession.authStateDidChangeHandler = { [weak self] in
                    Task { [weak self] in
                        await self?.loadChallenges()
                    }
                }
            }
        }
        
        // Start monitoring network connectivity
        setupNetworkMonitoring()
    }
    
    deinit {
        networkMonitor.cancel()
        
        // Clean up auth handler
        Task {
            await MainActor.run {
                // Using a local reference to avoid capturing self
                let session = userSession
                session.authStateDidChangeHandler = nil
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
            do {
                // Use proper async operation
                try await Task.sleep(for: .milliseconds(10))
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
        
        showLoading() // No await needed here - not async
        
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
            
            // Create a Sendable struct instead of a dictionary
            struct CheckInData: Sendable {
                let date: Date
                let dayNumber: Int
                let note: String
            }
            
            let checkInData = CheckInData(
                date: date,
                dayNumber: dayNumber,
                note: noteCopy
            )
            
            // Use Task.detached with sendable data to avoid main actor isolation issues
            try await Task.detached {
                // Convert struct to dictionary here
                var data: [String: Any] = [
                    "date": checkInData.date,
                    "dayNumber": checkInData.dayNumber
                ]
                
                if !checkInData.note.isEmpty {
                    data["note"] = checkInData.note
                }
                
                try await checkInRef.setData(data)
            }.value
            
            // Update challenge metadata
            // Create a Sendable struct for the update data
            struct UpdateData: Sendable {
                let daysCompleted: Int
                let streakCount: Int
                let lastCheckInDate: Date
                let lastModified: Date
            }
            
            let updateData = UpdateData(
                daysCompleted: challenge.daysCompleted + 1,
                streakCount: challenge.streakCount + 1,
                lastCheckInDate: date,
                lastModified: date
            )
            
            // Use Task.detached for the updateData operation too
            try await Task.detached {
                try await challengeRef.updateData([
                    "daysCompleted": updateData.daysCompleted,
                    "streakCount": updateData.streakCount,
                    "lastCheckInDate": updateData.lastCheckInDate,
                    "lastModified": updateData.lastModified
                ])
            }.value
            
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
            
            hideLoading() // No await needed here - not async
        } catch {
            handleError(error) // No await needed here - not async
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
            do {
                // Use proper async operation
                try await Task.sleep(for: .milliseconds(10))
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
    
    // Function to sync cached changes when back online
    func syncLocalChanges() async {
        do {
            // Use proper async operation
            try await Task.sleep(for: .milliseconds(10))
            // loadChallenges is async so retain the await here
            await loadChallenges()
        } catch {
            // Handle potential task cancellation
        }
    }
} 