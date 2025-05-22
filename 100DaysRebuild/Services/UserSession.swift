import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Network
import Firebase

enum AuthState {
    case loading
    case signedIn(FirebaseAuth.User)
    case signedOut
    case error(Error)
}

@MainActor
class UserSession: ObservableObject {
    static let shared = UserSession()
    
    @Published private(set) var authState: AuthState = .loading
    @Published private(set) var isAuthenticated = false
    @Published private(set) var hasCompletedOnboarding = false
    @Published private(set) var currentUser: FirebaseAuth.User?
    @Published private(set) var username: String?
    @Published private(set) var photoURL: URL?
    @Published var isNetworkAvailable = true
    @Published var errorMessage: String?
    @Published var lastSignInTime: Date?
    
    // Add a handler that other components can set to be notified of auth changes
    var authStateDidChangeHandler: (() -> Void)?
    
    private let auth = Auth.auth()
    private let firestore = Firestore.firestore()
    private var stateListener: AuthStateDidChangeListenerHandle?
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "UserSession.NetworkMonitor")
    
    private init() {
        setupNetworkMonitoring()
        setupAuthStateListener()
        
        // Listen for network status notification from AppDelegate
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNetworkStatusChange),
            name: NSNotification.Name("NetworkStatusChanged"),
            object: nil
        )
    }
    
    deinit {
        if let listener = stateListener {
            auth.removeStateDidChangeListener(listener)
        }
        networkMonitor.cancel()
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            let isConnected = path.status == .satisfied
            Task { @MainActor in
                self?.isNetworkAvailable = isConnected
                
                // If network becomes available and we're in an error state,
                // attempt to refresh the auth state
                if isConnected, case .error = self?.authState {
                    self?.refreshAuthState()
                }
            }
        }
        networkMonitor.start(queue: networkQueue)
    }
    
    @objc private func handleNetworkStatusChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let isConnected = userInfo["isConnected"] as? Bool,
              isConnected == true else { return }
        
        // Network is back, refresh auth state
        Task { @MainActor in
            self.isNetworkAvailable = true
            if case .error = self.authState {
                self.refreshAuthState()
            }
        }
    }
    
    private func refreshAuthState() {
        // Reset to loading state
        authState = .loading
        
        // Check current user
        if let user = auth.currentUser {
            currentUser = user
            isAuthenticated = true
            authState = .signedIn(user)
            lastSignInTime = Date()
            
            // Reload user profile
            Task {
                await loadUserProfile()
            }
        } else {
            authState = .signedOut
            currentUser = nil
            isAuthenticated = false
            username = nil
            photoURL = nil
            lastSignInTime = nil
        }
        
        // Notify listeners about auth state change
        authStateDidChangeHandler?()
    }
    
    private func setupAuthStateListener() {
        print("Setting up auth state listener in UserSession")
        
        // Check for existing listener and remove it
        if let listener = stateListener {
            auth.removeStateDidChangeListener(listener)
        }
        
        stateListener = auth.addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                guard let self = self else { return }
                
                if let user = user {
                    print("UserSession: User authenticated - \(user.uid)")
                    self.currentUser = user
                    self.isAuthenticated = true
                    self.authState = .signedIn(user)
                    self.lastSignInTime = Date()
                    await self.loadUserProfile()
                } else {
                    print("UserSession: No active user")
                    self.authState = .signedOut
                    self.currentUser = nil
                    self.isAuthenticated = false
                    self.username = nil
                    self.photoURL = nil
                    self.lastSignInTime = nil
                }
                
                // Notify listeners about auth state change
                self.authStateDidChangeHandler?()
                
                // Post notification for SubscriptionService
                NotificationCenter.default.post(
                    name: NSNotification.Name("AuthStateChanged"),
                    object: nil
                )
            }
        }
    }
    
    private func loadUserProfile() async {
        guard let userId = currentUser?.uid else { 
            print("UserSession: No user ID available for profile loading")
            return 
        }
        
        // Clear error message on new profile load attempt
        errorMessage = nil
        print("UserSession: Loading profile for user \(userId)")
        
        do {
            // Check network availability before making request
            guard isNetworkAvailable else {
                print("UserSession: Network unavailable, trying cache")
                // Try to get from cache first
                do {
                    let document = try await firestore
                        .collection("users")
                        .document(userId)
                        .getDocument(source: .cache)
                    
                    if let data = document.data() {
                        self.username = data["username"] as? String
                        self.hasCompletedOnboarding = self.username != nil
                        
                        if let username = self.username {
                            print("UserSession: Loaded cached profile with username: \(username)")
                        } else {
                            print("UserSession: Loaded cached profile but username is nil")
                            // Even in offline mode, we can set a local username to improve UX
                            let tempUsername = "User\(String(userId.prefix(4)))"
                            self.username = tempUsername
                            self.hasCompletedOnboarding = true
                            print("UserSession: Using temporary username \(tempUsername) until online")
                        }
                        
                        // Load the photoURL if available
                        if let photoURLString = data["photoURL"] as? String, 
                           let url = URL(string: photoURLString) {
                            self.photoURL = url
                        }
                        return
                    } else {
                        print("UserSession: No cached data found")
                    }
                } catch {
                    // Network is unavailable and cache retrieval failed
                    print("UserSession: Cache retrieval failed - \(error.localizedDescription)")
                    self.errorMessage = "Unable to load profile. Check your network connection."
                    return
                }
                
                return
            }
            
            // Network is available, make the request
            print("UserSession: Fetching profile from Firestore")
            let document = try await firestore
                .collection("users")
                .document(userId)
                .getDocument()
            
            if document.exists, let data = document.data() {
                print("UserSession: Profile document exists")
                self.username = data["username"] as? String
                self.hasCompletedOnboarding = self.username != nil
                
                if let photoURLString = data["photoURL"] as? String,
                   let url = URL(string: photoURLString) {
                    self.photoURL = url
                    print("UserSession: Loaded profile photo URL: \(url)")
                }
                
                if let username = self.username {
                    print("UserSession: Loaded username: \(username)")
                } else {
                    print("UserSession: Profile exists but username is nil, will create one")
                    
                    // Profile exists but username is missing - need to fix it
                    try await createDefaultProfileDocument(for: userId)
                }
            } else {
                // Document doesn't exist - this is normal for new users
                print("UserSession: No profile document exists for user \(userId), creating one")
                self.username = nil
                self.photoURL = nil
                self.hasCompletedOnboarding = false
                
                // For new users, create a default profile document
                try await createDefaultProfileDocument(for: userId)
            }
        } catch {
            print("UserSession: Error loading user profile - \(error.localizedDescription)")
            // Log detailed error info for debugging
            if let nsError = error as NSError? {
                print("UserSession: Error domain: \(nsError.domain), code: \(nsError.code)")
                if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
                    print("UserSession: Underlying error: \(underlyingError.localizedDescription)")
                }
            }
            
            self.errorMessage = "Error loading profile: \(error.localizedDescription)"
            
            // Try to create a default profile as a recovery attempt
            do {
                try await createDefaultProfileDocument(for: userId)
                print("UserSession: Created recovery profile after loading error")
            } catch {
                print("UserSession: Recovery attempt also failed: \(error.localizedDescription)")
            }
        }
    }
    
    // Helper method to create a default profile document for new users
    private func createDefaultProfileDocument(for userId: String) async throws {
        print("UserSession: Creating default profile document for new user \(userId)")
        
        // Check if the document already exists to avoid overwriting
        let document = try await firestore
            .collection("users")
            .document(userId)
            .getDocument()
        
        if !document.exists {
            // Generate a random username for new users
            let randomSuffix = String(Int.random(in: 1000...9999))
            let defaultUsername = "User\(randomSuffix)"
            
            // Create a Sendable struct for the data to avoid [AnyHashable : Any] Sendable warning
            struct UserProfileData: Sendable {
                let userId: String
                let username: String
                let joinedDate: Date
                let completedChallenges: Int
                let currentStreak: Int
                let longestStreak: Int
            }
            
            // Create the data using the Sendable struct
            let profileData = UserProfileData(
                userId: userId,
                username: defaultUsername,
                joinedDate: Date(),
                completedChallenges: 0,
                currentStreak: 0,
                longestStreak: 0
            )
            
            // Access the data in a @Sendable closure using Task.detached to avoid isolation issues
            try await Task.detached {
                // Convert struct to dictionary here
                let data: [String: Any] = [
                    "userId": profileData.userId,
                    "username": profileData.username,
                    "createdAt": FieldValue.serverTimestamp(),
                    "joinedDate": profileData.joinedDate,
                    "completedChallenges": profileData.completedChallenges,
                    "currentStreak": profileData.currentStreak,
                    "longestStreak": profileData.longestStreak
                ]
                
                try await Firestore.firestore()
                    .collection("users")
                    .document(profileData.userId)
                    .setData(data)
                
                // Create the username reservation
                try await Firestore.firestore()
                    .collection("usernames")
                    .document(profileData.username)
                    .setData(["userId": profileData.userId])
            }.value
            
            // Set the username locally
            await MainActor.run {
                self.username = defaultUsername
                self.hasCompletedOnboarding = true
            }
            
            print("UserSession: Created default profile document with username \(defaultUsername) for user \(userId)")
        } else if document.exists && document.data()?["username"] == nil {
            // Document exists but username is missing - add one
            let randomSuffix = String(Int.random(in: 1000...9999))
            let defaultUsername = "User\(randomSuffix)"
            
            // Create a separate struct for this case too
            struct UsernameUpdateData: Sendable {
                let userId: String
                let username: String
            }
            
            let updateData = UsernameUpdateData(
                userId: userId,
                username: defaultUsername
            )
            
            // Update using the same Task.detached pattern
            try await Task.detached {
                // Update the document with a username
                try await Firestore.firestore()
                    .collection("users")
                    .document(updateData.userId)
                    .updateData(["username": updateData.username])
                
                // Create a reservation for the username
                try await Firestore.firestore()
                    .collection("usernames")
                    .document(updateData.username)
                    .setData(["userId": updateData.userId])
            }.value
            
            // Set the username locally
            await MainActor.run {
                self.username = defaultUsername
                self.hasCompletedOnboarding = true
            }
            
            print("UserSession: Added missing username \(defaultUsername) to existing user \(userId)")
        }
    }
    
    // MARK: - Auth Handlers for AuthService
    
    /// Handle successful authentication 
    func handleAuthSuccess(provider: String) async {
        // Auth state listener will handle updating the state
        print("UserSession: Auth success with provider: \(provider)")
        errorMessage = nil
    }
    
    /// Handle authentication error
    func handleAuthError(_ error: Error, for action: AuthAction, provider: String) async {
        let nsError = error as NSError
        print("UserSession: Auth error for \(action) with provider \(provider): \(nsError.localizedDescription)")
        
        await MainActor.run {
            self.authState = .error(error)
            self.errorMessage = "Authentication failed: \(nsError.localizedDescription)"
        }
    }
    
    /// Handle password reset success
    func handlePasswordResetSuccess(email: String) async {
        print("UserSession: Password reset email sent to \(email)")
        await MainActor.run {
            self.errorMessage = "Password reset email sent to \(email)"
        }
    }
    
    /// Handle password reset error
    func handlePasswordResetError(_ error: Error, email: String) async {
        print("UserSession: Password reset failed for \(email): \(error.localizedDescription)")
        await MainActor.run {
            self.authState = .error(error)
            self.errorMessage = "Failed to send password reset email: \(error.localizedDescription)"
        }
    }
    
    /// Handle sign out success
    func handleSignOutSuccess() async {
        print("UserSession: Sign out successful")
        // Auth state listener will update the state
    }
    
    /// Handle sign out error
    func handleSignOutError(_ error: Error) async {
        print("UserSession: Sign out failed: \(error.localizedDescription)")
        await MainActor.run {
            self.errorMessage = "Failed to sign out: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Auth Methods
    
    /// Sign in with email and password
    func signIn(email: String, password: String) async throws {
        if !isNetworkAvailable {
            throw NSError(domain: "UserSession", 
                        code: 100, 
                        userInfo: [NSLocalizedDescriptionKey: "No internet connection available"])
        }
        
        _ = await AuthService.shared.signInWithEmail(email: email, password: password)
    }
    
    /// Sign up with email and password
    func signUp(email: String, password: String) async throws {
        if !isNetworkAvailable {
            throw NSError(domain: "UserSession", 
                        code: 100, 
                        userInfo: [NSLocalizedDescriptionKey: "No internet connection available"])
        }
        
        _ = await AuthService.shared.signUpWithEmail(email: email, password: password)
    }
    
    /// Sign out the current user
    func signOut() async throws {
        // Check if user is anonymous - prevents errors with anonymous users
        if Auth.auth().currentUser?.isAnonymous == true {
            print("UserSession: Current user is anonymous, skipping sign out")
            return
        }
        
        if !isNetworkAvailable {
            throw NSError(domain: "UserSession", 
                        code: 100, 
                        userInfo: [NSLocalizedDescriptionKey: "No internet connection available"])
        }
        
        _ = await AuthService.shared.signOut()
    }
    
    // Add a non-throwing sign out method to ensure we always sign out
    func signOutWithoutThrowing() async {
        print("DEBUG: UserSession: Starting sign out process")
        
        do {
            // Remove existing auth state listener first
            if let listener = stateListener {
                auth.removeStateDidChangeListener(listener)
                stateListener = nil
            }
            
            // Try to sign out using Firebase Auth
            try auth.signOut()
            
            // Reset local state immediately
            await MainActor.run {
                authState = .signedOut
                currentUser = nil
                isAuthenticated = false
                username = nil
                photoURL = nil
                hasCompletedOnboarding = false
                errorMessage = nil
                lastSignInTime = nil
            }
            
            // Force post a notification about auth state change
            NotificationCenter.default.post(
                name: NSNotification.Name("AuthStateChanged"),
                object: nil
            )
            
            // Set up a new auth state listener
            setupAuthStateListener()
            
            print("DEBUG: UserSession: Successfully signed out user")
        } catch {
            print("DEBUG: UserSession: Error during sign out - \(error.localizedDescription)")
            
            // Even if Firebase sign out fails, reset local state
            await MainActor.run {
                authState = .signedOut
                currentUser = nil
                isAuthenticated = false
                username = nil
                photoURL = nil
                hasCompletedOnboarding = false
                errorMessage = nil
                lastSignInTime = nil
            }
            
            // Force post a notification about auth state change
            NotificationCenter.default.post(
                name: NSNotification.Name("AuthStateChanged"),
                object: nil
            )
            
            // Set up a new auth state listener
            setupAuthStateListener()
        }
    }
    
    func updateUsername(_ newUsername: String) async throws {
        guard isNetworkAvailable else {
            throw NSError(domain: "UserSession", code: 100, 
                         userInfo: [NSLocalizedDescriptionKey: "No internet connection. Please check your network settings."])
        }
        
        guard let userId = currentUser?.uid else {
            throw NSError(domain: "UserSession", code: 101, 
                         userInfo: [NSLocalizedDescriptionKey: "No user is signed in."])
        }
        
        do {
            // Check if username is in the proper format
            if !isValidUsername(newUsername) {
                throw NSError(domain: "UserSession", code: 102,
                             userInfo: [NSLocalizedDescriptionKey: "Invalid username format. Username must be 3-20 characters and can only contain letters and numbers."])
            }
            
            // Get the user document to check for cooldown period
            let userDoc = try await firestore
                .collection("users")
                .document(userId)
                .getDocument()
            
            // Check for 48-hour cooldown period
            if let lastChangeTimestamp = userDoc.data()?["lastUsernameChangeAt"] as? Timestamp {
                let lastChangeDate = lastChangeTimestamp.dateValue()
                let now = Date()
                let timeSinceLastChange = now.timeIntervalSince(lastChangeDate)
                
                // 48 hours = 172800 seconds
                if timeSinceLastChange < 172800 {
                    let hoursRemaining = Int((172800 - timeSinceLastChange) / 3600)
                    throw NSError(domain: "UserSession", code: 103,
                                 userInfo: [NSLocalizedDescriptionKey: "You can change your username again in \(hoursRemaining) hours."])
                }
            }
            
            // Check if the username is available
            let usernameDoc = try await firestore
                .collection("usernames")
                .document(newUsername.lowercased())
                .getDocument()
            
            if usernameDoc.exists {
                // Check if the username belongs to this user
                if let ownerId = usernameDoc.data()?["userId"] as? String, ownerId == userId {
                    // Username already belongs to this user, so we can skip the update
                    self.username = newUsername.lowercased()
                    return
                }
                
                throw NSError(domain: "UserSession", code: 104,
                             userInfo: [NSLocalizedDescriptionKey: "Username is already taken."])
            }
            
            // Get current username for reservation update
            guard let currentUsername = userDoc.data()?["username"] as? String else {
                throw NSError(domain: "UserSession", code: 105,
                             userInfo: [NSLocalizedDescriptionKey: "Couldn't retrieve current username."])
            }
            
            // Run transaction to update username and reservation atomically
            try await firestore.runTransaction { [self] transaction, errorPointer in
                // Update username in users collection
                let userRef = firestore.collection("users").document(userId)
                transaction.updateData([
                    "username": newUsername.lowercased(),
                    "lastUsernameChangeAt": FieldValue.serverTimestamp()
                ], forDocument: userRef)
                
                // Delete old username reservation
                let oldUsernameRef = firestore.collection("usernames").document(currentUsername.lowercased())
                transaction.deleteDocument(oldUsernameRef)
                
                // Create new username reservation
                let newUsernameRef = firestore.collection("usernames").document(newUsername.lowercased())
                transaction.setData(["userId": userId], forDocument: newUsernameRef)
                
                return nil
            }
            
            // Update local state
            self.username = newUsername.lowercased()
            self.hasCompletedOnboarding = true
            
        } catch {
            errorMessage = "Error updating username: \(error.localizedDescription)"
            throw error
        }
    }
    
    private func isValidUsername(_ username: String) -> Bool {
        // Check length
        if username.count < 3 || username.count > 20 {
            return false
        }
        
        // Check for alphanumeric characters only
        let allowedCharacterSet = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        return username.rangeOfCharacter(from: allowedCharacterSet.inverted) == nil
    }
    
    func updateProfilePhoto(_ url: URL) async throws {
        guard let userId = currentUser?.uid else {
            throw FirebaseError.notAuthenticated
        }
        
        guard isNetworkAvailable else {
            throw FirebaseError.networkOffline
        }
        
        do {
            // Update Firestore document
            try await firestore.collection(CollectionPath.users).document(userId).updateData([
                "photoURL": url.absoluteString
            ])
            
            // Update Firebase Auth profile
            let changeRequest = currentUser?.createProfileChangeRequest()
            changeRequest?.photoURL = url
            try await changeRequest?.commitChanges()
            
            // Update local state
            await MainActor.run {
                self.photoURL = url
            }
            
            print("Successfully updated profile photo URL in Firestore and Auth")
        } catch {
            print("Error updating profile photo: \(error)")
            throw FirebaseError.firestoreError(error)
        }
    }
    
    // Add a proper account deletion method that handles Firestore cleanup
    func deleteAccount() async throws {
        guard isNetworkAvailable else {
            throw NSError(domain: "UserSession", code: 100, 
                         userInfo: [NSLocalizedDescriptionKey: "No internet connection. Please check your network settings."])
        }
        
        guard let user = Auth.auth().currentUser, let userId = currentUser?.uid else {
            throw NSError(domain: "UserSession", code: 101, 
                         userInfo: [NSLocalizedDescriptionKey: "No user is signed in"])
        }
        
        do {
            // 1. Delete all user data from Firestore first
            try await FirebaseService.shared.deleteUserData(userId: userId)
            
            // 2. Delete the actual Firebase Auth account
            try await user.delete()
            
            // 3. Clean up local state - Auth state listener will handle this
        } catch {
            authState = .error(error)
            errorMessage = "Error deleting account: \(error.localizedDescription)"
            throw error
        }
    }
    
    // Retry loading profile data
    func retryLoadingProfile() async {
        await loadUserProfile()
    }
    
    // MARK: - Routing Helpers
    
    var shouldShowAuth: Bool {
        if case .signedOut = authState {
            return true
        }
        return false
    }
    
    var shouldShowUsernameSetup: Bool {
        if case .signedIn = authState, username == nil {
            return true
        }
        return false
    }
    
    var shouldShowMainApp: Bool {
        if case .signedIn = authState, username != nil {
            return true
        }
        return false
    }
    
    // Added a helper to check if in error state
    var isInErrorState: Bool {
        if case .error = authState {
            return true
        }
        return false
    }
    
    // MARK: - Direct Authentication Methods
    
    // These methods will be called by DirectAuthService after authentication operations
    func handleEmailSignInResult(success: Bool, email: String, error: Error? = nil) async {
        if !success {
            await MainActor.run {
                if let error = error {
                    authState = .error(error)
                    errorMessage = "Error signing in: \(error.localizedDescription)"
                } else {
                    authState = .error(NSError(domain: "UserSession", code: 1001, 
                                              userInfo: [NSLocalizedDescriptionKey: "Failed to sign in with email"]))
                    errorMessage = "Authentication failed. Please check your credentials and try again."
                }
            }
        }
        // If successful, the auth state listener will handle the update
    }

    func handleEmailSignUpResult(success: Bool, email: String, error: Error? = nil) async {
        if !success {
            await MainActor.run {
                if let error = error {
                    authState = .error(error)
                    errorMessage = "Error creating account: \(error.localizedDescription)"
                } else {
                    authState = .error(NSError(domain: "UserSession", code: 1002, 
                                              userInfo: [NSLocalizedDescriptionKey: "Failed to sign up with email"]))
                    errorMessage = "Failed to create account. Please try again."
                }
            }
        }
        // If successful, the auth state listener will handle the update
    }

    func handlePasswordResetResult(success: Bool, email: String, error: Error? = nil) async -> String? {
        if success {
            return "Password reset email sent to \(email)"
        } else {
            await MainActor.run {
                if let error = error {
                    errorMessage = "Error sending password reset: \(error.localizedDescription)"
                } else {
                    errorMessage = "Failed to send password reset email. Please check your email and try again."
                }
            }
            return nil
        }
    }

    func handleGoogleSignInResult(success: Bool, error: Error? = nil) async {
        if !success {
            await MainActor.run {
                if let error = error {
                    authState = .error(error)
                    errorMessage = "Google sign-in error: \(error.localizedDescription)"
                } else {
                    authState = .error(NSError(domain: "UserSession", code: 1003,
                                              userInfo: [NSLocalizedDescriptionKey: "Failed to sign in with Google"]))
                    errorMessage = "Google sign-in failed. Please try again."
                }
            }
        }
        // If successful, the auth state listener will handle the update
    }

    func handleAppleSignInResult(success: Bool, error: Error? = nil) async {
        if !success {
            await MainActor.run {
                if let error = error {
                    authState = .error(error)
                    errorMessage = "Apple sign-in error: \(error.localizedDescription)"
                } else {
                    authState = .error(NSError(domain: "UserSession", code: 1004,
                                              userInfo: [NSLocalizedDescriptionKey: "Failed to sign in with Apple"]))
                    errorMessage = "Apple sign-in failed. Please try again."
                }
            }
        }
        // If successful, the auth state listener will handle the update
    }

    // Add method to check if user has a username without duplicating AuthViewModel.checkUsernameSetup
    func checkUsernameSetup(for userId: String) async -> Bool {
        do {
            let document = try await firestore
                .collection("users")
                .document(userId)
                .getDocument()
            
            let hasUsername = document.exists && document.data()?["username"] != nil
            return hasUsername
        } catch {
            print("Error checking username: \(error.localizedDescription)")
            return false
        }
    }
} 