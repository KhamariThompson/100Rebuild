import Foundation
@preconcurrency import FirebaseFirestore
@preconcurrency import FirebaseAuth
import Combine
import SwiftUI

@MainActor
class GroupChallengeService: ObservableObject {
    // Published properties
    @Published private(set) var challenges: [GroupChallenge] = []
    @Published private(set) var participatingChallenges: [GroupChallenge] = []
    @Published private(set) var invitations: [ChallengeInvitation] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String? = nil
    
    // Singleton instance
    static let shared = GroupChallengeService()
    
    // Dependencies
    nonisolated(unsafe) private let firestore = Firestore.firestore()
    private let userSession = UserSession.shared
    private let friendService = FriendService.shared
    private let subscriptionService = SubscriptionService.shared
    private var cancellables = Set<AnyCancellable>()
    private var challengesListener: ListenerRegistration?
    private var participatingChallengesListener: ListenerRegistration?
    private var invitationsListener: ListenerRegistration?
    
    // Notification names
    static let challengesDidUpdateNotification = Notification.Name("groupChallengesDidUpdate")
    static let invitationsDidUpdateNotification = Notification.Name("challengeInvitationsDidUpdate")
    
    private init() {
        setupSubscriptionListener()
    }
    
    deinit {
        // Clean up listeners synchronously since deinit can't be async
        challengesListener?.remove()
        participatingChallengesListener?.remove()
        invitationsListener?.remove()
    }
    
    // MARK: - Public Methods
    
    /// Start listening for challenges and invitations
    func startListening() {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "User not signed in"
            return
        }
        
        // Start listening for created challenges
        listenForCreatedChallenges(userId: userId)
        
        // Start listening for participating challenges
        listenForParticipatingChallenges(userId: userId)
        
        // Start listening for challenge invitations
        listenForChallengeInvitations(userId: userId)
    }
    
    /// Stop listening for challenges and invitations
    func stopListening() {
        challengesListener?.remove()
        challengesListener = nil
        
        participatingChallengesListener?.remove()
        participatingChallengesListener = nil
        
        invitationsListener?.remove()
        invitationsListener = nil
    }
    
    /// Create a new group challenge
    func createGroupChallenge(title: String, description: String, isPublic: Bool, maxParticipants: Int) async throws -> GroupChallenge {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw GroupChallengeError.userNotAuthenticated
        }
        
        // Check if user is Pro for group challenges with more than 2 participants
        if maxParticipants > 2 && !subscriptionService.isProUser {
            subscriptionService.showPaywall = true
            throw GroupChallengeError.proFeatureRequired
        }
        
        // Get current user's username
        let userDoc = try await firestore
            .collection("users")
            .document(userId)
            .getDocument()
        
        guard let username = userDoc.data()?["username"] as? String else {
            throw GroupChallengeError.missingUsername
        }
        
        // Create the challenge
        let challenge = GroupChallenge(
            title: title,
            description: description,
            creatorId: userId,
            creatorUsername: username,
            isPublic: isPublic,
            maxParticipants: maxParticipants
        )
        
        // Save to Firestore
        let challengeRef = firestore
            .collection("groupChallenges")
            .document(challenge.id)
        
        try await challengeRef.setData(challenge.asDictionary())
        
        // Add creator as first participant
        let participantRef = challengeRef
            .collection("participants")
            .document(userId)
        
        let displayName = userDoc.data()?["displayName"] as? String
        var photoURL: URL? = nil
        if let photoURLString = userDoc.data()?["photoURL"] as? String {
            photoURL = URL(string: photoURLString)
        }
        
        let participant = GroupChallengeParticipant(
            id: userId,
            userId: userId,
            username: username,
            displayName: displayName,
            photoURL: photoURL
        )
        
        try await participantRef.setData(participant.asDictionary())
        
        return challenge
    }
    
    /// Invite a friend to a challenge
    func inviteFriendToChallenge(challengeId: String, friendId: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw GroupChallengeError.userNotAuthenticated
        }
        
        // Get the challenge
        let challengeDoc = try await firestore
            .collection("groupChallenges")
            .document(challengeId)
            .getDocument()
        
        guard let challenge = GroupChallenge(from: challengeDoc) else {
            throw GroupChallengeError.challengeNotFound
        }
        
        // Verify the user is the creator of the challenge
        guard challenge.creatorId == userId else {
            throw GroupChallengeError.notAuthorized
        }
        
        // Check if the friend is already a participant
        let participantDoc = try await firestore
            .collection("groupChallenges")
            .document(challengeId)
            .collection("participants")
            .document(friendId)
            .getDocument()
        
        if participantDoc.exists {
            throw GroupChallengeError.alreadyParticipating
        }
        
        // Check if an invitation already exists
        let existingInviteQuery = try await firestore
            .collection("challengeInvites")
            .document(challengeId)
            .collection("invitees")
            .document(friendId)
            .getDocument()
        
        if existingInviteQuery.exists {
            throw GroupChallengeError.invitationAlreadySent
        }
        
        // Get current user's username
        let userDoc = try await firestore
            .collection("users")
            .document(userId)
            .getDocument()
        
        guard let username = userDoc.data()?["username"] as? String else {
            throw GroupChallengeError.missingUsername
        }
        
        // Create the invitation
        let invitationId = UUID().uuidString
        let invitation = ChallengeInvitation(
            id: invitationId,
            challengeId: challengeId,
            challengeTitle: challenge.title,
            fromUserId: userId,
            fromUsername: username,
            toUserId: friendId
        )
        
        // Save to Firestore
        try await firestore
            .collection("challengeInvites")
            .document(challengeId)
            .collection("invitees")
            .document(friendId)
            .setData(invitation.asDictionary())
        
        // Also add to the friend's incoming invitations for easier querying
        try await firestore
            .collection("users")
            .document(friendId)
            .collection("challengeInvitations")
            .document(invitationId)
            .setData(invitation.asDictionary())
    }
    
    /// Accept a challenge invitation
    func acceptChallengeInvitation(invitationId: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw GroupChallengeError.userNotAuthenticated
        }
        
        // Get the invitation
        let invitationDoc = try await firestore
            .collection("users")
            .document(userId)
            .collection("challengeInvitations")
            .document(invitationId)
            .getDocument()
        
        guard let invitation = ChallengeInvitation(from: invitationDoc) else {
            throw GroupChallengeError.invitationNotFound
        }
        
        // Check if the invitation is expired (older than 14 days)
        if invitation.status == .expired {
            throw GroupChallengeError.invitationExpired
        }
        
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.day], from: invitation.createdAt, to: now)
        if (components.day ?? 0) >= 14 {
            // Mark as expired and throw error
            try await markInvitationAsExpired(invitationId: invitationId, challengeId: invitation.challengeId)
            throw GroupChallengeError.invitationExpired
        }
        
        // Check if the invitation is for the current user
        guard invitation.toUserId == userId else {
            throw GroupChallengeError.notAuthorized
        }
        
        // Get the challenge
        let challengeDoc = try await firestore
            .collection("groupChallenges")
            .document(invitation.challengeId)
            .getDocument()
        
        guard let challenge = GroupChallenge(from: challengeDoc) else {
            throw GroupChallengeError.challengeNotFound
        }
        
        // Get current participant count
        let participantsQuery = try await firestore
            .collection("groupChallenges")
            .document(invitation.challengeId)
            .collection("participants")
            .count
            .getAggregation(source: .server)
        
        let participantCount = Int(truncating: participantsQuery.count)
        
        // Check if the challenge is full
        if participantCount >= challenge.maxParticipants {
            throw GroupChallengeError.challengeFull
        }
        
        // Get current user's details
        let userDoc = try await firestore
            .collection("users")
            .document(userId)
            .getDocument()
        
        guard let username = userDoc.data()?["username"] as? String else {
            throw GroupChallengeError.missingUsername
        }
        
        let displayName = userDoc.data()?["displayName"] as? String
        let photoURL: URL? = {
            if let photoURLString = userDoc.data()?["photoURL"] as? String {
                return URL(string: photoURLString)
            }
            return nil
        }()

        // Update invitation status using a transaction
        do {
            let photoURLLocal = photoURL
            try await Task.detached {
                let fs = self.firestore
                _ = try await fs.runTransaction { transaction, errorPointer -> Any? in
                    // Update the invitation in user's collection
                    let userInviteRef = fs
                        .collection("users")
                        .document(userId)
                        .collection("challengeInvitations")
                        .document(invitationId)

                    transaction.updateData([
                        "status": ChallengeInvitation.InvitationStatus.accepted.rawValue,
                        "updatedAt": FieldValue.serverTimestamp()
                    ], forDocument: userInviteRef)

                    // Update the invitation in challenge's collection
                    let challengeInviteRef = fs
                        .collection("challengeInvites")
                        .document(invitation.challengeId)
                        .collection("invitees")
                        .document(userId)

                    transaction.updateData([
                        "status": ChallengeInvitation.InvitationStatus.accepted.rawValue,
                        "updatedAt": FieldValue.serverTimestamp()
                    ], forDocument: challengeInviteRef)

                    // Add user as participant
                    let participantRef = fs
                        .collection("groupChallenges")
                        .document(invitation.challengeId)
                        .collection("participants")
                        .document(userId)

                    let participant = GroupChallengeParticipant(
                        id: userId,
                        userId: userId,
                        username: username,
                        displayName: displayName,
                        photoURL: photoURLLocal
                    )

                    transaction.setData(participant.asDictionary(), forDocument: participantRef)
                    return nil
                }
            }.value
        }

        // Notify about the updated challenge list
        NotificationCenter.default.post(
            name: Self.challengesDidUpdateNotification,
            object: nil
        )
    }
    
    /// Mark an invitation as expired
    private func markInvitationAsExpired(invitationId: String, challengeId: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw GroupChallengeError.userNotAuthenticated
        }
        
        // Update invitation status using a transaction
        try await Task.detached {
            let fs = self.firestore
            _ = try await fs.runTransaction { transaction, errorPointer -> Any? in
                // Update the invitation in user's collection
                let userInviteRef = fs
                    .collection("users")
                    .document(userId)
                    .collection("challengeInvitations")
                    .document(invitationId)

                transaction.updateData([
                    "status": ChallengeInvitation.InvitationStatus.expired.rawValue,
                    "updatedAt": FieldValue.serverTimestamp()
                ], forDocument: userInviteRef)

                // Update the invitation in challenge's collection
                let challengeInviteRef = fs
                    .collection("challengeInvites")
                    .document(challengeId)
                    .collection("invitees")
                    .document(userId)

                transaction.updateData([
                    "status": ChallengeInvitation.InvitationStatus.expired.rawValue,
                    "updatedAt": FieldValue.serverTimestamp()
                ], forDocument: challengeInviteRef)
                return nil
            }
        }.value

        // Notify about the updated invitation list
        NotificationCenter.default.post(
            name: Self.invitationsDidUpdateNotification,
            object: nil
        )
    }

    /// Reject a challenge invitation
    func rejectChallengeInvitation(invitationId: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw GroupChallengeError.userNotAuthenticated
        }
        
        // Get the invitation
        let invitationDoc = try await firestore
            .collection("users")
            .document(userId)
            .collection("challengeInvitations")
            .document(invitationId)
            .getDocument()
        
        guard let invitation = ChallengeInvitation(from: invitationDoc) else {
            throw GroupChallengeError.invitationNotFound
        }
        
        // Check if the invitation is for the current user
        guard invitation.toUserId == userId else {
            throw GroupChallengeError.notAuthorized
        }
        
        // Update invitation status using a transaction
        try await Task.detached {
            let fs = self.firestore
            _ = try await fs.runTransaction { transaction, errorPointer -> Any? in
                // Update the invitation in user's collection
                let userInviteRef = fs
                    .collection("users")
                    .document(userId)
                    .collection("challengeInvitations")
                    .document(invitationId)

                transaction.updateData([
                    "status": ChallengeInvitation.InvitationStatus.rejected.rawValue,
                    "updatedAt": FieldValue.serverTimestamp()
                ], forDocument: userInviteRef)

                // Update the invitation in challenge's collection
                let challengeInviteRef = fs
                    .collection("challengeInvites")
                    .document(invitation.challengeId)
                    .collection("invitees")
                    .document(userId)

                transaction.updateData([
                    "status": ChallengeInvitation.InvitationStatus.rejected.rawValue,
                    "updatedAt": FieldValue.serverTimestamp()
                ], forDocument: challengeInviteRef)
                return nil
            }
        }.value

        // Notify about the updated invitation list
        NotificationCenter.default.post(
            name: Self.invitationsDidUpdateNotification,
            object: nil
        )
    }


    /// Leave a group challenge
    func leaveGroupChallenge(challengeId: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw GroupChallengeError.userNotAuthenticated
        }
        
        // Get the challenge
        let challengeDoc = try await firestore
            .collection("groupChallenges")
            .document(challengeId)
            .getDocument()
        
        guard let challenge = GroupChallenge(from: challengeDoc) else {
            throw GroupChallengeError.challengeNotFound
        }
        
        // Check if the user is the creator - creators can't leave, they must delete
        if challenge.creatorId == userId {
            throw GroupChallengeError.creatorCannotLeave
        }
        
        // Check if the user is a participant
        let participantDoc = try await firestore
            .collection("groupChallenges")
            .document(challengeId)
            .collection("participants")
            .document(userId)
            .getDocument()
        
        if !participantDoc.exists {
            throw GroupChallengeError.notParticipating
        }
        
        // Remove the participant
        try await firestore
            .collection("groupChallenges")
            .document(challengeId)
            .collection("participants")
            .document(userId)
            .delete()
        
        // Notify about the updated challenge list
        NotificationCenter.default.post(
            name: Self.challengesDidUpdateNotification,
            object: nil
        )
    }
    
    /// Delete a group challenge (creator only)
    func deleteGroupChallenge(challengeId: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw GroupChallengeError.userNotAuthenticated
        }
        
        // Get the challenge
        let challengeDoc = try await firestore
            .collection("groupChallenges")
            .document(challengeId)
            .getDocument()
        
        guard let challenge = GroupChallenge(from: challengeDoc) else {
            throw GroupChallengeError.challengeNotFound
        }
        
        // Verify the user is the creator of the challenge
        guard challenge.creatorId == userId else {
            throw GroupChallengeError.notAuthorized
        }
        
        // Delete the challenge and all related data using a batch
        let batch = firestore.batch()
        
        // Delete the challenge document
        let challengeRef = firestore
            .collection("groupChallenges")
            .document(challengeId)
        
        batch.deleteDocument(challengeRef)
        
        // Delete all participants
        let participantsQuery = try await firestore
            .collection("groupChallenges")
            .document(challengeId)
            .collection("participants")
            .getDocuments()
        
        for participantDoc in participantsQuery.documents {
            batch.deleteDocument(participantDoc.reference)
        }
        
        // Delete all invitations
        let invitationsQuery = try await firestore
            .collection("challengeInvites")
            .document(challengeId)
            .collection("invitees")
            .getDocuments()
        
        for invitationDoc in invitationsQuery.documents {
            // Delete from challenge invites collection
            batch.deleteDocument(invitationDoc.reference)
            
            // Also delete from user's invitations collection
            let inviteeId = invitationDoc.documentID
            let userInviteRef = firestore
                .collection("users")
                .document(inviteeId)
                .collection("challengeInvitations")
                .document(invitationDoc.data()["id"] as? String ?? "")
            
            batch.deleteDocument(userInviteRef)
        }
        
        // Commit the batch
        try await batch.commit()
        
        // Notify about the updated challenge list
        NotificationCenter.default.post(
            name: Self.challengesDidUpdateNotification,
            object: nil
        )
    }
    
    /// Clean up stale invitations (older than 7 days)
    func cleanupStaleInvitations() async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw GroupChallengeError.userNotAuthenticated
        }
        
        // Get invitations older than 7 days
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let cutoffTimestamp = Timestamp(date: cutoffDate)
        
        // Get stale invitations from user's collection
        let staleInvitationsQuery = try await firestore
            .collection("users")
            .document(userId)
            .collection("challengeInvitations")
            .whereField("status", isEqualTo: ChallengeInvitation.InvitationStatus.pending.rawValue)
            .whereField("createdAt", isLessThan: cutoffTimestamp)
            .getDocuments()
        
        // Update each stale invitation
        for invitationDoc in staleInvitationsQuery.documents {
            guard let invitation = ChallengeInvitation(from: invitationDoc) else { continue }

            // Update invitation status using a transaction
            try await Task.detached {
                let fs = self.firestore
                _ = try await fs.runTransaction { transaction, errorPointer -> Any? in
                    // Update the invitation in user's collection
                    let userInviteRef = fs
                        .collection("users")
                        .document(userId)
                        .collection("challengeInvitations")
                        .document(invitation.id)

                    transaction.updateData([
                        "status": ChallengeInvitation.InvitationStatus.expired.rawValue,
                        "updatedAt": FieldValue.serverTimestamp()
                    ], forDocument: userInviteRef)

                    // Update the invitation in challenge's collection
                    let challengeInviteRef = fs
                        .collection("challengeInvites")
                        .document(invitation.challengeId)
                        .collection("invitees")
                        .document(userId)

                    transaction.updateData([
                        "status": ChallengeInvitation.InvitationStatus.expired.rawValue,
                        "updatedAt": FieldValue.serverTimestamp()
                    ], forDocument: challengeInviteRef)
                    return nil
                }
            }.value
        }

        // Notify about the updated invitation list
        if !staleInvitationsQuery.documents.isEmpty {
            NotificationCenter.default.post(
                name: Self.invitationsDidUpdateNotification,
                object: nil
            )
        }
    }
    
    // MARK: - Private Methods
    
    /// Listen for changes to the user's created challenges
    private func listenForCreatedChallenges(userId: String) {
        // Remove any existing listener
        challengesListener?.remove()
        
        // Create a new listener
        challengesListener = firestore
            .collection("groupChallenges")
            .whereField("creatorId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    self.errorMessage = "Failed to listen for challenges: \(error.localizedDescription)"
                    return
                }
                
                guard let snapshot = snapshot else { return }
                
                // Convert documents to GroupChallenge objects
                let challenges = snapshot.documents.compactMap { GroupChallenge(from: $0) }
                
                // Update the published property
                Task { @MainActor in
                    self.challenges = challenges
                    
                    // Notify about the updated challenge list
                    NotificationCenter.default.post(
                        name: Self.challengesDidUpdateNotification,
                        object: nil
                    )
                }
            }
    }
    
    /// Listen for changes to the user's participating challenges
    private func listenForParticipatingChallenges(userId: String) {
        // Remove any existing listener
        participatingChallengesListener?.remove()
        
        // Create a new listener for challenges where the user is a participant but not the creator
        participatingChallengesListener = firestore
            .collection("groupChallenges")
            .whereField("creatorId", isNotEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    self.errorMessage = "Failed to listen for participating challenges: \(error.localizedDescription)"
                    return
                }
                
                guard let snapshot = snapshot else { return }
                
                // We need to filter the challenges where the user is a participant
                Task {
                    var participatingChallenges: [GroupChallenge] = []
                    
                    for document in snapshot.documents {
                        guard let challenge = GroupChallenge(from: document) else { continue }
                        
                        // Check if user is a participant
                        let participantDoc = try? await self.firestore
                            .collection("groupChallenges")
                            .document(challenge.id)
                            .collection("participants")
                            .document(userId)
                            .getDocument()
                        
                        if let participantDoc = participantDoc, participantDoc.exists {
                            participatingChallenges.append(challenge)
                        }
                    }
                    
                    // Update the published property
                    await MainActor.run {
                        self.participatingChallenges = participatingChallenges
                        
                        // Notify about the updated challenge list
                        NotificationCenter.default.post(
                            name: Self.challengesDidUpdateNotification,
                            object: nil
                        )
                    }
                }
            }
    }
    
    /// Listen for changes to the user's challenge invitations
    private func listenForChallengeInvitations(userId: String) {
        // Remove any existing listener
        invitationsListener?.remove()
        
        // Create a new listener
        invitationsListener = firestore
            .collection("users")
            .document(userId)
            .collection("challengeInvitations")
            .whereField("status", isEqualTo: ChallengeInvitation.InvitationStatus.pending.rawValue)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    self.errorMessage = "Failed to listen for invitations: \(error.localizedDescription)"
                    return
                }
                
                guard let snapshot = snapshot else { return }
                
                // Convert documents to ChallengeInvitation objects
                let invitations = snapshot.documents.compactMap { ChallengeInvitation(from: $0) }
                
                // Update the published property
                Task { @MainActor in
                    self.invitations = invitations
                    
                    // Notify about the updated invitation list
                    NotificationCenter.default.post(
                        name: Self.invitationsDidUpdateNotification,
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
                // related to challenge limits
                if let isProUser = notification.userInfo?["isProUser"] as? Bool {
                    print("Subscription status changed: isProUser = \(isProUser)")
                    
                    // Notify about the updated challenge list to refresh UI
                    NotificationCenter.default.post(
                        name: Self.challengesDidUpdateNotification,
                        object: nil
                    )
                }
            }
            .store(in: &cancellables)
    }
}

/// Errors related to group challenge operations
enum GroupChallengeError: Error, LocalizedError {
    case userNotAuthenticated
    case challengeNotFound
    case invitationNotFound
    case notAuthorized
    case proFeatureRequired
    case missingUsername
    case alreadyParticipating
    case invitationAlreadySent
    case challengeFull
    case notParticipating
    case creatorCannotLeave
    case invitationExpired
    
    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "You need to be signed in to perform this action."
        case .challengeNotFound:
            return "Challenge not found."
        case .invitationNotFound:
            return "Invitation not found."
        case .notAuthorized:
            return "You are not authorized to perform this action."
        case .proFeatureRequired:
            return "This feature requires a Pro subscription."
        case .missingUsername:
            return "You need to set a username before creating challenges."
        case .alreadyParticipating:
            return "This user is already participating in the challenge."
        case .invitationAlreadySent:
            return "An invitation has already been sent to this user."
        case .challengeFull:
            return "The challenge has reached its maximum number of participants."
        case .notParticipating:
            return "You are not participating in this challenge."
        case .creatorCannotLeave:
            return "The creator cannot leave the challenge. You must delete it instead."
        case .invitationExpired:
            return "This invitation has expired."
        }
    }
}
