import SwiftUI
import FirebaseAuth

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var subscriptionService: SubscriptionService
    @EnvironmentObject var notificationService: NotificationService
    
    @AppStorage("AppTheme") private var appTheme: String = "system"
    @State private var showingChangeEmail = false
    @State private var showingChangePassword = false
    @State private var showingDeleteAccount = false
    @State private var isRestoringPurchases = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isNotificationsEnabled = false
    @State private var showingDeleteConfirmation = false
    
    private let themeOptions = ["light", "dark", "system"]
    
    var body: some View {
        NavigationView {
            Form {
                notificationsContent
                accountContent
                appearanceContent
                membershipContent()
                aboutContent
            }
            .navigationTitle("Settings")
            .navigationBarItems(trailing: Button("Done") { dismiss() })
            .sheet(isPresented: $showingChangeEmail) {
                ChangeEmailView()
            }
            .sheet(isPresented: $showingChangePassword) {
                ChangePasswordView()
            }
            .sheet(isPresented: $subscriptionService.showPaywall) {
                PaywallView()
            }
            .alert("Delete Account", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task {
                        await handleDeleteAccount()
                    }
                }
            } message: {
                Text("Are you sure you want to delete your account? This action cannot be undone.")
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private var notificationsContent: some View {
        Group {
            Section {
                Toggle("Daily Reminders", isOn: $isNotificationsEnabled)
                    .onChange(of: isNotificationsEnabled) { oldValue, newValue in
                        Task {
                            await handleNotificationToggle(newValue)
                        }
                    }
            } header: {
                Text("Notifications")
            }
        }
    }
    
    private var accountContent: some View {
        Group {
            Section {
                Button(action: { showingChangeEmail = true }) {
                    Label("Change Email", systemImage: "envelope")
                }
                
                Button(action: { showingChangePassword = true }) {
                    Label("Change Password", systemImage: "lock")
                }
                
                Button(action: { 
                    Task {
                        await handleSignOut()
                    }
                }) {
                    Label("Sign Out", systemImage: "arrow.right.square")
                        .foregroundColor(.red)
                }
                
                Button(action: { showingDeleteConfirmation = true }) {
                    Label("Delete Account", systemImage: "trash")
                        .foregroundColor(.red)
                }
            } header: {
                Text("Account")
            }
        }
    }
    
    private var appearanceContent: some View {
        Group {
            Section {
                Picker("Theme", selection: $appTheme) {
                    ForEach(themeOptions, id: \.self) { theme in
                        Text(theme.capitalized)
                            .tag(theme)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            } header: {
                Text("Appearance")
            }
        }
    }
    
    private func membershipContent() -> some View {
        Group {
            Section {
                if subscriptionService.isProUser {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("Pro Member")
                        Spacer()
                        if let renewalDate = subscriptionService.renewalDate {
                            Text("Renews \(renewalDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundColor(.theme.subtext)
                        }
                    }
                    
                    Button(action: restorePurchases) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Restore Purchases")
                            if isRestoringPurchases {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isRestoringPurchases)
                } else {
                    Button(action: {
                        subscriptionService.presentSubscriptionSheet()
                    }) {
                        Label("Upgrade to Pro", systemImage: "star.fill")
                    }
                }
            } header: {
                Text("Membership")
            }
        }
    }
    
    private var aboutContent: some View {
        Group {
            Section {
                Link(destination: URL(string: "https://100days.site/privacy")!) {
                    Label("Privacy Policy", systemImage: "hand.raised")
                }
                
                Link(destination: URL(string: "https://100days.site/terms")!) {
                    Label("Terms of Service", systemImage: "doc.text")
                }
                
                HStack {
                    Label("Version", systemImage: "info.circle")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.gray)
                }
            } header: {
                Text("About")
            }
        }
    }
    
    private func handleNotificationToggle(_ isEnabled: Bool) async {
        do {
            if isEnabled {
                try await notificationService.scheduleDailyReminder()
            } else {
                notificationService.cancelAllNotifications()
            }
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    private func handleSignOut() async {
        await userSession.signOutWithoutThrowing()
    }
    
    private func restorePurchases() {
        isRestoringPurchases = true
        Task {
            do {
                try await subscriptionService.purchaseSubscription(plan: .monthly)
                await MainActor.run {
                    isRestoringPurchases = false
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
        do {
            // Use the UserSession method that handles both Auth and Firestore data deletion
            try await userSession.deleteAccount()
            
            await MainActor.run {
                errorMessage = ""
                showingError = false
                // Close the settings view after successful deletion
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
}

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
                        if isUpdating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Update Email")
                        }
                    }
                    .disabled(newEmail.isEmpty || password.isEmpty || isUpdating)
                }
            }
            .navigationTitle("Change Email")
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
                        if isUpdating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Update Password")
                        }
                    }
                    .disabled(currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty || isUpdating)
                }
            }
            .navigationTitle("Change Password")
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