import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

enum FirebaseError: Error {
    case notConfigured
    case authError(Error)
    case firestoreError(Error)
    case storageError(Error)
    case invalidData
    case documentNotFound
    case unauthorized
}

enum CollectionPath {
    static let users = "users"
    static let challenges = "challenges"
    static let usernames = "usernames"
    static let profile = "profile"
}

struct UserProfile: Codable {
    let username: String
    var displayName: String?
    var photoURL: URL?
    var bio: String?
    var joinedDate: Date
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
}

class FirebaseService {
    static let shared = FirebaseService()
    
    private var auth: Auth?
    private var firestore: Firestore?
    private var storage: Storage?
    
    private init() {
        // Firebase configuration will be initialized in AppDelegate
    }
    
    func configure() {
        guard FirebaseApp.app() != nil else {
            fatalError("FirebaseApp must be configured before initializing services")
        }
        
        auth = Auth.auth()
        firestore = Firestore.firestore()
        storage = Storage.storage()
        
        // Configure Firestore settings
        let settings = FirestoreSettings()
        settings.cacheSettings = PersistentCacheSettings(sizeBytes: NSNumber(value: FirestoreCacheSizeUnlimited))
        firestore?.settings = settings
    }
    
    // MARK: - Auth Methods
    func signIn(email: String, password: String) async throws -> FirebaseAuth.User {
        guard let auth = auth else {
            throw FirebaseError.notConfigured
        }
        
        do {
            let result = try await auth.signIn(withEmail: email, password: password)
            return result.user
        } catch {
            throw FirebaseError.authError(error)
        }
    }
    
    func signUp(email: String, password: String) async throws -> FirebaseAuth.User {
        guard let auth = auth else {
            throw FirebaseError.notConfigured
        }
        
        do {
            let result = try await auth.createUser(withEmail: email, password: password)
            return result.user
        } catch {
            throw FirebaseError.authError(error)
        }
    }
    
    func signOut() async throws {
        guard let auth = auth else {
            throw FirebaseError.notConfigured
        }
        
        do {
            try auth.signOut()
        } catch {
            throw FirebaseError.authError(error)
        }
    }
    
    // MARK: - Firestore Methods
    func createDocument<T: Encodable>(_ data: T, in collection: String) async throws -> String {
        guard let firestore = firestore else {
            throw FirebaseError.notConfigured
        }
        
        do {
            let documentRef = try firestore.collection(collection).addDocument(from: data)
            return documentRef.documentID
        } catch {
            throw FirebaseError.firestoreError(error)
        }
    }
    
    func updateDocument<T: Encodable>(_ data: T, in collection: String, documentId: String) async throws {
        guard let firestore = firestore else {
            throw FirebaseError.notConfigured
        }
        
        do {
            let docRef = firestore.collection(collection).document(documentId)
            
            // Convert the generic type to a dictionary using Firestore's encoder
            let encodedData = try Firestore.Encoder().encode(data)
            
            // Use the standard setData method instead of the generic one
            try await docRef.setData(encodedData, merge: true)
        } catch {
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
        guard let firestore = firestore else {
            throw FirebaseError.notConfigured
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
        } catch {
            throw FirebaseError.firestoreError(error)
        }
    }
    
    func fetchUserProfile(userId: String) async throws -> UserProfile? {
        guard let firestore = firestore else {
            throw FirebaseError.notConfigured
        }
        
        do {
            let document = try await firestore
                .collection(CollectionPath.users)
                .document(userId)
                .getDocument()
            
            return try document.data(as: UserProfile.self)
        } catch {
            throw FirebaseError.firestoreError(error)
        }
    }
    
    func updateUsername(_ username: String, userId: String) async throws {
        guard let firestore = firestore else {
            throw FirebaseError.notConfigured
        }
        
        do {
            // Check if new username is available
            let usernameSnapshot = try await firestore
                .collection(CollectionPath.usernames)
                .document(username)
                .getDocument()
            
            if usernameSnapshot.exists {
                throw FirebaseError.invalidData
            }
            
            // Get current username
            let userDoc = try await firestore
                .collection(CollectionPath.users)
                .document(userId)
                .getDocument()
            
            guard let currentUsername = userDoc.data()?["username"] as? String else {
                throw FirebaseError.documentNotFound
            }
            
            // Update username in users collection
            try await firestore
                .collection(CollectionPath.users)
                .document(userId)
                .updateData(["username": username])
            
            // Update username reservation
            try await firestore
                .collection(CollectionPath.usernames)
                .document(currentUsername)
                .delete()
            
            try await firestore
                .collection(CollectionPath.usernames)
                .document(username)
                .setData(["userId": userId])
        } catch {
            throw FirebaseError.firestoreError(error)
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
} 