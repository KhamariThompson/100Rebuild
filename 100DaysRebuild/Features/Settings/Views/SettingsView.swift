import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var userSession: UserSessionService
    @EnvironmentObject var subscriptionService: SubscriptionService
    @EnvironmentObject var notificationService: NotificationService
    
    @AppStorage("AppTheme") private var appTheme: String = "system"
    @State private var showingChangeEmail = false
    @State private var showingChangePassword = false
    @State private var showingDeleteAccount = false
    @State private var showingPaywall = false
    @State private var isRestoringPurchases = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    private let themeOptions = ["light", "dark", "system"]
    
    var body: some View {
        NavigationView {
            List {
                // Notifications Section
                Section(header: Text("Notifications")) {
                    Toggle("Daily Reminders", isOn: $notificationService.isNotificationsEnabled)
                        .onChange(of: notificationService.isNotificationsEnabled) { newValue in
                            if newValue {
                                notificationService.scheduleDailyReminder()
                            } else {
                                notificationService.cancelAllNotifications()
                            }
                        }
                }
                
                // Account Section
                Section(header: Text("Account")) {
                    Button(action: { showingChangeEmail = true }) {
                        HStack {
                            Image(systemName: "envelope")
                            Text("Change Email")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                        }
                    }
                    
                    Button(action: { showingChangePassword = true }) {
                        HStack {
                            Image(systemName: "lock")
                            Text("Change Password")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                        }
                    }
                }
                
                // Appearance Section
                Section(header: Text("Appearance")) {
                    Picker("Theme", selection: $appTheme) {
                        ForEach(themeOptions, id: \.self) { theme in
                            Text(theme.capitalized)
                                .tag(theme)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                // Membership Section
                Section(header: Text("Membership")) {
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
                        Button(action: { showingPaywall = true }) {
                            HStack {
                                Image(systemName: "crown.fill")
                                Text("Upgrade to Pro")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                            }
                        }
                    }
                }
                
                // Danger Zone Section
                Section(header: Text("Danger Zone")) {
                    Button(action: { showingDeleteAccount = true }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete Account")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                        }
                        .foregroundColor(.red)
                    }
                    
                    Button(action: signOut) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign Out")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Settings")
            .navigationBarItems(trailing: Button("Done") { dismiss() })
            .sheet(isPresented: $showingChangeEmail) {
                ChangeEmailView()
            }
            .sheet(isPresented: $showingChangePassword) {
                ChangePasswordView()
            }
            .sheet(isPresented: $showingDeleteAccount) {
                DeleteAccountView()
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func restorePurchases() {
        isRestoringPurchases = true
        Task {
            do {
                try await subscriptionService.restorePurchases()
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
            isRestoringPurchases = false
        }
    }
    
    private func signOut() {
        do {
            try userSession.signOut()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

struct ChangeEmailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var userSession: UserSessionService
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
                    
                    SecureField("Current Password", text: $password)
                        .textContentType(.password)
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
                try await userSession.updateEmail(newEmail, password: password)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
            isUpdating = false
        }
    }
}

struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var userSession: UserSessionService
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
                    
                    SecureField("New Password", text: $newPassword)
                        .textContentType(.newPassword)
                    
                    SecureField("Confirm New Password", text: $confirmPassword)
                        .textContentType(.newPassword)
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
                    .disabled(currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty || newPassword != confirmPassword || isUpdating)
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
                try await userSession.updatePassword(currentPassword, newPassword: newPassword)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
            isUpdating = false
        }
    }
}

struct DeleteAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var userSession: UserSessionService
    @State private var password = ""
    @State private var isDeleting = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Text("Are you sure you want to delete your account? This action cannot be undone.")
                        .foregroundColor(.red)
                    
                    SecureField("Enter Password to Confirm", text: $password)
                        .textContentType(.password)
                }
                
                Section {
                    Button(action: deleteAccount) {
                        if isDeleting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Delete Account")
                                .foregroundColor(.red)
                        }
                    }
                    .disabled(password.isEmpty || isDeleting)
                }
            }
            .navigationTitle("Delete Account")
            .navigationBarItems(trailing: Button("Cancel") { dismiss() })
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func deleteAccount() {
        isDeleting = true
        Task {
            do {
                try await userSession.deleteAccount(password: password)
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
            isDeleting = false
        }
    }
} 