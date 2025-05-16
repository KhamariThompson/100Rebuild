import SwiftUI

// Router to handle tab switching and loading state management 
class TabViewRouter: ObservableObject {
    @Published var selectedTab = 0
    @Published var previousTab = 0
    @Published var tabIsChanging = false
    
    func changeTab(to tab: Int) {
        // Only if tab is actually changing
        if tab != selectedTab {
            previousTab = selectedTab
            selectedTab = tab
            tabIsChanging = true
            
            // Add a small delay for viewModel to initialize before showing UI
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.tabIsChanging = false
            }
        }
    }
}

// Define the notification name for showing notification settings
extension Notification.Name {
    static let showNotificationSettings = Notification.Name("showNotificationSettings")
}

struct MainAppView: View {
    @EnvironmentObject var userSession: UserSession
    @StateObject private var router = TabViewRouter()
    @StateObject private var subscriptionService = SubscriptionService.shared
    @StateObject private var notificationService = NotificationService.shared
    @StateObject private var userStatsService = UserStatsService.shared
    @StateObject private var viewModel = ProgressDashboardViewModel.shared
    @State private var showTabBar = true
    @State private var showNotificationSettings = false
    @State private var showPaywall = false
    
    // Accessibility settings
    @AppStorage("isLargeTextEnabled") private var isLargeTextEnabled = false
    @AppStorage("isHighContrastEnabled") private var isHighContrastEnabled = false
    
    var body: some View {
        ZStack {
            // Background color covering entire screen
            Color.theme.background
                .ignoresSafeArea()
                .zIndex(-1) // Ensure background is at the bottom
            
            // Main tab view showing tabs
            TabView(selection: $router.selectedTab) {
                ChallengesView()
                    .tabItem {
                        Image(systemName: "flag.fill")
                            .renderingMode(.template)
                            .foregroundColor(.theme.accent)
                        Text("Challenges")
                    }
                    .tag(0)
                
                ProgressView()
                    .environmentObject(viewModel)
                    .tabItem {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .renderingMode(.template)
                            .foregroundColor(.theme.accent)
                        Text("Progress")
                    }
                    .tag(1)
                
                MainApp_SocialTabView()
                    .tabItem {
                        Image(systemName: "person.2.fill")
                            .renderingMode(.template)
                            .foregroundColor(.theme.accent)
                        Text("Social")
                    }
                    .tag(2)
                
                ProfileView()
                    .tabItem {
                        Image(systemName: "person.fill")
                            .renderingMode(.template)
                            .foregroundColor(.theme.accent)
                        Text("Profile")
                    }
                    .tag(3)
            }
            .accentColor(Color.theme.accent) // Set explicit accent color for tab items
            .onChange(of: router.selectedTab) { newValue in
                router.changeTab(to: newValue)
            }
            .zIndex(1) // Ensure tab view is above background but below overlays
            .environmentObject(router)
            .environmentObject(subscriptionService)
            .environmentObject(notificationService)
            .environmentObject(userStatsService)
            
            // Paywall overlay with theme awareness
            if subscriptionService.showPaywall {
                PaywallView()
                    .withAppTheme() // Apply theme explicitly to the overlay
                    .transition(.opacity)
                    .zIndex(100)
            }
            
            // Notification settings overlay with theme awareness
            if showNotificationSettings {
                NotificationSettingsView(isPresented: $showNotificationSettings)
                    .withAppTheme() // Apply theme explicitly to the overlay
                    .transition(.opacity)
                    .zIndex(101)
            }
        }
        .background(Color.theme.background) // Additional background to ensure no transparency
        .onAppear {
            setupTabBarAppearance()
            
            // Only display the paywall sheet if needed
            showPaywall = subscriptionService.showPaywall
            
            // Load UserStatsService data when app starts
            Task {
                await userStatsService.fetchUserStats()
            }
        }
        // Listen for subscriptionService changes
        .onChange(of: subscriptionService.showPaywall) { newValue in
            showPaywall = newValue
        }
        // Listen for notification settings request
        .onReceive(NotificationCenter.default.publisher(for: .showNotificationSettings)) { _ in
            withAnimation {
                showNotificationSettings = true
            }
        }
        // Apply accessibility settings but don't apply explicit theme here
        // Theme is now handled by ThemeManager through withAppTheme() modifier
        .environment(\.sizeCategory, isLargeTextEnabled ? .accessibilityExtraLarge : .large)
    }
    
    private func setupTabBarAppearance() {
        // Configure tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithDefaultBackground()
        
        // Fix tab bar appearance for iOS 15 and later
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        }
        
        // Apply to standard appearance
        UITabBar.appearance().standardAppearance = tabBarAppearance
        
        // Set tint color for tab bar items - ensure it's using the accent color
        UITabBar.appearance().tintColor = UIColor(Color.theme.accent)
        
        // Make unselected items visible with a consistent inactive color
        UITabBar.appearance().unselectedItemTintColor = UIColor(Color.theme.tabInactive)
        
        // Fix for NavigationView layout constraint issues
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.theme.background)
        appearance.shadowColor = nil // Remove shadow line
        
        // Use this appearance for all navigation bars
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }
}

// These wrapper views ensure each tab has its own navigation context
struct ChallengesTabView: View {
    var body: some View {
        NavigationView {
            ChallengesView()
                .navigationTitle("Challenges")
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct ProgressTabView: View {
    @EnvironmentObject var progressViewModel: ProgressDashboardViewModel
    
    var body: some View {
        NavigationView {
            ProgressView()
                .environmentObject(progressViewModel)
                .navigationTitle("Progress")
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct MainApp_SocialTabView: View {
    var body: some View {
        NavigationView {
            SocialView()
                .navigationTitle("Social")
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct ProfileTabView: View {
    var body: some View {
        NavigationView {
            ProfileView()
                .navigationTitle("Profile")
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct MainAppView_Previews: PreviewProvider {
    static var previews: some View {
        lightDarkVariants(title: "Main App") {
            MainAppView()
                .environmentObject(UserSession.shared)
                .environmentObject(SubscriptionService.shared)
                .environmentObject(NotificationService.shared)
                .environmentObject(ThemeManager.shared)
        }
    }
}

// Fixing missing view structures
struct FliqloView: View {
    var body: some View {
        Text("Timer Coming Soon")
            .font(.title)
            .foregroundColor(.theme.text)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.theme.background)
    }
}

struct NotificationSettingsView: View {
    @Binding var isPresented: Bool
    @State private var isDailyReminderEnabled: Bool = true
    @State private var isStreakReminderEnabled: Bool = true
    @State private var reminderTime: Date = Calendar.current.date(from: DateComponents(hour: 20, minute: 0)) ?? Date()
    @EnvironmentObject var notificationService: NotificationService
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }
            
            VStack(spacing: 20) {
                // Header
                HStack {
                    Text("Notification Settings")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.theme.text)
                    
                    Spacer()
                    
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.theme.subtext)
                    }
                }
                .padding(.bottom)
                
                // Daily Reminder
                VStack(alignment: .leading, spacing: 8) {
                    Text("Daily Reminder")
                        .font(.headline)
                        .foregroundColor(.theme.text)
                    
                    Toggle("Enable Daily Reminder", isOn: $isDailyReminderEnabled)
                        .onChange(of: isDailyReminderEnabled) { newValue in
                            updateNotificationSettings()
                        }
                        .tint(.theme.accent)
                    
                    if isDailyReminderEnabled {
                        DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                            .onChange(of: reminderTime) { newValue in
                                updateNotificationSettings()
                            }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.theme.surface)
                )
                
                // Streak Reminder
                VStack(alignment: .leading, spacing: 8) {
                    Text("Streak Reminder")
                        .font(.headline)
                        .foregroundColor(.theme.text)
                    
                    Toggle("Enable Streak Reminder", isOn: $isStreakReminderEnabled)
                        .onChange(of: isStreakReminderEnabled) { newValue in
                            updateNotificationSettings()
                        }
                        .tint(.theme.accent)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.theme.surface)
                )
                
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.theme.background)
            )
            .padding(.horizontal, 20)
            .frame(maxWidth: 500, maxHeight: 500)
            .onAppear {
                loadNotificationSettings()
            }
        }
        .transition(.opacity)
    }
    
    private func loadNotificationSettings() {
        isDailyReminderEnabled = notificationService.isDailyReminderEnabled
        isStreakReminderEnabled = notificationService.isStreakReminderEnabled
        reminderTime = notificationService.reminderTime
    }
    
    private func updateNotificationSettings() {
        notificationService.isDailyReminderEnabled = isDailyReminderEnabled
        notificationService.isStreakReminderEnabled = isStreakReminderEnabled
        notificationService.reminderTime = reminderTime
        
        // Save to UserDefaults
        UserDefaults.standard.set(isDailyReminderEnabled, forKey: "isDailyReminderEnabled")
        UserDefaults.standard.set(isStreakReminderEnabled, forKey: "isStreakReminderEnabled")
        UserDefaults.standard.set(reminderTime, forKey: "reminderTime")
    }
}



