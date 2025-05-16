import SwiftUI
import Firebase
import FirebaseFirestore
import Combine

// Using canonical Challenge model
// (No import needed as it will be accessed directly)

struct ChallengesView: View {
    @StateObject private var viewModel = ChallengesViewModel()
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @EnvironmentObject private var notificationService: NotificationService
    @EnvironmentObject private var router: TabViewRouter
    @EnvironmentObject private var userStatsService: UserStatsService
    @State private var isShowingEditChallenge = false
    @State private var challengeToEdit: Challenge?
    @State private var isShowingCheckInSheet = false
    @State private var challengeToCheckIn: Challenge?
    @State private var isCheckingIn = false
    @State private var checkInError: String?
    @State private var offlineCheckInQueued = false
    @State private var showSuccessToast = false
    @State private var showOfflineToast = false
    @State private var showErrorAlert = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                contentView
            }
            .navigationTitle("Challenges")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { viewModel.isShowingNewChallenge = true }) {
                            Label("New Challenge", systemImage: "plus")
                        }
                        
                        if !viewModel.challenges.isEmpty {
                            Button(action: refreshChallenges) {
                                Label("Refresh", systemImage: "arrow.clockwise")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 18, weight: .semibold))
                    }
                }
            }
            .sheet(isPresented: $viewModel.isShowingNewChallenge) {
                NewChallengeView(isPresented: $viewModel.isShowingNewChallenge, challengeTitle: $viewModel.challengeTitle) { title, isTimed in
                    Task {
                        await viewModel.createChallenge(title: title, isTimed: isTimed)
                        await userStatsService.refreshUserStats()
                    }
                }
            }
            .sheet(isPresented: $isShowingEditChallenge) {
                if let challenge = challengeToEdit {
                    EditChallengeSheet(viewModel: viewModel, challenge: challenge)
                }
            }
            .sheet(isPresented: $isShowingCheckInSheet) {
                if let challenge = challengeToCheckIn {
                    // Assuming a CheckInView exists or create a simple one
                    VStack {
                        Text("Check in to: \(challenge.title)")
                            .font(.headline)
                            .padding()
                        
                        Button("Check In") {
                            checkInToChallenge(challenge)
                            isShowingCheckInSheet = false
                        }
                        .padding()
                        .background(Color.theme.accent)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        
                        Button("Cancel") {
                            isShowingCheckInSheet = false
                        }
                        .padding()
                    }
                    .padding()
                    .frame(width: 300, height: 250)
                }
            }
            .alert(isPresented: $viewModel.showError) {
                Alert(
                    title: Text("Oops!"),
                    message: Text(viewModel.errorMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .onAppear {
            // Mark tab as changing when this view appears
            if router.selectedTab == 0 {
                router.tabIsChanging = true
            }
            
            Task {
                await viewModel.loadChallenges()
                await viewModel.loadUserProfile()
                
                // After data is loaded, mark tab as not changing
                if router.selectedTab == 0 {
                    router.tabIsChanging = false
                }
            }
        }
        .refreshable {
            await viewModel.loadChallenges()
        }
        .withDiagnostics()
    }
    
    private var contentView: some View {
        ZStack {
            if viewModel.isInitialLoad {
                loadingView
                    .transition(.opacity)
            } else if viewModel.isLoading && viewModel.challenges.isEmpty {
                loadingView
                    .transition(.opacity)
            } else if viewModel.challenges.isEmpty {
                emptyStateView
                    .transition(.opacity)
            } else {
                challengeListView
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.isInitialLoad)
        .animation(.easeInOut(duration: 0.3), value: viewModel.isLoading)
        .animation(.easeInOut(duration: 0.3), value: viewModel.challenges.isEmpty)
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.theme.accent)
            
            Text("Loading challenges...")
                .font(.headline)
                .foregroundColor(.theme.text)
            
            Text("Hold tight as we fetch your latest data")
                .font(.subheadline)
                .foregroundColor(.theme.subtext)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.theme.background)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            GreetingView(viewModel: viewModel)
                .padding(.horizontal)
                .padding(.bottom, 8)
            
            FliqloTimerView(viewModel: viewModel)
                .padding(.horizontal)
                .padding(.bottom, 24)
            
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
    }
    
    private var challengeListView: some View {
        VStack(spacing: 0) {
            if viewModel.isOffline {
                ChallengesOfflineBanner()
            }
            
            ScrollView {
                VStack(spacing: 24) {
                    GreetingView(viewModel: viewModel)
                        .padding(.horizontal)
                        .padding(.top, 16)
                    
                    FliqloTimerView(viewModel: viewModel)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    
                    LazyVStack(spacing: 16) {
                        ForEach(viewModel.challenges) { challenge in
                            challengeCardView(challenge)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    private func challengeCardView(_ challenge: Challenge) -> some View {
        ChallengeCardView(
            challenge: challenge,
            subscriptionService: subscriptionService,
            onCheckIn: {
                // Only show the check-in sheet if not already completed today
                if !challenge.isCompletedToday && !challenge.isCompleted {
                    self.challengeToCheckIn = challenge
                    self.isShowingCheckInSheet = true
                }
            }
        )
        .padding(.bottom, 4)
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                self.challengeToEdit = challenge
                self.isShowingEditChallenge = true
            } label: {
                Label("Edit Challenge", systemImage: "pencil")
            }
            
            Button(role: .destructive) {
                Task {
                    await viewModel.archiveChallenge(challenge)
                }
            } label: {
                Label("Archive Challenge", systemImage: "archivebox")
            }
        }
    }
    
    // MARK: - Check In Functionality
    
    func checkInToChallenge(_ challenge: Challenge) {
        Task {
            let result = await viewModel.checkInToChallenge(challenge)
            
            switch result {
            case .success(let updatedChallenge):
                showSuccessToast = true
                // Refresh user stats after successful check-in
                await userStatsService.refreshUserStats()
                
                // Dismiss the toast after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    showSuccessToast = false
                }
            case .failure(let error):
                checkInError = error.localizedDescription
                showErrorAlert = true
            }
        }
    }
    
    // MARK: - Helper Functions
    
    func deleteChallenge(_ challenge: Challenge) {
        Task {
            let result = await viewModel.deleteChallenge(challenge)
            
            switch result {
            case .success:
                // Refresh user stats after successful deletion
                await userStatsService.refreshUserStats()
            case .failure(let error):
                viewModel.showError = true
                viewModel.errorMessage = "Failed to delete challenge: \(error.localizedDescription)"
            }
        }
    }
    
    private func refreshChallenges() {
        Task {
            await viewModel.loadChallenges()
            await userStatsService.refreshUserStats()
        }
    }
}

struct ChallengesOfflineBanner: View {
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
    @State private var isTimed: Bool = false
    
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
                    
                    Toggle(isOn: $isTimed) {
                        HStack {
                            Image(systemName: "timer")
                                .foregroundColor(.theme.accent)
                            Text("Require timer to check in")
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .theme.accent))
                    
                    if isTimed {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Timer challenges require you to complete a timed session before checking in.")
                                .font(.callout)
                                .foregroundColor(.theme.subtext)
                                .padding(.vertical, 4)
                        }
                    }
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
                            await viewModel.createChallenge(title: viewModel.challengeTitle, isTimed: isTimed)
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

struct GreetingView: View {
    @ObservedObject var viewModel: ChallengesViewModel
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(viewModel.getGreeting())
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.theme.text)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Time of day icon
            ZStack {
                Circle()
                    .fill(timeOfDayGradient)
                    .frame(width: 50, height: 50)
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 3)
                
                Text(viewModel.currentTimeOfDay.emoji)
                    .font(.system(size: 24))
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(Color.theme.background)
        .transition(.opacity)
    }
    
    private var timeOfDayGradient: LinearGradient {
        switch viewModel.currentTimeOfDay {
        case .morning:
            return LinearGradient(
                gradient: Gradient(colors: [Color.orange.opacity(0.7), Color.yellow.opacity(0.5)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .afternoon:
            return LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.cyan.opacity(0.4)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .evening:
            return LinearGradient(
                gradient: Gradient(colors: [Color.indigo.opacity(0.6), Color.purple.opacity(0.4)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

struct FliqloTimerView: View {
    @ObservedObject var viewModel: ChallengesViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if viewModel.lastCheckInDate == nil {
                Text("You haven't checked in yet — today's your Day 1.")
                    .font(.headline)
                    .foregroundColor(.theme.accent)
                    .padding(.vertical, 8)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "clock")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.theme.accent)
                        
                        Text("Since your last check-in")
                            .font(.headline)
                            .foregroundColor(.theme.text)
                    }
                    
                    if let lastCheckIn = viewModel.lastCheckInDate {
                        Text("Last check-in: \(formattedDate(lastCheckIn))")
                            .font(.subheadline)
                            .foregroundColor(.theme.subtext)
                            .padding(.bottom, 4)
                    }
                    
                    // Use TimelineView to update every second
                    TimelineView(.animation(minimumInterval: 1, paused: false)) { _ in
                        ModernFlipClockView(timeString: viewModel.formattedTimeSinceLastCheckIn())
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.theme.surface)
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 5)
        )
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct ModernFlipClockView: View {
    var timeString: String
    
    var body: some View {
        HStack(spacing: 10) {
            // Parse the timeString (format: "Xh Ym Zs")
            let components = timeString.components(separatedBy: " ")
            
            ForEach(0..<components.count, id: \.self) { index in
                let component = components[index]
                let isValue = component.dropLast().allSatisfy { $0.isNumber }
                
                if isValue {
                    // This is a number component (with unit suffix like 'h', 'm', 's')
                    let digitPart = String(component.dropLast())
                    let unitPart = String(component.suffix(1))
                    
                    VStack(spacing: 4) {
                        // Create flip panel for the digit
                        Text(digitPart)
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(.theme.text)
                            .frame(minWidth: 60)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color.theme.surface,
                                                Color.theme.surface.opacity(0.9)
                                            ]),
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
                            )
                        
                        // Unit label
                        Text(unitLabel(for: unitPart))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.theme.subtext)
                    }
                }
            }
        }
    }
    
    private func unitLabel(for unit: String) -> String {
        switch unit {
        case "h": return "hours"
        case "m": return "minutes"
        case "s": return "seconds"
        default: return unit
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
