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
    
    func validateUsername() {
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
        
        // For better UX, don't check availability on every keystroke
        // Allow at least 3 characters before checking
        if username.count >= 3 {
            // Check availability after typing stops
            debounceCheckAvailability()
        }
    }
    
    private var availabilityCheckTask: Task<Void, Never>?
    
    private func debounceCheckAvailability() {
        // Cancel any pending availability check
        availabilityCheckTask?.cancel()
        
        // Start a new check with a delay to avoid too many Firestore calls
        availabilityCheckTask = Task {
            do {
                try await Task.sleep(nanoseconds: 600_000_000) // 600ms debounce
                if !Task.isCancelled {
                    await checkUsernameAvailability()
                }
            } catch {}
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
            try await userSession.updateUsername(username)
            isLoading = false
            showSuccess = true
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