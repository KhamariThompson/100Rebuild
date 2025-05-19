import SwiftUI
import FirebaseAuth
import MessageUI
import StoreKit

struct SettingsView: View {
    // Environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var subscriptionService: SubscriptionService
    @EnvironmentObject var notificationService: NotificationService
    @EnvironmentObject var themeManager: ThemeManager
    
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
    
    var body: some View {
        mainContent
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.medium)
                }
            }
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
            }
            .accentColor(Color.theme.accent)
            .onReceive(NotificationCenter.default.publisher(for: .appThemeDidChange)) { notification in
                // Update selectedTheme when it changes externally
                if let themeRawValue = notification.object as? String,
                   let updatedTheme = AppThemeMode(rawValue: themeRawValue) {
                    selectedTheme = updatedTheme
                } else {
                    selectedTheme = themeManager.currentTheme
                }
            }
    }
    
    // MARK: - Content Views
    
    private var mainContent: some View {
        ZStack {
            Color.theme.background.ignoresSafeArea()
            
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
        }
    }
    
    // MARK: - Section Views
    
    private var accountSection: some View {
        SettingsSection(title: "Account", icon: "person.crop.circle.fill") {
            SettingsCard {
                VStack(alignment: .leading, spacing: 16) {
                    if let username = userSession.username {
                        HStack {
                            Text("@\(username)")
                                .font(.system(.subheadline, design: .monospaced))
                                .foregroundColor(Color.theme.accent)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Button("Change") {
                                showingChangeUsername = true
                            }
                            .font(.footnote)
                            .foregroundColor(Color.theme.accent)
                        }
                    }
                    
                    Button(action: { showingChangeEmail = true }) {
                        SettingsRow(icon: "envelope.fill", title: "Change Email", color: .theme.text, showChevron: true)
                    }
                    
                    Button(action: { showingChangePassword = true }) {
                        SettingsRow(icon: "lock.fill", title: "Change Password", color: .theme.text, showChevron: true)
                    }
                    
                    Button(action: { 
                        Task {
                            await handleSignOut()
                        }
                    }) {
                        SettingsRow(icon: "arrow.right.square", title: "Sign Out", color: .red, showChevron: true)
                    }
                    
                    Button(action: { showingDeleteConfirmation = true }) {
                        SettingsRow(icon: "trash", title: "Delete Account", color: .red, showChevron: true)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    private var subscriptionSection: some View {
        SettingsSection(title: "Subscription", icon: "star.fill") {
            SettingsCard {
                VStack(alignment: .leading, spacing: 16) {
                    // Current plan display
                    HStack {
                        Image(systemName: subscriptionService.isProUser ? "sparkles" : "sparkles.rectangle.stack")
                            .foregroundColor(subscriptionService.isProUser ? Color.yellow : Color.theme.subtext)
                        
                        Text(subscriptionService.isProUser ? "Pro" : "Free")
                            .font(.headline)
                            .foregroundColor(subscriptionService.isProUser ? Color.theme.accent : Color.theme.text)
                        
                        Spacer()
                        
                        if subscriptionService.isProUser, let renewalDate = subscriptionService.renewalDate {
                            Text("Renews \(renewalDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundColor(Color.theme.subtext)
                        }
                    }
                    .padding(.vertical, 4)
                    
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
                            SettingsRow(icon: "star.fill", title: "Upgrade to Pro", color: .theme.accent, showChevron: true)
                        }
                    }
                    
                    // Restore purchases
                    Button(action: restorePurchases) {
                        HStack {
                            SettingsRow(icon: "arrow.clockwise", title: "Restore Purchases", color: .theme.text, showChevron: true)
                            
                            if isRestoringPurchases {
                                Spacer()
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            }
                        }
                    }
                    .disabled(isRestoringPurchases)
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    private var dataSection: some View {
        SettingsSection(title: "Data & Challenges", icon: "tray.full.fill") {
            SettingsCard {
                VStack(alignment: .leading, spacing: 16) {
                    Button(action: { showingDeleteChallengesConfirmation = true }) {
                        SettingsRow(icon: "trash.fill", title: "Delete All Challenges", color: .red, showChevron: true)
                    }
                    .disabled(isPerformingAction)
                    
                    if isPerformingAction {
                        HStack {
                            Spacer()
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(.vertical, 4)
            }
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
                                    scheduleReminders()
                                } else {
                                    cancelReminders()
                                }
                            }
                            .tint(Color.theme.accent)
                            .disabled(!notificationService.isAuthorized)
                        
                        DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.compact)
                            .onChange(of: reminderTime) { oldValue, newValue in
                                if isDailyReminderEnabled {
                                    updateReminderTime()
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
                                    scheduleStreakReminder()
                                } else {
                                    cancelStreakReminder()
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
                        
                        Toggle("Vibration", isOn: $isVibrationEnabled)
                            .tint(Color.theme.accent)
                            .disabled(!notificationService.isAuthorized)
                    }
                    .padding(.vertical, 4)
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    private var appearanceSection: some View {
        SettingsSection(title: "Appearance", icon: "paintpalette.fill") {
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
                VStack(alignment: .leading, spacing: 16) {
                    Button(action: { showingShareSheet = true }) {
                        SettingsRow(icon: "square.and.arrow.up", title: "Refer a Friend", color: .theme.text, showChevron: true)
                    }
                    
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
                    
                    Button(action: {
                        AppStoreHelper.openAppStoreReview()
                    }) {
                        SettingsRow(icon: "star.bubble.fill", title: "Rate on App Store", color: .theme.text, showChevron: true)
                    }
                    
                    Button(action: {
                        if let twitterURL = URL(string: "https://twitter.com/100daysapp") {
                            UIApplication.shared.open(twitterURL)
                        }
                    }) {
                        SettingsRow(icon: "bird.fill", title: "Follow Us on Twitter", color: .theme.text, showChevron: true)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    private var legalSection: some View {
        SettingsSection(title: "Legal", icon: "doc.plaintext.fill") {
            SettingsCard {
                VStack(alignment: .leading, spacing: 16) {
                    Link(destination: URL(string: "https://100days.site/privacy")!) {
                        SettingsRow(icon: "hand.raised.fill", title: "Privacy Policy", color: .theme.text, showChevron: true)
                    }
                    
                    Link(destination: URL(string: "https://100days.site/terms")!) {
                        SettingsRow(icon: "doc.text.fill", title: "Terms of Service", color: .theme.text, showChevron: true)
                    }
                }
                .padding(.vertical, 4)
            }
        }
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
                    
                    if let appID = Bundle.main.infoDictionary?["AppStoreID"] as? String {
                        Link(destination: URL(string: "https://apps.apple.com/app/id\(appID)")!) {
                            SettingsRow(icon: "square.and.arrow.up", title: "Share App", color: .theme.text, showChevron: true)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
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
            try await userSession.signOut()
            dismiss()
        } catch {
            await MainActor.run {
                errorMessage = "Failed to sign out: \(error.localizedDescription)"
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
    
    private func handleDeleteAccount() async {
        isPerformingAction = true
        
        do {
            try await userSession.deleteAccount()
            dismiss()
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showingError = true
                isPerformingAction = false
            }
        }
    }
    
    private func handleDeleteAllChallenges() async {
        guard let userId = userSession.currentUser?.uid else {
            errorMessage = "You must be signed in to delete challenges"
            showingError = true
            return
        }
        
        isPerformingAction = true
        
        do {
            try await ChallengeService.shared.deleteAllChallenges(userId: userId)
            
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
    
    // MARK: - Notification Helpers
    
    private func syncWithNotificationService() {
        // Get notification settings from the service
        isDailyReminderEnabled = notificationService.isDailyReminderEnabled
        isStreakReminderEnabled = notificationService.isStreakReminderEnabled
        reminderTime = notificationService.reminderTime
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
    }
    
    private func requestNotificationPermission() {
        Task {
            do {
                let authorized = try await notificationService.requestNotificationPermission()
                if !authorized {
                    showingPermissionAlert = true
                }
            } catch {
                errorMessage = "Could not request notification permissions: \(error.localizedDescription)"
                showingError = true
            }
        }
    }
    
    private func scheduleReminders() {
        Task {
            do {
                try await notificationService.scheduleDailyReminder()
                UserDefaults.standard.set(true, forKey: "isDailyReminderEnabled")
                notificationService.isDailyReminderEnabled = true
            } catch {
                errorMessage = "Could not schedule reminder: \(error.localizedDescription)"
                showingError = true
                isDailyReminderEnabled = false
            }
        }
    }
    
    private func updateReminderTime() {
        Task {
            do {
                try await notificationService.updateReminderTime(reminderTime)
                // Save user preference
                notificationService.reminderTime = reminderTime
            } catch {
                errorMessage = "Could not update reminder time: \(error.localizedDescription)"
                showingError = true
            }
        }
    }
    
    private func cancelReminders() {
        Task {
            try? await notificationService.cancelDailyReminder()
            UserDefaults.standard.set(false, forKey: "isDailyReminderEnabled")
            notificationService.isDailyReminderEnabled = false
        }
    }
    
    private func scheduleStreakReminder() {
        Task {
            do {
                try await notificationService.scheduleStreakReminder()
                UserDefaults.standard.set(true, forKey: "isStreakReminderEnabled")
                notificationService.isStreakReminderEnabled = true
            } catch {
                errorMessage = "Could not schedule streak reminder: \(error.localizedDescription)"
                showingError = true
                isStreakReminderEnabled = false
            }
        }
    }
    
    private func cancelStreakReminder() {
        Task {
            notificationService.cancelStreakReminder()
            UserDefaults.standard.set(false, forKey: "isStreakReminderEnabled")
            notificationService.isStreakReminderEnabled = false
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

// MARK: - Change Email View

struct ChangeEmailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var userSession: UserSession
    @State private var newEmail = ""
    @State private var password = ""
    @State private var isUpdating = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("New Email", text: $newEmail)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .submitLabel(.next)
                    
                    SecureField("Current Password", text: $password)
                        .textContentType(.password)
                        .submitLabel(.done)
                }
                
                Section {
                    Button(action: updateEmail) {
                        HStack {
                            Spacer()
                            
                        if isUpdating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Update Email")
                                    .fontWeight(.semibold)
                                    .foregroundColor(Color.theme.accent)
                            }
                            
                            Spacer()
                        }
                    }
                    .disabled(newEmail.isEmpty || password.isEmpty || isUpdating)
                }
            }
            .navigationTitle("Change Email")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Cancel") { dismiss() })
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func updateEmail() {
        isUpdating = true
        Task {
            do {
                try await updateEmailWithUserSession()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
            isUpdating = false
        }
    }
    
    private func updateEmailWithUserSession() async throws {
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "App", code: 1, userInfo: [NSLocalizedDescriptionKey: "No user is signed in"])
        }
        
        // Reauthenticate user
        let credential = EmailAuthProvider.credential(withEmail: user.email ?? "", password: password)
        try await user.reauthenticate(with: credential)
        
        // Update email with verification
        try await user.sendEmailVerification(beforeUpdatingEmail: newEmail)
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