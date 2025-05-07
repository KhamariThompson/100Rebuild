import SwiftUI

struct ReminderTabView: View {
    @StateObject private var viewModel = RemindersViewModel()
    @EnvironmentObject var subscriptionService: SubscriptionService
    @EnvironmentObject var notificationService: NotificationService
    @State private var showingPermissionAlert = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
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
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.theme.surface)
                                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                        )
                        .padding(.horizontal)
                    }
                    
                    // Daily Reminder
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Daily Reminder")
                            .font(.title3)
                            .foregroundColor(.theme.text)
                        
                        Toggle("Enable Daily Reminder", isOn: Binding(
                            get: { viewModel.state.isDailyReminderEnabled },
                            set: { 
                                viewModel.handle(.toggleDailyReminder(isEnabled: $0))
                                if $0 {
                                    scheduleReminders()
                                } else {
                                    cancelReminders()
                                }
                            }
                        ))
                        .tint(.theme.accent)
                        .disabled(!notificationService.isAuthorized)
                        
                        DatePicker("Time", selection: Binding(
                            get: { viewModel.state.dailyReminderTime },
                            set: { 
                                viewModel.handle(.updateDailyReminderTime(time: $0))
                                updateReminderTime($0)
                            }
                        ), displayedComponents: .hourAndMinute)
                        .datePickerStyle(.compact)
                        .tint(.theme.accent)
                        .disabled(!notificationService.isAuthorized || !viewModel.state.isDailyReminderEnabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.theme.surface)
                            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                    )
                    .padding(.horizontal)
                    
                    // Streak Reminder
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Streak Reminder")
                            .font(.title3)
                            .foregroundColor(.theme.text)
                        
                        Toggle("Enable Streak Reminder", isOn: Binding(
                            get: { viewModel.state.isStreakReminderEnabled },
                            set: { 
                                viewModel.handle(.toggleStreakReminder(isEnabled: $0))
                                if $0 {
                                    scheduleStreakReminder()
                                } else {
                                    cancelStreakReminder()
                                }
                            }
                        ))
                        .tint(.theme.accent)
                        .disabled(!notificationService.isAuthorized)
                        
                        Text("Get notified when you're about to break your streak")
                            .font(.subheadline)
                            .foregroundColor(.theme.subtext)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.theme.surface)
                            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                    )
                    .padding(.horizontal)
                    
                    // Notification Settings
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Notification Settings")
                            .font(.title3)
                            .foregroundColor(.theme.text)
                        
                        Toggle("Sound", isOn: Binding(
                            get: { viewModel.state.notificationSettings.soundEnabled },
                            set: { newValue in
                                viewModel.handle(.updateNotificationSettings(
                                    sound: newValue,
                                    vibration: viewModel.state.notificationSettings.vibrationEnabled
                                ))
                            }
                        ))
                        .tint(.theme.accent)
                        
                        Toggle("Vibration", isOn: Binding(
                            get: { viewModel.state.notificationSettings.vibrationEnabled },
                            set: { newValue in
                                viewModel.handle(.updateNotificationSettings(
                                    sound: viewModel.state.notificationSettings.soundEnabled,
                                    vibration: newValue
                                ))
                            }
                        ))
                        .tint(.theme.accent)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.theme.surface)
                            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                    )
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Color.theme.background.ignoresSafeArea())
            .navigationTitle("Reminders")
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
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private func requestNotificationPermission() {
        Task {
            do {
                try await notificationService.requestAuthorization()
                if notificationService.isAuthorized {
                    if viewModel.state.isDailyReminderEnabled {
                        scheduleReminders()
                    }
                    if viewModel.state.isStreakReminderEnabled {
                        scheduleStreakReminder()
                    }
                } else {
                    showingPermissionAlert = true
                }
            } catch {
                showingPermissionAlert = true
            }
        }
    }
    
    private func scheduleReminders() {
        Task {
            do {
                try await notificationService.scheduleDailyReminder()
            } catch {
                // Handle error
            }
        }
    }
    
    private func cancelReminders() {
        notificationService.cancelAllNotifications()
    }
    
    private func scheduleStreakReminder() {
        Task {
            do {
                try await notificationService.scheduleStreakReminder()
            } catch {
                // Handle error
            }
        }
    }
    
    private func cancelStreakReminder() {
        notificationService.cancelAllNotifications()
    }
    
    private func updateReminderTime(_ time: Date) {
        Task {
            do {
                try await notificationService.updateReminderTime(time)
            } catch {
                // Handle error
            }
        }
    }
    
    private func syncWithNotificationService() {
        // Sync view model with notification service state
        viewModel.handle(.updateDailyReminderTime(time: notificationService.reminderTime))
    }
}

struct ReminderTabView_Previews: PreviewProvider {
    static var previews: some View {
        ReminderTabView()
            .environmentObject(SubscriptionService.shared)
            .environmentObject(NotificationService.shared)
    }
} 