import Foundation
@preconcurrency import FirebaseFirestore
@preconcurrency import FirebaseAuth
import Combine
import SwiftUI

@MainActor
class FriendService: ObservableObject, FriendServiceProtocol {
    // Published properties
    @Published private(set) var friends: [Friend] = []
    @Published private(set) var incomingRequests: [FriendRequest] = []
    @Published private(set) var outgoingRequests: [FriendRequest] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String? = nil

    // Singleton instance
    static let shared = FriendService()
    
    // Dependencies
    nonisolated(unsafe) private let firestore = Firestore.firestore()
    private let userSession = UserSession.shared
    private var cancellables = Set<AnyCancellable>()
    private var friendsListener: ListenerRegistration?
    private var incomingRequestsListener: ListenerRegistration?
    private var outgoingRequestsListener: ListenerRegistration?
    // Cache for username claim checks to reduce Firestore reads
    // Stores (isClaimed, timestamp)
    private var usernameClaimCache: [String: (Bool, Date)] = [:]
    // Cache TTL in seconds
    private let usernameClaimCacheTTL: TimeInterval = 300 // 5 minutes
    
    // Friend limit for free users
    private let FREE_USER_FRIEND_LIMIT = 5
    
    // Notification names
    static let friendsDidUpdateNotification = Notification.Name("friendsDidUpdate")
    static let friendRequestsDidUpdateNotification = Notification.Name("friendRequestsDidUpdate")
    
    private init() {
        setupSubscriptionListener()
    }
    
    deinit {
        // Clean up listeners synchronously since deinit can't be async
        friendsListener?.remove()
        incomingRequestsListener?.remove()
        outgoingRequestsListener?.remove()
    }
    
    // MARK: - Public Methods
    
    /// Start listening for friends and friend requests
    func startListening() {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "User not signed in"
            return
        }
        
        // Start listening for friends
        listenForFriends(userId: userId)
        
        // Start listening for incoming friend requests
        listenForIncomingRequests(userId: userId)
        
        // Start listening for outgoing friend requests
        listenForOutgoingRequests(userId: userId)
    }
    
    /// Stop listening for friends and friend requests
    func stopListening() {
        friendsListener?.remove()
        friendsListener = nil
        
        incomingRequestsListener?.remove()
        incomingRequestsListener = nil
        
        outgoingRequestsListener?.remove()
        outgoingRequestsListener = nil
    }
    
    /// Get the count of accepted friends
    func getFriendsCount() async throws -> Int {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FriendError.userNotAuthenticated
        }
        
        let snapshot = try await firestore
            .collection("friends")
            .document(userId)
            .collection("connections")
            .whereField("status", isEqualTo: FriendRequest.RequestStatus.accepted.rawValue)
            .count
            .getAggregation(source: .server)
        
        return Int(truncating: snapshot.count)
    }
    
    /// Check if the user can add more friends based on their subscription status
    func canAddMoreFriends() async throws -> Bool {
        // If user is Pro, they can add unlimited friends
        if SubscriptionService.shared.isProUser {
            return true
        }
        
        // Free users are limited to FREE_USER_FRIEND_LIMIT friends
        let friendsCount = try await getFriendsCount()
        return friendsCount < FREE_USER_FRIEND_LIMIT
    }
    
    /// Search for users by username
    func searchUsers(query: String) async throws -> [UserProfileResult] {
        guard !query.isEmpty else { return [] }
        guard query.count >= 3 else { return [] }
        
        let snapshot = try await firestore
            .collection("usernames")
            .whereField("username", isGreaterThanOrEqualTo: query.lowercased())
            .whereField("username", isLessThanOrEqualTo: query.lowercased() + "\u{f8ff}")
            .limit(to: 10)
            .getDocuments()
        
        var users: [UserProfileResult] = []
        
        for document in snapshot.documents {
            guard let userId = document.data()["userId"] as? String else { continue }
            
            // Skip the current user
            if userId == Auth.auth().currentUser?.uid { continue }
            
            // Get user profile
            let userDoc = try await firestore
                .collection("users")
                .document(userId)
                .getDocument()
            
            if let username = userDoc.data()?["username"] as? String {
                var displayName: String? = nil
                var photoURL: URL? = nil
                
                if let displayNameString = userDoc.data()?["displayName"] as? String {
                    displayName = displayNameString
                }
                
                if let photoURLString = userDoc.data()?["photoURL"] as? String {
                    photoURL = URL(string: photoURLString)
                }
                
                let user = UserProfileResult(
                    id: userId,
                    username: username,
                    displayName: displayName,
                    photoURL: photoURL
                )
                
                users.append(user)
            }
        }
        
        return users
    }

    /// Check if a username is claimed (exists in the `usernames` collection)
    func isUsernameClaimed(_ username: String) async throws -> Bool {
        guard !username.isEmpty else { return false }
        let key = username.lowercased()
        // Return cached value if present and not expired
        if let (cachedValue, cachedAt) = usernameClaimCache[key] {
            if Date().timeIntervalSince(cachedAt) < usernameClaimCacheTTL {
                return cachedValue
            } else {
                usernameClaimCache.removeValue(forKey: key)
            }
        }

        let doc = try await firestore
            .collection("usernames")
            .document(key)
            .getDocument()

        let claimed: Bool
        if !doc.exists {
            claimed = false
        } else if let userId = doc.data()?["userId"] as? String, !userId.isEmpty {
            claimed = true
        } else {
            claimed = false
        }

        // Cache result
        usernameClaimCache[key] = (claimed, Date())
        return claimed
    }
    
    /// Send a friend request to another user
    func sendFriendRequest(to username: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw FriendError.userNotAuthenticated
        }
        
        // Check if user can add more friends
        let canAdd = try await canAddMoreFriends()
        if !canAdd {
            throw FriendError.friendLimitReached
        }
        
        // Get the target user's ID from the username
        let usernameDoc = try await firestore
            .collection("usernames")
            .document(username.lowercased())
            .getDocument()
        
        guard let targetUserId = usernameDoc.data()?["userId"] as? String else {
            throw FriendError.userNotFound
        }
        
        // Don't allow sending friend requests to yourself
        if targetUserId == currentUserId {
            throw FriendError.cannotAddSelf
        }
        
        // Check if a friend connection already exists
        let existingConnection = try await firestore
            .collection("friends")
            .document(currentUserId)
            .collection("connections")
            .document(targetUserId)
            .getDocument()
        
        if existingConnection.exists {
            throw FriendError.alreadyFriends
        }
        
        // Check if there's already a pending request
        let existingRequest = try await firestore
            .collection("friendRequests")
            .document(targetUserId)
            .collection("incoming")
            .whereField("fromUserId", isEqualTo: currentUserId)
            .getDocuments()
        
        if !existingRequest.documents.isEmpty {
            throw FriendError.requestAlreadySent
        }
        
        // Get current user's profile info
        let currentUserDoc = try await firestore
            .collection("users")
            .document(currentUserId)
            .getDocument()
        
        guard let currentUsername = currentUserDoc.data()?["username"] as? String else {
            throw FriendError.missingUsername
        }
        
        let currentDisplayName = currentUserDoc.data()?["displayName"] as? String
        let currentPhotoURLString = currentUserDoc.data()?["photoURL"] as? String
        let currentPhotoURL = currentPhotoURLString != nil ? URL(string: currentPhotoURLString!) : nil
        
        // Create a new request
        let requestId = UUID().uuidString
        let request = FriendRequest(
            id: requestId,
            fromUserId: currentUserId,
            fromUsername: currentUsername,
            fromDisplayName: currentDisplayName,
            fromPhotoURL: currentPhotoURL,
            toUserId: targetUserId,
            status: .pending,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        // Save the request in Firestore using a transaction
        // Run the Firestore transaction off the actor to avoid crossing the actor boundary with a non-Sendable `Any?`.
        try await Task.detached {
            let fs = self.firestore
            _ = try await fs.runTransaction { transaction, errorPointer -> Any? in
                do {
                    // Add to target user's incoming requests
                    let incomingRef = fs
                        .collection("friendRequests")
                        .document(targetUserId)
                        .collection("incoming")
                        .document(requestId)

                    // Add to current user's outgoing requests
                    let outgoingRef = fs
                        .collection("friendRequests")
                        .document(currentUserId)
                        .collection("outgoing")
                        .document(requestId)

                    // Convert request to dictionary
                    let requestData: [String: Any] = [
                        "fromUserId": request.fromUserId,
                        "fromUsername": request.fromUsername,
                        "fromDisplayName": request.fromDisplayName as Any,
                        "fromPhotoURL": request.fromPhotoURL?.absoluteString as Any,
                        "toUserId": request.toUserId,
                        "status": request.status.rawValue,
                        "createdAt": FieldValue.serverTimestamp(),
                        "updatedAt": FieldValue.serverTimestamp()
                    ]

                    transaction.setData(requestData, forDocument: incomingRef)
                    transaction.setData(requestData, forDocument: outgoingRef)

                    // Add to sender's friends
                    let senderFriendRef = fs
                        .collection("friends")
                        .document(request.fromUserId)
                        .collection("connections")
                        .document(currentUserId)

                    // Get current user details - using synchronous document fetch in transaction
                    let currentUserRef = fs
                        .collection("users")
                        .document(currentUserId)

                    // Get the document synchronously within the transaction
                    let currentUserDoc = try transaction.getDocument(currentUserRef)

                    let currentUsername = currentUserDoc.data()?["username"] as? String ?? ""
                    let currentDisplayName = currentUserDoc.data()?["displayName"] as? String
                    let currentPhotoURLString = currentUserDoc.data()?["photoURL"] as? String

                    let senderFriendData: [String: Any] = [
                        "username": currentUsername,
                        "displayName": currentDisplayName as Any,
                        "photoURL": currentPhotoURLString as Any,
                        "status": FriendRequest.RequestStatus.accepted.rawValue,
                        "createdAt": FieldValue.serverTimestamp(),
                        "updatedAt": FieldValue.serverTimestamp()
                    ]

                    transaction.setData(senderFriendData, forDocument: senderFriendRef)

                    // Update friend counts
                    let currentUserStatsRef = fs.collection("users").document(currentUserId)
                    transaction.updateData([
                        "friendsCount": FieldValue.increment(Int64(1))
                    ], forDocument: currentUserStatsRef)

                    let senderRef = fs.collection("users").document(request.fromUserId)
                    transaction.updateData([
                        "friendsCount": FieldValue.increment(Int64(1))
                    ], forDocument: senderRef)
                    return nil
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
            }
        }.value

        // Notify about the new request
        NotificationCenter.default.post(
            name: Self.friendRequestsDidUpdateNotification,
            object: nil
        )
    // Telemetry: friend request sent
    TelemetryService.shared.track(event: "friend_request_sent", properties: ["toUsername": username])
    }
    
    /// Accept a friend request
    func acceptFriendRequest(_ requestId: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw FriendError.userNotAuthenticated
        }
        
        // Get the request
        let requestDoc = try await firestore
            .collection("friendRequests")
            .document(currentUserId)
            .collection("incoming")
            .document(requestId)
            .getDocument()
        
        guard let request = FriendRequest(from: requestDoc) else {
            throw FriendError.requestNotFound
        }
        
        // Check if user can add more friends
        let canAdd = try await canAddMoreFriends()
        if !canAdd {
            throw FriendError.friendLimitReached
        }

        // Update request status using a transaction
        // Run the transaction off the actor to avoid returning a non-sendable Any? across the actor boundary.
        try await Task.detached {
            let fs = self.firestore
            _ = try await fs.runTransaction { transaction, errorPointer -> Any? in
                do {
                    // Update incoming request
                    let incomingRef = fs
                        .collection("friendRequests")
                        .document(currentUserId)
                        .collection("incoming")
                        .document(requestId)

                    transaction.updateData([
                        "status": FriendRequest.RequestStatus.accepted.rawValue,
                        "updatedAt": FieldValue.serverTimestamp()
                    ], forDocument: incomingRef)

                    // Update outgoing request
                    let outgoingRef = fs
                        .collection("friendRequests")
                        .document(request.fromUserId)
                        .collection("outgoing")
                        .document(requestId)

                    transaction.updateData([
                        "status": FriendRequest.RequestStatus.accepted.rawValue,
                        "updatedAt": FieldValue.serverTimestamp()
                    ], forDocument: outgoingRef)

                    // Add to current user's friends
                    let currentUserFriendRef = fs
                        .collection("friends")
                        .document(currentUserId)
                        .collection("connections")
                        .document(request.fromUserId)

                    let currentUserFriendData: [String: Any] = [
                        "username": request.fromUsername,
                        "displayName": request.fromDisplayName as Any,
                        "photoURL": request.fromPhotoURL?.absoluteString as Any,
                        "status": FriendRequest.RequestStatus.accepted.rawValue,
                        "createdAt": FieldValue.serverTimestamp(),
                        "updatedAt": FieldValue.serverTimestamp()
                    ]

                    transaction.setData(currentUserFriendData, forDocument: currentUserFriendRef)

                    // Add to sender's friends
                    let senderFriendRef = fs
                        .collection("friends")
                        .document(request.fromUserId)
                        .collection("connections")
                        .document(currentUserId)

                    // Get current user details - using synchronous document fetch in transaction
                    let currentUserRef = fs
                        .collection("users")
                        .document(currentUserId)

                    // Get the document synchronously within the transaction
                    let currentUserDoc = try transaction.getDocument(currentUserRef)

                    let currentUsername = currentUserDoc.data()?["username"] as? String ?? ""
                    let currentDisplayName = currentUserDoc.data()?["displayName"] as? String
                    let currentPhotoURLString = currentUserDoc.data()?["photoURL"] as? String

                    let senderFriendData: [String: Any] = [
                        "username": currentUsername,
                        "displayName": currentDisplayName as Any,
                        "photoURL": currentPhotoURLString as Any,
                        "status": FriendRequest.RequestStatus.accepted.rawValue,
                        "createdAt": FieldValue.serverTimestamp(),
                        "updatedAt": FieldValue.serverTimestamp()
                    ]

                    transaction.setData(senderFriendData, forDocument: senderFriendRef)

                    // Update friend counts
                    let currentUserStatsRef = fs.collection("users").document(currentUserId)
                    transaction.updateData([
                        "friendsCount": FieldValue.increment(Int64(1))
                    ], forDocument: currentUserStatsRef)

                    let senderRef = fs.collection("users").document(request.fromUserId)
                    transaction.updateData([
                        "friendsCount": FieldValue.increment(Int64(1))
                    ], forDocument: senderRef)
                    return nil
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
            }
        }.value

        // Notify about the updated friend list
        NotificationCenter.default.post(
            name: Self.friendsDidUpdateNotification,
            object: nil
        )
    }

    /// Cancel an outgoing friend request by id. Removes both outgoing and incoming request documents.
    func cancelOutgoingRequest(requestId: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw FriendError.userNotAuthenticated
        }

        // Get the outgoing request document
        let outgoingRef = firestore
            .collection("friendRequests")
            .document(currentUserId)
            .collection("outgoing")
            .document(requestId)

        let outgoingDoc = try await outgoingRef.getDocument()
        guard let data = outgoingDoc.data(), let toUserId = data["toUserId"] as? String else {
            throw FriendError.requestNotFound
        }

        // Prepare refs
        let incomingRef = firestore
            .collection("friendRequests")
            .document(toUserId)
            .collection("incoming")
            .document(requestId)

        // Run a batch to delete both
        let batch = firestore.batch()
        batch.deleteDocument(outgoingRef)
        batch.deleteDocument(incomingRef)

        try await batch.commit()

        // Notify listeners
        NotificationCenter.default.post(name: Self.friendRequestsDidUpdateNotification, object: nil)
    // Telemetry: friend request cancelled
    TelemetryService.shared.track(event: "friend_request_cancelled", properties: ["requestId": requestId])
    }
    
    /// Reject a friend request
    func rejectFriendRequest(_ requestId: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw FriendError.userNotAuthenticated
        }
        
        // Get the request
        let requestDoc = try await firestore
            .collection("friendRequests")
            .document(currentUserId)
            .collection("incoming")
            .document(requestId)
            .getDocument()
        
        guard let request = FriendRequest(from: requestDoc) else {
            throw FriendError.requestNotFound
        }

        // Update request status using a transaction
        try await Task.detached {
            let fs = self.firestore
            _ = try await fs.runTransaction { transaction, errorPointer -> Any? in
                // Update incoming request
                let incomingRef = fs
                    .collection("friendRequests")
                    .document(currentUserId)
                    .collection("incoming")
                    .document(requestId)

                transaction.updateData([
                    "status": FriendRequest.RequestStatus.rejected.rawValue,
                    "updatedAt": FieldValue.serverTimestamp()
                ], forDocument: incomingRef)

                // Update outgoing request
                let outgoingRef = fs
                    .collection("friendRequests")
                    .document(request.fromUserId)
                    .collection("outgoing")
                    .document(requestId)

                transaction.updateData([
                    "status": FriendRequest.RequestStatus.rejected.rawValue,
                    "updatedAt": FieldValue.serverTimestamp()
                ], forDocument: outgoingRef)
                return nil
            }
        }.value

        // Notify about the updated request list
        NotificationCenter.default.post(
            name: Self.friendRequestsDidUpdateNotification,
            object: nil
        )
    }
    
    /// Remove a friend
    func removeFriend(_ friendId: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw FriendError.userNotAuthenticated
        }
        
        // Remove friend connection using a transaction
        try await Task.detached {
            let fs = self.firestore
            _ = try await fs.runTransaction { transaction, errorPointer -> Any? in
                // Remove from current user's friends
                let currentUserFriendRef = fs
                    .collection("friends")
                    .document(currentUserId)
                    .collection("connections")
                    .document(friendId)

                transaction.deleteDocument(currentUserFriendRef)

                // Remove from other user's friends
                let otherUserFriendRef = fs
                    .collection("friends")
                    .document(friendId)
                    .collection("connections")
                    .document(currentUserId)

                transaction.deleteDocument(otherUserFriendRef)

                // Update friend counts
                let currentUserStatsRef = fs.collection("users").document(currentUserId)
                transaction.updateData([
                    "friendsCount": FieldValue.increment(Int64(-1))
                ], forDocument: currentUserStatsRef)

                let friendRef = fs.collection("users").document(friendId)
                transaction.updateData([
                    "friendsCount": FieldValue.increment(Int64(-1))
                ], forDocument: friendRef)
                return nil
            }
        }.value

        // Notify about the updated friend list
        NotificationCenter.default.post(
            name: Self.friendsDidUpdateNotification,
            object: nil
        )
    }
    
    // MARK: - Private Methods
    
    /// Listen for changes to the user's friends
    private func listenForFriends(userId: String) {
        // Remove any existing listener
        friendsListener?.remove()
        
        // Create a new listener
        friendsListener = firestore
            .collection("friends")
            .document(userId)
            .collection("connections")
            .whereField("status", isEqualTo: FriendRequest.RequestStatus.accepted.rawValue)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    self.errorMessage = "Failed to listen for friends: \(error.localizedDescription)"
                    return
                }
                
                guard let snapshot = snapshot else { return }
                
                // Convert documents to Friend objects
                let friends = snapshot.documents.compactMap { document -> Friend? in
                    let id = document.documentID
                    guard let data = document.data() as [String: Any]? else { return nil }
                    
                    let username = data["username"] as? String ?? ""
                    let displayName = data["displayName"] as? String
                    var photoURL: URL? = nil
                    
                    if let photoURLString = data["photoURL"] as? String {
                        photoURL = URL(string: photoURLString)
                    }
                    
                    let statusString = data["status"] as? String ?? FriendRequest.RequestStatus.pending.rawValue
                    let status = FriendRequest.RequestStatus(rawValue: statusString) ?? .pending
                    
                    let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                    let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
                    
                    return Friend(
                        id: id,
                        name: username,
                        streak: 0, // Default streak, should be fetched separately if needed
                        lastActive: updatedAt,
                        profileImageURL: photoURL
                    )
                }
                
                // Update the published property
                DispatchQueue.main.async {
                    self.friends = friends
                    
                    // Notify about the updated friend list
                    NotificationCenter.default.post(
                        name: Self.friendsDidUpdateNotification,
                        object: nil
                    )
                }
            }
    }
    
    /// Listen for changes to the user's incoming friend requests
    private func listenForIncomingRequests(userId: String) {
        // Remove any existing listener
        incomingRequestsListener?.remove()
        
        // Create a new listener
        incomingRequestsListener = firestore
            .collection("friendRequests")
            .document(userId)
            .collection("incoming")
            .whereField("status", isEqualTo: FriendRequest.RequestStatus.pending.rawValue)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    self.errorMessage = "Failed to listen for incoming requests: \(error.localizedDescription)"
                    return
                }
                
                guard let snapshot = snapshot else { return }
                
                // Convert documents to FriendRequest objects
                let requests = snapshot.documents.compactMap { FriendRequest(from: $0) }
                
                // Update the published property
                DispatchQueue.main.async {
                    self.incomingRequests = requests
                    
                    // Notify about the updated request list
                    NotificationCenter.default.post(
                        name: Self.friendRequestsDidUpdateNotification,
                        object: nil
                    )
                }
            }
    }
    
    /// Listen for changes to the user's outgoing friend requests
    private func listenForOutgoingRequests(userId: String) {
        // Remove any existing listener
        outgoingRequestsListener?.remove()
        
        // Create a new listener
        outgoingRequestsListener = firestore
            .collection("friendRequests")
            .document(userId)
            .collection("outgoing")
            .whereField("status", isEqualTo: FriendRequest.RequestStatus.pending.rawValue)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    self.errorMessage = "Failed to listen for outgoing requests: \(error.localizedDescription)"
                    return
                }
                
                guard let snapshot = snapshot else { return }
                
                // Convert documents to FriendRequest objects
                let requests = snapshot.documents.compactMap { FriendRequest(from: $0) }
                
                // Update the published property
                DispatchQueue.main.async {
                    self.outgoingRequests = requests
                    
                    // Notify about the updated request list
                    NotificationCenter.default.post(
                        name: Self.friendRequestsDidUpdateNotification,
                        object: nil
                    )
                }
            }
    }
    
    /// Setup listener for subscription status changes
    private func setupSubscriptionListener() {
        NotificationCenter.default.publisher(for: NSNotification.Name("SubscriptionStatusChanged"))
            .sink { [weak self] notification in
                guard let self = self else { return }
                
                // If subscription status changes, we may need to update UI elements
                // related to friend limits
                if let userInfo = notification.userInfo as? [AnyHashable: Any], 
                   let isProUser = userInfo["isProUser"] as? Bool {
                    print("Subscription status changed: isProUser = \(isProUser)")
                    
                    // Notify about the updated friend list to refresh UI
                    NotificationCenter.default.post(
                        name: Self.friendsDidUpdateNotification,
                        object: nil
                    )
                }
            }
            .store(in: &cancellables)
    }
    
    // Add configureIfNeeded method
    private func configureIfNeeded() {
        // This is a placeholder method since Firestore is already configured in the init
        // No need to do anything here since firestore is already initialized
    }
    
    func fetchUserProfile(userId: String) async throws -> UserProfile? {
        // No need to call configureIfNeeded() since firestore is already initialized
        
        // Implementation of fetchUserProfile method
        // This method should return a UserProfile object
        // For now, we'll return nil as the implementation is not provided
        return nil
    }
}

/// Simple model for user search results
struct UserProfileResult: Identifiable {
    let id: String
    let username: String
    let displayName: String?
    let photoURL: URL?
}

/// Errors related to friend operations
enum FriendError: Error, LocalizedError {
    case userNotAuthenticated
    case userNotFound
    case friendLimitReached
    case alreadyFriends
    case requestAlreadySent
    case requestNotFound
    case cannotAddSelf
    case missingUsername
    
    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "You need to be signed in to perform this action."
        case .userNotFound:
            return "User not found."
        case .friendLimitReached:
            return "You've reached the maximum number of friends for your account. Upgrade to Pro for unlimited friends."
        case .alreadyFriends:
            return "You are already friends with this user."
        case .requestAlreadySent:
            return "Friend request already sent."
        case .requestNotFound:
            return "Friend request not found."
        case .cannotAddSelf:
            return "You cannot add yourself as a friend."
        case .missingUsername:
            return "You need to set a username before adding friends."
        }
    }
} 