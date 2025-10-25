import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Combine

struct SocialFeedView: View {
    @StateObject private var viewModel = SocialFeedViewModel()
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @Environment(\.colorScheme) private var colorScheme
    @State private var showUsernameSheet: Bool = false
    
    var body: some View {
        ZStack {
            Color.theme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Content
                if viewModel.isLoading && viewModel.feedItems.isEmpty {
                    loadingView
                } else if viewModel.feedItems.isEmpty {
                    emptyStateView
                } else {
                    feedListView
                }
            }
        }
        .navigationTitle("Activity")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.startListening()
            // Ensure friend listeners are active so outgoingRequests are available
            Task {
                await FriendService.shared.startListening()
            }
        }
        .onDisappear {
            viewModel.stopListening()
        }
        .sheet(isPresented: $showUsernameSheet) {
            UsernameSetupView()
                .environmentObject(UserSession.shared)
        }
        .alert(isPresented: $viewModel.showError) {
            Alert(
                title: Text("Error"),
                message: Text(viewModel.errorMessage ?? "An unknown error occurred"),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack {
            Text("Activity Feed")
                .font(.largeTitle)
                .bold()
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.theme.accent, Color.theme.accent.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            Spacer()
            // Quick access buttons to simplify social discovery
            HStack(spacing: 12) {
                NavigationLink(destination: FriendsView()) {
                    Label("Add Friend", systemImage: "person.badge.plus")
                        .font(.subheadline)
                }

                Button(action: {
                    showUsernameSheet = true
                }) {
                    Label("Claim Username", systemImage: "person.crop.circle.badge.checkmark")
                        .font(.subheadline)
                }

                NavigationLink(destination: ChallengeInvitationsView()) {
                    Image(systemName: "envelope.open.fill")
                        .foregroundColor(.theme.accent)
                }

                Button(action: {
                    Task {
                        await viewModel.refreshFeed()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: AppSpacing.iconSizeMedium, weight: .semibold))
                        .foregroundColor(.theme.accent)
                }
                .buttonStyle(AppScaleButtonStyle())
                .disabled(viewModel.isLoading)
            }
        }
        .padding(.horizontal, AppSpacing.screenHorizontalPadding)
        .padding(.top, AppSpacing.m)
        .padding(.bottom, AppSpacing.s)
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: AppSpacing.m) {
            ProgressView()
                .scaleEffect(1.5)
                .padding()
            
            Text("Loading activity...")
                .font(.subheadline)
                .foregroundColor(.theme.subtext)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        ScrollView {
            VStack(spacing: AppSpacing.l) {
                Spacer()
                
                Image(systemName: "person.2.circle")
                    .font(.system(size: 60))
                    .foregroundColor(Color.theme.accent.opacity(0.7))
                    .padding(.top, 60)
                
                VStack(spacing: AppSpacing.s) {
                    Text("No Activity Yet")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.theme.text)
                    
                    Text("Connect with friends to see their progress and milestones here!")
                        .font(.subheadline)
                        .foregroundColor(.theme.subtext)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.xxl)
                }
                
                AppComponents.Card {
                    VStack(spacing: AppSpacing.s) {
                        Text("Get Started")
                            .font(.headline)
                            .foregroundColor(.theme.text)
                        
                        Text("Add friends to see their check-ins and celebrate milestones together")
                            .font(.subheadline)
                            .foregroundColor(.theme.subtext)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                
                Spacer()
            }
        }
    }
    
    // MARK: - Feed List
    private var feedListView: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.s) {
                ForEach(viewModel.feedItems) { item in
                    SocialFeedItemView(
                        item: item,
                        onReaction: { emoji in
                            Task {
                                await viewModel.addReaction(to: item.id, emoji: emoji)
                            }
                        }
                    )
                }
                
                // Loading indicator at bottom
                if viewModel.isLoading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading more...")
                            .font(.caption)
                            .foregroundColor(.theme.subtext)
                    }
                    .padding()
                }
                
                Color.clear.frame(height: 100) // Bottom padding
            }
            .padding(.horizontal, AppSpacing.screenHorizontalPadding)
        }
        .refreshable {
            await viewModel.refreshFeed()
        }
    }
}

// MARK: - Feed Item View
struct SocialFeedItemView: View {
    let item: SocialFeedItem
    let onReaction: (String) -> Void
    
    @State private var showReactions = false
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var friendService = FriendService.shared
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @State private var isSendingRequest = false
    @State private var actionErrorMessage: String?
    @State private var optimisticRequested: Bool = false
    @State private var usernameClaimed: Bool? = nil // nil = unknown/loading, false = not claimed
    @State private var showingCancelConfirmation: Bool = false
    @State private var cancellingRequestId: String? = nil
    
    var body: some View {
        AppComponents.GlassCard {
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                // Header with user info
                HStack(spacing: AppSpacing.s) {
                    // Profile image and user info wrapped in NavigationLink
                    NavigationLink(destination: FriendProfileView(friendId: item.userId, friendUsername: item.username)) {
                        HStack(spacing: AppSpacing.s) {
                            // Profile image placeholder
                            Circle()
                                .fill(Color.theme.accent.opacity(0.2))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Text(String(item.username.prefix(1)).uppercased())
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.theme.accent)
                                )
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("@\(item.username)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.theme.text)
                                
                                Text(item.timestamp.timeAgoDisplay())
                                    .font(.caption)
                                    .foregroundColor(.theme.subtext)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()

                    // Friend action button (only for other users)
                    if item.userId != Auth.auth().currentUser?.uid {
                        Group {
                            // Check username claimed state
                            if usernameClaimed == nil {
                                // Show a subtle loading indicator while we check
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .padding(6)
                            } else if usernameClaimed == false {
                                // Username not claimed — show disabled indicator
                                Text("Unavailable")
                                    .font(.caption2)
                                    .foregroundColor(.theme.subtext)
                                    .padding(8)
                                    .background(RoundedRectangle(cornerRadius: 8).stroke(Color.theme.subtext.opacity(0.3)))
                            } else {
                            if friendService.friends.contains(where: { $0.id == item.userId }) {
                                Text("Friend")
                                    .font(.caption2)
                                    .foregroundColor(.theme.success)
                                    .padding(8)
                                    .background(RoundedRectangle(cornerRadius: 8).stroke(Color.theme.success))
                            } else if optimisticRequested || friendService.outgoingRequests.contains(where: { $0.toUserId == item.userId }) {
                                // Make Requested tappable to allow cancelling the outgoing request
                                Button(action: {
                                    // Find the outgoing request id if available
                                    if let req = friendService.outgoingRequests.first(where: { $0.toUserId == item.userId }) {
                                        cancellingRequestId = req.id
                                    } else {
                                        // No request id available yet; use nil and still show confirmation
                                        cancellingRequestId = nil
                                    }
                                    showingCancelConfirmation = true
                                }) {
                                    Text("Requested")
                                        .font(.caption2)
                                        .foregroundColor(.white)
                                        .padding(8)
                                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.theme.subtext))
                                }
                                .accessibilityLabel("Requested. Double tap to cancel friend request")
                            } else {
                                Button(action: {
                                    Task {
                                        // Optimistic UI: show requested immediately
                                        optimisticRequested = true
                                        isSendingRequest = true
                                        do {
                                            // Respect friend limit and show paywall if needed
                                            let canAdd = try await friendService.canAddMoreFriends()
                                            if !canAdd {
                                                // Revert optimistic state and trigger paywall
                                                optimisticRequested = false
                                                await MainActor.run {
                                                    subscriptionService.showPaywall = true
                                                }
                                                isSendingRequest = false
                                                return
                                            }

                                            try await friendService.sendFriendRequest(to: item.username)
                                            // on success, leave optimisticRequested true until listener updates
                                        } catch {
                                            // Revert optimistic state on failure
                                            optimisticRequested = false
                                            actionErrorMessage = error.localizedDescription
                                        }
                                        isSendingRequest = false
                                    }
                                }) {
                                    if isSendingRequest {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                            .padding(6)
                                    } else {
                                        Text("Add")
                                            .font(.caption2)
                                            .fontWeight(.semibold)
                                            .padding(8)
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.theme.accent)
                                )
                                .foregroundColor(.white)
                                .accessibilityLabel("Add friend")
                                .alert(isPresented: Binding<Bool>(
                                    get: { actionErrorMessage != nil },
                                    set: { if !$0 { actionErrorMessage = nil } }
                                )) {
                                    Alert(
                                        title: Text("Error"),
                                        message: Text(actionErrorMessage ?? "An error occurred"),
                                        dismissButton: .default(Text("OK"), action: { actionErrorMessage = nil })
                                    )
                                }
                            }
                            }
                        }
                        
                        // Cancel confirmation alert
                        .alert(isPresented: $showingCancelConfirmation) {
                            Alert(
                                title: Text("Cancel Request?"),
                                message: Text("Are you sure you want to cancel this friend request?"),
                                primaryButton: .destructive(Text("Cancel Request")) {
                                    Task {
                                        guard let id = cancellingRequestId else { return }
                                        do {
                                            try await FriendService.shared.cancelOutgoingRequest(requestId: id)
                                        } catch {
                                            actionErrorMessage = error.localizedDescription
                                        }
                                        cancellingRequestId = nil
                                    }
                                },
                                secondaryButton: .cancel()
                            )
                        }
                    }
                    
                    // Activity type badge
                    AppComponents.Badge(
                        text: item.type.displayName,
                        color: item.type.color,
                        style: .filled
                    )
                }
                .onAppear {
                    // Only check once per cell
                    if usernameClaimed == nil {
                        Task {
                            do {
                                let claimed = try await FriendService.shared.isUsernameClaimed(item.username)
                                usernameClaimed = claimed
                            } catch {
                                // If the check fails, default to true so Add button remains available
                                usernameClaimed = true
                            }
                        }
                    }
                }
                
                // Activity description
                Text(item.description)
                    .font(.subheadline)
                    .foregroundColor(.theme.text)
                    .lineSpacing(2)
                
                // Challenge info if available
                if let challengeTitle = item.challengeTitle {
                    HStack {
                        Image(systemName: "flag.fill")
                            .font(.caption)
                            .foregroundColor(.theme.accent)
                        
                        Text(challengeTitle)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.theme.accent)
                    }
                    .padding(.horizontal, AppSpacing.s)
                    .padding(.vertical, AppSpacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: AppSpacing.xs)
                            .fill(Color.theme.accent.opacity(0.1))
                    )
                }
                
                // Reactions section
                HStack {
                    if !item.reactions.isEmpty {
                        ForEach(Array(item.reactions.keys.sorted()), id: \.self) { emoji in
                            reactionButton(emoji: emoji, count: item.reactions[emoji] ?? 0)
                        }
                    }
                    
                    Spacer()
                    
                    // Add reaction button
                    Button(action: {
                        withAnimation(.spring()) {
                            showReactions.toggle()
                        }
                    }) {
                        Image(systemName: showReactions ? "heart.fill" : "heart")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.theme.accent)
                    }
                    .buttonStyle(AppScaleButtonStyle())
                }
                
                // Reaction picker
                if showReactions {
                    HStack(spacing: AppSpacing.s) {
                        ForEach(["🔥", "💪", "❤️", "🎉", "👏"], id: \.self) { emoji in
                            Button(action: {
                                onReaction(emoji)
                                withAnimation(.spring()) {
                                    showReactions = false
                                }
                            }) {
                                Text(emoji)
                                    .font(.title2)
                                    .scaleEffect(1.2)
                            }
                            .buttonStyle(AppScaleButtonStyle())
                        }
                        
                        Spacer()
                    }
                    .padding(.top, AppSpacing.xs)
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .animation(.spring(response: 0.4), value: showReactions)
    }
    
    private func reactionButton(emoji: String, count: Int) -> some View {
        HStack(spacing: 4) {
            Text(emoji)
                .font(.caption)
            
            Text("\(count)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.theme.subtext)
        }
        .padding(.horizontal, AppSpacing.xs)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.theme.surface.opacity(0.7))
        )
    }
}

// MARK: - Preview
struct SocialFeedView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SocialFeedView()
                .environmentObject(SubscriptionService.shared)
        }
        .preferredColorScheme(.dark)
    }
} 