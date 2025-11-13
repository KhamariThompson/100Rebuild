import Foundation
import Firebase
import FirebaseFirestore
import FirebaseAuth
import Combine
import Network // For NetworkMonitor

// Make these symbols accessible to other files by prefixing with 'public'
public enum CheckInError: Error, LocalizedError {
    case notAuthenticated
    case networkUnavailable
    case firestoreError(Error)
    case transactionFailed
    case timeout
    case alreadyCheckedInToday
    case authRequired
    
    public var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to check in"
        case .networkUnavailable:
            return "No internet connection. Your check-in will be saved when you're back online."
        case .firestoreError(let error):
            return "Database error: \(error.localizedDescription)"
        case .transactionFailed:
            return "Could not complete check-in. Please try again."
        case .timeout:
            return "The operation timed out. Please try again."
        case .alreadyCheckedInToday:
            return "You've already checked in today. Come back tomorrow!"
        case .authRequired:
            return "Authentication required to perform this operation"
        }
    }
}

@MainActor
public class CheckInService {
    public static let shared = CheckInService()
    
    private let firestore = Firestore.firestore()
    private let pendingCheckInsKey = "pendingCheckIns"
    
    private init() {
        // Initialize pending check-ins queue from UserDefaults
        synchronizePendingCheckIns()
        
        // Listen for network changes to try synchronizing pending check-ins
        NotificationCenter.default.addObserver(
            self, 
            selector: #selector(handleNetworkStatusChange),
            name: NetworkMonitor.networkStatusChanged, 
            object: nil
        )
    }
    
    @objc private func handleNetworkStatusChange(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let isConnected = userInfo["isConnected"] as? Bool,
           isConnected {
            // When network becomes available, try to process pending check-ins
            synchronizePendingCheckIns()
        }
    }
    
    // Attempt to synchronize any pending check-ins
    private func synchronizePendingCheckIns() {
        guard NetworkMonitor.shared.isConnected else { return }
        
        // Get pending check-ins from UserDefaults
        guard let data = UserDefaults.standard.data(forKey: pendingCheckInsKey) else {
            return // No data to process
        }
        
        // Decode the data without try? expression
        let pendingCheckIns: [PendingCheckIn]
        do {
            pendingCheckIns = try JSONDecoder().decode([PendingCheckIn].self, from: data)
        } catch {
            print("Failed to decode pending check-ins: \(error)")
            return
        }
        
        // Proceed only if there are check-ins to process
        guard !pendingCheckIns.isEmpty else {
            return
        }
        
        print("Processing \(pendingCheckIns.count) pending check-ins")
        
        // Process each pending check-in
        Task {
            var remainingCheckIns = pendingCheckIns
            var processedCount = 0
            
            for checkIn in pendingCheckIns {
                do {
                    _ = try await performCheckIn(
                        userId: checkIn.userId, 
                        challengeId: checkIn.challengeId,
                        date: checkIn.date,
                        durationInMinutes: checkIn.durationInMinutes
                    )
                    remainingCheckIns.removeAll { $0.id == checkIn.id }
                    processedCount += 1
                } catch {
                    print("Failed to process pending check-in: \(error.localizedDescription)")
                    // Keep in the queue if it's a transient error
                    if let error = error as? CheckInError, 
                       case .networkUnavailable = error {
                        // Keep in queue if network error
                    } else if let error = error as? CheckInError,
                            case .alreadyCheckedInToday = error {
                        // Remove from queue if already checked in
                        remainingCheckIns.removeAll { $0.id == checkIn.id }
                    } else {
                        // Remove from queue if other error (likely permanent)
                        remainingCheckIns.removeAll { $0.id == checkIn.id }
                    }
                }
            }
            
            // Update UserDefaults with remaining check-ins
            if remainingCheckIns.isEmpty {
                UserDefaults.standard.removeObject(forKey: pendingCheckInsKey)
                print("All pending check-ins processed successfully")
            } else {
                // Encode without try? expression
                do {
                    let encoded = try JSONEncoder().encode(remainingCheckIns)
                    UserDefaults.standard.set(encoded, forKey: pendingCheckInsKey)
                    print("\(processedCount) check-ins processed, \(remainingCheckIns.count) remaining")
                } catch {
                    print("Failed to encode remaining check-ins: \(error)")
                }
            }
            UserDefaults.standard.synchronize()
        }
    }
    
    // Main check-in function with robust error handling
    public func checkIn(
        for challengeId: String,
        durationInMinutes: Int? = nil,
        note: String? = nil,
        photo: UIImage? = nil
    ) async throws -> Bool {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw CheckInError.authRequired
        }

        if !NetworkMonitor.shared.isConnected {
            // Queue check-in for later processing
            // Note: Photo uploads are skipped in offline mode for now
            savePendingCheckIn(userId: userId, challengeId: challengeId, date: Date(), durationInMinutes: durationInMinutes)

            // Return success immediately for offline mode
            return true
        }

        // Upload photo to Firebase Storage if provided
        var photoURL: String? = nil
        if let photo = photo {
            let checkInId = UUID().uuidString
            do {
                let url = try await PhotoStorageService.shared.uploadCheckInPhoto(
                    image: photo,
                    challengeId: challengeId,
                    checkInId: checkInId
                )
                photoURL = url.absoluteString
            } catch {
                print("Failed to upload photo: \(error.localizedDescription)")
                // Continue with check-in even if photo upload fails
            }
        }

        // Fire and forget - run all operations in background from the main actor.
        Task { @MainActor in
            do {
                // Perform the check-in operation (internally the heavy work runs off the actor)
                let _ = try await self.performCheckIn(
                    userId: userId,
                    challengeId: challengeId,
                    date: Date(),
                    durationInMinutes: durationInMinutes,
                    note: note,
                    photoURL: photoURL
                )

                // Run badge evaluation in background with even lower priority
                Task.detached(priority: .background) {
                    await BadgeService.shared.evaluateBadgesAfterCheckIn(challengeId: challengeId)
                }
            } catch {
                print("Background check-in failed: \(error.localizedDescription)")
            }
        }

        // Return success immediately to avoid UI delay
        return true
    }
    
    // Perform the actual check-in operation
    nonisolated private func performCheckIn(
        userId: String,
        challengeId: String,
        date: Date,
        durationInMinutes: Int? = nil,
        note: String? = nil,
        photoURL: String? = nil
    ) async throws -> Bool {
        // Run the Firestore transaction
        let db = Firestore.firestore()

        let result = try await db.runTransaction { (transaction, errorPointer) -> Any? in
            do {
                let challengeRef = db.collection("users").document(userId).collection("challenges").document(challengeId)

                // Get current challenge data
                let challengeSnapshot = try transaction.getDocument(challengeRef)
                guard var challengeData = challengeSnapshot.data() else {
                    return false
                }

                let calendar = Calendar.current
                let today = calendar.startOfDay(for: date)

                // Get last check-in date if available
                var lastCheckInDate: Date?
                if let lastCheckInTimestamp = challengeData["lastCheckInDate"] as? Timestamp {
                    lastCheckInDate = lastCheckInTimestamp.dateValue()
                }

                // If already checked in today, don't duplicate the check-in
                if let lastCheckIn = lastCheckInDate, calendar.isDate(lastCheckIn, inSameDayAs: today) {
                    return "already_checked_in"
                }

                // Calculate streak based on date difference
                var streakCount = (challengeData["streakCount"] as? Int) ?? 0
                var streakActive = false

                if let lastCheckIn = lastCheckInDate {
                    let lastCheckInDay = calendar.startOfDay(for: lastCheckIn)
                    let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
                    streakActive = calendar.isDate(lastCheckInDay, inSameDayAs: yesterday)
                }

                if streakActive {
                    streakCount += 1
                } else {
                    streakCount = 1
                }

                let daysCompleted = (challengeData["daysCompleted"] as? Int) ?? 0

                // Update the challenge with streak and completion info
                challengeData["streakCount"] = streakCount
                challengeData["daysCompleted"] = daysCompleted + 1
                challengeData["lastCheckInDate"] = Timestamp(date: date)
                challengeData["isCompletedToday"] = true
                challengeData["lastModified"] = Timestamp(date: date)

                try transaction.setData(challengeData, forDocument: challengeRef)

                // Create check-in document
                let checkInId = UUID().uuidString
                let checkInRef = challengeRef.collection("checkIns").document(checkInId)

                var checkInData: [String: Any] = [
                    "date": Timestamp(date: date),
                    "userId": userId,
                    "dayNumber": daysCompleted + 1
                ]

                if let duration = durationInMinutes {
                    checkInData["durationInMinutes"] = duration
                }

                // Add note if provided
                if let note = note, !note.isEmpty {
                    checkInData["note"] = note
                }

                // Add photo URL if provided
                if let photoURL = photoURL {
                    checkInData["photoURL"] = photoURL
                }

                try transaction.setData(checkInData, forDocument: checkInRef)

                return true
            } catch {
                errorPointer?.pointee = error as NSError
                return false
            }
        }

        // Interpret transaction result
        if let resultString = result as? String, resultString == "already_checked_in" {
            throw CheckInError.alreadyCheckedInToday
        }

        guard let success = result as? Bool, success else {
            throw CheckInError.transactionFailed
        }

        return true
    }
    
    // Store pending check-in for offline mode
    private func savePendingCheckIn(userId: String, challengeId: String, date: Date, durationInMinutes: Int? = nil) {
        let key = self.pendingCheckInsKey
        // Get existing pending check-ins
        var pendingCheckIns: [PendingCheckIn] = []
        if let data = UserDefaults.standard.data(forKey: key) {
            // Properly handle the decoding with try-catch
            do {
                pendingCheckIns = try JSONDecoder().decode([PendingCheckIn].self, from: data)
            } catch {
                print("Failed to decode existing pending check-ins: \(error)")
                // Continue with empty array if decoding fails
            }
        }
        
        // Add new check-in
        let newCheckIn = PendingCheckIn(
            id: UUID().uuidString,
            userId: userId,
            challengeId: challengeId,
            date: date,
            durationInMinutes: durationInMinutes
        )
        pendingCheckIns.append(newCheckIn)
        
        // Save back to UserDefaults with proper try-catch
        do {
            let encoded = try JSONEncoder().encode(pendingCheckIns)
            UserDefaults.standard.set(encoded, forKey: key)
            UserDefaults.standard.synchronize()
            print("Saved check-in for offline processing: \(challengeId)")
        } catch {
            print("Failed to encode pending check-ins: \(error)")
        }
    }
    
    // Add a method to check if a user has already checked in today for a challenge
    public func isCheckedInToday(for challengeId: String) async throws -> Bool {
        // Verify authentication
        guard let userId = Auth.auth().currentUser?.uid else {
            throw CheckInError.notAuthenticated
        }

        let db = self.firestore
        let challengeRef = db
            .collection("users")
            .document(userId)
            .collection("challenges")
            .document(challengeId)
        
        do {
            let document = try await challengeRef.getDocument()
            guard let data = document.data() else {
                return false
            }
            
            // Get last check-in date
            if let lastCheckInTimestamp = data["lastCheckInDate"] as? Timestamp {
                let lastCheckInDate = lastCheckInTimestamp.dateValue()
                // Use Calendar to check if it's the same day
                return Calendar.current.isDateInToday(lastCheckInDate)
            }
            
            return false
        } catch {
            throw CheckInError.firestoreError(error)
        }
    }
    
    // Helper function to determine if a streak is still active
    public func isStreakActive(lastCheckInDate: Date?) -> Bool {
        guard let lastCheckIn = lastCheckInDate else { return false }

        // A streak is active if the last check-in was today or yesterday
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastCheckInDay = calendar.startOfDay(for: lastCheckIn)

        let daysBetween = calendar.dateComponents([.day], from: lastCheckInDay, to: today).day ?? 0

        // Streak is active if checked in today or yesterday
        return daysBetween <= 1
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// Model for storing pending check-ins
struct PendingCheckIn: Codable {
    let id: String
    let userId: String
    let challengeId: String
    let date: Date
    let durationInMinutes: Int?
} 
