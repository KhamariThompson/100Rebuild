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
    
    private let firebaseService = FirebaseService.shared
    private let subscriptionService = SubscriptionService.shared
    private let maxChallengesForFreeUsers = 2
    
    @Published var isDeleting = false
    @Published var deletionError: String? = nil
    
    private init() {}
    
    /// Create a new challenge
    func createChallenge(_ challenge: Challenge) async throws {
        if !subscriptionService.isProUser {
            let challengeCount = try await getChallengeCount()
            if challengeCount >= maxChallengesForFreeUsers {
                subscriptionService.showPaywall = true
                throw ChallengeError.proFeatureRequired
            }
        }
        
        // Save to Firestore
        try await firebaseService.saveChallenge(challenge)
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
            // Fetch all challenges first
            let challenges = try await firebaseService.getChallengesFor(userId: userId)
            
            // Delete each challenge
            for challenge in challenges {
                try await firebaseService.deleteChallenge(id: challenge.id, userId: userId)
            }
            
            isDeleting = false
            return
        } catch {
            isDeleting = false
            deletionError = error.localizedDescription
            throw error
        }
    }
    
    /// Get current challenge count for a user
    private func getChallengeCount() async throws -> Int {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw ChallengeError.userNotAuthenticated
        }
        
        let challenges = try await firebaseService.getChallengesFor(userId: userId)
        return challenges.count
    }
    
    // MARK: - CRUD Operations
    
    func createChallenge(title: String, userId: String) async throws -> Challenge {
        // Check free user limit
        if !subscriptionService.isProUser {
            let activeChallenges = try await loadChallenges(for: userId)
            if activeChallenges.count >= maxChallengesForFreeUsers {
                // Show paywall
                subscriptionService.showPaywall = true
                throw ChallengeError.freeUserLimitExceeded
            }
        }
        
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
        
        _ = try await firebaseService.saveChallenge(challenge)
        return challenge
    }
    
    /// Returns true if user has reached their free challenge limit
    func hasReachedFreeLimit(userId: String) async -> Bool {
        if subscriptionService.isProUser {
            return false
        }
        
        do {
            let activeChallenges = try await loadChallenges(for: userId)
            return activeChallenges.count >= maxChallengesForFreeUsers
        } catch {
            return false
        }
    }
    
    func loadChallenges(for userId: String) async throws -> [Challenge] {
        do {
            let snapshot = try await Firestore.firestore()
                .collection("users")
                .document(userId)
                .collection("challenges")
                .whereField("isArchived", isEqualTo: false)
                .getDocuments()
            
            return try snapshot.documents.compactMap { document in
                try document.data(as: Challenge.self)
            }
        } catch {
            throw ChallengeError.networkError
        }
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
        // Prevent check-in if challenge is completed
        guard !challenge.isCompleted else {
            throw ChallengeError.challengeCompleted
        }
        
        let effectiveDate = effectiveCheckInDate()
        
        // Prevent multiple check-ins per day
        if let lastCheckIn = challenge.lastCheckInDate,
           Calendar.current.isDate(lastCheckIn, inSameDayAs: effectiveDate) {
            throw ChallengeError.alreadyCheckedIn
        }
        
        var updatedChallenge = challenge
        
        // Reset streak if more than 1 day has passed
        if challenge.hasStreakExpired {
            updatedChallenge.streakCount = 0
        }
        
        // Update challenge
        updatedChallenge.lastCheckInDate = effectiveDate
        updatedChallenge.isCompletedToday = true
        updatedChallenge.streakCount += 1
        updatedChallenge.daysCompleted += 1
        
        // Auto-archive if completed
        if updatedChallenge.isCompleted {
            updatedChallenge.isArchived = true
        }
        
        try await firebaseService.saveChallenge(updatedChallenge)
        
        return updatedChallenge
    }
    
    func archiveChallenge(_ challenge: Challenge) async throws {
        var updatedChallenge = challenge
        updatedChallenge.isArchived = true
        
        try await firebaseService.saveChallenge(updatedChallenge)
    }
    
    // MARK: - Streak Management
    
    func resetStreakIfMissed(for challenge: Challenge) async throws {
        guard challenge.hasStreakExpired else { return }
        
        var updatedChallenge = challenge
        updatedChallenge.streakCount = 0
        updatedChallenge.isCompletedToday = false
        
        try await firebaseService.saveChallenge(updatedChallenge)
    }
    
    func validateAndUpdateStreaks(for userId: String) async throws {
        let challenges = try await loadChallenges(for: userId)
        
        for challenge in challenges {
            try await resetStreakIfMissed(for: challenge)
        }
    }
    
    /// Fetch all challenges for a user - renamed to avoid conflict
    func getUserChallenges(userId: String) async throws -> [Challenge] {
        return try await loadChallenges(for: userId)
    }
    
    /// Update an existing challenge
    func updateChallenge(_ challenge: Challenge) async throws {
        try await firebaseService.saveChallenge(challenge)
    }
    
    /// Delete a specific challenge
    func deleteChallenge(_ challengeId: String, userId: String) async throws {
        try await firebaseService.deleteChallenge(id: UUID(uuidString: challengeId) ?? UUID(), userId: userId)
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
            "lastModified": lastModified
        ]
    }
} 
