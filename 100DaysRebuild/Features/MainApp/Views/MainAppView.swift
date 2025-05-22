import SwiftUI

// Import NavigationRouter from MainTabView
import UIKit

// Define the notification name for showing notification settings
extension Notification.Name {
    static let showNotificationSettings = Notification.Name("showNotificationSettings")
}

struct MainAppView: View {
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var router: NavigationRouter
    @EnvironmentObject var subscriptionService: SubscriptionService
    @EnvironmentObject var notificationService: NotificationService
    @EnvironmentObject var userStatsService: UserStatsService
    @EnvironmentObject var progressViewModel: ProgressDashboardViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var showTabBar = true
    @State private var showNotificationSettings = false
    @State private var showPaywall = false
    @State private var showAddAction = false
    @State private var safeAreaBottom: CGFloat = 0
    
    // Accessibility settings
    @AppStorage("isLargeTextEnabled") private var isLargeTextEnabled = false
    @AppStorage("isHighContrastEnabled") private var isHighContrastEnabled = false
    
    // Tab items for CalAI style tab bar
    private let tabItems = [
        CalAITabBar.TabItem(icon: "house", text: "Home"),
        CalAITabBar.TabItem(icon: "chart.bar", text: "Progress"),
        CalAITabBar.TabItem(icon: "person.2", text: "Social"),
        CalAITabBar.TabItem(icon: "person", text: "Profile")
    ]
    
    var body: some View {
        ZStack {
            // Main tab view - using SwiftUI TabView for the container
            ZStack {
                Color.theme.background.ignoresSafeArea()
                
                TabView(selection: $router.selectedTab) {
                    // Challenges Tab
                    ChallengesView()
                        .environmentObject(router)
                        .tag(0)
                    
                    // Progress Tab
                    ProgressView()
                        .environmentObject(router)
                        .tag(1)
                    
                    // Social Feed Tab (Disabled for now)
                    ZStack(alignment: .bottom) {
                        SocialView()
                            .environmentObject(router)
                        
                        // Remove the Challenge a friend button as it's not implemented yet
                    }
                    .tag(2)
                    
                    // Profile Tab
                    ProfileView()
                        .environmentObject(router)
                        .tag(3)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                // Fix: Use easeOut animation for smoother tab transitions
                .animation(.easeOut(duration: 0.2), value: router.selectedTab)
                .padding(.bottom, CalAIDesignTokens.tabBarHeight + safeAreaBottom + 10) // Added extra padding
                .withTabTransition(router: router) // Apply transition effect to prevent flashing
                
                // Only show the custom tab bar
                VStack {
                    Spacer()
                    customTabBar
                }
            }
            
            // Paywall overlay
            if showPaywall {
                paywallOverlay
            }
            
            // Show notification permission request for new users
            if showNotificationSettings {
                notificationPermissionOverlay
            }
            
            // Add action overlay when showAddAction is true
            if showAddAction {
                addActionOverlay
            }
        }
        .ignoresSafeArea(.keyboard)
        .accentColor(Color.theme.accent)
        // Prevent unwanted animations but allow tab bar to remain visible
        .transaction { transaction in
            // Only disable animations for specific properties
            if router.tabIsChanging {
                transaction.animation = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showNotificationSettings)) { _ in
            withAnimation {
                showNotificationSettings = true
            }
        }
        .onAppear {
            // Calculate safe area for tab bar
            updateSafeAreaInsets()
            
            // Check onboarding status - we show subscription options after a short delay
            let workItem = DispatchWorkItem {
                Task {
                    // Don't show paywall immediately after user authentication
                    // Only show paywall if user hasn't seen it before AND has been using the app for some time
                    if !subscriptionService.showPaywall && !subscriptionService.isProUser {
                        // Check if user just signed in - in that case, don't show paywall yet
                        let currentTime = Date()
                        if let signInTime = userSession.lastSignInTime, 
                           currentTime.timeIntervalSince(signInTime) > 300 { // Only show if user signed in more than 5 minutes ago
                            withAnimation {
                                showPaywall = true
                                subscriptionService.showPaywall = true // Mark as seen
                            }
                        }
                    }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: workItem)
            
            // Set up tab bar appearance
            setupTabBarAppearance()
        }
        .onChange(of: UIDevice.current.orientation) { _ in
            // Update safe area when device rotates
            updateSafeAreaInsets()
        }
        .onReceive(subscriptionService.$showPaywall) { newValue in
            withAnimation {
                showPaywall = newValue
            }
        }
    }
    
    // MARK: - Helper Views
    
    private var addActionOverlay: some View {
        ZStack {
            // Dimmed background with tap-to-dismiss
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showAddAction = false
                    }
                }
            
            // Floating action sheet
            VStack(spacing: 16) {
                // Sheet handle for better UX - subtle line indicating draggability
                Capsule()
                    .fill(Color.theme.subtext.opacity(0.3))
                    .frame(width: 40, height: 4)
                    .padding(.top, 12)
                
                // Action items with icons, titles and subtitles
                ActionSheetItem(
                    icon: "flag.fill",
                    title: "New Challenge",
                    subtitle: "Start a fresh 100-day goal",
                    isPrimary: true
                ) {
                    hapticFeedback(.medium)
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showAddAction = false
                    }
                    // Navigate to add challenge view - don't wrap in animation
                    router.changeTab(to: 0) // Use changeTab instead of direct assignment
                    // Show the new challenge view (in implementation would add logic to show proper sheet)
                }
                
                ActionSheetItem(
                    icon: "checkmark.circle.fill",
                    title: "Check In",
                    subtitle: "Log your progress for today",
                    isPrimary: false
                ) {
                    hapticFeedback(.medium)
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showAddAction = false
                        // Show log entry flow
                        // Implementation would navigate to appropriate screen
                    }
                }
                
                // Pro-locked feature (grayed out)
                ActionSheetItem(
                    icon: "person.3.fill",
                    title: "Group Challenge",
                    subtitle: "Complete goals with friends",
                    isPrimary: false,
                    isLocked: true
                ) {
                    hapticFeedback(.medium)
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showAddAction = false
                        // Would show paywall
                        subscriptionService.showPaywall = true
                    }
                }
                
                // Cancel button
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showAddAction = false
                    }
                } label: {
                    Text("Cancel")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.theme.subtext)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.theme.background)
                    .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 4)
            )
            .frame(width: UIScreen.main.bounds.width * 0.9) // 90% of screen width
            // Animate from bottom with spring motion
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
    
    private var paywallOverlay: some View {
        PaywallView()
            .environmentObject(themeManager)
            .withAppTheme() // Apply theme explicitly to the overlay
            .transition(.opacity)
            .zIndex(100)
    }
    
    private var notificationPermissionOverlay: some View {
        NotificationSettingsView(isPresented: $showNotificationSettings)
            .environmentObject(themeManager)
            .withAppTheme() // Apply theme explicitly to the overlay
            .transition(.opacity)
            .zIndex(101)
    }
    
    private var customTabBar: some View {
        VStack(spacing: 0) {
            // Tab bar divider
            Divider()
                .opacity(0.2)
            
            ZStack(alignment: .center) {
                // Floating action button for creating new challenges
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showAddAction = true
                    }
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.theme.accent, Color.theme.accent.opacity(0.9)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .shadow(color: Color.theme.accent.opacity(0.25), radius: 6, x: 0, y: 3)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                }
                .offset(y: -30) // Increased offset to make button more visible
                .zIndex(2) // Ensures it appears above tab bar
                
                // Tab items with icons and labels
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    
                    ForEach(Array(tabItems.enumerated()), id: \.offset) { index, item in
                        Button(action: {
                            // Use the router's changeTab method for proper tab switching
                            if router.selectedTab != index {
                                hapticFeedback(.light)
                                router.changeTab(to: index)
                            }
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: item.icon)
                                    .font(.system(size: 20, weight: router.selectedTab == index ? .semibold : .regular))
                                    .foregroundColor(router.selectedTab == index ? 
                                                    Color.theme.accent : 
                                                    (colorScheme == .dark ? Color.white.opacity(0.7) : Color.theme.subtext.opacity(0.8)))
                                
                                Text(item.text)
                                    .font(.system(size: 10, weight: router.selectedTab == index ? .semibold : .medium))
                                    .foregroundColor(router.selectedTab == index ? 
                                                    Color.theme.accent : 
                                                    (colorScheme == .dark ? Color.white.opacity(0.7) : Color.theme.subtext.opacity(0.8)))
                            }
                            .frame(height: CalAIDesignTokens.tabBarHeight - 10) // Reduced height slightly
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(TabBarButtonStyle())
                        
                        Spacer(minLength: 0)
                    }
                }
                .padding(.horizontal, 16)
                .background(Color.theme.surface.opacity(0.98))
            }
            .frame(height: CalAIDesignTokens.tabBarHeight)
            
            // Extra space that extends to the bottom safe area
            if safeAreaBottom > 0 {
                Rectangle()
                    .fill(Color.theme.surface.opacity(0.98))
                    .frame(height: safeAreaBottom)
            }
        }
        .background(Color.theme.surface.opacity(0.98))
        .ignoresSafeArea(edges: .bottom)
        .zIndex(2)
    }
    
    // Helper function for consistent haptic feedback
    private func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
    private func setupTabBarAppearance() {
        // Implementation of setupTabBarAppearance method
    }
    
    // MARK: - Helper Methods
    
    private func updateSafeAreaInsets() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            safeAreaBottom = window.safeAreaInsets.bottom
            print("Safe area bottom updated: \(safeAreaBottom)")
        }
    }
}

// MARK: - Action Sheet Components

/// Custom action sheet item with icon, title, subtitle and optional locked state
struct ActionSheetItem: View {
    let icon: String
    let title: String
    let subtitle: String
    let isPrimary: Bool
    var isLocked: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isPrimary ? Color.theme.accent : Color.theme.surface)
                        .frame(width: 40, height: 40)
                        .overlay(
                            !isPrimary ? Circle()
                                .stroke(Color.theme.accent, lineWidth: 1.5) : nil
                        )
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(isPrimary ? .white : .theme.accent)
                }
                
                // Title and subtitle
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppTypography.body(.medium))
                        .foregroundColor(isLocked ? .theme.subtext.opacity(0.6) : .theme.text)
                    
                    Text(subtitle)
                        .font(AppTypography.caption1())
                        .foregroundColor(isLocked ? .theme.subtext.opacity(0.5) : .theme.subtext)
                }
                
                Spacer()
                
                // Lock icon for pro-locked features
                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(AppTypography.subhead())
                        .foregroundColor(.theme.subtext.opacity(0.6))
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.theme.surface)
            )
        }
        .disabled(isLocked)
        .buttonStyle(SpringPressButtonStyle())
    }
}

// Button style for spring animation on press
struct SpringPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// Button style for tab items
private struct TabBarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct MainApp_ChallengesTabView: View {
    var body: some View {
        ChallengesView()
    }
}

struct ProgressTabView: View {
    @EnvironmentObject var progressViewModel: ProgressDashboardViewModel
    
    var body: some View {
        ProgressView()
            .environmentObject(progressViewModel)
    }
}

struct MainApp_SocialTabView: View {
    var body: some View {
        SocialView()
    }
}

struct ProfileTabView: View {
    var body: some View {
        ProfileView()
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



