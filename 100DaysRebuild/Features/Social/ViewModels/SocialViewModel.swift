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
    
    // Computed properties for UI
    var validationBorderColor: Color {
        switch usernameStatus {
        case .validating:
            return .yellow
        case .claimed:
            return .green
        case .invalid:
            return .red
        case .error:
            return .red
        case .unclaimed:
            // When unclaimed but username has content and passes basic validation, show green
            if !username.isEmpty && username.count >= 3 && isValidFormat(username) {
                return .green
            }
            return Color.theme.border
        }
    }
    
    var validationMessageColor: Color {
        switch usernameStatus {
        case .validating:
            return .yellow
        case .claimed:
            return .green
        case .invalid, .error:
            return .red
        case .unclaimed:
            // Show green for available username
            if validationMessage == "Username available!" {
                return .green
            }
            return Color.theme.subtext
        }
    }
    
    var canClaimUsername: Bool {
        if case .validating = usernameStatus { return false }
        if case .claimed = usernameStatus { return false }
        if case .invalid = usernameStatus { return false }
        if case .error = usernameStatus { return false }
        if isCheckingUsername { return false }
        return !username.isEmpty && username.count >= 3 && isValidFormat(username)
    }
    
    
    // Dependencies
    private let firestore = Firestore.firestore()
    
    enum UsernameStatus: Equatable {
        case unclaimed
        case claimed(String)
        case validating
        case invalid
        case error(String)
        
        // Add computed property to check for error state
        var hasError: Bool {
            if case .error(_) = self {
                return true
            }
            return false
        }
        
        static func == (lhs: UsernameStatus, rhs: UsernameStatus) -> Bool {
            switch (lhs, rhs) {
            case (.unclaimed, .unclaimed):
                return true
            case (.claimed(let lhsValue), .claimed(let rhsValue)):
                return lhsValue == rhsValue
            case (.validating, .validating):
                return true
            case (.invalid, .invalid):
                return true
            case (.error(let lhsValue), .error(let rhsValue)):
                return lhsValue == rhsValue
            default:
                return false
            }
        }
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
        Task { [weak self] in
            guard let self = self else { return }
            await self.refreshData()
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
        validationTask?.cancel()
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
            // Check UserSession first - this should be most up-to-date
            if let sessionUsername = UserSession.shared.username, !sessionUsername.isEmpty {
                self.username = sessionUsername
                usernameStatus = .claimed(sessionUsername)
                isLoading = false
                return
            }
            
            // If not in UserSession, check Firestore
            let document = try await firestore
                .collection("users")
                .document(userId)
                .getDocument()
            
            if document.exists, let data = document.data(), let username = data["username"] as? String, !username.isEmpty {
                self.username = username
                usernameStatus = .claimed(username)
                
                // Update the UserSession as well
                try? await UserSession.shared.updateUsername(username)
            } else {
                // No username found or empty username
                self.username = ""
                usernameStatus = .unclaimed
            }
        } catch {
            usernameStatus = .error("Failed to load username: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    /// Shows the username setup UI and prepares for username validation
    func showUsernameSetup() {
        // Reset the validation state
        username = ""
        validationMessage = "Enter a username"
        usernameStatus = .unclaimed
        
        // Display a text field or prompt for username input
        // This method is called when the user taps the "Set Username" button
    }
    
    // MARK: - Username Validation
    
    // Improved debouncing with cancellation
    private var validationTask: Task<Void, Never>?
    
    /// Validates the input username with debouncing to prevent rapid UI updates
    func validateUsername(username: String) {
        // Reset validation state
        self.username = username
        
        // Cancel any pending validation task
        validationTask?.cancel()
        
        // Quick format checks - these are immediate, without server check
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
        
        if !isValidFormat(username) {
            validationMessage = "Username can only contain letters and numbers"
            usernameStatus = .invalid
            return
        }
        
        // At this point, username format is valid
        validationMessage = "Valid format, checking availability..."
        
        // Create a new task with debounce to avoid rapid server calls
        validationTask = Task { @MainActor in
            do {
                // Debounce delay - only start server check after user stops typing
                try await Task.sleep(nanoseconds: 800_000_000) // 800ms debounce
                
                if Task.isCancelled { return }
                
                // Indicate validation in progress
                usernameStatus = .validating
                isCheckingUsername = true
                
                // Check username availability with the server
                let isAvailable = try await isUsernameAvailable(username)
                
                if Task.isCancelled { return }
                
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
                if !Task.isCancelled {
                    validationMessage = "Error checking username"
                    usernameStatus = .error(error.localizedDescription)
                }
            }
            
            // Reset loading state
            if !Task.isCancelled {
                isCheckingUsername = false
            }
        }
    }
    
    /// Claims the validated username for the user
    func claimUsername() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "User not signed in"
            usernameStatus = .error("User not signed in")
            return
        }
        
        // Don't allow claiming if the format is invalid
        if !isValidFormat(username) {
            errorMessage = "Invalid username format"
            usernameStatus = .invalid
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
            
            // Update UserSession
            try await UserSession.shared.updateUsername(username.lowercased())
            
            // Update local state
            usernameStatus = .claimed(username.lowercased())
            showSuccessToast = true
            usernameJustClaimed = true
            
            // Hide toast after delay
            Task { [weak self] in
                guard let self = self else { return }
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                await MainActor.run {
                    self.showSuccessToast = false
                }
                
                // Reset the animation trigger after a delay
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                await MainActor.run {
                    self.usernameJustClaimed = false
                }
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
    
    // MARK: - Helper Methods
    
    /// Checks if a username follows the required format
    private func isValidFormat(_ username: String) -> Bool {
        let allowedCharacterSet = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        return username.rangeOfCharacter(from: allowedCharacterSet.inverted) == nil
    }
    
    /// Filters username to only contain alphanumeric characters
    func filterUsername(_ input: String) -> String {
        return input.replacingOccurrences(of: "[^a-zA-Z0-9]", with: "", options: .regularExpression)
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