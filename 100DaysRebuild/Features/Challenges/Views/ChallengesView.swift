import SwiftUI
import Firebase
import FirebaseFirestore
import Combine

// Using canonical Challenge model
// (No import needed as it will be accessed directly)

// Define notification for showing subscription screen
extension Notification.Name {
    static let showSubscription = Notification.Name("showSubscription")
}

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
    @State private var checkInError: String?
    @State private var showSuccessToast = false
    @State private var showOfflineToast = false
    @State private var showErrorAlert = false
    @State private var scrollOffset: CGFloat = 0
    
    // Gradient for challenges header styling
    private let challengesGradient = LinearGradient(
        colors: [Color.theme.accent, Color.theme.accent.opacity(0.8)],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    var body: some View {
        ZStack {
            // Background
            Color.theme.background
                .ignoresSafeArea()
            
            // ScrollView with integrated title
            ScrollView {
                VStack(spacing: AppSpacing.m) {
                    // App title as "100Days" inside the ScrollView 
                    HStack(alignment: .top) {
                        Text("100Days")
                            .font(.largeTitle)
                            .bold()
                            .foregroundStyle(challengesGradient)
                        
                        Spacer()
                        
                        // Add button
                        Button(action: { viewModel.isShowingNewChallenge = true }) {
                            Image(systemName: "plus")
                                .font(.system(size: AppSpacing.iconSizeMedium, weight: .semibold))
                                .foregroundColor(.theme.accent)
                                .frame(width: 40, height: 40)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(AppScaleButtonStyle())
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                    .padding(.top, AppSpacing.m)
                    
                    // Main content
                    contentView
                        .padding(.bottom, AppSpacing.xl)
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
                // Using SimpleCheckInSheet instead of EnhancedCheckInSheet
                SimpleCheckInSheet(
                    challenge: challenge, 
                    dayNumber: challenge.daysCompleted + 1,
                    onCheckIn: { note, image in
                        performCheckIn(challenge: challenge, note: note, image: image)
                        isShowingCheckInSheet = false
                    },
                    onDismiss: {
                        isShowingCheckInSheet = false
                    }
                )
                .presentationDetents([.large, .medium])
                .presentationDragIndicator(.visible)
            }
        }
        .alert(isPresented: $viewModel.showError) {
            Alert(
                title: Text("Oops!"),
                message: Text(viewModel.errorMessage),
                dismissButton: .default(Text("OK"))
            )
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
        VStack(spacing: AppSpacing.m) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.theme.accent)
            
            Text("Loading challenges...")
                .font(AppTypography.headline)
                .foregroundColor(.theme.text)
            
            Text("Hold tight as we fetch your latest data")
                .font(AppTypography.subheadline)
                .foregroundColor(.theme.subtext)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.theme.background)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: AppSpacing.m) {
            // New personalized greeting component
            MorningGreetingComponent(
                userName: viewModel.userName,
                streakCount: viewModel.maxStreak,
                timeOfDay: convertToComponentTimeOfDay(viewModel.currentTimeOfDay)
            )
            .padding(.horizontal, AppSpacing.screenHorizontalPadding)
            .padding(.bottom, AppSpacing.s)
            
            Image(systemName: "flag.fill")
                .font(.system(size: 70))
                .foregroundColor(.theme.accent.opacity(0.7))
                .padding(.bottom, AppSpacing.m)
            
            Text("No Challenges Yet")
                .font(AppTypography.title2)
                .bold()
                .foregroundColor(.theme.text)
            
            Text("Start your first 100-day challenge and begin tracking your progress.")
                .font(AppTypography.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.theme.subtext)
                .padding(.horizontal, AppSpacing.screenHorizontalPadding)
            
            Button(action: { viewModel.isShowingNewChallenge = true }) {
                Text("Create Challenge")
                    .font(AppTypography.headline)
                    .foregroundColor(.white)
                    .padding(.vertical, AppSpacing.buttonVerticalPadding)
                    .padding(.horizontal, AppSpacing.buttonHorizontalPadding)
                    .background(
                        RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                            .fill(Color.theme.accent)
                    )
            }
            .buttonStyle(AppScaleButtonStyle())
            .padding(.top, AppSpacing.s)
        }
        .padding(AppSpacing.m)
    }
    
    private var challengeListView: some View {
        VStack(spacing: 0) {
            if viewModel.isOffline {
                ChallengesOfflineBanner()
            }
            
            VStack(spacing: AppSpacing.l) {
                // New personalized greeting component
                MorningGreetingComponent(
                    userName: viewModel.userName,
                    streakCount: viewModel.maxStreak,
                    timeOfDay: convertToComponentTimeOfDay(viewModel.currentTimeOfDay)
                )
                .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                .padding(.top, AppSpacing.m)
                
                // Add back the Fliqlo timer view to show time since last check-in
                FliqloTimerView(viewModel: viewModel)
                    .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                
                // Use the space for a more urgent call to action
                if let urgentChallenge = viewModel.mostUrgentChallenge {
                    urgentChallengeCard(urgentChallenge)
                        .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                }
                
                // Pro limit warning if user has too many challenges
                if viewModel.challenges.count >= 3 && !subscriptionService.isProUser {
                    proLimitWarning
                        .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                        .padding(.bottom, AppSpacing.s)
                }
                
                // Challenge list with our new component
                LazyVStack(spacing: AppSpacing.m) {
                    ForEach(viewModel.challenges) { challenge in
                        ChallengeCardComponent(challenge: challenge) {
                            // Only show the check-in sheet if not already completed today
                            if !challenge.isCompletedToday && !challenge.isCompleted {
                                self.challengeToCheckIn = challenge
                                self.isShowingCheckInSheet = true
                            }
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontalPadding)
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
                }
                .padding(.bottom, AppSpacing.m)
                
                // Add challenge button at bottom for easy access
                Button(action: { viewModel.isShowingNewChallenge = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.theme.accent)
                        
                        Text("Add Another Challenge")
                            .font(.headline)
                            .foregroundColor(.theme.accent)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                            .stroke(Color.theme.accent, lineWidth: 1)
                            .background(Color.theme.surface.cornerRadius(AppSpacing.cardCornerRadius))
                    )
                }
                .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                .opacity(viewModel.challenges.count >= 3 && !subscriptionService.isProUser ? 0.5 : 1.0)
                .disabled(viewModel.challenges.count >= 3 && !subscriptionService.isProUser)
            }
        }
    }
    
    // Card for the most urgent challenge (about to break streak)
    private func urgentChallengeCard(_ challenge: Challenge) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.title3)
                
                Text("Don't Break the Chain!")
                    .font(.headline)
                    .foregroundColor(.theme.text)
                
                Spacer()
            }
            
            if challenge.hasStreakExpired {
                Text("Your streak for \"\(challenge.title)\" is at risk. Check in today to keep your \(challenge.streakCount)-day streak going!")
                    .font(.subheadline)
                    .foregroundColor(.theme.subtext)
            } else {
                Text("Keep your \(challenge.streakCount)-day streak for \"\(challenge.title)\" by checking in today!")
                    .font(.subheadline)
                    .foregroundColor(.theme.subtext)
            }
            
            Button {
                self.challengeToCheckIn = challenge
                self.isShowingCheckInSheet = true
            } label: {
                Text("Keep the Streak")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.s)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [.orange, .orange.opacity(0.8)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    )
            }
            .buttonStyle(AppScaleButtonStyle())
            .padding(.top, AppSpacing.xs)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.orange.opacity(0.1), Color.theme.surface]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.theme.shadow.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
    
    // Pro limit warning when user has 3+ challenges as a free user
    private var proLimitWarning: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            HStack {
                Image(systemName: "lock.fill")
                    .foregroundColor(.theme.accent)
                
                Text("Pro Feature")
                    .font(.headline)
                    .foregroundColor(.theme.accent)
                
                Spacer()
            }
            
            Text("Unlock unlimited challenges with Pro")
                .font(.subheadline)
                .foregroundColor(.theme.text)
            
            Button {
                // Navigate to subscription screen
                router.selectedTab = 3 // Switch to Profile tab
                // Navigate to subscription view in profile tab
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    NotificationCenter.default.post(name: .showSubscription, object: nil)
                }
            } label: {
                Text("Upgrade to Pro")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.s)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.theme.accent, Color.theme.accent.opacity(0.8)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    )
            }
            .buttonStyle(AppScaleButtonStyle())
            .padding(.top, AppSpacing.xs)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.theme.accent.opacity(0.1), Color.theme.surface]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.theme.shadow.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
    
    // MARK: - Check In Functionality
    
    private func performCheckIn(challenge: Challenge, note: String, image: UIImage?) {
        Task {
            let result = await viewModel.checkInToChallenge(challenge, note: note, image: image)
            
            switch result {
            case .success(_):
                showSuccessToast = true
                // User stats are now being refreshed in the viewModel's checkInToChallenge method
                
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
    
    // Helper functions to convert between TimeOfDay enums
    private func convertToComponentTimeOfDay(_ timeOfDay: ChallengesViewModel.TimeOfDay) -> MorningGreetingComponent.TimeOfDay {
        switch timeOfDay {
        case .morning:
            return .morning
        case .afternoon:
            return .afternoon
        case .evening:
            return .evening
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
        .padding(.horizontal, AppSpacing.screenHorizontalPadding)
        .padding(.vertical, AppSpacing.xs)
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
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text("Timer challenges require you to complete a timed session before checking in.")
                                .font(.callout)
                                .foregroundColor(.theme.subtext)
                                .padding(.vertical, AppSpacing.xxs)
                        }
                    }
                }
                
                Section(header: Text("Popular Challenge Ideas")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: AppSpacing.xs) {
                            ForEach(challengeSuggestions, id: \.self) { suggestion in
                                Button(action: {
                                    viewModel.challengeTitle = suggestion
                                }) {
                                    Text(suggestion)
                                        .font(.footnote)
                                        .padding(.horizontal, AppSpacing.s)
                                        .padding(.vertical, AppSpacing.xs)
                                        .background(
                                            RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                                                .fill(Color.theme.surface)
                                                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                                        )
                                        .foregroundColor(.theme.text)
                                }
                            }
                        }
                        .padding(.vertical, AppSpacing.xs)
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
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
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
        .padding(.vertical, AppSpacing.s)
        .padding(.horizontal, AppSpacing.xs)
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
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            if viewModel.lastCheckInDate == nil {
                Text("You haven't checked in yet — today's your Day 1.")
                    .font(.headline)
                    .foregroundColor(.theme.accent)
                    .padding(.vertical, AppSpacing.xs)
            } else {
                VStack(alignment: .leading, spacing: AppSpacing.s) {
                    HStack(spacing: AppSpacing.xs) {
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
                            .padding(.bottom, AppSpacing.xxs)
                    }
                    
                    // Use TimelineView to update every second
                    TimelineView(.animation(minimumInterval: 1, paused: false)) { _ in
                        ModernFlipClockView(timeString: viewModel.formattedTimeSinceLastCheckIn())
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
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
        HStack(spacing: AppSpacing.s) {
            // Parse the timeString (format: "Xhr Ymin Zsec")
            let components = timeString.components(separatedBy: " ")
            
            ForEach(Array(zip(components.indices, components)), id: \.0) { index, component in
                // Extract numeric part and unit part
                if let numericEndIndex = component.firstIndex(where: { !$0.isNumber }) {
                    let numericPart = String(component[..<numericEndIndex])
                    let unitPart = String(component[numericEndIndex...])
                    
                    VStack(spacing: AppSpacing.xxs) {
                        // Create flip panel for the digit
                        Text(numericPart)
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(.theme.text)
                            .frame(minWidth: 60)
                            .padding(.vertical, AppSpacing.xs)
                            .background(
                                RoundedRectangle(cornerRadius: AppSpacing.s)
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
                        Text(formatUnit(unitPart))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.theme.subtext)
                            .id("\(index)_\(unitPart)")
                    }
                }
            }
        }
    }
    
    private func formatUnit(_ unit: String) -> String {
        switch unit {
        case "hr": return "hours"
        case "min": return "minutes"
        case "sec": return "seconds"
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
