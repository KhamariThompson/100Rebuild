import Foundation
import FirebaseFirestore


enum ChallengeError: Error {
    case notFound
    case invalidData
    case networkError
    case unauthorized
    case freeUserLimitExceeded
    case challengeCompleted
    case alreadyCheckedIn
}

@MainActor
class ChallengeService: ObservableObject {
    static let shared = ChallengeService()
    private let firestore = FirebaseService.shared
    private let collectionPath = "challenges"
    private let subscriptionService = SubscriptionService.shared
    
    private init() {}
    
    // MARK: - CRUD Operations
    
    func createChallenge(title: String, userId: String) async throws -> Challenge {
        // Check free user limit
        if !subscriptionService.isProUser {
            let activeChallenges = try await loadChallenges(for: userId)
            if activeChallenges.count >= 2 {
                throw ChallengeError.freeUserLimitExceeded
            }
        }
        
        let challenge = Challenge(title: title, ownerId: userId)
        _ = try await firestore.createDocument(challenge, in: "users/\(userId)/\(collectionPath)")
        return challenge
    }
    
    func loadChallenges(for userId: String) async throws -> [Challenge] {
        do {
            let snapshot = try await Firestore.firestore()
                .collection("users")
                .document(userId)
                .collection(collectionPath)
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
        
        try await firestore.updateDocument(
            updatedChallenge,
            in: "users/\(challenge.ownerId)/\(collectionPath)",
            documentId: challenge.id.uuidString
        )
        
        return updatedChallenge
    }
    
    func archiveChallenge(_ challenge: Challenge) async throws {
        var updatedChallenge = challenge
        updatedChallenge.isArchived = true
        
        try await firestore.updateDocument(
            updatedChallenge,
            in: "users/\(challenge.ownerId)/\(collectionPath)",
            documentId: challenge.id.uuidString
        )
    }
    
    // MARK: - Streak Management
    
    func resetStreakIfMissed(for challenge: Challenge) async throws {
        guard challenge.hasStreakExpired else { return }
        
        var updatedChallenge = challenge
        updatedChallenge.streakCount = 0
        updatedChallenge.isCompletedToday = false
        
        try await firestore.updateDocument(
            updatedChallenge,
            in: "users/\(challenge.ownerId)/\(collectionPath)",
            documentId: challenge.id.uuidString
        )
    }
    
    func validateAndUpdateStreaks(for userId: String) async throws {
        let challenges = try await loadChallenges(for: userId)
        
        for challenge in challenges {
            try await resetStreakIfMissed(for: challenge)
        }
    }
} 
