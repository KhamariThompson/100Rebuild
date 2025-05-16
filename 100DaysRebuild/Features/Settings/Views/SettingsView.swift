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
        NavigationView {
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
                .sheet(isPresented: $showingChangeEmail) {
                    ChangeEmailView()
                }
                .sheet(isPresented: $showingChangePassword) {
                    ChangePasswordView()
                }
                .sheet(isPresented: $showingChangeUsername) {
                    ChangeUsernameView()
                        .environmentObject(userSession)
                }
                .sheet(isPresented: $subscriptionService.showPaywall) {
                    PaywallView()
                }
                .sheet(isPresented: $showingEmailComposer) {
                    if EmailComposer.canSendEmail() {
                        EmailComposer(
                            recipient: "support@100days.site",
                            subject: "100Days App Support",
                            body: getEmailSupportBody()
                        )
                    }
                }
                .sheet(isPresented: $showingShareSheet) {
                    Utilities_ShareSheet(items: [
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
        }
        .accentColor(.theme.accent)
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
                                .foregroundColor(.theme.accent)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Button("Change") {
                                showingChangeUsername = true
                            }
                            .font(.footnote)
                            .foregroundColor(.theme.accent)
                        }
                    }
                    
                    Button(action: { showingChangeEmail = true }) {
                        SettingsRow(icon: "envelope.fill", title: "Change Email", showChevron: true)
                    }
                    
                    Button(action: { showingChangePassword = true }) {
                        SettingsRow(icon: "lock.fill", title: "Change Password", showChevron: true)
                    }
                    
                    Button(action: { 
                        Task {
                            await handleSignOut()
                        }
                    }) {
                        SettingsRow(icon: "arrow.right.square", title: "Sign Out", color: .red)
                    }
                    
                    Button(action: { showingDeleteConfirmation = true }) {
                        SettingsRow(icon: "trash", title: "Delete Account", color: .red)
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
                            .foregroundColor(subscriptionService.isProUser ? .yellow : .theme.subtext)
                        
                        Text(subscriptionService.isProUser ? "Pro" : "Free")
                            .font(.headline)
                            .foregroundColor(subscriptionService.isProUser ? .theme.accent : .theme.text)
                        
                        Spacer()
                        
                        if subscriptionService.isProUser, let renewalDate = subscriptionService.renewalDate {
                            Text("Renews \(renewalDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundColor(.theme.subtext)
                        }
                    }
                    .padding(.vertical, 4)
                    
                    Divider()
                    
                    // Manage subscription
                    if subscriptionService.isProUser {
                        Button(action: {
                            AppStoreHelper.openSubscriptionManagement()
                        }) {
                            SettingsRow(icon: "creditcard", title: "Manage Subscription", showChevron: true)
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
                            SettingsRow(icon: "arrow.clockwise", title: "Restore Purchases")
                            
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
                        SettingsRow(icon: "trash.fill", title: "Delete All Challenges", color: .red)
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
                                .foregroundColor(.theme.text)
                            
                            Text("Enable notifications to receive reminders for your challenges.")
                                .font(.subheadline)
                                .foregroundColor(.theme.subtext)
                            
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
                            .foregroundColor(.theme.text)
                        
                        Toggle("Enable Daily Reminder", isOn: $isDailyReminderEnabled)
                            .onChange(of: isDailyReminderEnabled) { oldValue, newValue in
                                if newValue {
                                    scheduleReminders()
                                } else {
                                    cancelReminders()
                                }
                            }
                            .tint(.theme.accent)
                            .disabled(!notificationService.isAuthorized)
                        
                        DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.compact)
                            .onChange(of: reminderTime) { oldValue, newValue in
                                if isDailyReminderEnabled {
                                    updateReminderTime()
                                }
                            }
                            .tint(.theme.accent)
                            .disabled(!notificationService.isAuthorized || !isDailyReminderEnabled)
                    }
                    .padding(.vertical, 4)
                    
                    Divider()
                    
                    // Streak Reminder
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Streak Reminder")
                            .font(.headline)
                            .foregroundColor(.theme.text)
                        
                        Toggle("Enable Streak Reminder", isOn: $isStreakReminderEnabled)
                            .onChange(of: isStreakReminderEnabled) { oldValue, newValue in
                                if newValue {
                                    scheduleStreakReminder()
                                } else {
                                    cancelStreakReminder()
                                }
                            }
                            .tint(.theme.accent)
                            .disabled(!notificationService.isAuthorized)
                        
                        Text("Get notified when you're about to break your streak")
                            .font(.subheadline)
                            .foregroundColor(.theme.subtext)
                    }
                    .padding(.vertical, 4)
                    
                    Divider()
                    
                    // Notification Settings
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Settings")
                            .font(.headline)
                            .foregroundColor(.theme.text)
                        
                        Toggle("Sound", isOn: $isSoundEnabled)
                            .tint(.theme.accent)
                            .disabled(!notificationService.isAuthorized)
                        
                        Toggle("Vibration", isOn: $isVibrationEnabled)
                            .tint(.theme.accent)
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
                VStack(alignment: .leading, spacing: 16) {
                    Text("Theme")
                        .font(.subheadline)
                        .foregroundColor(.theme.subtext)
                        .padding(.bottom, 4)
                    
                    // Updated theme picker using ThemeManager
                    Picker("Theme", selection: $selectedTheme) {
                        ForEach(AppThemeMode.allCases) { theme in
                            HStack {
                                Image(systemName: theme.iconName)
                                Text(theme.displayName)
                            }
                            .tag(theme)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: selectedTheme) { oldValue, newValue in
                        hapticFeedback()
                        themeManager.setTheme(newValue)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }
    
    private var communitySection: some View {
        SettingsSection(title: "Community & Support", icon: "bubble.left.and.bubble.right.fill") {
            SettingsCard {
                VStack(alignment: .leading, spacing: 16) {
                    Button(action: { showingShareSheet = true }) {
                        SettingsRow(icon: "square.and.arrow.up", title: "Refer a Friend", showChevron: true)
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
                        SettingsRow(icon: "envelope.fill", title: "Contact Support", showChevron: true)
                    }
                    
                    Button(action: {
                        AppStoreHelper.openAppStoreReview()
                    }) {
                        SettingsRow(icon: "star.bubble.fill", title: "Rate on App Store", showChevron: true)
                    }
                    
                    Button(action: {
                        if let twitterURL = URL(string: "https://twitter.com/100daysapp") {
                            UIApplication.shared.open(twitterURL)
                        }
                    }) {
                        SettingsRow(icon: "bird.fill", title: "Follow Us on Twitter", showChevron: true)
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
                        SettingsRow(icon: "hand.raised.fill", title: "Privacy Policy", showChevron: true)
                    }
                    
                    Link(destination: URL(string: "https://100days.site/terms")!) {
                        SettingsRow(icon: "doc.text.fill", title: "Terms of Service", showChevron: true)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    private var appInfoSection: some View {
        SettingsSection(title: "App Info", icon: "info.circle.fill") {
            SettingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    // Version info
                    InfoRow(title: "Version", value: getAppVersion())
                    InfoRow(title: "Build", value: getBuildNumber())
                    InfoRow(title: "Last Updated", value: getFormattedDate())
                }
                .padding(.vertical, 8)
            }
        }
    }
    
    // MARK: - Helper Views
    
    private struct InfoRow: View {
        let title: String
        let value: String
        
        var body: some View {
            HStack {
                Text(title)
                    .foregroundColor(.theme.subtext)
                Spacer()
                Text(value)
                    .foregroundColor(.theme.text)
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
    
    private func hapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .light)
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
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(.theme.accent)
                    .font(.system(size: 18, weight: .semibold))
                
                Text(title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.theme.text)
            }
            .padding(.horizontal, 4)
            
            content
        }
        .padding(.vertical, 8)
    }
}

/// A styled card container for settings content
struct SettingsCard<Content: View>: View {
    let content: Content
    
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
                    .shadow(color: Color.theme.shadow.opacity(0.1), radius: 10, x: 0, y: 4)
            )
    }
}

/// A styled row for settings options
struct SettingsRow: View {
    let icon: String
    let title: String
    var color: Color = .theme.text
    var showChevron: Bool = false
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(title)
                .foregroundColor(color)
            
            Spacer()
            
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.theme.subtext.opacity(0.6))
            }
        }
    }
}

// MARK: - Change Email/Password Views

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
                                    .foregroundColor(.theme.accent)
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

struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var userSession: UserSession
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isUpdating = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    SecureField("Current Password", text: $currentPassword)
                        .textContentType(.password)
                        .submitLabel(.next)
                    
                    SecureField("New Password", text: $newPassword)
                        .textContentType(.newPassword)
                        .submitLabel(.next)
                    
                    SecureField("Confirm New Password", text: $confirmPassword)
                        .textContentType(.newPassword)
                        .submitLabel(.done)
                }
                
                Section {
                    Button(action: updatePassword) {
                        HStack {
                            Spacer()
                            
                        if isUpdating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Update Password")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.theme.accent)
                            }
                            
                            Spacer()
                        }
                    }
                    .disabled(currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty || isUpdating)
                }
            }
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Cancel") { dismiss() })
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func updatePassword() {
        isUpdating = true
        Task {
            do {
                try await updatePasswordWithUserSession()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
            isUpdating = false
        }
    }
    
    private func updatePasswordWithUserSession() async throws {
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "App", code: 1, userInfo: [NSLocalizedDescriptionKey: "No user is signed in"])
        }
        
        // Check if passwords match
        if newPassword != confirmPassword {
            throw NSError(domain: "App", code: 1, userInfo: [NSLocalizedDescriptionKey: "New passwords do not match"])
        }
        
        // Reauthenticate user
        let credential = EmailAuthProvider.credential(withEmail: user.email ?? "", password: currentPassword)
        try await user.reauthenticate(with: credential)
        
        // Update password
        try await user.updatePassword(to: newPassword)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(UserSession.shared)
            .environmentObject(SubscriptionService.shared)
            .environmentObject(NotificationService.shared)
    }
} 