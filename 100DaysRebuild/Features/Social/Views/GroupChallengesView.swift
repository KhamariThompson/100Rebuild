import SwiftUI
import FirebaseFirestore
import Combine

struct GroupChallengesView: View {
    @StateObject private var viewModel = GroupChallengesViewModel()
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @State private var showingNewChallengeSheet = false
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack {
                Color.theme.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Custom header with tabs
                    VStack(spacing: 16) {
                        // Title and action button
                        HStack {
                            Text("Group Challenges")
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
                            
                            Button(action: {
                                if subscriptionService.isProUser || viewModel.createdChallenges.count < 1 {
                                    showingNewChallengeSheet = true
                                } else {
                                    subscriptionService.showPaywall = true
                                }
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(AppTypography.title2())
                                    .foregroundColor(Color.theme.accent)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Tab selector
                        Picker("Challenge Type", selection: $selectedTab) {
                            Text("My Challenges").tag(0)
                            Text("Participating").tag(1)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal)
                    }
                    .padding(.top)
                    .background(Color.theme.background)
                    
                    // Content based on selected tab
                    if viewModel.isLoading {
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.5)
                        Spacer()
                    } else {
                        TabView(selection: $selectedTab) {
                            // My Challenges tab
                            createdChallengesView
                                .tag(0)
                            
                            // Participating tab
                            participatingChallengesView
                                .tag(1)
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        .animation(.easeInOut, value: selectedTab)
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                viewModel.loadChallenges()
            }
            .sheet(isPresented: $showingNewChallengeSheet) {
                NewGroupChallengeView { challenge in
                    Task {
                        await viewModel.createChallenge(challenge)
                        showingNewChallengeSheet = false
                    }
                }
                .environmentObject(subscriptionService)
            }
            .alert(isPresented: $viewModel.showError) {
                Alert(
                    title: Text("Error"),
                    message: Text(viewModel.errorMessage ?? "An unknown error occurred"),
                    dismissButton: .default(Text("OK"))
                )
            }
    }
    
    // Created challenges view
    private var createdChallengesView: some View {
        ScrollView {
            if viewModel.createdChallenges.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "flag.fill")
                        .font(AppTypography.font(size: 60, weight: .bold))
                        .foregroundColor(Color.theme.accent.opacity(0.7))
                        .padding(.top, 60)
                    
                    Text("No Challenges Created")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Color.theme.text)
                    
                    Text("Create a challenge and invite your friends to join!")
                        .font(.subheadline)
                        .foregroundColor(Color.theme.subtext)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    Button(action: {
                        if subscriptionService.isProUser || viewModel.createdChallenges.count < 1 {
                            showingNewChallengeSheet = true
                        } else {
                            subscriptionService.showPaywall = true
                        }
                    }) {
                        Text("Create Challenge")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 30)
                            .padding(.vertical, 12)
                            .background(Color.theme.accent)
                            .cornerRadius(10)
                    }
                    .padding(.top, 10)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.createdChallenges) { challenge in
                        NavigationLink(destination: GroupChallengeDetailView(challengeId: challenge.id)) {
                            GroupChallengeCard(challenge: challenge, isCreator: true)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
            }
        }
        .refreshable {
            await viewModel.refreshChallenges()
        }
    }
    
    // Participating challenges view
    private var participatingChallengesView: some View {
        ScrollView {
            if viewModel.participatingChallenges.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "person.3.fill")
                        .font(AppTypography.font(size: 60, weight: .bold))
                        .foregroundColor(Color.theme.accent.opacity(0.7))
                        .padding(.top, 60)
                    
                    Text("Not Participating in Challenges")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Color.theme.text)
                    
                    Text("Join challenges created by your friends or find public challenges to participate in.")
                        .font(.subheadline)
                        .foregroundColor(Color.theme.subtext)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    // We could add a "Browse Public Challenges" button here in the future
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.participatingChallenges) { challenge in
                        NavigationLink(destination: GroupChallengeDetailView(challengeId: challenge.id)) {
                            GroupChallengeCard(challenge: challenge, isCreator: false)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
            }
        }
        .refreshable {
            await viewModel.refreshChallenges()
        }
    }
}

// MARK: - Supporting Views

struct GroupChallengeCard: View {
    let challenge: GroupChallenge
    let isCreator: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with title and privacy indicator
            HStack {
                Text(challenge.title)
                    .font(.headline)
                    .foregroundColor(Color.theme.text)
                    .lineLimit(1)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: challenge.isPublic ? "globe" : "lock")
                        .font(.caption)
                        .foregroundColor(challenge.isPublic ? Color.theme.success : Color.theme.accent)
                    
                    Text(challenge.isPublic ? "Public" : "Private")
                        .font(.caption)
                        .foregroundColor(Color.theme.subtext)
                }
            }
            
            // Description
            if !challenge.description.isEmpty {
                Text(challenge.description)
                    .font(.subheadline)
                    .foregroundColor(Color.theme.subtext)
                    .lineLimit(2)
            }
            
            Divider()
                .background(Color.theme.border)
            
            // Footer with creator and days left
            HStack {
                if isCreator {
                    Label("Created by you", systemImage: "person.fill")
                        .font(.caption)
                        .foregroundColor(Color.theme.subtext)
                } else {
                    Label("By @\(challenge.creatorUsername)", systemImage: "person.fill")
                        .font(.caption)
                        .foregroundColor(Color.theme.subtext)
                }
                
                Spacer()
                
                Text("\(Calendar.current.dateComponents([.day], from: Date(), to: challenge.endDate).day ?? 0) days left")
                    .font(.caption)
                    .foregroundColor(Color.theme.subtext)
            }
            
            // Progress bar
            let progress = calculateProgress(startDate: challenge.startDate, endDate: challenge.endDate)
            ProgressBar(progress: progress)
                .frame(height: 6)
                .padding(.top, 4)
        }
        .padding()
        .background(Color.theme.surface)
        .cornerRadius(12)
        .shadow(color: Color.theme.shadow.opacity(0.1), radius: 5, x: 0, y: 2)
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

// MARK: - New Group Challenge View
struct NewGroupChallengeView: View {
    let onCreateChallenge: (GroupChallengeCreateRequest) -> Void
    
    @State private var title = ""
    @State private var description = ""
    @State private var isPublic = false
    @State private var maxParticipants = 5
    @State private var duration = 100
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var subscriptionService: SubscriptionService
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.theme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Title field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Challenge Title")
                                .font(.headline)
                                .foregroundColor(Color.theme.text)
                            
                            TextField("Enter a title", text: $title)
                                .padding()
                                .background(Color.theme.surface)
                                .cornerRadius(10)
                        }
                        
                        // Description field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.headline)
                                .foregroundColor(Color.theme.text)
                            
                            TextEditor(text: $description)
                                .padding(10)
                                .frame(minHeight: 100)
                                .background(Color.theme.surface)
                                .cornerRadius(10)
                        }
                        
                        // Privacy toggle
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Privacy")
                                .font(.headline)
                                .foregroundColor(Color.theme.text)
                            
                            Toggle(isOn: $isPublic) {
                                HStack {
                                    Image(systemName: isPublic ? "globe" : "lock")
                                        .foregroundColor(isPublic ? Color.theme.success : Color.theme.accent)
                                    
                                    Text(isPublic ? "Public" : "Private")
                                        .foregroundColor(Color.theme.text)
                                }
                            }
                            .padding()
                            .background(Color.theme.surface)
                            .cornerRadius(10)
                            
                            Text(isPublic ? "Anyone can find and join this challenge" : "Only people you invite can join this challenge")
                                .font(.caption)
                                .foregroundColor(Color.theme.subtext)
                                .padding(.horizontal, 4)
                        }
                        
                        // Max participants picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Maximum Participants")
                                .font(.headline)
                                .foregroundColor(Color.theme.text)
                            
                            if !subscriptionService.isProUser {
                                Text("Free users can create challenges with up to 2 participants (1-on-1)")
                                    .font(.caption)
                                    .foregroundColor(Color.theme.subtext)
                                    .padding(.horizontal, 4)
                            }
                            
                            HStack {
                                Text("2")
                                    .foregroundColor(Color.theme.text)
                                
                                Slider(value: Binding(
                                    get: { Double(maxParticipants) },
                                    set: { maxParticipants = Int($0) }
                                ), in: 2...10, step: 1)
                                .disabled(!subscriptionService.isProUser)
                                
                                Text("10")
                                    .foregroundColor(Color.theme.text)
                            }
                            .padding()
                            .background(Color.theme.surface)
                            .cornerRadius(10)
                            
                            Text("Current: \(maxParticipants) participants")
                                .font(.caption)
                                .foregroundColor(Color.theme.subtext)
                                .padding(.horizontal, 4)
                        }
                        
                        // Duration picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Duration")
                                .font(.headline)
                                .foregroundColor(Color.theme.text)
                            
                            HStack {
                                Text("30")
                                    .foregroundColor(Color.theme.text)
                                
                                Slider(value: Binding(
                                    get: { Double(duration) },
                                    set: { duration = Int($0) }
                                ), in: 30...365, step: 1)
                                
                                Text("365")
                                    .foregroundColor(Color.theme.text)
                            }
                            .padding()
                            .background(Color.theme.surface)
                            .cornerRadius(10)
                            
                            Text("Current: \(duration) days")
                                .font(.caption)
                                .foregroundColor(Color.theme.subtext)
                                .padding(.horizontal, 4)
                        }
                        
                        // Create button
                        Button(action: {
                            createChallenge()
                        }) {
                            Text("Create Challenge")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(isFormValid ? Color.theme.accent : Color.gray)
                                .cornerRadius(10)
                        }
                        .disabled(!isFormValid)
                        .padding(.top, 20)
                    }
                    .padding()
                }
            }
            .navigationTitle("New Group Challenge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (subscriptionService.isProUser || maxParticipants <= 2)
    }
    
    private func createChallenge() {
        // Force max participants to 2 for free users
        let finalMaxParticipants = subscriptionService.isProUser ? maxParticipants : 2
        
        // Create the challenge request
        let request = GroupChallengeCreateRequest(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            isPublic: isPublic,
            maxParticipants: finalMaxParticipants,
            durationDays: duration
        )
        
        onCreateChallenge(request)
    }
}

// MARK: - View Model
@MainActor
class GroupChallengesViewModel: ObservableObject {
    @Published var createdChallenges: [GroupChallenge] = []
    @Published var participatingChallenges: [GroupChallenge] = []
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage: String?
    
    private let groupChallengeService = GroupChallengeService.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupNotificationListeners()
    }
    
    func loadChallenges() {
        isLoading = true
        
        // Start listening for challenges
        groupChallengeService.startListening()
        
        // Get challenges from the service
        createdChallenges = groupChallengeService.challenges
        participatingChallenges = groupChallengeService.participatingChallenges
        
        isLoading = false
    }
    
    func refreshChallenges() async {
        isLoading = true
        
        // Stop and restart listening to refresh data
        groupChallengeService.stopListening()
        groupChallengeService.startListening()
        
        // Wait a moment for the listeners to update
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Update our local copies
        createdChallenges = groupChallengeService.challenges
        participatingChallenges = groupChallengeService.participatingChallenges
        
        isLoading = false
    }
    
    func createChallenge(_ request: GroupChallengeCreateRequest) async {
        isLoading = true
        
        do {
            let startDate = Date()
            let endDate = Calendar.current.date(byAdding: .day, value: request.durationDays, to: startDate) ?? Date()
            
            _ = try await groupChallengeService.createGroupChallenge(
                title: request.title,
                description: request.description,
                isPublic: request.isPublic,
                maxParticipants: request.maxParticipants
            )
            
            // The listener will update the challenges list
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            isLoading = false
        }
    }
    
    private func setupNotificationListeners() {
        // Listen for changes to challenges
        NotificationCenter.default.publisher(for: GroupChallengeService.challengesDidUpdateNotification)
            .sink { [weak self] _ in
                guard let self = self else { return }
                
                self.createdChallenges = self.groupChallengeService.challenges
                self.participatingChallenges = self.groupChallengeService.participatingChallenges
            }
            .store(in: &cancellables)
    }
}

// MARK: - Models
struct GroupChallengeCreateRequest {
    let title: String
    let description: String
    let isPublic: Bool
    let maxParticipants: Int
    let durationDays: Int
} 