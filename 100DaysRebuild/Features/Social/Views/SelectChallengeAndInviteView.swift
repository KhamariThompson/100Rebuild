import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct SelectChallengeAndInviteView: View {
    let friend: Friend
    @Environment(\.presentationMode) private var presentationMode
    @StateObject private var viewModel = SelectChallengeAndInviteViewModel()
    @State private var isInviting = false
    @State private var inviteError: String?

    // Loading view
    private var loadingView: some View {
        ProgressView()
    }
    
    // Empty state view
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "flag.2.crossed")
                .font(AppTypography.display())
                .foregroundColor(Color.theme.subtext)
            Text("No challenges")
                .font(AppTypography.headline())
                .foregroundColor(Color.theme.text)
            Text("Create a group challenge first, then invite friends to join it.")
                .font(AppTypography.subhead())
                .foregroundColor(Color.theme.subtext)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
    
    // Challenge list view
    private var challengeListView: some View {
        List {
            ForEach(viewModel.challenges) { challenge in
                ChallengeRowView(
                    challenge: challenge,
                    onTap: {
                        inviteToChallenge(challenge)
                    }
                )
            }
        }
        .listStyle(PlainListStyle())
    }
    
    // Challenge row view
    private func ChallengeRowView(challenge: GroupChallenge, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading) {
                    Text(challenge.title)
                        .font(AppTypography.headline())
                        .foregroundColor(Color.theme.text)
                    Text("Max \(challenge.maxParticipants) participants")
                        .font(AppTypography.caption1())
                        .foregroundColor(Color.theme.subtext)
                }
                Spacer()
                Image(systemName: "paperplane")
                    .foregroundColor(Color.theme.accent)
            }
        }
    }
    
    // Helper function to invite friend to challenge
    private func inviteToChallenge(_ challenge: GroupChallenge) {
        Task {
            isInviting = true
            do {
                try await GroupChallengeService.shared.inviteFriendToChallenge(
                    challengeId: challenge.id, 
                    friendId: friend.id
                )
                presentationMode.wrappedValue.dismiss()
            } catch {
                inviteError = error.localizedDescription
            }
            isInviting = false
        }
    }
    
    // Main body view
    var body: some View {
        NavigationView {
            ZStack {
                Color.theme.background.ignoresSafeArea()

                if viewModel.isLoading {
                    loadingView
                } else if viewModel.challenges.isEmpty {
                    emptyStateView
                } else {
                    challengeListView
                }
            }
            .navigationTitle("Invite to Challenge")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { 
                        presentationMode.wrappedValue.dismiss() 
                    }
                }
            }
            .alert(
                "Error",
                isPresented: .init(
                    get: { inviteError != nil },
                    set: { if !$0 { inviteError = nil } }
                ),
                actions: {
                    Button("OK") { inviteError = nil }
                },
                message: {
                    if let error = inviteError {
                        Text(error)
                    }
                }
            )
        }
        .onAppear {
            viewModel.loadChallenges()
        }
    }
}

@MainActor
class SelectChallengeAndInviteViewModel: ObservableObject {
    @Published var challenges: [GroupChallenge] = []
    @Published var isLoading = false

    private let groupService = GroupChallengeService.shared

    func loadChallenges() {
        isLoading = true
        Task {
            // Load challenges created by the current user
            let all = try? await Firestore.firestore()
                .collection("groupChallenges")
                .whereField("creatorId", isEqualTo: Auth.auth().currentUser?.uid ?? "")
                .getDocuments()

            self.challenges = all?.documents.compactMap { GroupChallenge(from: $0) } ?? []
            self.isLoading = false
        }
    }
}
