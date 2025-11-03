import SwiftUI

// This is the main implementation
struct MainAppChallengesTabView: View {
    @StateObject private var viewModel = ChallengesViewModel()
    @EnvironmentObject private var router: NavigationRouter
    @EnvironmentObject private var subscriptionStore: SubscriptionStore
    @EnvironmentObject private var entitlementsAdapter: EntitlementsAdapter
    @EnvironmentObject private var notificationService: NotificationService
    @EnvironmentObject private var userStatsService: UserStatsService
    @EnvironmentObject private var userSession: UserSession
    @State private var scrollOffset: CGFloat = 0
    @State private var currentTime = Date()
    @State private var timer: Timer? = nil
    @State private var challengeToCheckIn: Challenge?
    @State private var isShowingCheckInSheet = false
    
    // Quotes for motivation
    private let motivationalQuotes = [
        "The secret of getting ahead is getting started.",
        "Consistency is the key to achieving and maintaining success.",
        "Small daily improvements are the key to staggering long-term results.",
        "Success is the sum of small efforts repeated day in and day out.",
        "The only way to do great work is to love what you do.",
        "Don't count the days, make the days count.",
        "The difference between try and triumph is just a little umph!",
        "You don't have to be great to start, but you have to start to be great.",
        "Dreams don't work unless you do.",
        "The harder you work for something, the greater you'll feel when you achieve it."
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Static header outside of scroll view
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .top) {
                        // Title with proper styling
                        Text("100Days")
                            .font(AppTypography.largeTitle())
                            .fontWeight(.semibold)
                            .foregroundColor(.theme.text)
                        
                        Spacer()
                        
                        // Menu button
                        Menu {
                            // Removed direct "New Challenge" action from the top-right menu
                            // to avoid duplicate entry points for creating challenges.
                            // Keep Refresh if there are existing challenges.
                            if !viewModel.challenges.isEmpty {
                                Button(action: refreshChallenges) {
                                    Label("Refresh", systemImage: "arrow.clockwise")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(AppTypography.title3(.semibold))
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                .padding(.top, CalAIDesignTokens.headerPaddingTop)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.theme.background)
                
                // Content with ScrollView - separate from header
                ScrollView {
                    VStack(spacing: 0) {
                        // Conditionally show appropriate content
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
                }
                .safeAreaInset(edge: .top) {
                    // Spacer to ensure content doesn't appear under the header
                    Color.clear.frame(height: 0)
                }
                .animation(.easeInOut(duration: 0.3), value: viewModel.isInitialLoad)
                .animation(.easeInOut(duration: 0.3), value: viewModel.isLoading)
                .animation(.easeInOut(duration: 0.3), value: viewModel.challenges.isEmpty)
            }
            .background(Color.theme.background.ignoresSafeArea())
            .navigationBarHidden(true) // Hide the navigation bar since we have our own header
            .sheet(isPresented: $viewModel.isShowingNewChallenge) {
                NewChallengeView(isPresented: $viewModel.isShowingNewChallenge, challengeTitle: $viewModel.challengeTitle) { title, isTimed in
                    Task {
                        await viewModel.createChallenge(title: title, isTimed: isTimed)
                        await userStatsService.refreshUserStats()
                    }
                }
                .environmentObject(subscriptionStore)
                .environmentObject(entitlementsAdapter)
                .environmentObject(ThemeManager.shared)
                .environmentObject(userSession)
            }
            .alert(isPresented: $viewModel.showError) {
                Alert(
                    title: Text("Oops!"),
                    message: Text(viewModel.errorMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            Task {
                await viewModel.loadChallenges()
                await viewModel.loadUserProfile()
                checkAndScheduleStreakReminders()
            }
            
            // Start a timer to update every minute
            timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
                DispatchQueue.main.async {
                    currentTime = Date()
                }
            }
        }
        .onDisappear {
            // Clean up timer when view disappears
            timer?.invalidate()
            timer = nil
        }
        .sheet(isPresented: $isShowingCheckInSheet) {
            if let challenge = challengeToCheckIn {
                SimpleCheckInSheet(
                    challenge: challenge,
                    dayNumber: challenge.daysCompleted + 1,
                    onCheckIn: { note, image in
                        Task {
                            await viewModel.checkInToChallenge(challenge, note: note, image: image)
                        }
                        isShowingCheckInSheet = false
                    },
                    onDismiss: {
                        isShowingCheckInSheet = false
                    }
                )
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(Color.theme.accent)
            
            Text("Loading challenges...")
                .font(AppTypography.headline())
                .foregroundColor(Color.theme.text)
            
            Text("Hold tight as we fetch your latest data")
                .font(AppTypography.subhead())
                .foregroundColor(Color.theme.subtext)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.top, 40)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "flag.fill")
                .font(AppTypography.display())
                .foregroundColor(Color.theme.accent.opacity(0.7))
            
            Text("No challenges yet")
                .font(AppTypography.title3())
                .fontWeight(.semibold)
                .foregroundColor(Color.theme.text)
            
            Text("Create your first challenge to track your 100-day journey")
                .font(AppTypography.subhead())
                .foregroundColor(Color.theme.subtext)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: { viewModel.isShowingNewChallenge = true }) {
                Label("Create Challenge", systemImage: "plus")
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.theme.accent)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .buttonStyle(ChallengesScaleButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.top, 40)
    }
    
    private var challengeListView: some View {
        VStack(spacing: 24) {
            // Welcome banner with greeting based on time of day
            greetingBannerView
                .padding(.horizontal)
                .padding(.top, 8)
            
            if viewModel.isOffline {
                ChallengesOfflineBannerView()
                    .padding(.horizontal)
            }
            
            VStack(spacing: 20) {
                ForEach(viewModel.challenges) { challenge in
                    ChallengesCardView(challenge: challenge, viewModel: viewModel, challengeToCheckIn: $challengeToCheckIn, isShowingCheckInSheet: $isShowingCheckInSheet)
                        .padding(.horizontal)
                }
                
                // Show motivational prompt if user has fewer than 3 active challenges
                if viewModel.challenges.count < 3 && !viewModel.challenges.isEmpty {
                    motivationalPromptView
                        .padding(.horizontal)
                        .padding(.top, 8)
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    // New motivational prompt view when user has fewer than 3 challenges
    private var motivationalPromptView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .font(AppTypography.title3())
                    .foregroundColor(.yellow)
                
                Text("Add another challenge?")
                    .font(AppTypography.headline())
                    .foregroundColor(.theme.text)
                
                Spacer()
            }
            
            // Random motivational quote
            Text(motivationalQuotes.randomElement() ?? "Consistency is key to success.")
                .font(AppTypography.subhead())
                .foregroundColor(.theme.subtext)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
            
            Button(action: { viewModel.isShowingNewChallenge = true }) {
                Text("Create New Challenge")
                    .font(AppTypography.subhead())
                    .foregroundColor(.theme.accent)
                    .padding(.vertical, 8)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.theme.surface)
                .shadow(color: Color.theme.shadow.opacity(0.06), radius: 4, x: 0, y: 2)
        )
    }
    
    // Greeting banner that shows time-sensitive message
    private var greetingBannerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Good morning/afternoon/evening message
            Text(getGreeting())
                .font(AppTypography.title2())
                .fontWeight(.bold)
                .foregroundColor(.theme.text)
            
            // Don't break the chain - only show when streak is at risk
            if let streakAtRisk = getStreakAtRisk() {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .font(AppTypography.title3())
                        
                        Text("Streak at risk!")
                            .font(AppTypography.headline())
                            .foregroundColor(.red)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                        
                        Text("\(streakAtRisk.streakCount)-day streak for \"\(streakAtRisk.title)\" will break in \(formatTimeRemaining())")
                            .font(AppTypography.subhead())
                            .foregroundColor(.theme.subtext)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Button(action: {
                        if let challenge = getStreakAtRisk() {
                            // Directly set the state variables instead of using initializeCheckIn
                            challengeToCheckIn = challenge
                            isShowingCheckInSheet = true
                        }
                    }) {
                        Text("Check in now")
                            .font(AppTypography.subhead())
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color.theme.accent)
                            )
                    }
                    .padding(.top, 4)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.red.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                        )
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.theme.surface)
                .shadow(color: Color.theme.shadow.opacity(0.06), radius: 4, x: 0, y: 2)
        )
        .animation(.easeInOut, value: getStreakAtRisk() != nil)
    }
    
    // Get time-appropriate greeting
    private func getGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        
        if hour >= 0 && hour < 12 {
            return "Good morning"
        } else if hour >= 12 && hour < 17 {
            return "Good afternoon"
        } else {
            return "Good evening"
        }
    }
    
    // Check if any streak is at risk of breaking within 2 hours
    private func getStreakAtRisk() -> Challenge? {
        let calendar = Calendar.current
        let now = Date()
        
        // Calculate midnight tonight
        guard let tomorrowDate = calendar.date(byAdding: .day, value: 1, to: now) else {
            return nil
        }
        let midnight = calendar.startOfDay(for: tomorrowDate)
        
        // Calculate the cutoff time (2 hours before midnight)
        guard let twoPreviousHours = calendar.date(byAdding: .hour, value: -2, to: midnight) else {
            return nil
        }
        
        // Only show the alert if we're within 2 hours of midnight
        if now < twoPreviousHours {
            return nil
        }
        
        // Find challenges with active streaks that haven't been checked in today
        var riskyStreaks: [Challenge] = []
        
        for challenge in viewModel.challenges {
            let notCompletedToday = !challenge.isCompletedToday
            let notFullyCompleted = !challenge.isCompleted
            let hasActiveStreak = challenge.streakCount > 0
            let streakNotExpired = !challenge.hasStreakExpired
            
            if notCompletedToday && notFullyCompleted && hasActiveStreak && streakNotExpired {
                riskyStreaks.append(challenge)
            }
        }
        
        // Return the challenge with the highest streak count
        return riskyStreaks.max(by: { $0.streakCount < $1.streakCount })
    }
    
    // Format the time remaining until midnight
    private func formatTimeRemaining() -> String {
        let calendar = Calendar.current
        let now = Date()
        
        // Find midnight tonight
        guard let tomorrowDate = calendar.date(byAdding: .day, value: 1, to: now) else {
            return "soon"
        }
        let midnight = calendar.startOfDay(for: tomorrowDate)
        
        // Calculate the difference
        let components = calendar.dateComponents([.hour, .minute], from: now, to: midnight)
        let hours = components.hour ?? 0
        let minutes = components.minute ?? 0
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes) minutes"
        }
    }
    
    // Schedule streak reminders if needed
    private func checkAndScheduleStreakReminders() {
        if let streakAtRisk = getStreakAtRisk() {
            // Schedule an immediate notification if there's a streak at risk
            Task {
                do {
                    try await scheduleUrgentStreakNotification(for: streakAtRisk)
                } catch {
                    print("Failed to schedule streak notification: \(error)")
                }
            }
        }
    }
    
    // Schedule an urgent notification for a streak at risk
    private func scheduleUrgentStreakNotification(for challenge: Challenge) async throws {
        guard notificationService.isAuthorized else { return }
        
        // Remove any existing streak notifications with this ID
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["urgentStreakReminder"])
        
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = "Streak About to Break!"
        content.body = "Your \(challenge.streakCount)-day streak for \"\(challenge.title)\" will break at midnight. Check in now!"
        content.sound = .default
        
        // Create a time-based trigger for 5 minutes from now (just as a fallback if user doesn't see the UI alert)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5 * 60, repeats: false)
        
        // Create request
        let request = UNNotificationRequest(
            identifier: "urgentStreakReminder",
            content: content,
            trigger: trigger
        )
        
        // Schedule notification
        try await UNUserNotificationCenter.current().add(request)
    }
    
    private func refreshChallenges() {
        Task {
            await viewModel.loadChallenges()
            await userStatsService.refreshUserStats()
        }
    }
}

// MARK: - Supporting Views

struct ChallengesCardView: View {
    let challenge: Challenge
    @ObservedObject var viewModel: ChallengesViewModel
    @State private var showActionSheet = false
    @Binding var challengeToCheckIn: Challenge?
    @Binding var isShowingCheckInSheet: Bool
    
    var body: some View {
        ChallengeCardComponent(challenge: challenge) {
            // Handle check-in action
            if !challenge.isCompletedToday && !challenge.isCompleted && 
               !(challenge.hasStreakExpired && challenge.lastCheckInDate != nil && challenge.streakCount > 0) {
                // Directly set the state variables instead of using initializeCheckIn
                challengeToCheckIn = challenge
                isShowingCheckInSheet = true
            } else if challenge.hasStreakExpired && challenge.lastCheckInDate != nil && challenge.streakCount > 0 {
                // Show the expired challenge alert instead of check-in sheet
                viewModel.currentExpiredChallenge = challenge
                viewModel.showExpiredChallengeAlert = true
            }
        }
        .contextMenu {
            Button {
                viewModel.prepareToEditChallenge(challenge)
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

struct ChallengesOfflineBannerView: View {
    var body: some View {
        HStack {
            Image(systemName: "wifi.slash")
                .foregroundColor(.yellow)
            Text("You're offline. Some features may be limited.")
                .font(AppTypography.footnote())
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(Color(.systemGray6))
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

struct ChallengesScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

// For backward compatibility - using a typealias instead of a separate struct
typealias ChallengesTabView = MainAppChallengesTabView

// Preview
struct MainAppChallengesTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainAppChallengesTabView()
    }
} 