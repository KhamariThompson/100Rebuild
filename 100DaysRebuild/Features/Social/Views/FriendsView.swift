import SwiftUI
import Combine

struct FriendsView: View {
    @StateObject private var viewModel = SocialViewModel()
    @State private var searchText = ""
    @State private var showingSearchResults = false
    @State private var isSearching = false
    @State private var selectedTab = 0
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @StateObject private var friendSuggestionEngine = FriendSuggestionEngine.shared
    @StateObject private var contactSyncService = ContactSyncService.shared
    @StateObject private var friendService = FriendService.shared
    @State private var searchResults: [UserProfileResult] = []
    @State private var isSearchingLocal = false
    
    var body: some View {
        ZStack {
                Color.theme.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Custom header with tabs
                    VStack(spacing: 16) {
                        // Search bar
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(Color.theme.subtext)
                            
                            TextField("Search users", text: $searchText)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .onChange(of: searchText) { newValue in
                                    Task {
                                        if newValue.isEmpty {
                                            searchResults = []
                                            isSearchingLocal = false
                                        } else if newValue.count >= 3 {
                                            isSearchingLocal = true
                                            do {
                                                searchResults = try await friendService.searchUsers(query: newValue)
                                            } catch {
                                                searchResults = []
                                            }
                                            isSearchingLocal = false
                                        }
                                    }
                                }
                            
                            if !searchText.isEmpty {
                                Button(action: {
                                    // Clear local search state instead of calling a missing viewModel API
                                    searchText = ""
                                    searchResults = []
                                    isSearchingLocal = false
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
                        
                        // Tab selector
                        Picker("Friend Type", selection: $selectedTab) {
                            Text("Friends").tag(0)
                            Text("Requests").tag(1)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal)
                    }
                    .padding(.top)
                    .background(Color.theme.background)
                    
                    // Friend Suggestions Section
                    if !friendSuggestionEngine.suggestions.isEmpty {
                        AppComponents.Card {
                            VStack(alignment: .leading, spacing: AppSpacing.s) {
                                HStack {
                                    Text("Suggested Friends")
                                        .font(AppTypography.headline())
                                        .foregroundColor(Color.theme.text)
                                    
                                    Spacer()
                                    
                                    if friendSuggestionEngine.isLoading {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    }
                                }
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    LazyHStack(spacing: AppSpacing.s) {
                                        ForEach(friendSuggestionEngine.suggestions) { suggestion in
                                            SuggestedFriendCard(
                                                suggestion: suggestion,
                                                onAddFriend: {
                                                    Task {
                                                        try? await friendService.sendFriendRequest(to: suggestion.username)
                                                    }
                                                },
                                                isAtFriendLimit: false
                                            )
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            .padding(.vertical, AppSpacing.s)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, AppSpacing.m)
                    }
                    
                    // Content based on selected tab and search
                                if !searchText.isEmpty {
                        searchResultsView
                    } else {
                        TabView(selection: $selectedTab) {
                            // Friends tab
                            friendsListView
                                .tag(0)
                            
                            // Requests tab
                            requestsView
                                .tag(1)
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        .animation(.easeInOut, value: selectedTab)
                    }
                }
            }
            .navigationTitle("Friends")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // Start FriendService listeners instead of missing viewModel APIs
                friendService.startListening()
                Task {
                    await friendSuggestionEngine.generateSuggestions()
                }
            }
            .alert(isPresented: Binding(get: { friendService.errorMessage != nil }, set: { newValue in if !newValue { friendService.errorMessage = nil } })) {
                Alert(
                    title: Text("Error"),
                    message: Text(friendService.errorMessage ?? "An error occurred"),
                    dismissButton: .default(Text("OK")) {
                        friendService.errorMessage = nil
                    }
                )
            }
    }
    
    // Search results view
    private var searchResultsView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if isSearchingLocal {
                    ProgressView()
                        .padding()
                } else if searchResults.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.fill.questionmark")
                            .font(AppTypography.display())
                            .foregroundColor(Color.theme.subtext)
                            .padding(.bottom, 8)
                        
                        Text("No users found")
                            .font(AppTypography.headline())
                            .foregroundColor(Color.theme.text)
                        
                        Text("Try a different username")
                            .font(AppTypography.subhead())
                            .foregroundColor(Color.theme.subtext)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else {
                    ForEach(searchResults) { user in
                        // Local computed flags use FriendService state to avoid missing viewModel helpers
                        let isSent = friendService.outgoingRequests.contains(where: { $0.toUserId == user.id })
                        let isFriend = friendService.friends.contains(where: { $0.id == user.id })

                        SearchResultRow(
                            user: user,
                            onAddFriend: {
                                Task {
                                    try? await friendService.sendFriendRequest(to: user.username)
                                }
                            },
                            isFriendRequestSent: isSent,
                            isFriend: isFriend,
                            isAtFriendLimit: false
                        )
                    }
                }
            }
            .padding(.top, 8)
        }
    }
    
    // Friends list view
    private var friendsListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if viewModel.isLoading {
                    ProgressView()
                        .padding()
                } else if friendService.friends.isEmpty {
                    AppComponents.Card {
                        emptyFriendsView
                    }
                } else {
                    ForEach(friendService.friends) { friend in
                        FriendRow(
                            friend: friend,
                            onRemove: {
                                Task {
                                    try? await FriendService.shared.removeFriend(friend.id)
                                }
                            }
                        )
                    }
                }
            }
            .padding(.top, 8)
        }
    }
    
    // Empty friends view
    private var emptyFriendsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3.sequence.fill")
                .font(AppTypography.display())
                .foregroundColor(Color.theme.accent.opacity(0.7))
                .padding(.bottom, 8)
            
            Text("No Friends Yet")
                .font(AppTypography.title2())
                .fontWeight(.bold)
                .foregroundColor(Color.theme.text)
            
            Text("Search for users by username and send friend requests to connect.")
                .font(AppTypography.subhead())
                .foregroundColor(Color.theme.subtext)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
    
    // Friend requests view
    private var requestsView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if viewModel.isLoading {
                    ProgressView()
                        .padding()
                } else if friendService.incomingRequests.isEmpty {
                    AppComponents.Card {
                        emptyRequestsView
                    }
                } else {
                    ForEach(friendService.incomingRequests) { request in
                        FriendRequestRow(
                            request: request,
                            onAccept: {
                                Task {
                                    try? await FriendService.shared.acceptFriendRequest(request.id)
                                }
                            },
                            onReject: {
                                Task {
                                    try? await FriendService.shared.rejectFriendRequest(request.id)
                                }
                            }
                        )
                    }
                }
            }
            .padding(.top, 8)
        }
    }
    
    // Empty requests view
    private var emptyRequestsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(AppTypography.display())
                .foregroundColor(Color.theme.accent.opacity(0.7))
                .padding(.bottom, 8)
            
            Text("No Friend Requests")
                .font(AppTypography.title2())
                .fontWeight(.bold)
                .foregroundColor(Color.theme.text)
            
            Text("When someone sends you a friend request, it will appear here.")
                .font(AppTypography.subhead())
                .foregroundColor(Color.theme.subtext)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

// MARK: - Supporting Views

struct SearchResultRow: View {
    let user: UserProfileResult
    let onAddFriend: () -> Void
    let isFriendRequestSent: Bool
    let isFriend: Bool
    let isAtFriendLimit: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile image
            if let photoURL = user.photoURL {
                AsyncImage(url: photoURL) { image in
                    image.resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray.opacity(0.3)
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .foregroundColor(Color.theme.accent.opacity(0.5))
                    .frame(width: 50, height: 50)
            }
            
            // User info
            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName ?? "@\(user.username)")
                    .font(AppTypography.headline())
                    .foregroundColor(Color.theme.text)
                
                if user.displayName != nil {
                    Text("@\(user.username)")
                        .font(AppTypography.subhead())
                        .foregroundColor(Color.theme.subtext)
                }
            }
            
            Spacer()
            
            // Add friend button
            if isFriend {
                Text("Friend")
                    .font(AppTypography.subhead())
                    .foregroundColor(Color.theme.success)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.theme.success, lineWidth: 1)
                    )
            } else if isFriendRequestSent {
                Text("Requested")
                    .font(AppTypography.subhead())
                    .foregroundColor(Color.theme.subtext)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.theme.subtext, lineWidth: 1)
                    )
            } else if isAtFriendLimit {
                Button(action: onAddFriend) {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(AppTypography.caption1())
                        
                        Text("Upgrade")
                            .font(AppTypography.subhead())
                    }
                    .foregroundColor(Color.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.orange, lineWidth: 1)
                    )
                }
            } else {
                Button(action: onAddFriend) {
                    Text("Add")
                        .font(AppTypography.subhead())
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
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

struct FriendRow: View {
    let friend: Friend
    let onRemove: () -> Void
    @State private var showingRemoveAlert = false
    @State private var showInviteSheet: Bool = false
    
    var body: some View {
        HStack {
            // Profile image and user info wrapped in NavigationLink
            NavigationLink(destination: FriendProfileView(friendId: friend.id, friendUsername: friend.username)) {
                HStack {
                    // Profile image
                    if let photoURL = friend.photoURL {
                        AsyncImage(url: photoURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Color.gray.opacity(0.3)
                        }
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                    } else {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .foregroundColor(Color.theme.accent.opacity(0.5))
                            .frame(width: 50, height: 50)
                    }
                    
                    // User info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(friend.displayName ?? "@\(friend.username)")
                            .font(AppTypography.headline())
                            .foregroundColor(Color.theme.text)
                        
                        if friend.displayName != nil {
                            Text("@\(friend.username)")
                                .font(AppTypography.subhead())
                                .foregroundColor(Color.theme.subtext)
                        }
                    }
                    
                    Spacer()
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Remove button (outside NavigationLink)
            Button(action: {
                showingRemoveAlert = true
            }) {
                Image(systemName: "person.badge.minus")
                    .foregroundColor(Color.theme.error)
                    .padding(8)
                    .background(
                        Circle()
                            .fill(Color.theme.surface)
                    )
            }
            
            // Invite button
            Button(action: {
                showInviteSheet = true
            }) {
                Image(systemName: "paperplane")
                    .foregroundColor(Color.theme.accent)
                    .padding(8)
                    .background(
                        Circle()
                            .fill(Color.theme.surface)
                    )
            }
            .sheet(isPresented: $showInviteSheet) {
                SelectChallengeAndInviteView(friend: friend)
            }
        }
        .padding()
        .background(Color.theme.background)
        .contentShape(Rectangle())
        .alert(isPresented: $showingRemoveAlert) {
            Alert(
                title: Text("Remove Friend"),
                message: Text("Are you sure you want to remove this friend?"),
                primaryButton: .destructive(Text("Remove")) {
                    onRemove()
                },
                secondaryButton: .cancel()
            )
        }
    }
}

struct FriendRequestRow: View {
    let request: FriendRequest
    let onAccept: () -> Void
    let onReject: () -> Void
    
    var body: some View {
        HStack {
            // Profile image
            if let photoURL = request.fromPhotoURL {
                AsyncImage(url: photoURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray.opacity(0.3)
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .foregroundColor(Color.theme.accent.opacity(0.5))
                    .frame(width: 50, height: 50)
            }
            
            // User info
            VStack(alignment: .leading, spacing: 4) {
                Text(request.fromDisplayName ?? "@\(request.fromUsername)")
                    .font(AppTypography.headline())
                    .foregroundColor(Color.theme.text)
                
                if request.fromDisplayName != nil {
                    Text("@\(request.fromUsername)")
                        .font(AppTypography.subhead())
                        .foregroundColor(Color.theme.subtext)
                }
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 12) {
                // Reject button
                Button(action: onReject) {
                    Image(systemName: "xmark")
                        .foregroundColor(Color.theme.error)
                        .padding(8)
                        .background(
                            Circle()
                                .fill(Color.theme.surface)
                        )
                }
                
                // Accept button
                Button(action: onAccept) {
                    Image(systemName: "checkmark")
                        .foregroundColor(Color.theme.success)
                        .padding(8)
                        .background(
                            Circle()
                                .fill(Color.theme.surface)
                        )
                }
            }
        }
        .padding()
        .background(Color.theme.background)
        .contentShape(Rectangle())
    }
}

// Preview
struct FriendsView_Previews: PreviewProvider {
    static var previews: some View {
        FriendsView()
            .environmentObject(SubscriptionStore.shared)
    }
} 