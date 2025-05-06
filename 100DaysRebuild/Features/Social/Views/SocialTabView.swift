import SwiftUI

struct SocialTabView: View {
    @StateObject private var viewModel = SocialViewModel()
    @EnvironmentObject var subscriptionService: SubscriptionService
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    friendsSection
                    communityChallengesSection
                }
                .padding(.vertical)
            }
            .background(Color.theme.background.ignoresSafeArea())
            .navigationTitle("Social")
        }
    }
    
    private var friendsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Friends")
                .font(.title3)
                .foregroundColor(.theme.text)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(viewModel.friends) { friend in
                        FriendCard(friend: friend)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
    
    private var communityChallengesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Community Challenges")
                .font(.title3)
                .foregroundColor(.theme.text)
            
            ForEach(viewModel.state.communityChallenges) { challenge in
                CommunityChallengeCard(challenge: challenge)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.theme.surface)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal)
    }
}

struct FriendCard: View {
    let friend: Friend
    
    var body: some View {
        VStack(spacing: 8) {
            profileImage
            
            Text(friend.name)
                .font(.subheadline)
                .foregroundColor(.theme.text)
            Text("\(friend.streak) days")
                .font(.caption)
                .foregroundColor(.theme.subtext)
        }
        .frame(width: 80)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.theme.surface)
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
    
    private var profileImage: some View {
        Group {
            if let imageURL = friend.profileImageURL {
                AsyncImage(url: imageURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 40))
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.theme.accent)
            }
        }
    }
}

struct CommunityChallengeCard: View {
    let challenge: CommunityChallenge
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(challenge.title)
                .font(.headline)
                .foregroundColor(.theme.text)
            
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundColor(.theme.accent)
                Text("\(challenge.participants.count) participants")
                    .font(.subheadline)
                    .foregroundColor(.theme.subtext)
            }
            
            progressView
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.theme.surface)
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
    
    private var progressView: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .foregroundColor(Color.theme.surface)
                    .frame(height: 6)
                    .cornerRadius(3)
                
                Rectangle()
                    .foregroundColor(Color.theme.accent)
                    .frame(width: max(0, min(geometry.size.width, geometry.size.width * 0.5)), height: 6) // Calculate 50% progress for now
                    .cornerRadius(3)
            }
        }
        .frame(height: 6)
        .padding(.vertical, 4)
    }
}

struct SocialTabView_Previews: PreviewProvider {
    static var previews: some View {
        SocialTabView()
            .environmentObject(SubscriptionService.shared)
    }
} 