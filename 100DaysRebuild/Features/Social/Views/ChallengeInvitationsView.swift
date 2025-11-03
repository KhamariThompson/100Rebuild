import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Combine

struct ChallengeInvitationsView: View {
    @StateObject private var viewModel = ChallengeInvitationsViewModel()
    
    var body: some View {
        ZStack {
            Color.theme.background.ignoresSafeArea()
            
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
            } else if viewModel.invitations.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(viewModel.invitations) { invitation in
                            ChallengeInvitationCardView(
                                invitation: invitation,
                                onAccept: {
                                    Task {
                                        await viewModel.acceptInvitation(invitation.id)
                                    }
                                },
                                onReject: {
                                    Task {
                                        await viewModel.declineInvitation(invitation.id)
                                    }
                                }
                            )
                        }
                    }
                    .padding()
                }
                .refreshable {
                    await viewModel.refreshInvitations()
                }
            }
        }
        .navigationTitle("Invitations")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadInvitations()
        }
        .alert(isPresented: $viewModel.showError) {
            Alert(
                title: Text("Error"),
                message: Text(viewModel.errorMessage ?? "An unknown error occurred"),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "envelope.open.fill")
                .font(AppTypography.font(size: 60, weight: .bold))
                .foregroundColor(Color.theme.accent.opacity(0.7))
                .padding(.top, 40)
            
            Text("No Invitations")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(Color.theme.text)
            
            Text("When friends invite you to join their challenges, they'll appear here.")
                .font(.subheadline)
                .foregroundColor(Color.theme.subtext)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

struct ChallengeInvitationCardView: View {
    let invitation: ChallengeInvitation
    let onAccept: () -> Void
    let onReject: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with challenge title and time
            HStack {
                Text(invitation.challengeTitle)
                    .font(.headline)
                    .foregroundColor(Color.theme.text)
                
                Spacer()
                
                Text(invitation.createdAt.timeAgoDisplay())
                    .font(.caption)
                    .foregroundColor(Color.theme.subtext)
            }
            
            // Invitation message
            Text("You've been invited to join this challenge")
                .font(.subheadline)
                .foregroundColor(Color.theme.subtext)
            
            // Action buttons
            HStack {
                Button(action: onReject) {
                    Text("Decline")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(Color.theme.text)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color.theme.surface)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.theme.border, lineWidth: 1)
                        )
                }
                
                Spacer()
                
                Button(action: onAccept) {
                    Text("Accept")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color.theme.accent)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color.theme.surface)
        .cornerRadius(12)
        .shadow(color: Color.theme.shadow.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

struct LoadingView: View {
    var body: some View {
        ZStack {
            Color.theme.background.ignoresSafeArea()
            
            VStack {
                ProgressView()
                    .scaleEffect(1.5)
                    .padding(.bottom, 20)
                
                Text("Loading challenge details...")
                    .font(.headline)
                    .foregroundColor(Color.theme.text)
            }
        }
    }
}

// MARK: - View Model
@MainActor
class ChallengeInvitationsViewModel: ObservableObject {
    @Published var invitations: [ChallengeInvitation] = []
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage: String?
    
    private let groupChallengeService = GroupChallengeService.shared
    private var cancellables = Set<AnyCancellable>()
    private var listener: ListenerRegistration?
    
    deinit {
        // Listener will be automatically cleaned up when deallocated
    }
    
    func loadInvitations() {
        isLoading = true
        
        startListening()
        
        isLoading = false
    }
    
    func refreshInvitations() async {
        isLoading = true
        
        // Stop and restart listening to refresh data
        stopListening()
        startListening()
        
        // Wait a moment for the listeners to update
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        isLoading = false
    }
    
    func acceptInvitation(_ invitationId: String) async {
        isLoading = true
        
        do {
            // Check if invitation is expired first
            if let invitation = invitations.first(where: { $0.id == invitationId }) {
                if isInvitationExpired(invitation) {
                    await markInvitationAsExpired(invitationId)
                    errorMessage = "This invitation has expired and can no longer be accepted."
                    showError = true
                    isLoading = false
                    return
                }
            }
            
            try await groupChallengeService.acceptChallengeInvitation(invitationId: invitationId)
            // The listener will update the invitations list
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            isLoading = false
        }
    }
    
    func declineInvitation(_ invitationId: String) async {
        isLoading = true
        
        do {
            try await groupChallengeService.rejectChallengeInvitation(invitationId: invitationId)
            // The listener will update the invitations list
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            isLoading = false
        }
    }
    
    // Check if an invitation is expired (older than 14 days)
    private func isInvitationExpired(_ invitation: ChallengeInvitation) -> Bool {
        if invitation.status == .expired {
            return true
        }
        
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.day], from: invitation.createdAt, to: now)
        return (components.day ?? 0) >= 14
    }
    
    // Mark an invitation as expired in Firestore
    private func markInvitationAsExpired(_ invitationId: String) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        guard let invitation = invitations.first(where: { $0.id == invitationId }) else { return }
        
        do {
            // Update the invitation in the user's collection
            let userInviteRef = Firestore.firestore()
                .collection("users")
                .document(userId)
                .collection("challengeInvitations")
                .document(invitationId)
            
            try await userInviteRef.updateData([
                "status": ChallengeInvitation.InvitationStatus.expired.rawValue,
                "updatedAt": FieldValue.serverTimestamp()
            ])
            
            // Update the invitation in the challenge's collection
            let challengeInviteRef = Firestore.firestore()
                .collection("challengeInvites")
                .document(invitation.challengeId)
                .collection("invitees")
                .document(userId)
            
            try await challengeInviteRef.updateData([
                "status": ChallengeInvitation.InvitationStatus.expired.rawValue,
                "updatedAt": FieldValue.serverTimestamp()
            ])
            
            print("Marked invitation \(invitationId) as expired")
        } catch {
            print("Error marking invitation as expired: \(error.localizedDescription)")
        }
    }
    
    private func startListening() {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "You need to be signed in to view invitations"
            showError = true
            return
        }
        
        // Stop any existing listener
        stopListening()
        
        // Start listening for invitations
        listener = Firestore.firestore()
            .collection("users")
            .document(userId)
            .collection("challengeInvitations")
            .whereField("status", isEqualTo: ChallengeInvitation.InvitationStatus.pending.rawValue)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    self.invitations = []
                    return
                }
                
                // Process invitations and check for expired ones
                let pendingInvitations = documents.compactMap { ChallengeInvitation(from: $0) }
                    .sorted(by: { $0.createdAt > $1.createdAt }) // Sort newest first
                
                self.invitations = pendingInvitations
                
                // Check for any expired invitations that need to be updated
                Task {
                    for invitation in pendingInvitations {
                        if self.isInvitationExpired(invitation) {
                            await self.markInvitationAsExpired(invitation.id)
                        }
                    }
                }
            }
    }
    
    private func stopListening() {
        listener?.remove()
        listener = nil
    }
}

 