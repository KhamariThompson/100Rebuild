import SwiftUI
import FirebaseFirestore

struct InvitationCardView: View {
    let invitation: ChallengeInvitation
    let onAccept: () -> Void
    let onDecline: () -> Void
    
    @State private var showingChallengeDetails = false
    @State private var challenge: GroupChallenge?
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage: String?
    
    // Check if the invitation is expired (older than 14 days)
    private var isExpired: Bool {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.day], from: invitation.createdAt, to: now)
        return invitation.status == .expired || (components.day ?? 0) >= 14
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with challenge title and from user
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(invitation.challengeTitle)
                        .font(.headline)
                        .foregroundColor(Color.theme.text)
                        .lineLimit(1)
                    
                    Text("From @\(invitation.fromUsername)")
                        .font(.caption)
                        .foregroundColor(Color.theme.subtext)
                }
                
                Spacer()
                
                // Time ago with expired badge if needed
                HStack(spacing: 4) {
                    if isExpired {
                        Text("Expired")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.theme.error)
                            .cornerRadius(4)
                    }
                    
                    Text(invitation.createdAt.timeAgoDisplay())
                        .font(.caption)
                        .foregroundColor(Color.theme.subtext)
                }
            }
            
            // Divider
            Divider()
                .background(Color.theme.border)
            
            // Action buttons
            HStack {
                Button(action: {
                    loadChallengeDetails()
                }) {
                    Text("View Details")
                        .font(.subheadline)
                        .foregroundColor(Color.theme.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.theme.accent, lineWidth: 1)
                        )
                }
                
                Spacer()
                
                Button(action: onDecline) {
                    Text("Decline")
                        .font(.subheadline)
                        .foregroundColor(Color.theme.error)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.theme.error, lineWidth: 1)
                        )
                }
                .padding(.trailing, 8)
                
                Button(action: onAccept) {
                    Text("Accept")
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.theme.accent)
                        .cornerRadius(8)
                }
                .disabled(isExpired)
                .opacity(isExpired ? 0.5 : 1.0)
            }
        }
        .padding()
        .background(Color.theme.surface)
        .cornerRadius(12)
        .shadow(color: Color.theme.shadow.opacity(0.1), radius: 5, x: 0, y: 2)
        .sheet(isPresented: $showingChallengeDetails) {
            if let challenge = challenge {
                NavigationView {
                    GroupChallengeDetailView(challengeId: challenge.id)
                        .navigationBarItems(trailing: Button("Close") {
                            showingChallengeDetails = false
                        })
                }
            } else {
                LoadingView()
            }
        }
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Error"),
                message: Text(errorMessage ?? "An unknown error occurred"),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func loadChallengeDetails() {
        isLoading = true
        
        Task {
            do {
                let challengeDoc = try await Firestore.firestore()
                    .collection("groupChallenges")
                    .document(invitation.challengeId)
                    .getDocument()
                
                if let challenge = GroupChallenge(from: challengeDoc) {
                    await MainActor.run {
                        self.challenge = challenge
                        showingChallengeDetails = true
                        isLoading = false
                    }
                } else {
                    await MainActor.run {
                        errorMessage = "Challenge not found"
                        showError = true
                        isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isLoading = false
                }
            }
        }
    }
} 