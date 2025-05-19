import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import Network

// Using canonical Challenge model
// (No import needed as it will be accessed directly)

enum FirebaseError: Error, LocalizedError {
    case notConfigured
    case authError(Error)
    case firestoreError(Error)
    case storageError(Error)
    case invalidData
    case documentNotFound
    case unauthorized
    case networkOffline
    case cooldownPeriod(hoursRemaining: Int)
    case usernameAlreadyExists
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Firebase is not configured"
        case .authError(let error):
            return "Authentication error: \(error.localizedDescription)"
        case .firestoreError(let error):
            return "Database error: \(error.localizedDescription)"
        case .storageError(let error):
            return "Storage error: \(error.localizedDescription)"
        case .invalidData:
            return "Invalid data format"
        case .documentNotFound:
            return "Document not found"
        case .unauthorized:
            return "You are not authorized to perform this action"
        case .networkOffline:
            return "No internet connection. Some features may be limited."
        case .cooldownPeriod(let hoursRemaining):
            return "Username change cooldown period: \(hoursRemaining) hours remaining"
        case .usernameAlreadyExists:
            return "Username already exists"
        }
    }
}

enum CollectionPath {
    static let users = "users"
    static let challenges = "challenges"
    static let usernames = "usernames"
    static let profile = "profile"
}

struct UserProfile: Codable {
    var username: String?
    var displayName: String?
    var photoURL: URL?
    var bio: String?
    var joinedDate: Date?
    var completedChallenges: Int
    var currentStreak: Int
    var longestStreak: Int
    
    init(username: String) {
        self.username = username
        self.joinedDate = Date()
        self.completedChallenges = 0
        self.currentStreak = 0
        self.longestStreak = 0
    }
    
    // Empty initializer with default values
    init() {
        self.joinedDate = Date()
        self.completedChallenges = 0
        self.currentStreak = 0
        self.longestStreak = 0
    }
    
    enum CodingKeys: String, CodingKey {
        case username, displayName, photoURL, bio, joinedDate, completedChallenges, currentStreak, longestStreak
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Required fields with defaults if missing
        username = try container.decodeIfPresent(String.self, forKey: .username)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        photoURL = try container.decodeIfPresent(URL.self, forKey: .photoURL)
        bio = try container.decodeIfPresent(String.self, forKey: .bio)
        joinedDate = try container.decodeIfPresent(Date.self, forKey: .joinedDate)
        
        // Use 0 as fallback for numeric values
        completedChallenges = try container.decodeIfPresent(Int.self, forKey: .completedChallenges) ?? 0
        currentStreak = try container.decodeIfPresent(Int.self, forKey: .currentStreak) ?? 0
        longestStreak = try container.decodeIfPresent(Int.self, forKey: .longestStreak) ?? 0
    }
}

class FirebaseService {
    static let shared = FirebaseService()
    
    private var auth: Auth?
    private var firestore: Firestore?
    private var storage: Storage?
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "FirebaseService.NetworkMonitor")
    private var isNetworkAvailable = true
    
    private var pendingOperations: [() async throws -> Void] = []
    
    private init() {
        // Firebase configuration will be initialized in AppDelegate
        setupNetworkMonitoring()
        
        // Listen for Firestore connectivity check requests
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFirestoreConnectivityCheck),
            name: NetworkMonitor.firestoreConnectivityCheckRequested,
            object: nil
        )
    }
    
    @objc private func handleFirestoreConnectivityCheck() {
        // Only perform this check if Firestore is already initialized
        guard let db = firestore else { return }
        
        // Perform a simple read operation to test connectivity
        db.collection("_connectivity").limit(to: 1).getDocuments { snapshot, error in
            if let error = error {
                if error.localizedDescription.contains("firestore.googleapis.com") ||
                   error.localizedDescription.contains("lookup error") ||
                   error.localizedDescription.contains("Domain name not found") {
                    
                    // Notify about Firestore-specific connectivity issue
                    NotificationCenter.default.post(
                        name: NetworkMonitor.firestoreConnectivityChanged,
                        object: nil,
                        userInfo: [
                            "isConnected": false,
                            "hasDNSIssues": true,
                            "error": error.localizedDescription
                        ]
                    )
                }
            } else {
                // Firestore connection successful
                NotificationCenter.default.post(
                    name: NetworkMonitor.firestoreConnectivityChanged,
                    object: nil,
                    userInfo: ["isConnected": true, "hasDNSIssues": false]
                )
            }
        }
    }
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            let isConnected = path.status == .satisfied
            self?.isNetworkAvailable = isConnected
            
            if isConnected {
                // Execute pending operations when network is back
                Task {
                    await self?.executePendingOperations()
                }
            }
        }
        networkMonitor.start(queue: networkQueue)
    }
    
    private func executePendingOperations() async {
        let operations = pendingOperations
        pendingOperations.removeAll()
        
        for operation in operations {
            do {
                try await operation()
            } catch {
                print("Failed to execute pending operation: \(error.localizedDescription)")
            }
        }
    }
    
    deinit {
        networkMonitor.cancel()
        NotificationCenter.default.removeObserver(self)
    }
    
    func configure() {
        // Check if Firebase is already configured 
        if FirebaseApp.app() != nil {
            print("Firebase already configured in FirebaseService.configure")
            
            // Make sure services are initialized
            initializeServices()
            
            return
        } else {
            print("ERROR: Firebase not configured. It should be initialized in AppDelegate.")
            // Don't try to configure Firebase here - that should only happen in AppDelegate
        }
    }
    
    func configureIfNeeded() {
        if FirebaseApp.app() == nil {
            print("WARNING: Firebase not configured, should be initialized in AppDelegate")
            return
        } else {
            print("Firebase already configured, initializing services")
            
            // Ensure all services are initialized
            initializeServices()
        }
    }
    
    // Helper method to initialize services
    private func initializeServices() {
        if auth == nil {
            auth = Auth.auth()
            print("Auth service initialized")
        }
        
        if firestore == nil {
            firestore = Firestore.firestore()
            print("Firestore service initialized")
        }
        
        if storage == nil {
            storage = Storage.storage()
            print("Storage service initialized")
        }
    }
    
    // MARK: - Auth Methods
    func signIn(email: String, password: String) async throws -> FirebaseAuth.User {
        configureIfNeeded()
        
        guard let auth = auth else {
            print("Auth is nil in FirebaseService.signIn")
            throw FirebaseError.notConfigured
        }
        
        guard isNetworkAvailable else {
            print("Network unavailable in FirebaseService.signIn")
            throw FirebaseError.networkOffline
        }
        
        do {
            print("Attempting to sign in with email: \(email)")
            let result = try await auth.signIn(withEmail: email, password: password)
            print("Sign in successful for user: \(result.user.uid)")
            return result.user
        } catch {
            print("Sign in failed in FirebaseService: \(error.localizedDescription)")
            throw FirebaseError.authError(error)
        }
    }
    
    func signUp(email: String, password: String) async throws -> FirebaseAuth.User {
        configureIfNeeded()
        
        guard let auth = auth else {
            throw FirebaseError.notConfigured
        }
        
        guard isNetworkAvailable else {
            throw FirebaseError.networkOffline
        }
        
        do {
            let result = try await auth.createUser(withEmail: email, password: password)
            return result.user
        } catch {
            throw FirebaseError.authError(error)
        }
    }
    
    func signOut() async throws {
        configureIfNeeded()
        
        guard let auth = auth else {
            throw FirebaseError.notConfigured
        }
        
        do {
            try auth.signOut()
        } catch {
            throw FirebaseError.authError(error)
        }
    }
    
    // MARK: - Firestore Methods with Retry Logic
    func createDocument<T: Encodable>(_ data: T, in collection: String, maxRetries: Int = 3) async throws -> String {
        configureIfNeeded()
        
        guard let firestore = firestore else {
            throw FirebaseError.notConfigured
        }
        
        if !isNetworkAvailable {
            // Store operation for later execution
            let operation: () async throws -> Void = {
                _ = try await self.createDocument(data, in: collection)
            }
            pendingOperations.append(operation)
            throw FirebaseError.networkOffline
        }
        
        var lastError: Error?
        for attempt in 0..<maxRetries {
            do {
                let documentRef = try firestore.collection(collection).addDocument(from: data)
                return documentRef.documentID
            } catch {
                lastError = error
                
                // Wait before retry (exponential backoff)
                if attempt < maxRetries - 1 {
                    try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt)) * 100_000_000))
                }
            }
        }
        
        throw FirebaseError.firestoreError(lastError ?? NSError(domain: "FirebaseService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create document after multiple attempts"]))
    }
    
    func updateDocument<T: Encodable>(_ data: T, in collection: String, documentId: String, maxRetries: Int = 3) async throws {
        configureIfNeeded()
        
        guard let firestore = firestore else {
            throw FirebaseError.notConfigured
        }
        
        if !isNetworkAvailable {
            // Store operation for later execution
            let operation: () async throws -> Void = {
                try await self.updateDocument(data, in: collection, documentId: documentId)
            }
            pendingOperations.append(operation)
            throw FirebaseError.networkOffline
        }
        
        var lastError: Error?
        for attempt in 0..<maxRetries {
            do {
                let docRef = firestore.collection(collection).document(documentId)
                
                // Convert the generic type to a dictionary using Firestore's encoder
                let encodedData = try Firestore.Encoder().encode(data)
                
                // Use the standard setData method instead of the generic one
                try await docRef.setData(encodedData, merge: true)
                return
            } catch {
                lastError = error
                
                // Wait before retry (exponential backoff)
                if attempt < maxRetries - 1 {
                    try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt)) * 100_000_000))
                }
            }
        }
        
        throw FirebaseError.firestoreError(lastError ?? NSError(domain: "FirebaseService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to update document after multiple attempts"]))
    }
    
    // MARK: - Enhanced Error Handling for Fetching Data
    func fetchDocument<T: Decodable>(from collection: String, documentId: String) async throws -> T {
        configureIfNeeded()
        
        guard let firestore = firestore else {
            throw FirebaseError.notConfigured
        }
        
        do {
            let docRef = firestore.collection(collection).document(documentId)
            let document = try await docRef.getDocument()
            
            if !document.exists {
                throw FirebaseError.documentNotFound
            }
            
            do {
                return try document.data(as: T.self)
            } catch {
                throw FirebaseError.invalidData
            }
        } catch let error as FirebaseError {
            throw error
        } catch {
            if !isNetworkAvailable {
                throw FirebaseError.networkOffline
            }
            throw FirebaseError.firestoreError(error)
        }
    }
    
    // MARK: - Challenge Methods
    func createChallenge(_ challenge: Challenge, for userId: String) async throws -> String {
        guard let firestore = firestore else {
            throw FirebaseError.notConfigured
        }
        
        do {
            let challengeRef = firestore.collection(CollectionPath.challenges).document()
            var challengeData = try Firestore.Encoder().encode(challenge)
            challengeData["userId"] = userId
            challengeData["id"] = challengeRef.documentID
            
            try await challengeRef.setData(challengeData)
            return challengeRef.documentID
        } catch {
            throw FirebaseError.firestoreError(error)
        }
    }
    
    func fetchChallenges(for userId: String) async throws -> [Challenge] {
        guard let firestore = firestore else {
            throw FirebaseError.notConfigured
        }
        
        do {
            let snapshot = try await firestore
                .collection(CollectionPath.challenges)
                .whereField("userId", isEqualTo: userId)
                .getDocuments()
            
            return try snapshot.documents.compactMap { document in
                try document.data(as: Challenge.self)
            }
        } catch {
            throw FirebaseError.firestoreError(error)
        }
    }
    
    func deleteChallenge(id: String, userId: String) async throws {
        guard let firestore = firestore else {
            throw FirebaseError.notConfigured
        }
        
        do {
            try await firestore
                .collection(CollectionPath.challenges)
                .document(id)
                .delete()
        } catch {
            throw FirebaseError.firestoreError(error)
        }
    }
    
    // MARK: - User Profile Methods
    func createUserProfile(username: String, userId: String) async throws {
        configureIfNeeded()
        
        guard let firestore = firestore else {
            throw FirebaseError.notConfigured
        }
        
        if !isNetworkAvailable {
            // Store operation for later execution
            let operation: () async throws -> Void = {
                try await self.createUserProfile(username: username, userId: userId)
            }
            pendingOperations.append(operation)
            throw FirebaseError.networkOffline
        }
        
        do {
            // Check if username is available
            let usernameSnapshot = try await firestore
                .collection(CollectionPath.usernames)
                .document(username)
                .getDocument()
            
            if usernameSnapshot.exists {
                throw FirebaseError.invalidData
            }
            
            // Create user profile
            let profileData: [String: Any] = [
                "username": username,
                "userId": userId,
                "createdAt": FieldValue.serverTimestamp()
            ]
            
            try await firestore
                .collection(CollectionPath.users)
                .document(userId)
                .setData(profileData)
            
            // Reserve username
            try await firestore
                .collection(CollectionPath.usernames)
                .document(username)
                .setData(["userId": userId])
        } catch let error as FirebaseError {
            throw error
        } catch {
            throw FirebaseError.firestoreError(error)
        }
    }
    
    func fetchUserProfile(userId: String) async throws -> UserProfile? {
        configureIfNeeded()
        
        guard let firestore = firestore else {
            throw FirebaseError.notConfigured
        }
        
        do {
            let document = try await firestore
                .collection(CollectionPath.users)
                .document(userId)
                .getDocument()
            
            guard document.exists else {
                print("⚠️ No user profile document found for user: \(userId)")
                // Create a default empty profile instead of returning nil
                return UserProfile()
            }
            
            do {
                // Try to decode the document data into UserProfile
                let profile = try document.data(as: UserProfile.self)
                return profile
            } catch {
                print("⚠️ Failed to decode profile: \(error)")
                
                // Fallback: Try to manually extract fields from document data
                if let data = document.data() {
                    var profile = UserProfile()
                    
                    // Manually extract fields with safe fallbacks
                    if let username = data["username"] as? String {
                        profile.username = username
                    }
                    
                    if let displayName = data["displayName"] as? String {
                        profile.displayName = displayName
                    }
                    
                    if let photoURLString = data["photoURL"] as? String, 
                       let url = URL(string: photoURLString) {
                        profile.photoURL = url
                    }
                    
                    if let bio = data["bio"] as? String {
                        profile.bio = bio
                    }
                    
                    if let timestamp = data["joinedDate"] as? Timestamp {
                        profile.joinedDate = timestamp.dateValue()
                    }
                    
                    if let completedChallenges = data["completedChallenges"] as? Int {
                        profile.completedChallenges = completedChallenges
                    }
                    
                    if let currentStreak = data["currentStreak"] as? Int {
                        profile.currentStreak = currentStreak
                    }
                    
                    if let longestStreak = data["longestStreak"] as? Int {
                        profile.longestStreak = longestStreak
                    }
                    
                    return profile
                }
                
                // If all else fails, return a default profile
                return UserProfile()
            }
        } catch {
            if !isNetworkAvailable {
                // Try to get from cache
                do {
                    let document = try await firestore
                        .collection(CollectionPath.users)
                        .document(userId)
                        .getDocument(source: .cache)
                    
                    if document.exists {
                        do {
                            return try document.data(as: UserProfile.self)
                        } catch {
                            print("⚠️ Failed to decode cached profile: \(error)")
                            // Return empty profile instead of nil
                            return UserProfile()
                        }
                    }
                    return UserProfile() // Return empty profile with defaults instead of nil
                } catch {
                    throw FirebaseError.networkOffline
                }
            }
            throw FirebaseError.firestoreError(error)
        }
    }
    
    func updateUsername(_ username: String, userId: String) async throws {
        guard let firestore = firestore else {
            throw FirebaseError.notConfigured
        }
        
        do {
            // Get current user document to check cooldown period
            let userDoc = try await firestore
                .collection(CollectionPath.users)
                .document(userId)
                .getDocument()
            
            // Check 48-hour cooldown period
            if let lastChangeTimestamp = userDoc.data()?["lastUsernameChangeAt"] as? Timestamp {
                let lastChangeDate = lastChangeTimestamp.dateValue()
                let now = Date()
                let timeSinceLastChange = now.timeIntervalSince(lastChangeDate)
                
                // 48 hours = 172800 seconds
                if timeSinceLastChange < 172800 {
                    let hoursRemaining = Int((172800 - timeSinceLastChange) / 3600)
                    throw FirebaseError.cooldownPeriod(hoursRemaining: hoursRemaining)
                }
            }
            
            // Check if new username is available
            let usernameSnapshot = try await firestore
                .collection(CollectionPath.usernames)
                .document(username.lowercased())
                .getDocument()
            
            if usernameSnapshot.exists {
                throw FirebaseError.usernameAlreadyExists
            }
            
            // Get current username
            guard let currentUsername = userDoc.data()?["username"] as? String else {
                throw FirebaseError.documentNotFound
            }
            
            // Run as a transaction to ensure atomicity
            try await firestore.runTransaction { transaction, errorPointer in
                // 1. Delete old username reservation
                let oldUsernameRef = firestore
                    .collection(CollectionPath.usernames)
                    .document(currentUsername.lowercased())
                transaction.deleteDocument(oldUsernameRef)
                
                // 2. Create new username reservation
                let newUsernameRef = firestore
                    .collection(CollectionPath.usernames)
                    .document(username.lowercased())
                transaction.setData(["userId": userId], forDocument: newUsernameRef)
                
                // 3. Update user document with new username and timestamp
                let userRef = firestore
                    .collection(CollectionPath.users)
                    .document(userId)
                transaction.updateData([
                    "username": username.lowercased(),
                    "lastUsernameChangeAt": FieldValue.serverTimestamp()
                ], forDocument: userRef)
                
                return nil
            }
            
        } catch {
            // Rethrow as our custom error type
            if let firebaseError = error as? FirebaseError {
                throw firebaseError
            } else {
                throw FirebaseError.firestoreError(error)
            }
        }
    }
    
    func deleteUserData(userId: String) async throws {
        guard let firestore = firestore else {
            throw FirebaseError.notConfigured
        }
        
        do {
            // Get user profile to find username
            let userDoc = try await firestore
                .collection(CollectionPath.users)
                .document(userId)
                .getDocument()
            
            guard let username = userDoc.data()?["username"] as? String else {
                throw FirebaseError.documentNotFound
            }
            
            // Delete user challenges
            let challengesSnapshot = try await firestore
                .collection(CollectionPath.challenges)
                .whereField("userId", isEqualTo: userId)
                .getDocuments()
            
            for document in challengesSnapshot.documents {
                try await document.reference.delete()
            }
            
            // Delete user profile
            try await userDoc.reference.delete()
            
            // Delete username reservation
            try await firestore
                .collection(CollectionPath.usernames)
                .document(username)
                .delete()
        } catch {
            throw FirebaseError.firestoreError(error)
        }
    }
    
    // MARK: - Storage Methods
    func uploadProfileImage(data: Data, userId: String) async throws -> URL {
        guard let storage = storage else {
            throw FirebaseError.notConfigured
        }
        
        do {
            let storageRef = storage.reference()
            let profileImageRef = storageRef.child("\(CollectionPath.profile)/\(userId)/profile.jpg")
            
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            
            _ = try await profileImageRef.putDataAsync(data, metadata: metadata)
            return try await profileImageRef.downloadURL()
        } catch {
            throw FirebaseError.storageError(error)
        }
    }
    
    func deleteProfileImage(userId: String) async throws {
        guard let storage = storage else {
            throw FirebaseError.notConfigured
        }
        
        do {
            let storageRef = storage.reference()
            let profileImageRef = storageRef.child("\(CollectionPath.profile)/\(userId)/profile.jpg")
            try await profileImageRef.delete()
        } catch {
            throw FirebaseError.storageError(error)
        }
    }
    
    func uploadFile(data: Data, path: String) async throws -> String {
        guard let storage = storage else {
            throw FirebaseError.notConfigured
        }
        
        let storageRef = storage.reference().child(path)
        _ = try await storageRef.putDataAsync(data)
        return try await storageRef.downloadURL().absoluteString
    }
    
    // MARK: - Network Status Helper
    func isNetworkConnected() -> Bool {
        return isNetworkAvailable
    }
    
    // MARK: - Firestore Utilities
    func setCacheSettings(sizeLimitInMB: Int = -1) {
        // Skip setting cache settings - these should only be set in AppDelegate
        // before any Firestore operations
        print("setCacheSettings: Settings should only be modified in AppDelegate before Firestore is initialized")
    }
} 