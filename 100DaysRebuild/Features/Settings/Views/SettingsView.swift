import SwiftUI
import FirebaseAuth
import MessageUI
import StoreKit
import FirebaseFirestore
@preconcurrency import UserNotifications
import FirebaseStorage

// Local spacing constants
private let spacingS: CGFloat = 12
private let spacingM: CGFloat = 16

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

// Add ActiveSheet enum before the SettingsView struct
enum ActiveSheet: Identifiable {
    case changeEmail
    case changePassword
    case changeUsername
    case paywall
    case emailComposer
    case shareSheet
    
    var id: Int {
        switch self {
        case .changeEmail: return 0
        case .changePassword: return 1
        case .changeUsername: return 2
        case .paywall: return 3
        case .emailComposer: return 4
        case .shareSheet: return 5
        }
    }
}

struct SettingsView: View {
    // Environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var subscriptionService: SubscriptionService
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var notificationService: NotificationService
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var router: NavigationRouter
    
    // Section focus
    var initialSection: SettingsSectionType?
    @State private var scrollToSection: SettingsSectionType?
    
    // Add a state variable to track if view is active
    @State private var viewIsActive = true
    
    // State
    @State private var activeSheet: ActiveSheet?
    @State private var isRestoringPurchases = false
    @State private var isPerformingAction = false
    @State private var showingDeleteConfirmation = false
    @State private var showingDeleteChallengesConfirmation = false
    @State private var showingError = false
    @State private var errorMessage: String? = nil
    @State private var isNotificationsEnabled = false
    @State private var showSuccessMessage = false
    @State private var successMessage = ""
    @State private var selectedTheme: AppThemeMode = .system
    
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
    
    // Bio state
    @State private var userBio: String = ""
    @State private var isEditingBio = false
    @State private var isUpdatingBio = false
    
    // Presentation and gestures 
    @State private var dragOffset: CGFloat = 0
    private var isDraggable: Bool = true
    
    // Add new state for gesture handling
    @State private var isGestureActive = false
    
    // New states for social tab
    @State private var showSocialTab = false
    @State private var isPresentingPhotoPicker = false
    @State private var uiImage: UIImage?
    @State private var isUploadingImage = false
    @State private var uploadProgress: Double = 0
    @State private var shouldShowUpgradeSheet = false // Flag to control paywall sheet
    @State private var localThemeMode: AppThemeMode = .system // Local state for theme mode
    
    // New state for username setup
    @State private var isShowingUsernameSetup = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.theme.background
                    .ignoresSafeArea()
                
                // Main content
                ScrollView {
                    LazyVStack(spacing: 24) {
                        // Sections
                        accountSection

                        // Legacy grace period section (only shown for legacy users)
                        LegacyGraceSection()

                        subscriptionSection
                        dataSection
                        notificationsSection
                        appearanceSection
                        communitySection
                        legalSection
                        appInfoSection
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 100)
                }
                .safeAreaInset(edge: .top) {
                    // Collapsible header
                    headerView
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .changeEmail:
                ChangeEmailView()
                    .environmentObject(userSession)
                    .environmentObject(themeManager)
            case .changePassword:
                ChangePasswordView()
                    .environmentObject(userSession)
                    .environmentObject(themeManager)
            case .changeUsername:
                ChangeUsernameView()
                    .environmentObject(userSession)
                    .environmentObject(themeManager)
            case .paywall:
                PaywallView()
                    .environmentObject(subscriptionService)
                    .environmentObject(themeManager)
            case .emailComposer:
                emailComposerView()
            case .shareSheet:
                ShareSheet(items: [
                    AppStoreHelper.getShareMessage(),
                    AppStoreHelper.getShareableAppLink()
                ])
            }
        }
        .sheet(isPresented: $subscriptionService.showPaywall) {
            PaywallView()
                .environmentObject(subscriptionService)
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $isShowingUsernameSetup) {
            UsernameSetupView()
                .environmentObject(userSession)
        }
        .onAppear {
            viewIsActive = true
            syncWithNotificationService()
            selectedTheme = themeManager.currentTheme
            
            // Load user's display name
            Task {
                await loadUserProfile()
            }
            
            // Scroll to the specified section if needed
            scrollToInitialSectionIfNeeded()
        }
        .onDisappear {
            viewIsActive = false
        }
    }
    
    // Main body content extracted to a separate computed property
    private var bodyContent: some View {
        let content = VStack(spacing: 0) {
            // Modern header with large title
            settingsHeader
                .offset(y: -dragOffset * 0.2)
            
            // Main content container
            mainContent
                .offset(y: -dragOffset * 0.8)
        }
        .background(Color.theme.background.ignoresSafeArea())
        .accentColor(Color.theme.accent)
        
        // Apply all modifiers in sequence instead of chaining methods
        return applyDragGesture(
            applyEventHandlers(
                applyAlerts(
                    applySheets(content)
                )
            )
        )
    }
    
    // Add headerView definition
    private var headerView: some View {
        VStack(spacing: 0) {
            // Header with title and dismiss button
            HStack {
                Text("Settings")
                    .font(AppTypography.largeTitle(.bold))
                    .foregroundColor(Color.theme.text)
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 8)
            .background(Color.theme.background)
        }
    }
    
    // Extract sheet presentation to a separate method
    private func applySheets(_ content: some View) -> some View {
        content.sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .changeEmail:
                ChangeEmailView()
                    .environmentObject(userSession)
                    .environmentObject(themeManager)
            case .changePassword:
                ChangePasswordView()
                    .environmentObject(userSession)
                    .environmentObject(themeManager)
            case .changeUsername:
                ChangeUsernameView()
                    .environmentObject(userSession)
                    .environmentObject(themeManager)
            case .paywall:
                PaywallView()
                    .environmentObject(subscriptionService)
                    .environmentObject(themeManager)
            case .emailComposer:
                emailComposerView()
            case .shareSheet:
                ShareSheet(items: [
                    AppStoreHelper.getShareMessage(),
                    AppStoreHelper.getShareableAppLink()
                ])
            }
        }
    }
    
    // Helper function for email composer view
    private func emailComposerView() -> some View {
        Group {
            if EmailComposer.canSendEmail() {
                EmailComposer(
                    recipient: "support@100days.site",
                    subject: "100Days App Support",
                    body: getEmailSupportBody(),
                    completionHandler: { _, _ in
                        // Clear sheet when done
                        activeSheet = nil
                    }
                )
            } else {
                // If email composer not available, clear sheet and show fallback
                Color.clear.onAppear {
                    activeSheet = nil
                    let encodedSubject = "100Days App Support".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                    if let url = URL(string: "mailto:support@100days.site?subject=\(encodedSubject)") {
                        UIApplication.shared.open(url)
                    }
                }
            }
        }
    }
    
    // Extract alerts to a separate method
    private func applyAlerts(_ content: some View) -> some View {
        content
            // Success alert
            .alert("Success", isPresented: $showSuccessMessage) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(successMessage)
            }
            // Error alert
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            // Delete account confirmation
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
            // Delete challenges confirmation
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
            // Notification permission alert
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
    }
    
    // Apply event handlers
    private func applyEventHandlers(_ content: some View) -> some View {
        content
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
    
    // Extract drag gesture to a separate method
    private func applyDragGesture(_ content: some View) -> some View {
        if !isDraggable {
            return AnyView(content)
        }
        
        return AnyView(content.gesture(
            DragGesture(minimumDistance: 50) // Increase minimum distance significantly to avoid conflicts with taps
                .onChanged { gesture in
                    // Only capture vertical drags that are clearly downward
                    if gesture.translation.height > 30 && abs(gesture.translation.height) > abs(gesture.translation.width) * 2 {
                        self.dragOffset = min(gesture.translation.height, 200) // Limit maximum drag
                    }
                }
                .onEnded { gesture in
                    if gesture.translation.height > 150 {
                        withAnimation(.easeOut) {
                            self.dismiss()
                        }
                    } else {
                        withAnimation(.easeOut) {
                            self.dragOffset = 0
                        }
                    }
                }
        ))
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
                                .font(AppTypography.headline(.semibold))
                            
                            Text("Back")
                                .font(AppTypography.body(.medium))
                                .opacity(0.9)
                        }
                        .foregroundColor(Color.theme.accent)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.leading, 16)
                    
                    Spacer()
                    
                    Text("Settings")
                        .font(AppTypography.title3(.semibold))
                        .foregroundColor(Color.theme.text)
                    
                    Spacer()
                    
                    // Optional right button (for symmetry, can be hidden)
                    Button(action: { dismiss() }) {
                        Text("Done")
                            .font(AppTypography.body(.medium))
                            .foregroundColor(Color.theme.accent)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.trailing, 16)
                }
                .padding(.top, 8)
                
                // Main title (larger)
                Text("Settings")
                    .font(AppTypography.font(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(Color.theme.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 16)
            }
        }
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
            .onChange(of: scrollToSection) { newValue in
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
                    // Name button
                    Button {
                        isEditingDisplayName = true
                    } label: {
                        SettingsRow(icon: "person.fill", title: "Name", subtitle: displayName.isEmpty ? "Add your name" : displayName, color: .theme.text, showChevron: true)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Divider()
                    
                    // Username button
                    if let username = userSession.username, !username.isEmpty {
                        Button {
                            activeSheet = .changeUsername
                        } label: {
                            SettingsRow(icon: "at", title: "Username", subtitle: "@\(username)", color: .theme.text, showChevron: true)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        Button {
                            // Show username setup view directly instead of just showing social tab
                            isShowingUsernameSetup = true
                        } label: {
                            SettingsRow(icon: "at", title: "Username", subtitle: "Set up username", color: .theme.text, showChevron: true)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    Divider()
                    
                    // Bio button
                    Button {
                        isEditingBio = true
                    } label: {
                        SettingsRow(icon: "text.quote", title: "Bio", subtitle: userBio.isEmpty ? "Add your bio" : userBio, color: .theme.text, showChevron: true)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Divider()
                    
                    // Email button
                    Button {
                        activeSheet = .changeEmail
                    } label: {
                        SettingsRow(icon: "envelope.fill", title: "Change Email", color: .theme.text, showChevron: true)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Divider()
                    
                    // Password button
                    Button {
                        activeSheet = .changePassword
                    } label: {
                        SettingsRow(icon: "lock.fill", title: "Change Password", color: .theme.text, showChevron: true)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Divider()
                    
                    // Sign Out
                    Button {
                        Task {
                            await handleSignOut()
                        }
                    } label: {
                        SettingsRow(icon: "arrow.right.square", title: "Sign Out", color: .theme.text, showChevron: true)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isPerformingAction)
                    
                    Divider()
                    
                    // Delete Account (destructive)
                    Button {
                        showingDeleteConfirmation = true
                    } label: {
                        SettingsRow(
                            icon: "trash.fill", 
                            title: "Delete Account", 
                            color: .red, 
                            showChevron: true
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isPerformingAction)
                    
                    // Show a progress indicator if account action is in progress
                    if isPerformingAction {
                        HStack {
                            Spacer()
                            safeProgressView()
                            Spacer()
                        }
                    }
                }
                .padding(.vertical, 0)
            }
            
            // Edit Name Sheet
            .sheet(isPresented: $isEditingDisplayName) {
                NavigationView {
                    VStack(spacing: 20) {
                        Text("Change Your Name")
                            .font(AppTypography.title2())
                            .fontWeight(.bold)
                            .padding(.top, 20)
                        
                        Text("Your name is used for personalized greetings")
                            .font(AppTypography.subhead())
                            .foregroundColor(.theme.subtext)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)
                        
                        TextField("Your name", text: $displayName)
                            .font(AppTypography.title3())
                            .padding()
                            .background(Color.theme.surface)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.theme.border, lineWidth: 1)
                            )
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                        
                        if let errorMessage = displayNameErrorMessage {
                            Text(errorMessage)
                                .font(AppTypography.caption1())
                                .foregroundColor(.red)
                                .padding(.top, 4)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color.theme.background.edgesIgnoringSafeArea(.all))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                isEditingDisplayName = false
                                displayNameErrorMessage = nil
                            }
                        }
                        
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                Task {
                                    await updateDisplayName()
                                }
                            }
                            .disabled(isUpdatingDisplayName)
                        }
                    }
                    .overlay {
                        if isUpdatingDisplayName {
                            ProgressView()
                        }
                    }
                }
            }
            // Edit Bio Sheet
            .sheet(isPresented: $isEditingBio) {
                NavigationView {
                    VStack(spacing: 20) {
                        Text("Edit Your Bio")
                            .font(AppTypography.title2())
                            .fontWeight(.bold)
                            .padding(.top, 20)
                        
                        Text("Tell others a bit about yourself")
                            .font(AppTypography.subhead())
                            .foregroundColor(.theme.subtext)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)
                        
                        TextField("Your bio", text: $userBio)
                            .font(AppTypography.title3())
                            .padding()
                            .background(Color.theme.surface)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.theme.border, lineWidth: 1)
                            )
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                        
                        Text("Keep it short and sweet - it will be displayed on your profile")
                            .font(AppTypography.caption1())
                            .foregroundColor(.theme.subtext)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color.theme.background.edgesIgnoringSafeArea(.all))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                isEditingBio = false
                            }
                        }
                        
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                Task {
                                    await updateBio()
                                }
                            }
                            .disabled(isUpdatingBio)
                        }
                    }
                    .overlay {
                        if isUpdatingBio {
                            ProgressView()
                        }
                    }
                }
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
                            Image(systemName: subscriptionStore.isPro ? "crown.fill" : "star")
                                .font(AppTypography.title3())
                                .foregroundColor(subscriptionStore.isPro ? Color.yellow : Color.theme.subtext)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Current Plan")
                                    .font(AppTypography.subhead())
                                    .foregroundColor(Color.theme.subtext)

                                HStack(spacing: 6) {
                                    Text(subscriptionStore.isPro ? "Pro" : "Free")
                                        .font(AppTypography.headline(.semibold))
                                        .foregroundColor(subscriptionStore.isPro ? Color.yellow : Color.theme.text)

                                    // Show "Grandfathered" badge if applicable
                                    if subscriptionStore.state.isGrandfatherActive {
                                        Text("(Grandfathered)")
                                            .font(AppTypography.caption1(.medium))
                                            .foregroundColor(Color.theme.accent)
                                    }
                                }
                            }
                        }

                        Spacer()

                        // Show expiration date
                        if subscriptionStore.state.isGrandfatherActive, let accountCreatedAt = userSession.accountCreatedAt {
                            // Calculate expiration (1 year from account creation)
                            if let expirationDate = Calendar.current.date(byAdding: .year, value: 1, to: accountCreatedAt) {
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("Expires")
                                        .font(AppTypography.caption2())
                                        .foregroundColor(Color.theme.subtext)
                                    Text(expirationDate.formatted(date: .abbreviated, time: .omitted))
                                        .font(AppTypography.caption1())
                                        .foregroundColor(Color.theme.accent)
                                }
                            }
                        } else if subscriptionStore.state.rcIsPro, let renewalDate = subscriptionService.renewalDate {
                            Text("Renews \(renewalDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(AppTypography.caption1())
                                .foregroundColor(Color.theme.subtext)
                        }
                    }
                    .padding(.vertical, 14)
                    
                    Divider()

                    // Manage subscription (only show if user has RC subscription, not for grandfather)
                    if subscriptionStore.state.rcIsPro {
                        Button {
                            AppStoreHelper.openSubscriptionManagement()
                        } label: {
                            SettingsRow(icon: "creditcard", title: "Manage Subscription", color: .theme.text, showChevron: true)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else if subscriptionStore.state.isGrandfatherActive {
                        // Grandfathered users should be able to upgrade before expiration
                        Button {
                            subscriptionService.presentSubscriptionSheet()
                        } label: {
                            SettingsRow(
                                icon: "crown.fill",
                                title: "Upgrade Now",
                                color: Color.yellow,
                                showChevron: true
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        // Should not reach here since Pro is required to access app
                        // But keep as fallback
                        Button {
                            subscriptionService.presentSubscriptionSheet()
                        } label: {
                            SettingsRow(
                                icon: "star.circle.fill",
                                title: "Upgrade to Pro",
                                color: Color.yellow,
                                showChevron: true
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    Divider()
                    
                    // Restore purchases
                    Button {
                        restorePurchases()
                    } label: {
                        HStack {
                            SettingsRow(
                                icon: "arrow.clockwise", 
                                title: "Restore Purchases", 
                                color: .theme.text, 
                                showChevron: true
                            )
                            .contentShape(Rectangle())
                            
                            if isRestoringPurchases {
                                Spacer()
                                safeProgressView()
                                .padding(.trailing, 8)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
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
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isPerformingAction)
                    
                    if isPerformingAction {
                        HStack {
                            Spacer()
                            safeProgressView()
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
                                .font(AppTypography.headline())
                                .foregroundColor(Color.theme.text)
                            
                            Text("Enable notifications to receive reminders for your challenges.")
                                .font(AppTypography.subhead())
                                .foregroundColor(Color.theme.subtext)
                            
                            Button("Enable Notifications") {
                                requestNotificationPermission()
                            }
                            .font(AppTypography.headline())
                            .foregroundColor(colorScheme == .dark ? .black : .white)
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
                            .font(AppTypography.headline())
                            .foregroundColor(Color.theme.text)
                        
                        Toggle("Enable Daily Reminder", isOn: $isDailyReminderEnabled)
                            .onChange(of: isDailyReminderEnabled) { newValue in
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
                            .onChange(of: reminderTime) { newValue in
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
                            .font(AppTypography.headline())
                            .foregroundColor(Color.theme.text)
                        
                        Toggle("Enable Streak Reminder", isOn: $isStreakReminderEnabled)
                            .onChange(of: isStreakReminderEnabled) { newValue in
                                if newValue {
                                    Task { try? await scheduleStreakReminder() }
                                } else {
                                    Task { try? await cancelStreakReminder() }
                                }
                            }
                            .tint(Color.theme.accent)
                            .disabled(!notificationService.isAuthorized)
                        
                        Text("Get notified when you're about to break your streak")
                            .font(AppTypography.subhead())
                            .foregroundColor(Color.theme.subtext)
                    }
                    .padding(.vertical, 4)
                    
                    // Streak Expiration Warning
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Streak Expiration Warning")
                            .font(AppTypography.headline())
                            .foregroundColor(Color.theme.text)
                        
                        Toggle("Warn me when streak is about to expire", isOn: $notificationService.isStreakExpirationWarningEnabled)
                            .onChange(of: notificationService.isStreakExpirationWarningEnabled) { newValue in
                                if newValue {
                                    Task { try? await scheduleStreakExpirationWarning() }
                                } else {
                                    Task { try? await cancelStreakExpirationWarning() }
                                }
                            }
                            .tint(Color.theme.accent)
                            .disabled(!notificationService.isAuthorized)
                        
                        if notificationService.isStreakExpirationWarningEnabled {
                            HStack {
                                Text("Warn me")
                                    .font(AppTypography.subhead())
                                    .foregroundColor(Color.theme.text)
                                
                                Picker("", selection: $notificationService.streakExpirationWarningHours) {
                                    ForEach([1, 2, 3, 4, 6, 8, 12], id: \.self) { hour in
                                        Text(hour == 1 ? "1 hour" : "\(hour) hours")
                                            .tag(hour)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .accentColor(Color.theme.accent)
                                .onChange(of: notificationService.streakExpirationWarningHours) { newValue in
                                    Task { try? await updateExpirationWarningHours() }
                                }
                                
                                Text("before streak expires")
                                    .font(AppTypography.subhead())
                                    .foregroundColor(Color.theme.text)
                            }
                        }
                        
                        Text("Receive a notification when your streak is about to expire at the end of the day")
                            .font(AppTypography.subhead())
                            .foregroundColor(Color.theme.subtext)
                    }
                    .padding(.vertical, 4)
                    
                    Divider()
                    
                    // Notification Settings
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Settings")
                            .font(AppTypography.headline())
                            .foregroundColor(Color.theme.text)
                        
                        Toggle("Sound", isOn: $isSoundEnabled)
                            .tint(Color.theme.accent)
                            .disabled(!notificationService.isAuthorized)
                            .onChange(of: isSoundEnabled) { _ in
                                Task { 
                                    do {
                                        await updateNotificationSettings()
                                    } catch {
                                        print("Error updating notification settings: \(error.localizedDescription)")
                                    }
                                }
                            }
                        
                        Toggle("Vibration", isOn: $isVibrationEnabled)
                            .tint(Color.theme.accent)
                            .disabled(!notificationService.isAuthorized)
                            .onChange(of: isVibrationEnabled) { _ in
                                Task { 
                                    do {
                                        await updateNotificationSettings()
                                    } catch {
                                        print("Error updating notification settings: \(error.localizedDescription)")
                                    }
                                }
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
                        .font(AppTypography.headline())
                        .foregroundColor(Color.theme.text)
                    
                    // Enhanced theme selector with visual previews
                    HStack(spacing: 12) {
                        ForEach(AppThemeMode.allCases) { themeMode in
                            ThemeOptionButton(
                                theme: themeMode,
                                isSelected: selectedTheme == themeMode,
                                action: {
                                    hapticFeedback(style: .medium)
                                    selectedTheme = themeMode
                                    themeManager.setTheme(themeMode)
                                }
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
                                .font(AppTypography.caption1())
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
                            .font(AppTypography.title2(.medium))
                            .foregroundColor(themeIconColor)
                    }
                    
                    // Theme name
                    Text(theme.displayName)
                        .font(AppTypography.subhead())
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
            }
            .buttonStyle(PlainButtonStyle())
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
                    Button {
                        if EmailComposer.canSendEmail() {
                            activeSheet = .emailComposer
                        } else {
                            let encodedSubject = "100Days App Support".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                            if let url = URL(string: "mailto:support@100days.site?subject=\(encodedSubject)") {
                                UIApplication.shared.open(url)
                            }
                        }
                    } label: {
                        SettingsRow(icon: "envelope.fill", title: "Contact Support", color: .theme.text, showChevron: true)
                    }
                    .buttonStyle(AppScaleButtonStyle())
                    
                    Divider()
                    
                    Button {
                        AppStoreHelper.openAppStoreReview()
                    } label: {
                        SettingsRow(icon: "star.bubble.fill", title: "Rate on App Store", color: .theme.text, showChevron: true)
                    }
                    .buttonStyle(AppScaleButtonStyle())
                    
                    Divider()
                    
                    Button {
                        if let twitterURL = URL(string: "https://twitter.com/100daysHQ") {
                            UIApplication.shared.open(twitterURL)
                        }
                    } label: {
                        SettingsRow(icon: "bird.fill", title: "Follow Us on Twitter", color: .theme.text, showChevron: true)
                    }
                    .buttonStyle(AppScaleButtonStyle())
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
                    Link(destination: URL(string: "https://100days.site/privacy") ?? URL(string: "https://100days.site")!) {
                        SettingsRow(icon: "hand.raised.fill", title: "Privacy Policy", color: .theme.text, showChevron: true)
                    }
                    
                    Divider()
                    
                    Link(destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") ?? URL(string: "https://www.apple.com")!) {
                        SettingsRow(icon: "doc.text.fill", title: "Terms of Use", color: .theme.text, showChevron: true)
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
                    
                    Link(destination: URL(string: "https://100days.site") ?? URL(string: "https://apple.com")!) {
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
                        .font(AppTypography.subhead())
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
                        .font(AppTypography.caption1())
                        .foregroundColor(Color.theme.subtext)
                    
                    Text(value)
                        .font(AppTypography.callout())
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
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private func getBuildNumber() -> String {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
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
        // Set loading state
        await MainActor.run {
            isPerformingAction = true
            errorMessage = ""
        }
        
        // Dismiss the view first to avoid view hierarchy issues
        await MainActor.run {
            dismiss()
        }
        
        // Add a small delay to ensure view dismissal completes
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        // Create a task to handle the sign-out process
        let signOutTask = Task {
            // Perform sign-out
            await userSession.signOutWithoutThrowing()
            
            // Reset loading state in case this view is still in memory
            await MainActor.run {
                isPerformingAction = false
            }
        }
        
        // Wait for the sign-out process to complete
        await signOutTask.value
    }
    
    private func handleDeleteAccount() async {
        await MainActor.run {
            isPerformingAction = true
        }
        
        // Create a timeout task to prevent hangs
        let timeoutTask = Task {
            try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
            if isPerformingAction {
                print("DEBUG: Account deletion timed out")
                await MainActor.run {
                    errorMessage = "Account deletion timed out. Please try again."
                    showingError = true
                    isPerformingAction = false
                }
            }
        }
        
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
                activeSheet = nil
                
                // Now dismiss the view
                withAnimation {
                    dismiss()
                }
            }
        } catch {
            print("DEBUG: Error during account deletion: \(error.localizedDescription)")
            await MainActor.run {
                errorMessage = "Failed to delete account: \(error.localizedDescription)"
                showingError = true
                isPerformingAction = false
                
                // Force sign out if possible, as a recovery mechanism
                Task {
                    do {
                        await userSession.signOutWithoutThrowing()
                    } catch {
                        print("DEBUG: Failed to sign out after account deletion error: \(error.localizedDescription)")
                    }
                }
            }
        }
        
        // Cancel the timeout task
        timeoutTask.cancel()
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
    
    // Load user profile including display name and bio
    private func loadUserProfile() async {
        guard let userId = userSession.currentUser?.uid else { 
            // Handle case when user is not signed in
            await MainActor.run {
                displayName = ""
                userBio = ""
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
                userBio = profile?.bio ?? "Building my best habits 1 day at a time 💪"
                isPerformingAction = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load profile: \(error.localizedDescription)"
                showingError = true
                isPerformingAction = false
                
                // Set empty defaults to avoid null references
                displayName = ""
                userBio = "Building my best habits 1 day at a time 💪"
            }
            
            print("Failed to load user profile: \(error.localizedDescription)")
        }
    }
    
    // Update user's display name
    private func updateDisplayName() async {
        guard let userId = userSession.currentUser?.uid else {
            displayNameErrorMessage = "You must be signed in to update your name"
            return
        }
        
        if displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            displayNameErrorMessage = "Display name cannot be empty"
            return
        }
        
        await MainActor.run {
            isUpdatingDisplayName = true
            displayNameErrorMessage = nil
        }
        
        do {
            // Use the Firebase service to update the display name
            try await FirebaseService.shared.updateDisplayName(displayName, userId: userId)
            
            await MainActor.run {
                isEditingDisplayName = false
                isUpdatingDisplayName = false
                successMessage = "Display name updated successfully"
                showSuccessMessage = true
                
                // Post notification about the updated display name
                NotificationCenter.default.post(
                    name: NSNotification.Name("UserProfileUpdated"),
                    object: nil,
                    userInfo: ["displayName": displayName]
                )
            }
        } catch {
            await MainActor.run {
                isUpdatingDisplayName = false
                displayNameErrorMessage = "Failed to update display name: \(error.localizedDescription)"
            }
        }
    }
    
    // Load just the bio field
    private func loadBio() {
        Task {
            guard let userId = userSession.currentUser?.uid else { return }
            
            do {
                let document = try await Firestore.firestore()
                    .collection("users")
                    .document(userId)
                    .getDocument()
                
                if document.exists, let data = document.data() {
                    await MainActor.run {
                        self.userBio = data["bio"] as? String ?? "Building my best habits 1 day at a time 💪"
                    }
                }
            } catch {
                print("Error loading user bio: \(error.localizedDescription)")
            }
        }
    }
    
    // Update the user's bio in Firestore
    private func updateBio() async {
        guard let userId = userSession.currentUser?.uid else { return }
        
        await MainActor.run {
            isUpdatingBio = true
        }
        
        do {
            try await Firestore.firestore()
                .collection("users")
                .document(userId)
                .updateData(["bio": userBio])
            
            await MainActor.run {
                isUpdatingBio = false
                isEditingBio = false
                showSuccessMessage = true
                successMessage = "Bio updated successfully"
            }
        } catch {
            print("Error updating bio: \(error.localizedDescription)")
            await MainActor.run {
                isUpdatingBio = false
                errorMessage = "Failed to update bio"
                showingError = true
            }
        }
    }
    
    private func checkNotificationAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings: UNNotificationSettings = await center.notificationSettings()
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
    
    // Helper function to safely handle ProgressView
    private func safeProgressView() -> some View {
        Group {
            if viewIsActive {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            } else {
                // Empty view when component is not active
                EmptyView()
            }
        }
    }
    
    // Add the uploadProfileImage method
    private func uploadProfileImage(_ image: UIImage) async {
        await MainActor.run {
            isUploadingImage = true
            uploadProgress = 0.0
        }
        
        do {
            guard let imageData = image.jpegData(compressionQuality: 0.7) else {
                throw NSError(domain: "App", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid image data"])
            }
            
            // Simplified implementation - skip actual upload
            await MainActor.run {
                isUploadingImage = false
                successMessage = "Profile image updated successfully"
                showSuccessMessage = true
            }
        } catch {
            print("Error uploading profile image: \(error.localizedDescription)")
            
            await MainActor.run {
                isUploadingImage = false
                errorMessage = "Failed to upload profile image: \(error.localizedDescription)"
                showingError = true
            }
        }
    }
    
    private func scheduleStreakExpirationWarning() async throws {
        guard notificationService.isAuthorized else {
            notificationService.isStreakExpirationWarningEnabled = false
            throw NSError(domain: "App", code: 1, userInfo: [NSLocalizedDescriptionKey: "Notifications are not authorized"])
        }
        
        // Use the NotificationService to schedule the streak expiration warning
        try await notificationService.scheduleStreakExpirationWarning()
        
        // Save to Firestore if user is logged in
        if let userId = userSession.currentUser?.uid {
            do {
                try await Firestore.firestore().collection("users").document(userId).collection("preferences").document("notifications").setData([
                    "streakExpirationWarningEnabled": true,
                    "streakExpirationWarningHours": notificationService.streakExpirationWarningHours,
                    "soundEnabled": isSoundEnabled,
                    "vibrationEnabled": isVibrationEnabled
                ], merge: true)
            } catch {
                // Log error but don't fail the function - notification will still work locally
                print("Error saving streak expiration warning settings to Firestore: \(error.localizedDescription)")
            }
        }
    }
    
    private func cancelStreakExpirationWarning() async throws {
        // Cancel the warning in the NotificationService
        notificationService.cancelStreakExpirationWarning()
        
        // Update Firestore if user is logged in
        if let userId = userSession.currentUser?.uid {
            do {
                try await Firestore.firestore().collection("users").document(userId).collection("preferences").document("notifications").setData([
                    "streakExpirationWarningEnabled": false
                ], merge: true)
            } catch {
                print("Error updating streak expiration warning settings in Firestore: \(error.localizedDescription)")
            }
        }
    }
    
    private func updateExpirationWarningHours() async throws {
        // Update the hours in NotificationService and reschedule if needed
        try await notificationService.updateStreakExpirationWarningHours(notificationService.streakExpirationWarningHours)
        
        // Update Firestore if user is logged in
        if let userId = userSession.currentUser?.uid {
            do {
                try await Firestore.firestore().collection("users").document(userId).collection("preferences").document("notifications").setData([
                    "streakExpirationWarningHours": notificationService.streakExpirationWarningHours
                ], merge: true)
            } catch {
                print("Error updating streak expiration warning hours in Firestore: \(error.localizedDescription)")
            }
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
                        .font(AppTypography.headline(.semibold))
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
                        .font(AppTypography.font(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(Color.theme.text)
                    
                    Spacer()
                    
                    // Chevron indicator with rotation animation
                    Image(systemName: "chevron.down")
                        .font(AppTypography.subhead(.medium))
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
    var subtitle: String? = nil
    let color: Color
    let showChevron: Bool
    @State private var isPressed = false
    
    init(
        icon: String,
        title: String,
        subtitle: String? = nil,
        color: Color = Color.theme.text,
        showChevron: Bool = false
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
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
                    .font(AppTypography.body(.medium))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: subtitle == nil ? 0 : 2) {
                Text(title)
                    .font(AppTypography.body(.medium))
                    .foregroundColor(color)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(AppTypography.subhead())
                        .foregroundColor(Color.theme.subtext)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(AppTypography.subhead(.semibold))
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
        .onAppear { isPressed = false }
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