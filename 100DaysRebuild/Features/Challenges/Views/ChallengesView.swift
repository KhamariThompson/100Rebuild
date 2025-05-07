import SwiftUI

struct ChallengesView: View {
    @StateObject private var viewModel = ChallengesViewModel()
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @EnvironmentObject private var notificationService: NotificationService
    @State private var isShowingEditChallenge = false
    @State private var challengeToEdit: Challenge?
    @State private var isShowingCheckInSheet = false
    @State private var challengeToCheckIn: Challenge?
    
    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .overlay(
                        Text("Loading challenges...")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.challenges.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 70))
                        .foregroundColor(.theme.accent.opacity(0.7))
                        .padding(.bottom, 16)
                    
                    Text("No Challenges Yet")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.theme.text)
                    
                    Text("Start your first 100-day challenge and begin tracking your progress.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.theme.subtext)
                        .padding(.horizontal)
                    
                    Button(action: { viewModel.isShowingNewChallenge = true }) {
                        Text("Create Challenge")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 30)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.theme.accent)
                            )
                    }
                    .padding(.top, 12)
                }
                .padding()
            } else {
                VStack(spacing: 0) {
                    if viewModel.isOffline {
                        OfflineBanner()
                    }
                    
                    List {
                        ForEach(viewModel.challenges) { challenge in
                            ChallengeCardView(
                                challenge: challenge,
                                subscriptionService: subscriptionService,
                                onCheckIn: {
                                    challengeToCheckIn = challenge
                                    isShowingCheckInSheet = true
                                }
                            )
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                challengeToEdit = challenge
                                isShowingEditChallenge = true
                            }
                            .contextMenu {
                                Button(action: {
                                    challengeToEdit = challenge
                                    isShowingEditChallenge = true
                                }) {
                                    Label("Edit", systemImage: "pencil")
                                }
                                
                                Button(action: {
                                    challengeToCheckIn = challenge
                                    isShowingCheckInSheet = true
                                }) {
                                    Label("Check In", systemImage: "checkmark.circle")
                                }
                                
                                Button(role: .destructive, action: {
                                    Task {
                                        await viewModel.archiveChallenge(challenge)
                                    }
                                }) {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
        }
        .navigationTitle("Challenges")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { viewModel.isShowingNewChallenge = true }) {
                    Image(systemName: "plus")
                }
            }
            
            if viewModel.isOffline {
                ToolbarItem(placement: .navigationBarLeading) {
                    Image(systemName: "wifi.slash")
                        .foregroundColor(.yellow)
                }
            }
        }
        .sheet(isPresented: $viewModel.isShowingNewChallenge) {
            NewChallengeSheet(viewModel: viewModel)
                .environmentObject(subscriptionService)
                .environmentObject(notificationService)
        }
        .sheet(isPresented: $isShowingEditChallenge, onDismiss: {
            challengeToEdit = nil
        }) {
            if let challenge = challengeToEdit {
                EditChallengeSheet(viewModel: viewModel, challenge: challenge)
                    .environmentObject(subscriptionService)
                    .environmentObject(notificationService)
            }
        }
        .sheet(isPresented: $isShowingCheckInSheet, onDismiss: {
            challengeToCheckIn = nil
        }) {
            if let challenge = challengeToCheckIn {
                CheckInSheet(viewModel: viewModel, challenge: challenge)
                    .environmentObject(subscriptionService)
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }
        .onAppear {
            Task {
                await viewModel.loadChallenges()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct OfflineBanner: View {
    var body: some View {
        HStack {
            Image(systemName: "wifi.slash")
                .foregroundColor(.yellow)
            Text("You're offline. Some features may be limited.")
                .font(.footnote)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(Color(.systemGray6))
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

struct NewChallengeSheet: View {
    @ObservedObject var viewModel: ChallengesViewModel
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var subscriptionService: SubscriptionService
    @EnvironmentObject var notificationService: NotificationService
    @FocusState private var isTitleFocused: Bool
    
    // Popular challenge suggestions
    private let challengeSuggestions = [
        "Go to the gym",
        "Read 10 pages",
        "No sugar",
        "Code every day",
        "Meditate",
        "Drink a gallon of water"
    ]
    
    var body: some View {
        NavigationView {
            Form {
                if viewModel.isOffline {
                    Section {
                        HStack {
                            Image(systemName: "wifi.slash")
                                .foregroundColor(.yellow)
                            Text("You're offline. Your challenge will be saved locally.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section(header: Text("Challenge Details")) {
                    TextField("Title", text: $viewModel.challengeTitle)
                        .focused($isTitleFocused)
                }
                
                Section(header: Text("Popular Challenge Ideas")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(challengeSuggestions, id: \.self) { suggestion in
                                Button(action: {
                                    viewModel.challengeTitle = suggestion
                                }) {
                                    Text(suggestion)
                                        .font(.footnote)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(Color.theme.surface)
                                                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                                        )
                                        .foregroundColor(.theme.text)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .padding(.horizontal, -16)
                }
                
                Section {
                    Button("Create Challenge") {
                        Task {
                            await viewModel.createChallenge(title: viewModel.challengeTitle)
                            dismiss()
                        }
                    }
                    .disabled(viewModel.challengeTitle.isEmpty)
                }
            }
            .navigationTitle("New Challenge")
            .navigationBarItems(trailing: Button("Cancel") { dismiss() })
            .onAppear {
                // Auto-focus the title field when the view appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isTitleFocused = true
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }
}

struct CheckInSheet: View {
    @ObservedObject var viewModel: ChallengesViewModel
    let challenge: Challenge
    @Environment(\.dismiss) private var dismiss
    @State private var note: String = ""
    @State private var showSuccessAnimation = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Daily Check-In")) {
                    Text(challenge.title)
                        .font(.headline)
                        .foregroundColor(.theme.text)
                        .padding(.vertical, 4)
                    
                    HStack {
                        Text("Day \(challenge.daysCompleted + 1) of 100")
                            .font(.subheadline)
                            .foregroundColor(.theme.subtext)
                        
                        Spacer()
                        
                        Text("Current streak: \(challenge.streakCount) days")
                            .font(.caption)
                            .foregroundColor(.theme.subtext)
                    }
                }
                
                Section(header: Text("Notes (Optional)")) {
                    TextEditor(text: $note)
                        .frame(minHeight: 100)
                        .padding(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.theme.subtext.opacity(0.3), lineWidth: 1)
                        )
                        .overlay(
                            Group {
                                if note.isEmpty {
                                    Text("Add a note about today's progress...")
                                        .foregroundColor(.theme.subtext.opacity(0.6))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 12)
                                        .allowsHitTesting(false)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                }
                            }
                        )
                }
                
                Section {
                    Button(action: {
                        // Perform check-in
                        Task {
                            await viewModel.checkIn(to: challenge, note: note)
                            showSuccessAnimation = true
                            
                            // Dismiss after a brief delay to show success animation
                            try? await Task.sleep(for: .seconds(1.5))
                            dismiss()
                        }
                    }) {
                        HStack {
                            Spacer()
                            if showSuccessAnimation {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.white)
                                Text("Success!")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            } else {
                                Text("Complete Check-In")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(showSuccessAnimation ? Color.green : Color.theme.accent)
                        )
                        .animation(.spring, value: showSuccessAnimation)
                    }
                }
            }
            .navigationTitle("Check In")
            .navigationBarItems(trailing: Button("Cancel") { dismiss() })
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }
}

struct EditChallengeSheet: View {
    @ObservedObject var viewModel: ChallengesViewModel
    let challenge: Challenge
    @State private var title: String
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isTitleFocused: Bool
    
    init(viewModel: ChallengesViewModel, challenge: Challenge) {
        self.viewModel = viewModel
        self.challenge = challenge
        self._title = State(initialValue: challenge.title)
    }
    
    var body: some View {
        NavigationView {
            Form {
                if viewModel.isOffline {
                    Section {
                        HStack {
                            Image(systemName: "wifi.slash")
                                .foregroundColor(.yellow)
                            Text("You're offline. Changes will be saved locally.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section(header: Text("Challenge Details")) {
                    TextField("Title", text: $title)
                        .focused($isTitleFocused)
                }
                
                Section(header: Text("Challenge Progress")) {
                    HStack {
                        Text("Days Completed")
                        Spacer()
                        Text("\(challenge.daysCompleted) / 100")
                            .foregroundColor(.theme.subtext)
                    }
                    
                    HStack {
                        Text("Current Streak")
                        Spacer()
                        Text("\(challenge.streakCount) days")
                            .foregroundColor(.theme.subtext)
                    }
                    
                    HStack {
                        Text("Started On")
                        Spacer()
                        Text(challenge.startDate, style: .date)
                            .foregroundColor(.theme.subtext)
                    }
                    
                    HStack {
                        Text("Last Modified")
                        Spacer()
                        Text(challenge.lastModified, style: .date)
                            .foregroundColor(.theme.subtext)
                    }
                }
                
                Section {
                    Button("Save Changes") {
                        Task {
                            await viewModel.updateChallenge(id: challenge.id, title: title)
                            dismiss()
                        }
                    }
                    .disabled(title.isEmpty)
                }
                
                Section {
                    Button("Delete Challenge", role: .destructive) {
                        Task {
                            await viewModel.archiveChallenge(challenge)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Edit Challenge")
            .navigationBarItems(trailing: Button("Cancel") { dismiss() })
            .onAppear {
                // Auto-focus the title field when the view appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isTitleFocused = true
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }
}

struct ChallengesView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ChallengesView()
                .environmentObject(SubscriptionService.shared)
                .environmentObject(NotificationService.shared)
        }
    }
} 
