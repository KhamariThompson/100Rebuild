import SwiftUI
import FirebaseAuth
import MessageUI
import StoreKit
import FirebaseFirestore
import UserNotifications

// Enum for settings sections
enum SettingsSectionType {
    case account
    case subscription
    case data
    case notifications
    case appearance
    case community
    case legal
    case appInfo
}

struct SettingsView: View {
    // Environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var subscriptionService: SubscriptionService
    @EnvironmentObject var notificationService: NotificationService
    @EnvironmentObject var themeManager: ThemeManager
    
    // Section focus
    var initialSection: SettingsSectionType?
    @State private var scrollToSection: SettingsSectionType?
    
    // State
    @State private var showingChangeEmail = false
    @State private var showingChangePassword = false
    @State private var showingChangeUsername = false
    @State private var isRestoringPurchases = false
    @State private var isPerformingAction = false
    @State private var showingShareSheet = false
    @State private var showingEmailComposer = false
    @State private var showingDeleteConfirmation = false
    @State private var showingDeleteChallengesConfirmation = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isNotificationsEnabled = false
    @State private var showSuccessMessage = false
    @State private var successMessage = ""
    @State private var selectedTheme: AppThemeMode = .system // Local state for theme selection
    
    // Notification Settings
    @State private var isDailyReminderEnabled: Bool = true
    @State private var isStreakReminderEnabled: Bool = true
    @State private var reminderTime: Date = Calendar.current.date(from: DateComponents(hour: 20, minute: 0)) ?? Date()
    @State private var isSoundEnabled: Bool = true
    @State private var isVibrationEnabled: Bool = true
    @State private var showingPermissionAlert = false
    
    // Display name state
    @State private var displayName: String = ""
    @State private var isEditingDisplayName = false
    @State private var isUpdatingDisplayName = false
    @State private var displayNameErrorMessage: String? = nil
    
    // Presentation and gestures 
    @State private var dragOffset: CGFloat = 0
    private var isDraggable: Bool = true
    
    var body: some View {
        ZStack {
            // Main content container
            VStack(spacing: 0) {
                // Modern header with large title
                settingsHeader
                
                // Main content container
                mainContent
            }
            
            // Bottom drag indicator if modal
            if isDraggable {
                bottomDragIndicator
            }
        }
        .background(Color.theme.background.ignoresSafeArea())
        .accentColor(Color.theme.accent)
        // Sheets
        .fixedSheet(isPresented: $showingChangeEmail) {
            ChangeEmailView()
        }
        .fixedSheet(isPresented: $showingChangePassword) {
            ChangePasswordView()
        }
        .fixedSheet(isPresented: $showingChangeUsername) {
            ChangeUsernameView()
        }
        .fixedSheet(isPresented: $subscriptionService.showPaywall) {
            PaywallView()
        }
        .fixedSheet(isPresented: $showingEmailComposer) {
            if EmailComposer.canSendEmail() {
                EmailComposer(
                    recipient: "support@100days.site",
                    subject: "100Days App Support",
                    body: getEmailSupportBody()
                ) { _, _ in }
            }
        }
        .fixedSheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [
                AppStoreHelper.getShareMessage(),
                AppStoreHelper.getShareableAppLink()
            ])
        }
        // Alerts
        .alert("Success", isPresented: $showSuccessMessage) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(successMessage)
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .alert("Delete Account", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    await handleDeleteAccount()
                }
            }
        } message: {
            Text("Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently deleted.")
        }
        .alert("Delete All Challenges", isPresented: $showingDeleteChallengesConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    await handleDeleteAllChallenges()
                }
            }
        } message: {
            Text("Are you sure you want to delete all your challenges? This action cannot be undone.")
        }
        .alert("Notification Permission", isPresented: $showingPermissionAlert) {
            Button("Settings", role: .none) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please enable notifications in settings to receive reminders.")
        }
        .onAppear {
            syncWithNotificationService()
            selectedTheme = themeManager.currentTheme
            
            // Load user's display name
            Task {
                await loadUserProfile()
            }
            
            // Scroll to the specified section if needed
            scrollToInitialSectionIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .appThemeDidChange)) { notification in
            // Update selectedTheme when it changes externally
            if let themeRawValue = notification.object as? String,
               let updatedTheme = AppThemeMode(rawValue: themeRawValue) {
                selectedTheme = updatedTheme
            } else {
                selectedTheme = themeManager.currentTheme
            }
        }
        // Add swipe gesture to dismiss if draggable
        .gesture(isDraggable ? DragGesture()
            .onChanged { gesture in
                if gesture.translation.height > 0 {
                    self.dragOffset = gesture.translation.height
                }
            }
            .onEnded { gesture in
                if gesture.translation.height > 100 {
                    withAnimation(.easeOut) {
                        self.dismiss()
                    }
                } else {
                    withAnimation(.easeOut) {
                        self.dragOffset = 0
                    }
                }
            } : nil)
    }
    
    // MARK: - Header Views
    
    private var settingsHeader: some View {
        ZStack(alignment: .bottom) {
            // Background gradient/solid color
            Rectangle()
                .fill(Color.theme.background)
                .frame(height: 108)
                .overlay(
                    // Light bottom border for visual separation
                    Rectangle()
                        .fill(Color.theme.border)
                        .frame(height: 1)
                        .opacity(0.5),
                    alignment: .bottom
                )
            
            VStack(spacing: 0) {
                // Top navigation row
                HStack {
                    // Back/dismiss button
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            
                            Text("Back")
                                .font(.system(size: 16, weight: .medium))
                                .opacity(0.9)
                        }
                        .foregroundColor(Color.theme.accent)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(AppScaleButtonStyle())
                    .padding(.leading, 16)
                    
                    Spacer()
                    
                    Text("Settings")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color.theme.text)
                    
                    Spacer()
                    
                    // Optional right button (for symmetry, can be hidden)
                    Button(action: { dismiss() }) {
                        Text("Done")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color.theme.accent)
                    }
                    .buttonStyle(AppScaleButtonStyle())
                    .padding(.trailing, 16)
                }
                .padding(.top, 8)
                
                // Main title (larger)
                Text("Settings")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(Color.theme.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 16)
            }
        }
        .offset(y: -dragOffset * 0.2) // Slight parallax effect on drag
    }
    
    private var bottomDragIndicator: some View {
        VStack {
            Spacer()
            
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.gray.opacity(0.4))
                .frame(width: 40, height: 5)
                .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }
    
    // MARK: - Content Views
    
    private var mainContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 20) {
                    accountSection
                    subscriptionSection
                    dataSection
                    notificationsSection
                    appearanceSection
                    communitySection
                    legalSection
                    appInfoSection
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
            .offset(y: -dragOffset * 0.8) // Content follows drag
            .onChange(of: scrollToSection) { oldValue, newValue in
                if let section = newValue {
                    withAnimation {
                        proxy.scrollTo(section, anchor: .top)
                    }
                    // Reset once scrolled
                    scrollToSection = nil
                }
            }
        }
    }
    
    // MARK: - Section Views
    
    private var accountSection: some View {
        SettingsSection(title: "Account", icon: "person.crop.circle.fill") {
            SettingsCard {
                VStack(alignment: .leading, spacing: 0) {
                    // Display name field
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            HStack(spacing: 8) {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Color.theme.accent.opacity(0.8))
                                
                                if isEditingDisplayName {
                                    TextField("Your name", text: $displayName)
                                        .font(.system(size: 16))
                                        .foregroundColor(Color.theme.text)
                                        .disableAutocorrection(true)
                                } else {
                                    Text(displayName.isEmpty ? "Add your name" : displayName)
                                        .font(.system(size: 16))
                                        .foregroundColor(displayName.isEmpty ? Color.theme.subtext : Color.theme.text)
                                }
                            }
                            .padding(.vertical, 14)
                            
                            Spacer()
                            
                            if isEditingDisplayName {
                                // Save button
                                Button {
                                    Task {
                                        await updateDisplayName()
                                    }
                                } label: {
                                    if isUpdatingDisplayName {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle())
                                    } else {
                                        Text("Save")
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(Color.theme.accent)
                                    }
                                }
                                .buttonStyle(AppScaleButtonStyle())
                                .disabled(isUpdatingDisplayName)
                                
                                // Cancel button
                                Button {
                                    isEditingDisplayName = false
                                    Task {
                                        await loadUserProfile() // Reset to original value
                                    }
                                } label: {
                                    Text("Cancel")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(Color.theme.subtext)
                                }
                                .buttonStyle(AppScaleButtonStyle())
                                .padding(.leading, 8)
                            } else {
                                // Edit button
                                Button {
                                    isEditingDisplayName = true
                                } label: {
                                    Text("Edit")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(Color.theme.accent)
                                }
                                .buttonStyle(AppScaleButtonStyle())
                            }
                        }
                        
                        // Display error message if there is one
                        if let errorMessage = displayNameErrorMessage {
                            Text(errorMessage)
                                .font(.system(size: 13))
                                .foregroundColor(.red)
                                .padding(.bottom, 4)
                        }
                    }
                    
                    Divider()
                    
                    // Username display or selection
                    HStack {
                        if let username = userSession.username {
                            // Username display
                            HStack(spacing: 8) {
                                Image(systemName: "at")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Color.theme.accent.opacity(0.8))
                                
                                Text(username)
                                    .font(.system(size: 16, design: .monospaced))
                                    .foregroundColor(Color.theme.text)
                                    .fontWeight(.medium)
                            }
                            .padding(.vertical, 14)
                            
                            Spacer()
                            
                            // Change button
                            Button {
                                showingChangeUsername = true
                            } label: {
                                Text("Change")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(Color.theme.accent)
                            }
                            .buttonStyle(AppScaleButtonStyle())
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color.theme.subtext.opacity(0.6))
                        } else {
                            // No username set yet - prompt to create one
                            HStack(spacing: 8) {
                                Image(systemName: "person.fill.badge.plus")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Color.theme.accent.opacity(0.8))
                                
                                Text("Create Username")
                                    .font(.system(size: 16))
                                    .foregroundColor(Color.theme.text)
                            }
                            .padding(.vertical, 14)
                            
                            Spacer()
                            
                            Button {
                                showingChangeUsername = true
                            } label: {
                                HStack {
                                    Text("Set Now")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(Color.theme.accent)
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(Color.theme.subtext.opacity(0.6))
                                }
                            }
                            .buttonStyle(AppScaleButtonStyle())
                        }
                    }
                    
                    Divider()
                    
                    // Email button
                    Button(action: { showingChangeEmail = true }) {
                        SettingsRow(icon: "envelope.fill", title: "Change Email", color: .theme.text, showChevron: true)
                    }
                    
                    Divider()
                    
                    // Password button
                    Button(action: { showingChangePassword = true }) {
                        SettingsRow(icon: "lock.fill", title: "Change Password", color: .theme.text, showChevron: true)
                    }
                    
                    Divider()
                    
                    // Sign Out
                    Button(action: { 
                        Task {
                            await handleSignOut()
                        }
                    }) {
                        SettingsRow(icon: "arrow.right.square", title: "Sign Out", color: .theme.text, showChevron: true)
                    }
                    .disabled(isPerformingAction)
                    
                    Divider()
                    
                    // Delete Account (destructive)
                    Button(action: { showingDeleteConfirmation = true }) {
                        SettingsRow(
                            icon: "trash.fill", 
                            title: "Delete Account", 
                            color: .red, 
                            showChevron: true
                        )
                    }
                    .disabled(isPerformingAction)
                    
                    // Show a progress indicator if account action is in progress
                    if isPerformingAction {
                        HStack {
                            Spacer()
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                            Spacer()
                        }
                        .padding(.vertical, 10)
                    }
                }
                .padding(.vertical, 0)
            }
        }
        .id(SettingsSectionType.account) // Add identifier for scrolling
    }
    
    private var subscriptionSection: some View {
        SettingsSection(title: "Subscription", icon: "star.fill") {
            SettingsCard {
                VStack(alignment: .leading, spacing: 0) {
                    // Current plan display
                    HStack {
                        HStack(spacing: 10) {
                            Image(systemName: subscriptionService.isProUser ? "crown.fill" : "star")
                                .font(.system(size: 18))
                                .foregroundColor(subscriptionService.isProUser ? Color.yellow : Color.theme.subtext)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Current Plan")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.theme.subtext)
                                
                                Text(subscriptionService.isProUser ? "Pro" : "Free")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(subscriptionService.isProUser ? Color.yellow : Color.theme.text)
                            }
                        }
                        
                        Spacer()
                        
                        if subscriptionService.isProUser, let renewalDate = subscriptionService.renewalDate {
                            Text("Renews \(renewalDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundColor(Color.theme.subtext)
                        }
                    }
                    .padding(.vertical, 14)
                    
                    Divider()
                    
                    // Manage subscription
                    if subscriptionService.isProUser {
                        Button(action: {
                            AppStoreHelper.openSubscriptionManagement()
                        }) {
                            SettingsRow(icon: "creditcard", title: "Manage Subscription", color: .theme.text, showChevron: true)
                        }
                    } else {
                        Button(action: {
                            subscriptionService.presentSubscriptionSheet()
                        }) {
                            SettingsRow(
                                icon: "star.circle.fill", 
                                title: "Upgrade to Pro", 
                                color: Color.yellow, 
                                showChevron: true
                            )
                        }
                    }
                    
                    Divider()
                    
                    // Restore purchases
                    Button(action: restorePurchases) {
                        HStack {
                            SettingsRow(
                                icon: "arrow.clockwise", 
                                title: "Restore Purchases", 
                                color: .theme.text, 
                                showChevron: true
                            )
                            
                            if isRestoringPurchases {
                                Spacer()
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .padding(.trailing, 8)
                            }
                        }
                    }
                    .disabled(isRestoringPurchases)
                }
                .padding(.vertical, 0)
            }
        }
        .id(SettingsSectionType.subscription)
    }
    
    private var dataSection: some View {
        SettingsSection(title: "Data & Challenges", icon: "tray.full.fill") {
            SettingsCard {
                VStack(alignment: .leading, spacing: 0) {
                    Button(action: { showingDeleteChallengesConfirmation = true }) {
                        SettingsRow(
                            icon: "trash.fill", 
                            title: "Delete All Challenges", 
                            color: .red, 
                            showChevron: true
                        )
                    }
                    .disabled(isPerformingAction)
                    
                    if isPerformingAction {
                        HStack {
                            Spacer()
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                            Spacer()
                        }
                        .padding(.vertical, 10)
                    }
                }
                .padding(.vertical, 0)
            }
        }
        .id(SettingsSectionType.data)
        .alert("Delete All Challenges", isPresented: $showingDeleteChallengesConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    await handleDeleteAllChallenges()
                }
            }
        } message: {
            Text("Are you sure you want to delete all your challenges? This action cannot be undone.")
        }
    }
    
    private var notificationsSection: some View {
        SettingsSection(title: "Notifications", icon: "bell.fill") {
            SettingsCard {
                VStack(alignment: .leading, spacing: 16) {
                    // Notification Permission Status
                    if !notificationService.isAuthorized {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Notifications Disabled")
                                .font(.headline)
                                .foregroundColor(Color.theme.text)
                            
                            Text("Enable notifications to receive reminders for your challenges.")
                                .font(.subheadline)
                                .foregroundColor(Color.theme.subtext)
                            
                            Button("Enable Notifications") {
                                requestNotificationPermission()
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                            .background(Color.theme.accent)
                            .cornerRadius(8)
                            .padding(.top, 4)
                        }
                        .padding(.vertical, 4)
                        
                        Divider()
                    }
                    
                    // Daily Reminder
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Daily Reminder")
                            .font(.headline)
                            .foregroundColor(Color.theme.text)
                        
                        Toggle("Enable Daily Reminder", isOn: $isDailyReminderEnabled)
                            .onChange(of: isDailyReminderEnabled) { oldValue, newValue in
                                if newValue {
                                    Task { try? await scheduleReminders() }
                                } else {
                                    Task { try? await cancelReminders() }
                                }
                            }
                            .tint(Color.theme.accent)
                            .disabled(!notificationService.isAuthorized)
                        
                        DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.compact)
                            .onChange(of: reminderTime) { oldValue, newValue in
                                if isDailyReminderEnabled {
                                    Task { try? await updateReminderTime() }
                                }
                            }
                            .tint(Color.theme.accent)
                            .disabled(!notificationService.isAuthorized || !isDailyReminderEnabled)
                    }
                    .padding(.vertical, 4)
                    
                    Divider()
                    
                    // Streak Reminder
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Streak Reminder")
                            .font(.headline)
                            .foregroundColor(Color.theme.text)
                        
                        Toggle("Enable Streak Reminder", isOn: $isStreakReminderEnabled)
                            .onChange(of: isStreakReminderEnabled) { oldValue, newValue in
                                if newValue {
                                    Task { try? await scheduleStreakReminder() }
                                } else {
                                    Task { try? await cancelStreakReminder() }
                                }
                            }
                            .tint(Color.theme.accent)
                            .disabled(!notificationService.isAuthorized)
                        
                        Text("Get notified when you're about to break your streak")
                            .font(.subheadline)
                            .foregroundColor(Color.theme.subtext)
                    }
                    .padding(.vertical, 4)
                    
                    Divider()
                    
                    // Notification Settings
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Settings")
                            .font(.headline)
                            .foregroundColor(Color.theme.text)
                        
                        Toggle("Sound", isOn: $isSoundEnabled)
                            .tint(Color.theme.accent)
                            .disabled(!notificationService.isAuthorized)
                            .onChange(of: isSoundEnabled) { _, _ in
                                Task { await updateNotificationSettings() }
                            }
                        
                        Toggle("Vibration", isOn: $isVibrationEnabled)
                            .tint(Color.theme.accent)
                            .disabled(!notificationService.isAuthorized)
                            .onChange(of: isVibrationEnabled) { _, _ in
                                Task { await updateNotificationSettings() }
                            }
                    }
                    .padding(.vertical, 4)
                }
                .padding(.vertical, 4)
            }
        }
        .id(SettingsSectionType.notifications)
    }
    
    private var appearanceSection: some View {
        SettingsSection(title: "App Preferences", icon: "paintpalette.fill") {
            SettingsCard {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Theme")
                        .font(.headline)
                        .foregroundColor(Color.theme.text)
                    
                    // Enhanced theme selector with visual previews
                    HStack(spacing: 12) {
                        ForEach(AppThemeMode.allCases) { themeMode in
                            let isThemeSelected = selectedTheme == themeMode
                            let themeAction = {
                                hapticFeedback(style: .medium)
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    themeManager.setTheme(themeMode)
                                    // Force UI update after a short delay
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        selectedTheme = themeManager.currentTheme
                                    }
                                }
                            }
                            
                            ThemeOptionButton(
                                theme: themeMode,
                                isSelected: isThemeSelected,
                                action: themeAction
                            )
                        }
                    }
                    .padding(.vertical, 8)
                    
                    // Short explanation of the system theme option
                    if selectedTheme == .system {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle")
                                .foregroundColor(Color.theme.accent)
                            Text("System theme follows your device settings")
                                .font(.caption)
                                .foregroundColor(Color.theme.subtext)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .id(SettingsSectionType.appearance)
    }
    
    // Custom theme option button with preview
    struct ThemeOptionButton: View {
        let theme: AppThemeMode
        let isSelected: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                VStack(spacing: 12) {
                    // Theme preview circle with day/night visualization
                    ZStack {
                        Circle()
                            .fill(themePreviewColor)
                            .frame(width: 60, height: 60)
                            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                        
                        Image(systemName: theme.iconName)
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(themeIconColor)
                    }
                    
                    // Theme name
                    Text(theme.displayName)
                        .font(.subheadline)
                        .fontWeight(isSelected ? .semibold : .medium)
                        .foregroundColor(isSelected ? Color.theme.accent : Color.theme.text)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? Color.theme.accent.opacity(0.1) : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isSelected ? Color.theme.accent : Color.clear, lineWidth: 2)
                        )
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(AppScaleButtonStyle())
        }
        
        // Colors that represent the theme preview
        private var themePreviewColor: Color {
            switch theme {
            case .light:
                return Color(UIColor.systemGray6)
            case .dark:
                return Color(UIColor.systemGray)
            case .system:
                return Color.theme.background
            }
        }
        
        private var themeIconColor: Color {
            switch theme {
            case .light:
                return Color.black
            case .dark:
                return Color.white
            case .system:
                return Color.theme.accent
            }
        }
    }
    
    private var communitySection: some View {
        SettingsSection(title: "Community & Support", icon: "bubble.left.and.bubble.right.fill") {
            SettingsCard {
                VStack(alignment: .leading, spacing: 0) {
                    Button(action: {
                        if EmailComposer.canSendEmail() {
                            showingEmailComposer = true
                        } else {
                            let encodedSubject = "100Days App Support".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                            if let url = URL(string: "mailto:support@100days.site?subject=\(encodedSubject)") {
                                UIApplication.shared.open(url)
                            }
                        }
                    }) {
                        SettingsRow(icon: "envelope.fill", title: "Contact Support", color: .theme.text, showChevron: true)
                    }
                    
                    Divider()
                    
                    Button(action: {
                        AppStoreHelper.openAppStoreReview()
                    }) {
                        SettingsRow(icon: "star.bubble.fill", title: "Rate on App Store", color: .theme.text, showChevron: true)
                    }
                    
                    Divider()
                    
                    Button(action: {
                        if let twitterURL = URL(string: "https://twitter.com/100daysapp") {
                            UIApplication.shared.open(twitterURL)
                        }
                    }) {
                        SettingsRow(icon: "bird.fill", title: "Follow Us on Twitter", color: .theme.text, showChevron: true)
                    }
                }
                .padding(.vertical, 0)
            }
        }
        .id(SettingsSectionType.community)
    }
    
    private var legalSection: some View {
        SettingsSection(title: "Legal", icon: "doc.plaintext.fill") {
            SettingsCard {
                VStack(alignment: .leading, spacing: 0) {
                    Link(destination: URL(string: "https://100days.site/privacy")!) {
                        SettingsRow(icon: "hand.raised.fill", title: "Privacy Policy", color: .theme.text, showChevron: true)
                    }
                    
                    Divider()
                    
                    Link(destination: URL(string: "https://100days.site/terms")!) {
                        SettingsRow(icon: "doc.text.fill", title: "Terms of Service", color: .theme.text, showChevron: true)
                    }
                }
                .padding(.vertical, 0)
            }
        }
        .id(SettingsSectionType.legal)
    }
    
    private var appInfoSection: some View {
        SettingsSection(title: "App Info", icon: "info.circle.fill") {
            SettingsCard {
                VStack(alignment: .leading, spacing: 16) {
                    // Version info with icons
                    InfoRow(title: "Version", value: getAppVersion(), icon: "number")
                    InfoRow(title: "Build", value: getBuildNumber(), icon: "hammer.fill")
                    InfoRow(title: "Current Date", value: getFormattedDate(), icon: "calendar")
                    
                    // App links
                    Divider()
                        .padding(.vertical, 8)
                    
                    Link(destination: URL(string: "https://100days.site")!) {
                        SettingsRow(icon: "globe", title: "Visit Website", color: .theme.text, showChevron: true)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .id(SettingsSectionType.appInfo)
    }
    
    // MARK: - Helper Views
    
    private struct InfoRow: View {
        let title: String
        let value: String
        var icon: String? = nil
        
        var body: some View {
            HStack(spacing: 12) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(Color.theme.accent.opacity(0.7))
                        .frame(width: 24, height: 24)
                        .background(
                            Circle()
                                .fill(Color.theme.accent.opacity(0.1))
                                .frame(width: 30, height: 30)
                        )
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.caption)
                        .foregroundColor(Color.theme.subtext)
                    
                    Text(value)
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundColor(Color.theme.text)
                }
                
                Spacer()
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .contextMenu {
                Button(action: {
                    UIPasteboard.general.string = value
                    // Could add haptic feedback here
                }) {
                    Label("Copy", systemImage: "doc.on.doc")
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func themeIcon(for theme: String) -> String {
        switch theme {
        case "light": return "sun.max.fill"
        case "dark": return "moon.fill"
        default: return "gearshape.fill"
        }
    }
    
    private func getEmailSupportBody() -> String {
        """
        
        
        ----------
        Device: \(UIDevice.current.model)
        iOS Version: \(UIDevice.current.systemVersion)
        App Version: \(getAppVersion()) (\(getBuildNumber()))
        ----------
        """
    }
    
    private func getAppVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    private func getBuildNumber() -> String {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    private func getFormattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: Date())
    }
    
    private func hapticFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
    // MARK: - Action Handlers
    
    private func handleSignOut() async {
        isPerformingAction = true
        
        do {
            // First, reset all local state and cached values
            await MainActor.run {
                // Reset UI state
                displayName = ""
                isDailyReminderEnabled = false
                isStreakReminderEnabled = false
                // Any other state that should be reset
            }
            
            // Use the non-throwing version to ensure we always sign out
            await userSession.signOutWithoutThrowing()
            
            // Wait for the auth state to update
            for _ in 0..<10 { // Try for up to 1 second
                if case .signedOut = userSession.authState {
                    break
                }
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
            
            // Dismiss the settings view
            await MainActor.run {
                isPerformingAction = false
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to sign out: \(error.localizedDescription)"
                showingError = true
                isPerformingAction = false
            }
        }
    }
    
    private func handleDeleteAccount() async {
        isPerformingAction = true
        
        do {
            guard let userId = userSession.currentUser?.uid else {
                throw NSError(domain: "App", code: 1, userInfo: [NSLocalizedDescriptionKey: "No user is signed in"])
            }
            
            // Step 1: Delete user data from Firestore first
            do {
                try await deleteUserData(userId: userId)
            } catch {
                print("Warning: Some user data may not have been deleted: \(error.localizedDescription)")
                // Continue with account deletion even if some data couldn't be deleted
            }
            
            // Step 2: Delete the Firebase Auth account
            try await userSession.deleteAccount()
            
            // Step 3: Reset all local state before navigating away
            await MainActor.run {
                isPerformingAction = false
                
                // Reset all relevant state
                displayName = ""
                isDailyReminderEnabled = false
                isStreakReminderEnabled = false
                
                // Reset any other state variables here
                
                // Now dismiss the view
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to delete account: \(error.localizedDescription)"
                showingError = true
                isPerformingAction = false
            }
        }
    }
    
    private func deleteUserData(userId: String) async throws {
        let db = Firestore.firestore()
        
        // Delete all challenges using batched operations
        try await deleteCollection(db.collection("users").document(userId).collection("challenges"), batchSize: 50)
        
        // Delete analytics data if it exists
        try await deleteCollection(db.collection("users").document(userId).collection("analytics"), batchSize: 50)
        
        // Delete preferences data if it exists
        try await deleteCollection(db.collection("users").document(userId).collection("preferences"), batchSize: 50)
        
        // Delete user data from profile/social collections if they exist
        try await deleteCollection(db.collection("profiles").whereField("userId", isEqualTo: userId), batchSize: 20)
        
        // Delete the main user document itself
        try await db.collection("users").document(userId).delete()
        
        // Delete any other user-related data like comments, likes, etc.
        // This would depend on the specific data model of the app
    }
    
    // Helper function to delete a collection in batches (Firestore best practice)
    private func deleteCollection(_ query: Query, batchSize: Int) async throws {
        let snapshot = try await query.limit(to: batchSize).getDocuments()
        guard !snapshot.documents.isEmpty else { return }
        
        let db = Firestore.firestore()
        let batch = db.batch()
        
        for document in snapshot.documents {
            batch.deleteDocument(document.reference)
        }
        
        try await batch.commit()
        
        // Recursively delete remaining documents
        try await deleteCollection(query, batchSize: batchSize)
    }
    
    private func handleDeleteAllChallenges() async {
        guard let userId = userSession.currentUser?.uid else {
            errorMessage = "You must be signed in to delete challenges"
            showingError = true
            return
        }
        
        isPerformingAction = true
        
        do {
            let challengeStore = ChallengeStore.shared
            
            // Get all current challenges
            let allChallenges = challengeStore.challenges
            
            // Delete each challenge one by one using the challenge store
            for challenge in allChallenges {
                try await challengeStore.deleteChallenge(id: challenge.id)
                // Small delay to avoid overwhelming Firestore
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
            
            // Make sure challenge store refreshes to reflect the changes
            await challengeStore.refreshChallenges()
            
            // Notify any services that track challenges about the deletion
            NotificationCenter.default.post(name: NSNotification.Name("ChallengesDeleted"), object: nil)
            
            await MainActor.run {
                isPerformingAction = false
                successMessage = "All challenges deleted successfully"
                showSuccessMessage = true
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to delete challenges: \(error.localizedDescription)"
                showingError = true
                isPerformingAction = false
            }
        }
    }
    
    private func restorePurchases() {
        isRestoringPurchases = true
        
        Task {
            do {
                try await subscriptionService.restorePurchases()
                
                await MainActor.run {
                    isRestoringPurchases = false
                    successMessage = "Purchases restored successfully"
                    showSuccessMessage = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                    isRestoringPurchases = false
                }
            }
        }
    }
    
    // MARK: - Notification Helpers
    
    private func syncWithNotificationService() {
        // Get notification settings from the service
        isDailyReminderEnabled = notificationService.isDailyReminderEnabled
        isStreakReminderEnabled = notificationService.isStreakReminderEnabled
        
        // Validate reminderTime before using it
        let serviceReminderTime = notificationService.reminderTime
        if serviceReminderTime.timeIntervalSince1970 < 0 || serviceReminderTime >= Date.distantFuture {
            // Use a default time if the service has an invalid time
            reminderTime = Calendar.current.date(from: DateComponents(hour: 20, minute: 0)) ?? Date()
            
            // Also update the service with the corrected time
            notificationService.reminderTime = reminderTime
        } else {
            reminderTime = serviceReminderTime
        }
        
        isSoundEnabled = UserDefaults.standard.bool(forKey: "NotificationSoundEnabled")
        isVibrationEnabled = UserDefaults.standard.bool(forKey: "NotificationVibrationEnabled")
        
        // If they have default values, initialize them
        if UserDefaults.standard.object(forKey: "NotificationSoundEnabled") == nil {
            isSoundEnabled = true
            UserDefaults.standard.set(true, forKey: "NotificationSoundEnabled")
        }
        
        if UserDefaults.standard.object(forKey: "NotificationVibrationEnabled") == nil {
            isVibrationEnabled = true
            UserDefaults.standard.set(true, forKey: "NotificationVibrationEnabled")
        }
        
        // Check actual notification authorization status
        Task {
            let authorized = await checkNotificationAuthorization()
            if !authorized {
                await MainActor.run {
                    isDailyReminderEnabled = false
                    isStreakReminderEnabled = false
                    notificationService.isAuthorized = false
                }
            }
        }
    }
    
    // Load user profile including display name
    private func loadUserProfile() async {
        guard let userId = userSession.currentUser?.uid else { 
            // Handle case when user is not signed in
            await MainActor.run {
                displayName = ""
            }
            return 
        }
        
        // Show loading indicator
        await MainActor.run {
            isPerformingAction = true
        }
        
        do {
            let profile = try await FirebaseService.shared.fetchUserProfile(userId: userId)
            
            await MainActor.run {
                displayName = profile?.displayName ?? ""
                isPerformingAction = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load profile: \(error.localizedDescription)"
                showingError = true
                isPerformingAction = false
                
                // Set empty defaults to avoid null references
                displayName = ""
            }
            
            print("Failed to load user profile: \(error.localizedDescription)")
        }
    }
    
    // Update user's display name
    private func updateDisplayName() async {
        guard !displayName.isEmpty else {
            displayNameErrorMessage = "Name cannot be empty"
            return
        }
        
        guard let userId = userSession.currentUser?.uid else {
            displayNameErrorMessage = "You must be signed in to update your name"
            return
        }
        
        isUpdatingDisplayName = true
        displayNameErrorMessage = nil
        
        do {
            let db = Firestore.firestore()
            
            // Update the user's display name in Firestore
            try await db.collection("users").document(userId).updateData([
                "displayName": displayName
            ])
            
            // Update Firebase Auth display name if available
            if let user = Auth.auth().currentUser {
                let changeRequest = user.createProfileChangeRequest()
                changeRequest.displayName = displayName
                try await changeRequest.commitChanges()
            }
            
            // Notify about the update
            NotificationCenter.default.post(
                name: NSNotification.Name("UserProfileUpdated"),
                object: nil,
                userInfo: ["displayName": displayName]
            )
            
            await MainActor.run {
                isUpdatingDisplayName = false
                isEditingDisplayName = false
                successMessage = "Your name has been updated"
                showSuccessMessage = true
            }
        } catch {
            await MainActor.run {
                isUpdatingDisplayName = false
                displayNameErrorMessage = "Failed to update name: \(error.localizedDescription)"
            }
        }
    }
    
    private func checkNotificationAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        return settings.authorizationStatus == .authorized
    }
    
    private func requestNotificationPermission() {
        Task {
            do {
                // Request authorization
                let center = UNUserNotificationCenter.current()
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                
                await MainActor.run {
                    if granted {
                        notificationService.isAuthorized = true
                        
                        // If the user previously had reminders enabled, schedule them now
                        if isDailyReminderEnabled {
                            Task { try? await scheduleReminders() }
                        }
                        
                        if isStreakReminderEnabled {
                            Task { try? await scheduleStreakReminder() }
                        }
                    } else {
                        showingPermissionAlert = true
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Could not request notification permissions: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
    
    private func scheduleReminders() async throws {
        guard notificationService.isAuthorized else {
            isDailyReminderEnabled = false
            throw NSError(domain: "App", code: 1, userInfo: [NSLocalizedDescriptionKey: "Notifications are not authorized"])
        }
        
        // Validate reminderTime - ensure it's a valid date
        let validReminderTime: Date
        if reminderTime.timeIntervalSince1970 < 0 || reminderTime >= Date.distantFuture {
            // Use current time + 12 hours as a fallback if reminderTime is invalid
            validReminderTime = Calendar.current.date(byAdding: .hour, value: 12, to: Date()) ?? Date()
            reminderTime = validReminderTime // Update the state with valid value
        } else {
            validReminderTime = reminderTime
        }
        
        // Get time components from date
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: validReminderTime)
        let minute = calendar.component(.minute, from: validReminderTime)
        
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        // Set up notification content
        let content = UNMutableNotificationContent()
        content.title = "Daily Challenge Reminder"
        content.body = "Don't forget to check in with your challenges today!"
        content.categoryIdentifier = "dailyReminder"
        
        if isSoundEnabled {
            content.sound = UNNotificationSound.default
        }
        
        // Create trigger for daily notification
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        // Create request
        let request = UNNotificationRequest(
            identifier: "dailyReminder",
            content: content,
            trigger: trigger
        )
        
        // Schedule the notification
        try await UNUserNotificationCenter.current().add(request)
        
        // Save the preferences
        UserDefaults.standard.set(true, forKey: "isDailyReminderEnabled")
        UserDefaults.standard.set(hour, forKey: "reminderHour")
        UserDefaults.standard.set(minute, forKey: "reminderMinute")
        UserDefaults.standard.set(validReminderTime.timeIntervalSince1970, forKey: "reminderTimeInterval")
        
        // Update notification service
        notificationService.isDailyReminderEnabled = true
        notificationService.reminderTime = validReminderTime
        
        // Save to Firestore if user is logged in
        if let userId = userSession.currentUser?.uid {
            do {
                try await Firestore.firestore().collection("users").document(userId).collection("preferences").document("notifications").setData([
                    "dailyReminderEnabled": true,
                    "reminderTime": Timestamp(date: validReminderTime),
                    "reminderHour": hour,
                    "reminderMinute": minute,
                    "soundEnabled": isSoundEnabled,
                    "vibrationEnabled": isVibrationEnabled
                ], merge: true)
            } catch {
                // Log error but don't fail the function - notification will still be scheduled locally
                print("Error saving notification settings to Firestore: \(error.localizedDescription)")
            }
        }
    }
    
    private func updateReminderTime() async throws {
        // First cancel existing reminders
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["dailyReminder"])
        
        // Then reschedule with new time
        if isDailyReminderEnabled {
            try await scheduleReminders()
        }
    }
    
    private func cancelReminders() async {
        // Remove the scheduled notifications
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["dailyReminder"])
        
        // Update user defaults
        UserDefaults.standard.set(false, forKey: "isDailyReminderEnabled")
        
        // Update notification service
        notificationService.isDailyReminderEnabled = false
        
        // Update Firestore if user is logged in
        if let userId = userSession.currentUser?.uid {
            do {
                try await Firestore.firestore().collection("users").document(userId).collection("preferences").document("notifications").setData([
                    "dailyReminderEnabled": false
                ], merge: true)
            } catch {
                print("Error updating reminder settings in Firestore: \(error.localizedDescription)")
                // Don't propagate the error - reminders are already cancelled locally
            }
        }
    }
    
    private func scheduleStreakReminder() async throws {
        guard notificationService.isAuthorized else {
            isStreakReminderEnabled = false
            throw NSError(domain: "App", code: 1, userInfo: [NSLocalizedDescriptionKey: "Notifications are not authorized"])
        }
        
        // Set up fixed time for streak reminder (6 PM default)
        var dateComponents = DateComponents()
        dateComponents.hour = 18 // 6 PM
        dateComponents.minute = 0
        
        // Set up notification content
        let content = UNMutableNotificationContent()
        content.title = "Don't Break Your Streak!"
        content.body = "You haven't checked in today. Don't lose your progress!"
        content.categoryIdentifier = "streakReminder"
        
        if isSoundEnabled {
            content.sound = UNNotificationSound.default
        }
        
        // Create trigger for daily notification
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        // Create request
        let request = UNNotificationRequest(
            identifier: "streakReminder",
            content: content,
            trigger: trigger
        )
        
        // Schedule the notification
        try await UNUserNotificationCenter.current().add(request)
        
        // Save the preferences
        UserDefaults.standard.set(true, forKey: "isStreakReminderEnabled")
        
        // Update notification service
        notificationService.isStreakReminderEnabled = true
        
        // Save to Firestore if user is logged in
        if let userId = userSession.currentUser?.uid {
            do {
                try await Firestore.firestore().collection("users").document(userId).collection("preferences").document("notifications").setData([
                    "streakReminderEnabled": true,
                    "soundEnabled": isSoundEnabled,
                    "vibrationEnabled": isVibrationEnabled
                ], merge: true)
            } catch {
                // Log error but don't fail the function - notification will still work locally
                print("Error saving streak reminder settings to Firestore: \(error.localizedDescription)")
            }
        }
    }
    
    private func cancelStreakReminder() async {
        // Remove the scheduled notifications
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["streakReminder"])
        
        // Update user defaults
        UserDefaults.standard.set(false, forKey: "isStreakReminderEnabled")
        
        // Update notification service
        notificationService.isStreakReminderEnabled = false
        
        // Update Firestore if user is logged in
        if let userId = userSession.currentUser?.uid {
            do {
                try await Firestore.firestore().collection("users").document(userId).collection("preferences").document("notifications").setData([
                    "streakReminderEnabled": false
                ], merge: true)
            } catch {
                print("Error updating streak reminder settings in Firestore: \(error.localizedDescription)")
                // Don't propagate the error - streak reminders are already cancelled locally
            }
        }
    }
    
    // Validate a date before using it in Timestamp creation
    private func validDate(_ date: Date) -> Date {
        if date.timeIntervalSince1970 < 0 || date >= Date.distantFuture {
            // Return current date as a safe fallback
            return Date()
        }
        return date
    }
    
    // Update notification sound and vibration settings
    private func updateNotificationSettings() async {
        // Save to UserDefaults
        UserDefaults.standard.set(isSoundEnabled, forKey: "NotificationSoundEnabled")
        UserDefaults.standard.set(isVibrationEnabled, forKey: "NotificationVibrationEnabled")
        
        // Update existing notifications if needed
        if isDailyReminderEnabled {
            do {
                try await scheduleReminders() // This will recreate with new sound settings
            } catch {
                print("Error scheduling daily reminders: \(error.localizedDescription)")
                // Continue with other operations - don't block all settings updates
            }
        }
        
        if isStreakReminderEnabled {
            do {
                try await scheduleStreakReminder() // This will recreate with new sound settings
            } catch {
                print("Error scheduling streak reminders: \(error.localizedDescription)")
                // Continue with other operations - don't block all settings updates
            }
        }
        
        // Save to Firestore if user is logged in
        if let userId = userSession.currentUser?.uid {
            do {
                try await Firestore.firestore().collection("users").document(userId).collection("preferences").document("notifications").setData([
                    "soundEnabled": isSoundEnabled,
                    "vibrationEnabled": isVibrationEnabled
                ], merge: true)
            } catch {
                print("Error saving notification settings to Firestore: \(error.localizedDescription)")
            }
        }
    }
    
    // Add this function near the onAppear modifier in the body
    private func scrollToInitialSectionIfNeeded() {
        // Set the scrollToSection state if we have an initial section
        if let section = initialSection {
            scrollToSection = section
        }
    }
}

// MARK: - Supporting Views

/// A styled section header for the settings page
struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    @State private var isExpanded = true
    @State private var animateIcon = false
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Enhanced Header with animation
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                    animateIcon = true
                }
                
                // Reset animation flag after slight delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    animateIcon = false
                }
                
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            }) {
                HStack(spacing: 12) {
                    // Icon with enhanced visual appeal
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.theme.accent, Color.theme.accent.opacity(0.8)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .shadow(color: Color.theme.accent.opacity(0.3), radius: 3, x: 0, y: 2)
                        )
                        .rotationEffect(Angle(degrees: animateIcon ? 10 : 0))
                    
                    Text(title)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(Color.theme.text)
                    
                    Spacer()
                    
                    // Chevron indicator with rotation animation
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.theme.subtext)
                        .rotationEffect(Angle(degrees: isExpanded ? 0 : -90))
                        .animation(.easeInOut, value: isExpanded)
                }
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            // Content with slide animation
            if isExpanded {
                content
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.easeInOut, value: isExpanded)
            }
        }
        .padding(.bottom, 24)
    }
}

/// A styled card container for settings content
struct SettingsCard<Content: View>: View {
    let content: Content
    @State private var isAppearing = false
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.theme.surface)
                    .shadow(color: Color.black.opacity(0.07), radius: 10, x: 0, y: 5)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.theme.accent.opacity(0.05), lineWidth: 1)
                    )
            )
            .opacity(isAppearing ? 1.0 : 0.7)
            .scaleEffect(isAppearing ? 1.0 : 0.98)
            .onAppear {
                withAnimation(.easeOut(duration: 0.3)) {
                    isAppearing = true
                }
            }
    }
}

/// A styled row for settings options
struct SettingsRow: View {
    let icon: String
    let title: String
    let color: Color
    let showChevron: Bool
    @State private var isPressed = false
    
    init(
        icon: String,
        title: String,
        color: Color = Color.theme.text,
        showChevron: Bool = false
    ) {
        self.icon = icon
        self.title = title
        self.color = color
        self.showChevron = showChevron
    }
    
    var body: some View {
        HStack(spacing: 14) {
            // Enhanced icon with background
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(color)
            }
            
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(color)
            
            Spacer()
            
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.theme.subtext.opacity(0.6))
                    .padding(.trailing, 4)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.theme.surface)
                .shadow(color: Color.black.opacity(isPressed ? 0.0 : 0.03), 
                       radius: isPressed ? 0 : 3, 
                       x: 0, 
                       y: isPressed ? 0 : 1)
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isPressed)
        .contentShape(Rectangle())
        // Add gesture for feedback when pressed
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    isPressed = true
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
    }
}

// MARK: - Preview Provider

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            SettingsView()
                .withAppDependencies()
        }
    }
} 