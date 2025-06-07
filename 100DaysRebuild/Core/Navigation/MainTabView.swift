import SwiftUI

class MainTabViewModel: ObservableObject {
    @Published var showNewChallengeSheet = false
    @Published var showCheckInSheet = false
    @Published var selectedChallengeForCheckIn: Challenge?
    @Published var showChallengeSelector = false
    @Published var socialNotificationCount: Int? = 0
    @Published var isMenuExpanded = false
}

struct MainTabView: View {
    @StateObject private var router = NavigationRouter()
    @StateObject private var challengesViewModel = ChallengesViewModel()
    @StateObject private var subscriptionService = SubscriptionService.shared
    @StateObject private var viewModel = MainTabViewModel()
    
    var body: some View {
        ZStack(alignment: .bottom) {
            if #available(iOS 17.0, *) {
                TabView(selection: $router.selectedTab) {
                    // Home Tab
                    NavigationView {
                        Text("Home Tab")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.theme.background)
                            .navigationTitle("Home")
                            .contentPaddingForTabBar()
                    }
                    .tag(0)
                    
                    // Progress Tab
                    NavigationView {
                        Text("Progress Tab")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.theme.background)
                            .navigationTitle("Progress")
                            .contentPaddingForTabBar()
                    }
                    .tag(1)
                    
                    // Social Tab
                    NavigationView {
                        Text("Social Tab")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.theme.background)
                            .navigationTitle("Social")
                            .contentPaddingForTabBar()
                    }
                    .tag(2)
                    
                    // Profile Tab
                    NavigationView {
                        Text("Profile Tab")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.theme.background)
                            .navigationTitle("Profile")
                            .contentPaddingForTabBar()
                    }
                    .tag(3)
                }
                .disabled(viewModel.isMenuExpanded) // Disable tab view interaction when menu is expanded
                .edgesIgnoringSafeArea(.bottom)
                .onChange(of: router.selectedTab) { oldValue, newValue in
                    // Make sure the tab change is intentional and not a bug
                    // This prevents auto-switching back to home tab
                    print("Tab changed from \(oldValue) to \(newValue)")
                }
            } else {
                // Fallback on earlier versions
            }
            
            ZStack(alignment: .bottom) {
                // Custom tab bar (visible when menu is not expanded)
                if !viewModel.isMenuExpanded {
                    MainTabBarView(
                        selectedTab: $router.selectedTab,
                        onNewChallengeButtonTapped: {
                            withAnimation {
                                viewModel.isMenuExpanded = true
                            }
                        },
                        socialBadgeCount: viewModel.socialNotificationCount
                    )
                    .offset(y: router.tabIsChanging ? 100 : 0) // Hide during tab transitions
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: router.tabIsChanging)
                    .shadow(color: Color.theme.shadow.opacity(0.25), radius: 10, x: 0, y: -3)
                    .background(
                        Rectangle()
                            .fill(Color.theme.surface)
                            .edgesIgnoringSafeArea(.bottom)
                            .frame(height: 2)
                            .offset(y: 100)
                    )
                }
                
                // Floating action menu (replaces the + button with a menu)
                if viewModel.isMenuExpanded {
                    FloatingActionMenu(
                        content: {
                            VStack(spacing: 16) {
                                // Start New Challenge Button - Directly show the new challenge sheet
                                Button(action: {
                                    // First hide the menu
                                    withAnimation {
                                        viewModel.isMenuExpanded = false
                                    }
                                    
                                    // Print for debugging
                                    print("New Challenge button tapped")
                                    
                                    // Set a short delay to ensure proper view sequencing
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        // Force navigation to Challenges tab
                                        router.selectedTab = 0
                                        
                                        // Show the new challenge sheet with animation
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            viewModel.showNewChallengeSheet = true
                                            viewModel.objectWillChange.send()
                                        }
                                    }
                                }) {
                                    Label("Start New Challenge", systemImage: "plus.circle.fill")
                                        .font(.headline)
                                        .foregroundColor(.theme.accent)
                                }
                                
                                // Check In Button
                                Button(action: {
                                    // Instantly hide the menu
                                    withAnimation {
                                        viewModel.isMenuExpanded = false
                                    }
                                        
                                    // Print for debugging
                                    print("Check In button tapped")
                                    
                                    // First refresh challenges to ensure we have latest data
                                    Task(priority: .userInitiated) {
                                        print("Refreshing challenges before check in...")
                                        await challengesViewModel.loadChallenges()
                                        
                                        // Now handle the check-in with fresh data
                                        handleCheckInTapped()
                                    }
                                }) {
                                    Label("Check In", systemImage: "checkmark.circle.fill")
                                        .font(.headline)
                                        .foregroundColor(.theme.accent)
                                }
                                
                                // Cancel Button
                                Button(action: {
                                    withAnimation {
                                        viewModel.isMenuExpanded = false
                                    }
                                }) {
                                    Label("Cancel", systemImage: "xmark.circle.fill")
                                        .font(.headline)
                                        .foregroundColor(.theme.subtext)
                                }
                            }
                            .padding()
                        },
                        isExpanded: $viewModel.isMenuExpanded
                    )
                }
            }
            
            // DIRECT OVERLAY FOR NEW CHALLENGE VIEW
            if viewModel.showNewChallengeSheet {
                ZStack {
                    // Semi-transparent background
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .accessibility(identifier: "newChallengeOverlayBackground")
                        .onTapGesture {
                            viewModel.showNewChallengeSheet = false
                        }
                    
                    // The NewChallengeView in overlay mode
                    NewChallengeView(isPresented: $viewModel.showNewChallengeSheet, challengeTitle: $challengesViewModel.challengeTitle) { title, isTimed in
                        // Run with high priority to ensure UI updates immediately
                        Task(priority: .userInitiated) {
                            // Close the sheet first for better UI responsiveness
                            await MainActor.run {
                                viewModel.showNewChallengeSheet = false
                            }
                            
                            // Create the challenge using our viewModel
                            await challengesViewModel.createChallenge(title: title, isTimed: isTimed)
                            
                            // Make sure we're on the challenges tab to see the new challenge
                            await MainActor.run {
                                router.selectedTab = 0
                            }
                        }
                    }
                    .environmentObject(subscriptionService)
                    .environmentObject(ThemeManager.shared)
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.92)
                    .frame(maxHeight: UIScreen.main.bounds.height * 0.8)
                    .background(Color.theme.background)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                    .accessibility(identifier: "newChallengeView")
                }
                .transition(.opacity) // Change to a simpler transition
                .zIndex(100)
            }
            
            // DIRECT OVERLAY FOR CHECK-IN SHEET
            if viewModel.showCheckInSheet, let challenge = viewModel.selectedChallengeForCheckIn {
                ZStack {
                    // Semi-transparent background
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            print("Dismissing check-in sheet by tapping background")
                            viewModel.showCheckInSheet = false
                        }
                    
                    // The SimpleCheckInSheet
                SimpleCheckInSheet(
                    challenge: challenge,
                    dayNumber: challenge.daysCompleted + 1,
                    onCheckIn: { note, image in
                        print("SimpleCheckInSheet: onCheckIn called with note length: \(note.count)")
                        // Fire and forget - start task but dismiss sheet immediately
                        Task {
                            await challengesViewModel.checkInToChallenge(challenge, note: note, image: image)
                        }
                        // Dismiss immediately without waiting for task completion
                        print("SimpleCheckInSheet: dismissing after check-in")
                        viewModel.showCheckInSheet = false
                    },
                    onDismiss: {
                        print("SimpleCheckInSheet: onDismiss called")
                        viewModel.showCheckInSheet = false
                    }
                )
                .environmentObject(subscriptionService)
                }
                .transition(.identity) // Use identity transition for immediate appearance
                .zIndex(100)
                .onAppear {
                    print("Check-in sheet appeared with challenge: \(challenge.title)")
                }
            }
            
            // DIRECT OVERLAY FOR CHALLENGE SELECTOR
            if viewModel.showChallengeSelector {
                let activeChallenges = ChallengeStore.shared.getActiveChallenges()
                
                ZStack {
                    // Semi-transparent background
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            viewModel.showChallengeSelector = false
                        }
                    
                    // The ChallengeSelectorView
                    ChallengeSelectorView(
                        challenges: activeChallenges,
                        onSelect: { challenge in
                            // Debug print
                            print("Challenge selected: \(challenge.title), ID: \(challenge.id)")
                            viewModel.selectedChallengeForCheckIn = challenge
                            viewModel.showChallengeSelector = false
                            // Show check-in sheet immediately without delay
                            viewModel.showCheckInSheet = true
                            viewModel.objectWillChange.send()
                        },
                        onCancel: {
                            viewModel.showChallengeSelector = false
                        }
                    )
                    .background(Color.theme.background)
                    .cornerRadius(16)
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.92)
                    .frame(maxHeight: UIScreen.main.bounds.height * 0.6)
                    .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                }
                .transition(.identity) // Use identity transition for immediate appearance
                .zIndex(100)
                .onAppear {
                    // Debug print to verify challenges
                    print("ChallengeSelectorView: Found \(activeChallenges.count) active challenges")
                    
                    // Force refresh challenges when selector appears
                    Task {
                        print("Refreshing challenges on selector appear...")
                        await challengesViewModel.loadChallenges()
                        
                        // Force update UI after refresh
                        await MainActor.run {
                            viewModel.objectWillChange.send()
                        }
                    }
                }
            }
        }
        
        // Listen for notifications that might update the badge count
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SocialUpdateReceived"))) { notification in
            if let count = notification.object as? Int {
                viewModel.socialNotificationCount = count > 0 ? count : nil
            }
        }
        // Handle taps outside the FAB menu
        .contentShape(Rectangle())
        .gesture(
            TapGesture()
                .onEnded { _ in
                    if viewModel.isMenuExpanded {
                        withAnimation {
                            viewModel.isMenuExpanded = false
                        }
                    }
                }
        )
        .onAppear {
            // Load challenges when the view appears
            Task {
                await challengesViewModel.loadChallenges()
            }
        }
    }
    
    private func handleCheckInTapped() {
        // Get active challenges - only ones that are not completed and not checked in today
        let activeChallenges = ChallengeStore.shared.getActiveChallenges().filter { 
            !$0.isCompleted && !$0.isCompletedToday
        }
        
        // Print for debugging
        print("handleCheckInTapped called - Found \(activeChallenges.count) active challenges")
        
        // Use task with high priority to ensure immediate state updates
        Task(priority: .userInitiated) {
            // Force UI update using MainActor to ensure UI changes happen on the main thread
            await MainActor.run {
                if activeChallenges.isEmpty {
                    // No active challenges, show the new challenge sheet
                    print("No active challenges, showing new challenge sheet")
                    viewModel.showNewChallengeSheet = true
                    viewModel.objectWillChange.send()
                } else if activeChallenges.count == 1 {
                    // Only one challenge, go directly to check-in
                    print("Single challenge found, going directly to check-in")
                    viewModel.selectedChallengeForCheckIn = activeChallenges[0]
                    viewModel.showCheckInSheet = true
                    viewModel.objectWillChange.send()
                    print("showCheckInSheet set to true")
                } else {
                    // Multiple challenges, show selector
                    print("Multiple challenges found, showing selector")
                    viewModel.showChallengeSelector = true
                    viewModel.objectWillChange.send()
                }
            }
        }
    }
}

// Update the ChallengeSelectorView to be more modern and sleek
struct ChallengeSelectorView: View {
    let challenges: [Challenge]
    let onSelect: (Challenge) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Check In")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.theme.text)
                
                Spacer()
                
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.theme.subtext)
                }
            }
            .padding(.horizontal)
            .padding(.top, 20)
            .padding(.bottom, 16)
            
            // Divider
            Rectangle()
                .fill(Color.theme.border.opacity(0.5))
                .frame(height: 1)
                .padding(.horizontal)
            
            // Instructions text
            Text("Select a challenge to check in")
                .font(.subheadline)
                .foregroundColor(.theme.subtext)
                .padding(.top, 16)
                .padding(.bottom, 8)
            
            // Challenge list
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(challenges) { challenge in
                        Button(action: {
                            onSelect(challenge)
                        }) {
                            HStack(spacing: 12) {
                                // Challenge icon/indicator
                                Circle()
                                    .fill(Color.theme.accent.opacity(0.2))
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.theme.accent)
                                    )
                                
                                // Challenge info
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(challenge.title)
                                        .font(.headline)
                                        .foregroundColor(.theme.text)
                                        .lineLimit(1)
                                    
                                    Text("Day \(challenge.daysCompleted + 1) of 100")
                                        .font(.subheadline)
                                        .foregroundColor(.theme.subtext)
                                }
                                
                                Spacer()
                                
                                // Chevron
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.theme.subtext)
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.theme.surface)
                                    .shadow(color: Color.theme.shadow.opacity(0.1), radius: 2, x: 0, y: 1)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            
            Spacer()
        }
        .background(Color.theme.background.ignoresSafeArea())
    }
}

// Dynamic Tab Bar Notch Size Modifier
struct DynamicTabBarNotchModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.bottom, getSafeAreaInsets().bottom + 80) // Increased from 60 to 80 for more space
    }
    
    private func getSafeAreaInsets() -> UIEdgeInsets {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        }
        return window.safeAreaInsets
    }
}

extension View {
    func dynamicTabBarPadding() -> some View {
        self.modifier(DynamicTabBarNotchModifier())
    }
    
    // New modifier for content above tab bar
    func contentPaddingForTabBar() -> some View {
        self.padding(.bottom, 90) // Fixed extra padding to ensure content isn't hidden by tab bar
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
} 
