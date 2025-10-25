import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

@MainActor
class GroupChallengeViewModel: ObservableObject {
    // Challenge data
    @Published var challenge: GroupChallenge?
    @Published var participants: [GroupChallengeParticipant] = []
    @Published var invitations: [ChallengeInvitation] = []
    
    // UI state
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage: String?
    @Published var showInviteFriendSheet = false
    
    // User role flags
    @Published var isCreator = false
    @Published var isParticipant = false
    @Published var hasInvitation = false
    @Published var invitationId: String?
    
    // Services
    private let groupChallengeService = GroupChallengeService.shared
    private let friendService = FriendService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Load challenge details
    func loadChallenge(challengeId: String) {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "You need to be signed in to view challenges"
            showError = true
            return
        }
        
        isLoading = true
        
        Task {
            do {
                // Get challenge document
                let challengeDoc = try await Firestore.firestore()
                    .collection("groupChallenges")
                    .document(challengeId)
                    .getDocument()
                
                // Check if challenge exists
                guard let challenge = GroupChallenge(from: challengeDoc) else {
                    errorMessage = "Challenge not found"
                    showError = true
                    isLoading = false
                    return
                }
                
                // Set challenge
                self.challenge = challenge
                
                // Check user role
                isCreator = challenge.creatorId == userId
                
                // Get participants
                let participantsSnapshot = try await Firestore.firestore()
                    .collection("groupChallenges")
                    .document(challengeId)
                    .collection("participants")
                    .getDocuments()
                
                let participants = participantsSnapshot.documents.compactMap { GroupChallengeParticipant(from: $0) }
                self.participants = participants
                
                // Check if user is a participant
                isParticipant = participants.contains(where: { $0.userId == userId })
                
                // If user is creator, get invitations
                if isCreator {
                    let invitationsSnapshot = try await Firestore.firestore()
                        .collection("challengeInvites")
                        .document(challengeId)
                        .collection("invitees")
                        .whereField("status", isEqualTo: ChallengeInvitation.InvitationStatus.pending.rawValue)
                        .getDocuments()
                    
                    invitations = invitationsSnapshot.documents.compactMap { ChallengeInvitation(from: $0) }
                }
                
                // Check if user has an invitation
                if !isCreator && !isParticipant {
                    let userInvitationsSnapshot = try await Firestore.firestore()
                        .collection("users")
                        .document(userId)
                        .collection("challengeInvitations")
                        .whereField("challengeId", isEqualTo: challengeId)
                        .whereField("status", isEqualTo: ChallengeInvitation.InvitationStatus.pending.rawValue)
                        .getDocuments()
                    
                    if let invitation = userInvitationsSnapshot.documents.first.flatMap({ ChallengeInvitation(from: $0) }) {
                        hasInvitation = true
                        invitationId = invitation.id
                    }
                }
                
                isLoading = false
            } catch {
                errorMessage = "Failed to load challenge: \(error.localizedDescription)"
                showError = true
                isLoading = false
            }
        }
    }
    
    // Delete challenge (creator only)
    func deleteChallenge() async {
        guard let challenge = challenge else {
            errorMessage = "Challenge not found"
            showError = true
            return
        }
        
        isLoading = true
        
        do {
            try await groupChallengeService.deleteGroupChallenge(challengeId: challenge.id)
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            isLoading = false
        }
    }
    
    // Leave challenge (participant only)
    func leaveChallenge() async {
        guard let challenge = challenge else {
            errorMessage = "Challenge not found"
            showError = true
            return
        }
        
        isLoading = true
        
        do {
            try await groupChallengeService.leaveGroupChallenge(challengeId: challenge.id)
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            isLoading = false
        }
    }
    
    // Accept invitation
    func acceptInvitation() async {
        guard let invitationId = invitationId else {
            errorMessage = "Invitation not found"
            showError = true
            return
        }
        
        isLoading = true
        
        do {
            try await groupChallengeService.acceptChallengeInvitation(invitationId: invitationId)
            hasInvitation = false
            isParticipant = true
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            isLoading = false
        }
    }
    
    // Decline invitation
    func declineInvitation() async {
        guard let invitationId = invitationId else {
            errorMessage = "Invitation not found"
            showError = true
            return
        }
        
        isLoading = true
        
        do {
            try await groupChallengeService.rejectChallengeInvitation(invitationId: invitationId)
            hasInvitation = false
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            isLoading = false
        }
    }
    
    // Join public challenge
    func joinPublicChallenge() async {
        guard let challenge = challenge, challenge.isPublic else {
            errorMessage = "This challenge is not public"
            showError = true
            return
        }
        
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "You need to be signed in to join challenges"
            showError = true
            return
        }
        
        isLoading = true
        
        do {
            // Get user document to get username and profile
            let userDoc = try await Firestore.firestore()
                .collection("users")
                .document(userId)
                .getDocument()
            
            guard let userData = userDoc.data(),
                  let username = userData["username"] as? String else {
                errorMessage = "Failed to get your profile information"
                showError = true
                isLoading = false
                return
            }
            
            // Create participant object
            let displayName = userData["displayName"] as? String
            var photoURL: URL? = nil
            if let photoURLString = userData["photoURL"] as? String {
                photoURL = URL(string: photoURLString)
            }
            
            let participant = GroupChallengeParticipant(
                id: userId,
                userId: userId,
                username: username,
                displayName: displayName,
                photoURL: photoURL
            )
            
            // Add user as participant
            try await Firestore.firestore()
                .collection("groupChallenges")
                .document(challenge.id)
                .collection("participants")
                .document(userId)
                .setData(participant.asDictionary())
            
            isParticipant = true
            participants.append(participant)
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            isLoading = false
        }
    }
    
    // Invite a friend to the challenge
    func inviteFriend(friendId: String) async {
        guard let challenge = challenge else {
            errorMessage = "Challenge not found"
            showError = true
            return
        }
        
        isLoading = true
        
        do {
            try await groupChallengeService.inviteFriendToChallenge(
                challengeId: challenge.id,
                friendId: friendId
            )
            
            // Reload invitations
            let invitationsSnapshot = try await Firestore.firestore()
                .collection("challengeInvites")
                .document(challenge.id)
                .collection("invitees")
                .whereField("status", isEqualTo: ChallengeInvitation.InvitationStatus.pending.rawValue)
                .getDocuments()
            
            invitations = invitationsSnapshot.documents.compactMap { ChallengeInvitation(from: $0) }
            
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            isLoading = false
        }
    }
    
    // Cancel an invitation
    func cancelInvitation(_ invitationId: String) async {
        guard let challenge = challenge else {
            errorMessage = "Challenge not found"
            showError = true
            return
        }
        
        isLoading = true
        
        do {
            // Find the invitation
            guard let invitation = invitations.first(where: { $0.id == invitationId }) else {
                errorMessage = "Invitation not found"
                showError = true
                isLoading = false
                return
            }
            
            // Delete the invitation from both places
            try await Firestore.firestore()
                .collection("challengeInvites")
                .document(challenge.id)
                .collection("invitees")
                .document(invitation.toUserId)
                .delete()
            
            try await Firestore.firestore()
                .collection("users")
                .document(invitation.toUserId)
                .collection("challengeInvitations")
                .document(invitationId)
                .delete()
            
            // Update local state
            invitations.removeAll(where: { $0.id == invitationId })
            
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            isLoading = false
        }
    }
} 