import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct ExploreChallengesView: View {
    @StateObject private var viewModel = ExploreChallengesViewModel()
    @EnvironmentObject private var subscriptionStore: SubscriptionStore
    @State private var searchText = ""
    @State private var selectedFilter: ChallengeFilter = .all
    
    enum ChallengeFilter: String, CaseIterable {
        case all = "All"
        case group = "Group"
        case trending = "Popular"
    }
    
    var filteredChallenges: [GroupChallenge] {
        viewModel.publicChallenges.filter { challenge in
            let matchesSearch = searchText.isEmpty || 
                               challenge.title.localizedCaseInsensitiveContains(searchText) ||
                               challenge.description.localizedCaseInsensitiveContains(searchText)
            
            let matchesFilter: Bool
            switch selectedFilter {
            case .all:
                matchesFilter = true
            case .group:
                matchesFilter = true // All challenges in explore are group challenges
            case .trending:
                matchesFilter = true // TODO: Add popularity logic
            }
            
            return matchesSearch && matchesFilter
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.theme.subtext)
                    
                    TextField("Search public challenges...", text: $searchText)
                        .font(AppTypography.body())
                        .foregroundColor(.theme.text)
                }
                .padding(.horizontal, AppSpacing.m)
                .padding(.vertical, AppSpacing.s)
                .background(Color.theme.surface)
                .cornerRadius(AppSpacing.cardCornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                        .stroke(Color.theme.border.opacity(0.5), lineWidth: 1)
                )
                .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                .padding(.top, AppSpacing.m)
                
                // Content
                if viewModel.isLoading {
                    loadingView
                } else if filteredChallenges.isEmpty {
                    emptyStateView
                } else {
                    challengesList
                }
            }
            .background(Color.theme.background.ignoresSafeArea())
            .navigationTitle("Explore Challenges")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await viewModel.loadPublicChallenges()
            }
            .onAppear {
                Task {
                    await viewModel.loadPublicChallenges()
                }
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage)
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: AppSpacing.m) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.theme.accent)
            
            Text("Loading public challenges...")
                .font(AppTypography.headline())
                .foregroundColor(.theme.text)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.theme.background)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: AppSpacing.m) {
            Image(systemName: "globe")
                .font(AppTypography.font(size: 60, weight: .bold))
                .foregroundColor(.theme.accent.opacity(0.7))
            
            Text("No Public Challenges")
                .font(AppTypography.title2())
                .bold()
                .foregroundColor(.theme.text)
            
            Text("Be the first to create a public challenge for others to join!")
                .font(AppTypography.body())
                .multilineTextAlignment(.center)
                .foregroundColor(.theme.subtext)
                .padding(.horizontal, AppSpacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.theme.background)
    }
    
    private var challengesList: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.m) {
                ForEach(filteredChallenges) { challenge in
                    PublicChallengeCard(challenge: challenge)
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontalPadding)
            .padding(.top, AppSpacing.m)
        }
    }
}

struct PublicChallengeCard: View {
    let challenge: GroupChallenge
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            // Title and description
            VStack(alignment: .leading, spacing: 4) {
                Text(challenge.title)
                    .font(AppTypography.headline())
                    .foregroundColor(.theme.text)
                    .multilineTextAlignment(.leading)
                
                if !challenge.description.isEmpty {
                    Text(challenge.description)
                        .font(AppTypography.subhead())
                        .foregroundColor(.theme.subtext)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            
            // Creator and stats
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "person.circle")
                        .foregroundColor(.theme.subtext)
                    Text("@\(challenge.creatorUsername)")
                        .font(AppTypography.caption1())
                        .foregroundColor(.theme.subtext)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .foregroundColor(.theme.subtext)
                    Text(formatRelativeDate(challenge.createdAt))
                        .font(AppTypography.caption1())
                        .foregroundColor(.theme.subtext)
                }
            }
        }
        .padding(AppSpacing.m)
        .background(Color.theme.surface)
        .cornerRadius(AppSpacing.cardCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                .stroke(Color.theme.border.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: Color.theme.shadow.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private func formatRelativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

@MainActor
class ExploreChallengesViewModel: ObservableObject {
    @Published var publicChallenges: [GroupChallenge] = []
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""
    
    private let firestore = Firestore.firestore()
    
    func loadPublicChallenges() async {
        isLoading = true
        errorMessage = ""
        
        do {
            let snapshot = try await firestore
                .collection("groupChallenges")
                .whereField("isPublic", isEqualTo: true)
                .order(by: "createdAt", descending: true)
                .limit(to: 50)
                .getDocuments()
            
            let challenges = snapshot.documents.compactMap { GroupChallenge(from: $0) }
            
            publicChallenges = challenges
            
        } catch {
            errorMessage = "Failed to load challenges: \(error.localizedDescription)"
            showError = true
        }
        
        isLoading = false
    }
}
