import SwiftUI

struct SuggestedFriendCard: View {
    let suggestion: UserSuggestion
    let onAddFriend: () -> Void
    let isAtFriendLimit: Bool
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: AppSpacing.s) {
            // Avatar
            avatarView
            
            // User Info
            VStack(spacing: 4) {
                Text("@\(suggestion.username)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.theme.text)
                    .lineLimit(1)
                
                if let displayName = suggestion.displayName {
                    Text(displayName)
                        .font(.caption)
                        .foregroundColor(Color.theme.subtext)
                        .lineLimit(1)
                }
                
                // Suggestion reason
                suggestionReasonView
            }
            
            // Add Friend Button
            Button(action: onAddFriend) {
                HStack(spacing: 4) {
                    Image(systemName: isAtFriendLimit ? "crown.fill" : "person.badge.plus")
                        .font(.system(size: 12, weight: .semibold))
                    
                    Text(isAtFriendLimit ? "Upgrade" : "Add")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .foregroundColor(isAtFriendLimit ? .orange : Color.theme.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isAtFriendLimit ? Color.orange.opacity(0.1) : Color.theme.accent.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isAtFriendLimit ? .orange : Color.theme.accent, lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(AppSpacing.s)
        .frame(width: 140)
        .background(
            AppComponents.Card {
                VStack(spacing: AppSpacing.s) {
                    // Avatar
                    avatarView

                    // User Info
                    VStack(spacing: 4) {
                        Text("@\(suggestion.username)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(Color.theme.text)
                            .lineLimit(1)

                        if let displayName = suggestion.displayName {
                            Text(displayName)
                                .font(.caption)
                                .foregroundColor(Color.theme.subtext)
                                .lineLimit(1)
                        }

                        // Suggestion reason
                        suggestionReasonView
                    }

                    // Add Friend Button
                    Button(action: onAddFriend) {
                        HStack(spacing: 4) {
                            Image(systemName: isAtFriendLimit ? "crown.fill" : "person.badge.plus")
                                .font(.system(size: 12, weight: .semibold))

                            Text(isAtFriendLimit ? "Upgrade" : "Add")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(isAtFriendLimit ? .orange : Color.theme.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isAtFriendLimit ? Color.orange.opacity(0.1) : Color.theme.accent.opacity(0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isAtFriendLimit ? .orange : Color.theme.accent, lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(AppSpacing.s)
            }
        )
    }
    
    private var avatarView: some View {
        Group {
            if let photoURL = suggestion.photoURL {
                AsyncImage(url: photoURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    defaultAvatarView
                }
            } else {
                defaultAvatarView
            }
        }
        .frame(width: 50, height: 50)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.theme.accent.opacity(0.3), lineWidth: 2)
        )
    }
    
    private var defaultAvatarView: some View {
        Circle()
            .fill(Color.theme.accent.opacity(0.2))
            .overlay(
                Text(String(suggestion.username.prefix(1)).uppercased())
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.theme.accent)
            )
    }
    
    private var suggestionReasonView: some View {
        HStack(spacing: 2) {
            suggestionIcon
            Text(suggestionText)
                .font(.system(size: 10))
                .foregroundColor(Color.theme.subtext)
        }
    }
    
    private var suggestionIcon: some View {
        Group {
            switch suggestion.suggestionType {
            case .contactMatch:
                Image(systemName: "person.crop.circle.fill.badge.checkmark")
                    .foregroundColor(.green)
            case .mutualFriend:
                Image(systemName: "person.2.fill")
                    .foregroundColor(.blue)
            case .similarChallenge:
                Image(systemName: "flag.fill")
                    .foregroundColor(.orange)
            case .recentlyActive:
                Image(systemName: "clock.fill")
                    .foregroundColor(.purple)
            }
        }
        .font(.system(size: 8))
    }
    
    private var suggestionText: String {
        switch suggestion.suggestionType {
        case .contactMatch:
            return "From contacts"
        case .mutualFriend:
            return "\(suggestion.mutualFriends) mutual"
        case .similarChallenge:
            return "Similar goals"
        case .recentlyActive:
            return "Recently active"
        }
    }
}

#Preview {
    HStack {
        SuggestedFriendCard(
            suggestion: UserSuggestion(
                id: "1",
                username: "sarah_runs",
                displayName: "Sarah Johnson",
                photoURL: nil,
                suggestionType: .mutualFriend,
                mutualFriends: 3
            ),
            onAddFriend: {},
            isAtFriendLimit: false
        )
        
        SuggestedFriendCard(
            suggestion: UserSuggestion(
                id: "2",
                username: "mike_fitness",
                displayName: nil,
                photoURL: nil,
                suggestionType: .contactMatch,
                mutualFriends: 0
            ),
            onAddFriend: {},
            isAtFriendLimit: true
        )
    }
    .padding()
    .background(Color.theme.background)
} 