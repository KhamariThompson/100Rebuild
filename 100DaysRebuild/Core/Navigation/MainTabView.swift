import SwiftUI

struct MainTabView: View {
    @StateObject private var router = NavigationRouter()
    @StateObject private var challengesViewModel = ChallengesViewModel()
    @State private var showNewChallengeSheet = false
    @State private var showCheckInSheet = false
    @State private var selectedChallengeForCheckIn: Challenge?
    @State private var showChallengeSelector = false
    @State private var socialNotificationCount: Int? = 0
    @State private var isMenuExpanded = false
    
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
                .disabled(isMenuExpanded) // Disable tab view interaction when menu is expanded
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
                if !isMenuExpanded {
                    MainTabBarView(
                        selectedTab: $router.selectedTab,
                        onNewChallengeButtonTapped: {
                            withAnimation {
                                isMenuExpanded = true
                            }
                        },
                        socialBadgeCount: socialNotificationCount
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
                if isMenuExpanded {
                    FloatingActionMenu(
                        content: {
                            VStack(spacing: 16) {
                                // Start New Challenge Button
                                Button(action: {
                                    withAnimation {
                                        isMenuExpanded = false
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                            showNewChallengeSheet = true
                                        }
                                    }
                                }) {
                                    Label("Start New Challenge", systemImage: "plus.circle.fill")
                                        .font(.headline)
                                        .foregroundColor(.theme.accent)
                                }
                                
                                // Check In Button
                                Button(action: {
                                    withAnimation {
                                        isMenuExpanded = false
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                            handleCheckInTapped()
                                        }
                                    }
                                }) {
                                    Label("Check In", systemImage: "checkmark.circle.fill")
                                        .font(.headline)
                                        .foregroundColor(.theme.accent)
                                }
                                
                                // Cancel Button
                                Button(action: {
                                    withAnimation {
                                        isMenuExpanded = false
                                    }
                                }) {
                                    Label("Cancel", systemImage: "xmark.circle.fill")
                                        .font(.headline)
                                        .foregroundColor(.theme.subtext)
                                }
                            }
                            .padding()
                        },
                        isExpanded: $isMenuExpanded
                    )
                }
            }
        }
        .sheet(isPresented: $showNewChallengeSheet) {
            NewChallengeView(isPresented: $showNewChallengeSheet, challengeTitle: $challengesViewModel.challengeTitle) { title, isTimed in
                Task {
                    await challengesViewModel.createChallenge(title: title, isTimed: isTimed)
                }
            }
        }
        .sheet(isPresented: $showCheckInSheet) {
            if let challenge = selectedChallengeForCheckIn {
                SimpleCheckInSheet(
                    challenge: challenge,
                    dayNumber: challenge.daysCompleted + 1,
                    onCheckIn: { note, image in
                        Task {
                            await challengesViewModel.checkInToChallenge(challenge, note: note, image: image)
                        }
                        showCheckInSheet = false
                    },
                    onDismiss: {
                        showCheckInSheet = false
                    }
                )
            }
        }
        .sheet(isPresented: $showChallengeSelector) {
            ChallengeSelectorView(
                challenges: ChallengeStore.shared.getActiveChallenges(),
                onSelect: { challenge in
                    selectedChallengeForCheckIn = challenge
                    showChallengeSelector = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showCheckInSheet = true
                    }
                },
                onCancel: {
                    showChallengeSelector = false
                }
            )
        }
        // Listen for notifications that might update the badge count
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SocialUpdateReceived"))) { notification in
            if let count = notification.object as? Int {
                socialNotificationCount = count > 0 ? count : nil
            }
        }
        // Handle taps outside the FAB menu
        .contentShape(Rectangle())
        .gesture(
            TapGesture()
                .onEnded { _ in
                    if isMenuExpanded {
                        withAnimation {
                            isMenuExpanded = false
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
        // Get active challenges
        let activeChallenges = ChallengeStore.shared.getActiveChallenges().filter { !$0.isCompleted && !$0.isCompletedToday }
        
        if activeChallenges.isEmpty {
            // No active challenges, show the new challenge sheet
            showNewChallengeSheet = true
        } else if activeChallenges.count == 1 {
            // Only one challenge, go directly to check-in
            selectedChallengeForCheckIn = activeChallenges[0]
            showCheckInSheet = true
        } else {
            // Multiple challenges, show selector
            showChallengeSelector = true
        }
    }
}

// Challenge selector view for choosing which challenge to check in for
struct ChallengeSelectorView: View {
    let challenges: [Challenge]
    let onSelect: (Challenge) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Select a challenge to check in")) {
                    ForEach(challenges) { challenge in
                        Button(action: {
                            onSelect(challenge)
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(challenge.title)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Text("Day \(challenge.daysCompleted + 1) of 100")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Check In")
            .navigationBarItems(
                trailing: Button("Cancel") {
                    onCancel()
                }
            )
        }
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
