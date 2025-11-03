import Foundation
import SwiftUI
import FirebaseFirestore
import Combine

@MainActor
class ChangeUsernameViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var newUsername: String = ""
    @Published var currentUsername: String = ""
    @Published var isValidUsername: Bool = false
    @Published var validationMessage: String = ""
    @Published var isLoading: Bool = false
    @Published var showError: Bool = false
    @Published var showSuccess: Bool = false
    @Published var errorMessage: String = ""
    @Published var usernameUpdated: Bool = false

    // MARK: - Private Properties
    nonisolated(unsafe) private var timer: Timer?
    private var lastUsernameChangeTime: Date?
    private let cooldownPeriodInSeconds: TimeInterval = 60 * 60 * 24 * 30 // 30 days default
    private let userSession = UserSession.shared
    nonisolated(unsafe) private let firestore = Firestore.firestore()

    // MARK: - Initialization
    init() { }

    deinit {
        timer?.invalidate()
    }

    // MARK: - Public Properties

    var isInCooldownPeriod: Bool {
        guard let lastChange = lastUsernameChangeTime else { return false }

        let now = Date()
        let timeSinceLastChange = now.timeIntervalSince(lastChange)
        return timeSinceLastChange < cooldownPeriodInSeconds
    }

    var timeRemainingSeconds: TimeInterval {
        guard let lastChange = lastUsernameChangeTime else { return 0 }

        let now = Date()
        let timeSinceLastChange = now.timeIntervalSince(lastChange)
        let timeRemaining = max(0, cooldownPeriodInSeconds - timeSinceLastChange)
        return timeRemaining
    }

    var formattedTimeRemaining: String {
        let timeRemaining = timeRemainingSeconds

        let hours = Int(timeRemaining) / 3600
        let minutes = Int(timeRemaining) % 3600 / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            let seconds = Int(timeRemaining) % 60
            return "\(minutes)m \(seconds)s"
        }
    }

    var canSaveUsername: Bool {
        guard !isInCooldownPeriod,
              !newUsername.isEmpty,
              newUsername != currentUsername,
              isValidUsername else {
            return false
        }

        return validationMessage == "Username available"
    }

    // MARK: - Public Methods

    func loadUserData() async {
        isLoading = true

        // Load username from UserSession first
        if let username = userSession.username {
            currentUsername = username
            newUsername = username
        }

        guard let userId = userSession.currentUser?.uid else {
            isLoading = false
            return
        }

        do {
            let document = try await firestore
                .collection("users")
                .document(userId)
                .getDocument()

            if document.exists, let data = document.data() {
                // Get username if it exists
                if let username = data["username"] as? String {
                    currentUsername = username
                    newUsername = username
                }

                // Get last username change timestamp
                if let timestamp = data["lastUsernameChangeAt"] as? Timestamp {
                    lastUsernameChangeTime = timestamp.dateValue()
                }
            }
        } catch {
            errorMessage = "Error loading profile: \(error.localizedDescription)"
            showError = true
        }

        isLoading = false
    }

    func validateUsername() {
        guard !newUsername.isEmpty else {
            validationMessage = ""
            isValidUsername = false
            return
        }

        // Reset validation if it's the current username
        if newUsername == currentUsername {
            validationMessage = "This is your current username"
            isValidUsername = true
            return
        }

        // Validate length
        if newUsername.count < 3 {
            validationMessage = "Username must be at least 3 characters"
            isValidUsername = false
            return
        }

        if newUsername.count > 20 {
            validationMessage = "Username must be at most 20 characters"
            isValidUsername = false
            return
        }

        // Validate characters (alphanumeric only)
        let allowedCharacterSet = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        if newUsername.rangeOfCharacter(from: allowedCharacterSet.inverted) != nil {
            validationMessage = "Username can only contain letters and numbers"
            isValidUsername = false
            return
        }

        // If all local checks pass, check availability in Firestore
        checkUsernameAvailability()
    }

    func saveUsername() async {
        guard canSaveUsername else { return }

        isLoading = true

        do {
            guard let userId = userSession.currentUser?.uid else {
                throw NSError(domain: "ChangeUsername", code: 101,
                             userInfo: [NSLocalizedDescriptionKey: "No user is signed in."])
            }

            // 1. Double-check username availability
            let isAvailable = try await isUsernameAvailable()

            if !isAvailable {
                errorMessage = "Username is no longer available"
                showError = true
                isLoading = false
                return
            }

            // 2. Update username in Firestore including reservation and timestamp
            try await updateUsername(userId: userId)

            // 3. Update username in UserSession
            try await userSession.updateUsername(newUsername.lowercased())

            // 4. Update UI state
            currentUsername = newUsername.lowercased()

            // 5. Provide feedback that update was successful
            usernameUpdated = true

            // 6. Trigger haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

        } catch {
            errorMessage = "Failed to update username: \(error.localizedDescription)"
            showError = true
        }

        isLoading = false
    }

    // MARK: - Private Methods

    private func checkUsernameAvailability() {
        isLoading = true
        validationMessage = "Checking availability..."

        Task {
            do {
                let isAvailable = try await isUsernameAvailable()

                if isAvailable {
                    validationMessage = "Username available"
                    isValidUsername = true
                } else {
                    validationMessage = "Username already taken"
                    isValidUsername = false
                }
            } catch {
                validationMessage = "Error checking username"
                isValidUsername = false
            }

            isLoading = false
        }
    }

    private func isUsernameAvailable() async throws -> Bool {
        let usernameSnapshot = try await firestore
            .collection("usernames")
            .document(newUsername.lowercased())
            .getDocument()

        // If document exists, check if it belongs to the current user
        if usernameSnapshot.exists {
            if let userId = usernameSnapshot.data()?["userId"] as? String,
               userId == userSession.currentUser?.uid {
                return false // Username belongs to current user
            }
            return false // Username is taken by another user
        }

        return true // Username is available
    }

    private func updateUsername(userId: String) async throws {
        // Capture only Sendable local values before creating the detached task
        let newUsernameValue = newUsername.lowercased()
        let uid = userId

        do {
            try await Task.detached {
                // Create a Firestore instance locally inside the detached task so we don't capture actor state.
                let fs = Firestore.firestore()
                _ = try await fs.runTransaction { (transaction, errorPointer) -> Any? in
                    do {
                        // 1. Get the user document
                        let userRef = fs.collection("users").document(uid)
                        let userDoc = try transaction.getDocument(userRef)

                        // 2. Get the current username
                        guard let currentUsername = userDoc.data()?[
                            "username"
                        ] as? String else {
                            let error = NSError(
                                domain: "ChangeUsername",
                                code: 102,
                                userInfo: [NSLocalizedDescriptionKey: "Couldn't find current username."]
                            )
                            errorPointer?.pointee = error
                            return nil
                        }

                        // 3. Delete the old username reservation
                        let oldUsernameRef = fs.collection("usernames").document(currentUsername)
                        transaction.deleteDocument(oldUsernameRef)

                        // 4. Create a new username reservation
                        let newUsernameRef = fs.collection("usernames").document(newUsernameValue)
                        transaction.setData(["userId": uid], forDocument: newUsernameRef)

                        // 5. Update the user document with new username and timestamp
                        transaction.updateData([
                            "username": newUsernameValue,
                            "lastUsernameChangeAt": FieldValue.serverTimestamp()
                        ], forDocument: userRef)
                        return nil
                    } catch {
                        // Convert to NSError and surface through the provided pointer as required by the API
                        errorPointer?.pointee = (error as NSError)
                        return nil
                    }
                }
            }.value
        } catch {
            throw error
        }
    }
}