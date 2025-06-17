import Foundation
import FirebaseFirestore
import SwiftUI

@MainActor
class UsernameSetupViewModel: ObservableObject {
    @Published var username = ""
    @Published var error: String?
    @Published var isLoading = false
    @Published var showSuccess = false
    @Published var isValid = false
    
    private let firestore = FirebaseService.shared
    private let userSession = UserSession.shared
    private var validationTask: Task<Void, Never>?
    
    func validateUsername() {
        // Cancel any existing validation task
        validationTask?.cancel()
        
        // Reset validation state
        isValid = false
        error = nil
        
        // Check format first before checking availability
        if username.isEmpty {
            error = "Username cannot be empty"
            return
        }
        
        if !isValidFormat(username) {
            error = "Username must be 3-20 characters, letters and numbers only"
            return
        }
        
        // Create a new debounced task with increased debounce time
        validationTask = Task {
            do {
                // Longer debounce delay to prevent UI flickering
                try await Task.sleep(nanoseconds: 800_000_000) // 800ms debounce
                
                if !Task.isCancelled {
                    // Check availability after typing stops
                    await checkUsernameAvailability()
                }
            } catch {
                // Task was cancelled, do nothing
            }
        }
    }
    
    private func checkUsernameAvailability() async {
        do {
            let isAvailable = try await isUsernameAvailable(username)
            
            await MainActor.run {
                if !isAvailable {
                    self.error = "Username already taken"
                    self.isValid = false
                } else {
                    self.error = nil
                    self.isValid = true
                }
            }
        } catch {
            await MainActor.run {
                self.error = "Error checking username"
                self.isValid = false
            }
        }
    }
    
    func submitUsername() async throws {
        guard isValidFormat(username) else {
            error = "Username must be 3-20 characters, letters and numbers only"
            return
        }
        
        guard let userId = userSession.currentUser?.uid else {
            error = "User not authenticated"
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await firestore.createUserProfile(username: username, userId: userId)
            try await userSession.updateUsername(username)
            showSuccess = true
        } catch {
            self.error = "Failed to create username. Please try again."
            throw error
        }
    }
    
    func saveUsername() async {
        guard !username.isEmpty else {
            error = "Username cannot be empty"
            return
        }
        
        if !isValid {
            await checkUsernameAvailability()
            if !isValid { return }
        }
        
        isLoading = true
        error = nil
        
        do {
            // 1. Get current user ID
            guard let userId = userSession.currentUser?.uid else {
                error = "User not authenticated"
                isLoading = false
                return
            }
            
            // Normalize the username to lowercase
            let normalizedUsername = username.lowercased()
            
            // 2. Update Firestore user document - don't change the displayName
            try await Firestore.firestore()
                .collection("users")
                .document(userId)
                .updateData(["username": normalizedUsername])
            
            // 3. Create username reservation
            try await Firestore.firestore()
                .collection("usernames")
                .document(normalizedUsername)
                .setData(["userId": userId])
            
            // 4. Update UserSession's username (not displayName)
            try await userSession.updateUsername(normalizedUsername)
            
            isLoading = false
            showSuccess = true
            
            // Post notification that username has been updated
            NotificationCenter.default.post(
                name: NSNotification.Name("UserProfileUpdated"),
                object: nil,
                userInfo: ["username": normalizedUsername]
            )
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }
    
    private func isValidFormat(_ username: String) -> Bool {
        let usernameRegex = "^[a-zA-Z0-9]{3,20}$"
        let usernamePredicate = NSPredicate(format: "SELF MATCHES %@", usernameRegex)
        return usernamePredicate.evaluate(with: username)
    }
    
    private func isUsernameAvailable(_ username: String) async throws -> Bool {
        let snapshot = try await Firestore.firestore()
            .collection("usernames")
            .document(username)
            .getDocument()
        
        return !snapshot.exists
    }
}

struct UsernameLookup: Codable {
    let userId: String
} 