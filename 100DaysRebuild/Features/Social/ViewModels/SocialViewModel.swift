import Foundation
import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Network // For NetworkMonitor

@MainActor
class SocialViewModel: ObservableObject {
    // Username state
    @Published var username = ""
    @Published var usernameStatus: UsernameStatus = .unclaimed
    @Published var validationMessage: String = ""
    @Published var isCheckingUsername = false
    @Published private(set) var showSuccessToast = false
    
    // Animation state
    @Published var usernameJustClaimed = false
    
    // Loading state
    @Published private(set) var isLoading = false
    @Published var errorMessage: String? = nil
    
    // Social data
    @Published var friends: [Friend] = []
    @Published var communityChallenges: [CommunityChallenge] = []
    @Published var socialFeed: [SocialFeedItem] = [] // Empty array for future implementation
    @Published var isOffline = false // Track offline status
    @Published var error: String? = nil // For displaying errors
    
    // Dependencies
    private let firestore = Firestore.firestore()
    
    enum UsernameStatus {
        case unclaimed
        case claimed(String)
        case validating
        case invalid
        case error(String)
    }
    
    init() {
        // Check initial network status
        isOffline = !NetworkMonitor.shared.isConnected
        
        // Setup network status observer
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(networkStatusChanged),
            name: NetworkMonitor.networkStatusChanged,
            object: nil
        )
        
        // Load initial data
        Task {
            await refreshData()
        }
    }
    
    // Handle network status changes
    @objc private func networkStatusChanged(_ notification: Notification) {
        if let isConnected = notification.userInfo?["isConnected"] as? Bool {
            DispatchQueue.main.async {
                self.isOffline = !isConnected
            }
        }
    }
    
    deinit {
        print("✅ Released: SocialViewModel")
        NotificationCenter.default.removeObserver(self)
        // Cancel any async tasks
        Task {
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Loads the current user's username
    func loadUserUsername() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            usernameStatus = .error("User not signed in")
            return
        }
        
        isLoading = true
        
        do {
            let document = try await firestore
                .collection("users")
                .document(userId)
                .getDocument()
            
            if document.exists, let data = document.data(), let username = data["username"] as? String {
                self.username = username
                usernameStatus = .claimed(username)
            } else {
                usernameStatus = .unclaimed
            }
        } catch {
            usernameStatus = .error("Failed to load username: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    /// Validates the input username
    func validateUsername(username: String) {
        // Reset validation state
        self.username = username
        
        // Quick format checks
        if username.isEmpty {
            validationMessage = "Username cannot be empty"
            usernameStatus = .invalid
            return
        }
        
        if username.count < 3 {
            validationMessage = "Username must be at least 3 characters"
            usernameStatus = .invalid
            return
        }
        
        if username.count > 20 {
            validationMessage = "Username must be at most 20 characters"
            usernameStatus = .invalid
            return
        }
        
        // Check for alphanumeric characters
        let allowedCharacterSet = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        if username.rangeOfCharacter(from: allowedCharacterSet.inverted) != nil {
            validationMessage = "Username can only contain letters and numbers"
            usernameStatus = .invalid
            return
        }
        
        // If we pass all local validation, check availability
        checkUsernameAvailability(username: username)
    }
    
    /// Claims the validated username for the user
    func claimUsername() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "User not signed in"
            usernameStatus = .error("User not signed in")
            return
        }
        
        isLoading = true
        errorMessage = nil
        usernameJustClaimed = false
        
        do {
            // Double-check username availability
            let isAvailable = try await isUsernameAvailable(username)
            
            if !isAvailable {
                errorMessage = "Username is no longer available"
                usernameStatus = .invalid
                isLoading = false
                return
            }
            
            // Transaction to atomically update both user profile and usernames collection
            try await firestore.runTransaction { transaction, errorPointer in
                // 1. Reserve the username in usernames collection
                let usernameRef = self.firestore.collection("usernames").document(self.username.lowercased())
                transaction.setData(["userId": userId], forDocument: usernameRef)
                
                // 2. Update the user's profile
                let userRef = self.firestore.collection("users").document(userId)
                transaction.updateData(["username": self.username.lowercased()], forDocument: userRef)
                
                return nil
            }
            
            // Update local state
            usernameStatus = .claimed(username.lowercased())
            showSuccessToast = true
            usernameJustClaimed = true
            
            // Hide toast after delay
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                self.showSuccessToast = false
                
                // Reset the animation trigger after a delay
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                self.usernameJustClaimed = false
            }
        } catch {
            errorMessage = "Failed to claim username: \(error.localizedDescription)"
            usernameStatus = .error(error.localizedDescription)
        }
        
        isLoading = false
    }
    
    /// Refreshes all social data
    func refreshData() async {
        isLoading = true
        error = nil
        errorMessage = nil
        
        // Check internet connectivity
        isOffline = !NetworkMonitor.shared.isConnected
        
        do {
            // Load username first
            await loadUserUsername()
            
            // In the future, this would load real social data
            // For now, just simulate a delay and set empty data
            if !isOffline {
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
                socialFeed = [] // Empty for now until social features are implemented
            }
        } catch {
            self.error = error.localizedDescription
            self.errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Private Methods
    
    /// Filters username to only contain alphanumeric characters
    func filterUsername(_ input: String) -> String {
        return input.replacingOccurrences(of: "[^a-zA-Z0-9]", with: "", options: .regularExpression)
    }
    
    /// Checks if a username is available to claim
    private func checkUsernameAvailability(username: String) {
        usernameStatus = .validating
        isCheckingUsername = true
        validationMessage = "Checking availability..."
        
        Task {
            do {
                let isAvailable = try await isUsernameAvailable(username)
                
                if isAvailable {
                    validationMessage = "Username available!"
                    usernameStatus = .unclaimed
                } else {
                    // Check if it's the user's own username
                    if case .claimed(let currentUsername) = usernameStatus, 
                       currentUsername.lowercased() == username.lowercased() {
                        validationMessage = "This is already your username"
                    } else {
                        validationMessage = "Username already taken"
                        usernameStatus = .invalid
                    }
                }
            } catch {
                validationMessage = "Error checking username"
                usernameStatus = .error(error.localizedDescription)
            }
            
            isCheckingUsername = false
        }
    }
    
    /// Checks if a username is available in Firestore
    private func isUsernameAvailable(_ username: String) async throws -> Bool {
        let usernameSnapshot = try await firestore
            .collection("usernames")
            .document(username.lowercased())
            .getDocument()
        
        // If document exists, username is taken
        if usernameSnapshot.exists {
            // Check if this is the user's current username
            if let userId = usernameSnapshot.data()?["userId"] as? String,
               userId == Auth.auth().currentUser?.uid {
                return false // Username belongs to current user
            }
            return false // Username is taken by another user
        }
        
        return true // Username is available
    }
    
    // MARK: - Models
    
    /// Simple model for a social feed item (placeholder for future implementation)
    struct SocialFeedItem: Identifiable {
        let id = UUID()
        let userId: String
        let username: String
        let content: String
        let timestamp: Date
        let likes: Int
        let userProfileImageUrl: URL?
        
        init(userId: String, username: String, content: String, timestamp: Date, likes: Int = 0, userProfileImageUrl: URL? = nil) {
            self.userId = userId
            self.username = username
            self.content = content
            self.timestamp = timestamp
            self.likes = likes
            self.userProfileImageUrl = userProfileImageUrl
        }
    }
    
    /// Simple model for a friend connection (placeholder for future implementation)
    struct Friend: Identifiable {
        let id: String
        let username: String
        let displayName: String
        let profileImageUrl: URL?
        
        init(id: String, username: String, displayName: String, profileImageUrl: URL? = nil) {
            self.id = id
            self.username = username
            self.displayName = displayName
            self.profileImageUrl = profileImageUrl
        }
    }
    
    /// Simple model for a community challenge (placeholder for future implementation)
    struct CommunityChallenge: Identifiable {
        let id = UUID()
        let title: String
        let description: String
        let creatorUsername: String
        let participants: Int
        let startDate: Date
        
        init(title: String, description: String, creatorUsername: String, participants: Int = 0, startDate: Date = Date()) {
            self.title = title
            self.description = description
            self.creatorUsername = creatorUsername
            self.participants = participants
            self.startDate = startDate
        }
    }
} 