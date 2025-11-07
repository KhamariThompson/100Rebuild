import Foundation
import FirebaseFirestore
import FirebaseAuth
import SwiftUI

// Using canonical Challenge model
// (No import needed as it will be accessed directly)

enum ChallengeError: Error, LocalizedError {
    case notFound
    case invalidData
    case networkError
    case unauthorized
    case freeUserLimitExceeded
    case challengeCompleted
    case alreadyCheckedIn
    case proFeatureRequired
    case userNotAuthenticated
    
    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Challenge not found"
        case .invalidData:
            return "Invalid challenge data"
        case .networkError:
            return "Network error occurred"
        case .unauthorized:
            return "You're not authorized to access this challenge"
        case .freeUserLimitExceeded:
            return "Free users can create up to 2 active challenges. Upgrade to Pro for unlimited challenges."
        case .challengeCompleted:
            return "This challenge is already completed"
        case .alreadyCheckedIn:
            return "You've already checked in today"
        case .proFeatureRequired:
            return "This feature requires a Pro subscription."
        case .userNotAuthenticated:
            return "You must be signed in to perform this action."
        }
    }
}

@MainActor
class ChallengeService: ObservableObject {
    static let shared = ChallengeService()

    private let challengeStore = ChallengeStore.shared
    private let subscriptionService = SubscriptionService.shared
    // No challenge limits - unlimited for all users

    @Published var isDeleting = false
    @Published var deletionError: String? = nil

    private init() {}

    /// Create a new challenge - unlimited for all users
    func createChallenge(_ challenge: Challenge) async throws {
        // No limits - all users can create unlimited challenges
        try await challengeStore.saveChallenge(challenge)
    }
    
    /// Delete all challenges for the current user
    func deleteAllChallenges(userId: String) async throws {
        guard !userId.isEmpty else {
            throw NSError(domain: "ChallengeService", code: 1001, 
                         userInfo: [NSLocalizedDescriptionKey: "User ID is required to delete challenges"])
        }
        
        isDeleting = true
        deletionError = nil
        
        do {
            // Fetch all challenges first from the store
            let challenges = challengeStore.challenges
            
            // Delete each challenge through the store
            for challenge in challenges {
                try await challengeStore.deleteChallenge(id: challenge.id)
            }
            
            isDeleting = false
            return
        } catch {
            isDeleting = false
            deletionError = error.localizedDescription
            throw error
        }
    }
    
    /// Get current active challenge count for a user
    private func getChallengeCount() async throws -> Int {
        // Only count active (non-archived) challenges
        return challengeStore.getActiveChallenges().count
    }
    
    // MARK: - CRUD Operations
    
    func createChallenge(title: String, userId: String) async throws -> Challenge {
        // No limits - all users can create unlimited challenges
        let challenge = Challenge(
            id: UUID(),
            title: title,
            startDate: Date(),
            lastCheckInDate: nil,
            streakCount: 0,
            daysCompleted: 0,
            isCompletedToday: false,
            isArchived: false,
            ownerId: userId,
            lastModified: Date()
        )

        // Save through the centralized store
        try await challengeStore.saveChallenge(challenge)
        return challenge
    }
    
    /// Returns true if user has reached their challenge limit - always false (no limits)
    func hasReachedFreeLimit(userId: String) async -> Bool {
        // No limits - all users can create unlimited challenges
        return false
    }
    
    func loadChallenges(for userId: String) async throws -> [Challenge] {
        // First ensure challenges are refreshed in the store
        await challengeStore.refreshChallenges()
        
        // Then return active challenges from the store
        return challengeStore.getActiveChallenges()
    }
    
    // MARK: - Check-in Validation
    
    func isCheckInValid(for date: Date) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        
        // If it's before 8 AM, allow check-in for yesterday
        if calendar.component(.hour, from: now) < 8 {
            return calendar.isDate(date, inSameDayAs: calendar.date(byAdding: .day, value: -1, to: now) ?? now)
        }
        
        // Otherwise, only allow check-in for today
        return calendar.isDate(date, inSameDayAs: now)
    }
    
    func effectiveCheckInDate() -> Date {
        let calendar = Calendar.current
        let now = Date()
        
        // If it's before 8 AM, return yesterday
        if calendar.component(.hour, from: now) < 8 {
            return calendar.date(byAdding: .day, value: -1, to: now) ?? now
        }
        
        // Otherwise, return today
        return now
    }
    
    func checkIn(to challenge: Challenge) async throws -> Challenge {
        // Use the centralized store's check-in functionality
        return try await challengeStore.checkIn(to: challenge.id)
    }
    
    func archiveChallenge(_ challenge: Challenge) async throws {
        print("⏱️ Starting archive process for challenge: \(challenge.id)")
        
        var updatedChallenge = challenge
        updatedChallenge.isArchived = true
        updatedChallenge.lastModified = Date() // Update the last modified date
        
        print("⏱️ Prepared updated challenge with isArchived=true: \(updatedChallenge.id)")
        
        // Save the updated challenge through the store
        try await challengeStore.saveChallenge(updatedChallenge)
        
        print("✅ Successfully archived challenge: \(updatedChallenge.id)")
    }
    
    // MARK: - Streak Management
    
    func resetStreakIfMissed(for challenge: Challenge) async throws {
        guard challenge.hasStreakExpired else { return }
        
        var updatedChallenge = challenge
        updatedChallenge.streakCount = 0
        updatedChallenge.isCompletedToday = false
        
        // Save the updated challenge through the store
        try await challengeStore.saveChallenge(updatedChallenge)
    }
    
    func validateAndUpdateStreaks(for userId: String) async throws {
        // Get active challenges from the store
        let challenges = challengeStore.getActiveChallenges()
        
        for challenge in challenges {
            try await resetStreakIfMissed(for: challenge)
        }
    }
    
    /// Check for challenges that have expired and need to be restarted
    /// Returns any challenges that have expired and the user should be asked about restarting
    func checkForExpiredChallenges() async -> [Challenge] {
        // Get active challenges that haven't been checked into in more than a day
        let expiredChallenges = challengeStore.getActiveChallenges().filter { challenge in
            // Only include challenges that:
            // 1. Have an expired streak (haven't checked in for more than a day)
            // 2. Have made progress (at least some days completed)
            // 3. Are not completed (not reached 100 days)
            return challenge.hasStreakExpired && 
                   challenge.daysCompleted > 0 && 
                   !challenge.isCompleted
        }
        
        return expiredChallenges
    }
    
    /// Restart an expired challenge
    func restartChallenge(_ challenge: Challenge) async throws -> Challenge {
        print("🔄 Starting challenge restart process for challenge ID: \(challenge.id)")
        
        // Create a new Challenge instance with updated values instead of modifying properties
        let restartedChallenge = Challenge(
            id: challenge.id,
            title: challenge.title,
            startDate: Date(), // Use current date as the new start date
            lastCheckInDate: nil,
            streakCount: 0,
            daysCompleted: 0,
            isCompletedToday: false,
            isArchived: challenge.isArchived,
            ownerId: challenge.ownerId,
            lastModified: Date(),
            isTimed: challenge.isTimed
        )
        
        print("📝 Created restarted challenge object with fresh values")
        
        // Save the restarted challenge
        try await challengeStore.saveChallenge(restartedChallenge)
        print("✅ Saved restarted challenge to database")
        
        // Force a refresh of all challenges to ensure UI updates
        await challengeStore.refreshChallenges()
        print("🔄 Forced refresh of all challenges after restart")
        
        // Post notification to explicitly inform all observers that this challenge was restarted
        // This is crucial for updating the UI components like ChallengeCardComponent
        print("📢 Posting challengesDidUpdateNotification after challenge restart")
        NotificationCenter.default.post(
            name: ChallengeStore.challengesDidUpdateNotification,
            object: nil,
            userInfo: ["restartedChallengeId": challenge.id]
        )
        
        return restartedChallenge
    }
    
    /// Fetch all challenges for a user - renamed to avoid conflict
    func getUserChallenges(userId: String) async throws -> [Challenge] {
        // Refresh and get challenges from the store
        await challengeStore.refreshChallenges()
        return challengeStore.challenges
    }
    
    /// Update an existing challenge
    func updateChallenge(_ challenge: Challenge) async throws {
        // Save through the centralized store
        try await challengeStore.saveChallenge(challenge)
    }
    
    /// Delete a specific challenge
    func deleteChallenge(id: UUID, userId: String) async throws {
        guard !userId.isEmpty else {
            throw NSError(domain: "ChallengeService", code: 1001, 
                         userInfo: [NSLocalizedDescriptionKey: "User ID is required to delete a challenge"])
        }
        
        // Delete through the centralized store
        try await challengeStore.deleteChallenge(id: id)
    }
}

// Fix for the saveChallenge method: use a mock implementation if original can't be found
extension FirebaseService {
    func saveChallenge(_ challenge: Challenge) async throws {
        // Get the user ID
        guard let userId = Auth.auth().currentUser?.uid else {
            throw ChallengeError.userNotAuthenticated
        }
        
        // Convert UUID to String where needed
        let challengeId = challenge.id.uuidString
        
        // Create a Firestore reference
        let challengeRef = Firestore.firestore()
            .collection("users")
            .document(userId)
            .collection("challenges")
            .document(challengeId)
        
        // Convert to dictionary and save
        try await challengeRef.setData(challenge.asDictionary())
    }
    
    func deleteChallenge(id: UUID, userId: String) async throws {
        let challengeId = id.uuidString
        
        // Delete the challenge document
        let challengeRef = Firestore.firestore()
            .collection("users")
            .document(userId)
            .collection("challenges")
            .document(challengeId)
        
        try await challengeRef.delete()
    }
    
    // Renamed to avoid redeclaration with ChallengeService.fetchChallenges
    func getChallengesFor(userId: String) async throws -> [Challenge] {
        let snapshot = try await Firestore.firestore()
            .collection("users")
            .document(userId)
            .collection("challenges")
            .getDocuments()
        
        return try snapshot.documents.compactMap { document in
            try document.data(as: Challenge.self)
        }
    }
}

// Extension to convert a Challenge to a dictionary
extension Challenge {
    func asDictionary() -> [String: Any] {
        return [
            "id": id.uuidString,
            "title": title,
            "startDate": startDate,
            "lastCheckInDate": lastCheckInDate as Any,
            "streakCount": streakCount,
            "daysCompleted": daysCompleted,
            "isCompletedToday": isCompletedToday,
            "isArchived": isArchived,
            "ownerId": ownerId,
            "lastModified": lastModified,
            "isTimed": isTimed
        ]
    }
} 
