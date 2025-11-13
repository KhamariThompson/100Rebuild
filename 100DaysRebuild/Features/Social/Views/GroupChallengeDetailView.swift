import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct GroupChallengeDetailView: View {
    let challengeId: String
    @StateObject private var viewModel = GroupChallengeViewModel()
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var subscriptionStore: SubscriptionStore

    var body: some View {
        ZStack {
            // Background
            Color.theme.background.ignoresSafeArea()

            if viewModel.isLoading || viewModel.challenge == nil {
                ProgressView()
                    .scaleEffect(1.5)
            } else if let challenge = viewModel.challenge {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header
                        challengeHeader(challenge: challenge)
                        
                        Divider()
                            .background(Color.theme.border)
                        
                        // Description
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(AppTypography.headline())
                                .foregroundColor(Color.theme.text)
                            
                            Text(challenge.description.isEmpty ? "No description provided." : challenge.description)
                                .font(AppTypography.body())
                                .foregroundColor(Color.theme.text)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal)
                        
                        Divider()
                            .background(Color.theme.border)
                        
                        // Participants
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Participants")
                                    .font(AppTypography.headline())
                                    .foregroundColor(Color.theme.text)
                                
                                Spacer()
                                
                                Text("\(viewModel.participants.count)/\(challenge.maxParticipants)")
                                    .font(AppTypography.subhead())
                                    .foregroundColor(Color.theme.subtext)
                            }
                            
                            if viewModel.participants.isEmpty {
                                Text("No participants yet.")
                                    .font(AppTypography.subhead())
                                    .foregroundColor(Color.theme.subtext)
                                    .padding(.vertical, 10)
                            } else {
                                ForEach(viewModel.participants) { participant in
                                    ParticipantRow(participant: participant)
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // Invitations (for creator only)
                        if viewModel.isCreator {
                            Divider()
                                .background(Color.theme.border)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Invitations")
                                        .font(AppTypography.headline())
                                        .foregroundColor(Color.theme.text)
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        viewModel.showInviteFriendSheet = true
                                    }) {
                                        Label("Invite", systemImage: "person.badge.plus")
                                            .font(AppTypography.subhead())
                                            .foregroundColor(Color.theme.accent)
                                    }
                                    .disabled(viewModel.participants.count >= challenge.maxParticipants)
                                }
                                
                                if viewModel.invitations.isEmpty {
                                    Text("No pending invitations.")
                                        .font(AppTypography.subhead())
                                        .foregroundColor(Color.theme.subtext)
                                        .padding(.vertical, 10)
                                } else {
                                    ForEach(viewModel.invitations) { invitation in
                                        InvitationRow(
                                            invitation: invitation,
                                            onCancel: {
                                                Task {
                                                    await viewModel.cancelInvitation(invitation.id)
                                                }
                                            }
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        Spacer()
                        
                        // Action buttons
                        actionButtons(challenge: challenge)
                            .padding(.horizontal)
                            .padding(.bottom, 20)
                    }
                    .padding(.vertical)
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(AppTypography.display())
                        .foregroundColor(Color.theme.error)
                    
                    Text("Challenge not found")
                        .font(AppTypography.title2())
                        .foregroundColor(Color.theme.text)
                    
                    Button("Go Back") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
        }
        .navigationTitle("Challenge Details")
        .navigationBarTitleDisplayMode(.inline)
        .id(challengeId) // Enforce unique identity per challengeId
        .onAppear {
            viewModel.loadChallenge(challengeId: challengeId)
        }
        .alert(isPresented: $viewModel.showError) {
            Alert(
                title: Text("Error"),
                message: Text(viewModel.errorMessage ?? "An unknown error occurred"),
                dismissButton: .default(Text("OK"))
            )
        }
        .sheet(isPresented: $viewModel.showInviteFriendSheet) {
            InviteFriendView(
                challengeId: challengeId,
                onInviteSent: { friendId in
                    Task {
                        await viewModel.inviteFriend(friendId: friendId)
                    }
                }
            )
        }
    }
    
    // Challenge header
    private func challengeHeader(challenge: GroupChallenge) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(challenge.title)
                        .font(AppTypography.title2())
                        .fontWeight(.bold)
                        .foregroundColor(Color.theme.text)
                    
                    Text("Created by @\(challenge.creatorUsername)")
                        .font(AppTypography.subhead())
                        .foregroundColor(Color.theme.subtext)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: challenge.isPublic ? "globe" : "lock")
                            .foregroundColor(challenge.isPublic ? Color.theme.success : Color.theme.accent)
                        
                        Text(challenge.isPublic ? "Public" : "Private")
                            .font(AppTypography.caption1())
                            .foregroundColor(Color.theme.subtext)
                    }
                    
                    Text("\(Calendar.current.dateComponents([.day], from: Date(), to: challenge.endDate).day ?? 0) days left")
                        .font(AppTypography.caption1())
                        .foregroundColor(Color.theme.subtext)
                }
            }
            
            // Progress bar
            let progress = calculateProgress(startDate: challenge.startDate, endDate: challenge.endDate)
            ProgressBar(progress: progress)
                .frame(height: 8)
                .padding(.top, 4)
        }
        .padding(.horizontal)
    }
    
    // Action buttons based on user role
    private func actionButtons(challenge: GroupChallenge) -> some View {
        VStack(spacing: 12) {
            if viewModel.isCreator {
                // Creator actions
                Button(action: {
                    Task {
                        await viewModel.deleteChallenge()
                        if !viewModel.showError {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }) {
                    Text("Delete Challenge")
                        .font(AppTypography.headline())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.theme.error)
                        .cornerRadius(10)
                }
            } else if viewModel.isParticipant {
                // Participant actions
                Button(action: {
                    Task {
                        await viewModel.leaveChallenge()
                        if !viewModel.showError {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }) {
                    Text("Leave Challenge")
                        .font(AppTypography.headline())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.theme.error)
                        .cornerRadius(10)
                }
            } else if viewModel.hasInvitation {
                // Invited user actions
                HStack(spacing: 20) {
                    Button(action: {
                        Task {
                            await viewModel.declineInvitation()
                            if !viewModel.showError {
                                presentationMode.wrappedValue.dismiss()
                            }
                        }
                    }) {
                        Text("Decline")
                            .font(AppTypography.headline())
                            .foregroundColor(Color.theme.text)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.theme.surface)
                            .cornerRadius(10)
                    }
                    
                    Button(action: {
                        Task {
                            await viewModel.acceptInvitation()
                            if !viewModel.showError {
                                // Refresh to show participant view
                                await viewModel.loadChallenge(challengeId: challengeId)
                            }
                        }
                    }) {
                        Text("Join Challenge")
                            .font(AppTypography.headline())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.theme.accent)
                            .cornerRadius(10)
                    }
                }
            } else if challenge.isPublic {
                // Public challenge - can join
                Button(action: {
                    Task {
                        await viewModel.joinPublicChallenge()
                        if !viewModel.showError {
                            // Refresh to show participant view
                            await viewModel.loadChallenge(challengeId: challengeId)
                        }
                    }
                }) {
                    Text("Join Challenge")
                        .font(AppTypography.headline())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.theme.accent)
                        .cornerRadius(10)
                }
            }
        }
    }
    
    // Calculate progress percentage
    private func calculateProgress(startDate: Date, endDate: Date) -> Double {
        let totalDuration = endDate.timeIntervalSince(startDate)
        let elapsedDuration = Date().timeIntervalSince(startDate)
        
        if elapsedDuration <= 0 {
            return 0.0
        } else if elapsedDuration >= totalDuration {
            return 1.0
        } else {
            return elapsedDuration / totalDuration
        }
    }
}

// MARK: - Supporting Views

struct ParticipantRow: View {
    let participant: GroupChallengeParticipant
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile image
            if let photoURL = participant.photoURL {
                AsyncImage(url: photoURL) { image in
                    image.resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray.opacity(0.3)
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .foregroundColor(Color.theme.accent.opacity(0.5))
                    .frame(width: 40, height: 40)
            }
            
            // User info
            VStack(alignment: .leading, spacing: 2) {
                Text(participant.displayName ?? "@\(participant.username)")
                    .font(AppTypography.subhead())
                    .foregroundColor(Color.theme.text)
                
                if participant.displayName != nil {
                    Text("@\(participant.username)")
                        .font(AppTypography.caption1())
                        .foregroundColor(Color.theme.subtext)
                }
            }
            
            Spacer()
            
            // Status indicator
            if participant.status == .completed {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Color.theme.success)
            } else if participant.status == .dropped {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(Color.theme.error)
            }
        }
        .padding(.vertical, 8)
    }
}

struct InvitationRow: View {
    let invitation: ChallengeInvitation
    let onCancel: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("@\(invitation.toUserId)")
                    .font(AppTypography.subhead())
                    .foregroundColor(Color.theme.text)
                
                Text("Invited \(invitation.createdAt.timeAgoDisplay())")
                    .font(AppTypography.caption1())
                    .foregroundColor(Color.theme.subtext)
            }
            
            Spacer()
            
            Button(action: onCancel) {
                Text("Cancel")
                    .font(AppTypography.caption1())
                    .foregroundColor(Color.theme.error)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.theme.error, lineWidth: 1)
                    )
            }
        }
        .padding(.vertical, 8)
    }
}

struct ProgressBar: View {
    var progress: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .foregroundColor(Color.theme.surface)
                    .cornerRadius(5)
                
                Rectangle()
                    .foregroundColor(Color.theme.accent)
                    .cornerRadius(5)
                    .frame(width: geometry.size.width * CGFloat(progress))
            }
        }
    }
}

struct DetailPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.headline())
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.theme.accent)
            .cornerRadius(10)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
    }
}

struct GroupPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.headline())
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.theme.accent)
            .cornerRadius(10)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
    }
}



// MARK: - InviteFriendView
struct InviteFriendView: View {
    let challengeId: String
    let onInviteSent: (String) -> Void
    
    @StateObject private var viewModel = InviteFriendViewModel()
    @Environment(\.presentationMode) private var presentationMode
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.theme.background.ignoresSafeArea()
                
                VStack(spacing: 16) {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Color.theme.subtext)
                        
                        TextField("Search friends", text: $viewModel.searchText)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .onChange(of: viewModel.searchText) { _ in
                                viewModel.searchFriends()
                            }
                        
                        if !viewModel.searchText.isEmpty {
                            Button(action: {
                                viewModel.searchText = ""
                                viewModel.searchFriends()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(Color.theme.subtext)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color.theme.surface)
                    .cornerRadius(10)
                    .padding(.horizontal)
                    
                    if viewModel.isLoading {
                        Spacer()
                        ProgressView()
                        Spacer()
                    } else if viewModel.friends.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "person.3.sequence")
                                .font(AppTypography.display())
                                .foregroundColor(Color.theme.subtext)
                            
                            Text("No friends found")
                                .font(AppTypography.headline())
                                .foregroundColor(Color.theme.text)
                            
                            Text("Add friends to invite them to challenges")
                                .font(AppTypography.subhead())
                                .foregroundColor(Color.theme.subtext)
                                .multilineTextAlignment(.center)
                        }
                        Spacer()
                    } else {
                        List {
                            ForEach(viewModel.filteredFriends) { friend in
                                Button(action: {
                                    onInviteSent(friend.id)
                                    presentationMode.wrappedValue.dismiss()
                                }) {
                                    HStack(spacing: 12) {
                                        // Profile image
                                        if let photoURL = friend.photoURL {
                                            AsyncImage(url: photoURL) { image in
                                                image.resizable()
                                                    .aspectRatio(contentMode: .fill)
                                            } placeholder: {
                                                Color.gray.opacity(0.3)
                                            }
                                            .frame(width: 40, height: 40)
                                            .clipShape(Circle())
                                        } else {
                                            Image(systemName: "person.circle.fill")
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .foregroundColor(Color.theme.accent.opacity(0.5))
                                                .frame(width: 40, height: 40)
                                        }
                                        
                                        // User info
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(friend.displayName ?? "@\(friend.username)")
                                                .font(AppTypography.subhead())
                                                .foregroundColor(Color.theme.text)
                                            
                                            if friend.displayName != nil {
                                                Text("@\(friend.username)")
                                                    .font(AppTypography.caption1())
                                                    .foregroundColor(Color.theme.subtext)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "plus.circle")
                                            .foregroundColor(Color.theme.accent)
                                    }
                                }
                            }
                        }
                        .listStyle(PlainListStyle())
                        .background(Color.theme.background)
                    }
                }
                .padding(.top)
                .navigationTitle("Invite Friends")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Cancel") {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
            }
        }
        .onAppear {
            viewModel.loadFriends()
        }
    }
}

@MainActor
class InviteFriendViewModel: ObservableObject {
    @Published var friends: [Friend] = []
    @Published var filteredFriends: [Friend] = []
    @Published var searchText = ""
    @Published var isLoading = false

    private let friendService: FriendService

    init() {
        self.friendService = FriendService.shared
    }
    
    func loadFriends() {
        isLoading = true
        
        // Use the friends from FriendService - access on main actor
        Task { @MainActor in
            self.friends = friendService.friends
            self.filteredFriends = friends
            self.isLoading = false
        }
    }
    
    func searchFriends() {
        if searchText.isEmpty {
            filteredFriends = friends
        } else {
            filteredFriends = friends.filter { friend in
                let nameMatch = friend.displayName?.localizedCaseInsensitiveContains(searchText) ?? false
                let usernameMatch = friend.username.localizedCaseInsensitiveContains(searchText)
                return nameMatch || usernameMatch
            }
        }
    }
} 