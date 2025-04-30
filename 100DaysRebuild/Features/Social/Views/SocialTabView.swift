import SwiftUI

struct SocialTabView: View {
    @StateObject private var viewModel = SocialViewModel()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Friends Section
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
                    
                    // Community Challenges
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Community Challenges")
                            .font(.title3)
                            .foregroundColor(.theme.text)
                        
                        ForEach(viewModel.communityChallenges) { challenge in
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
                .padding(.vertical)
            }
            .background(Color.theme.background.ignoresSafeArea())
            .navigationTitle("Social")
        }
    }
}

struct FriendCard: View {
    let friend: Friend
    
    var body: some View {
        VStack(spacing: 8) {
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
                Text("\(challenge.participants) participants")
                    .font(.subheadline)
                    .foregroundColor(.theme.subtext)
            }
            
            ProgressView(value: challenge.progress)
                .tint(.theme.accent)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.theme.surface)
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
}

struct SocialTabView_Previews: PreviewProvider {
    static var previews: some View {
        SocialTabView()
    }
} 