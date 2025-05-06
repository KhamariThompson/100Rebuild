import SwiftUI

struct ReminderTabView: View {
    @StateObject private var viewModel = RemindersViewModel()
    @EnvironmentObject var subscriptionService: SubscriptionService
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Daily Reminder
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Daily Reminder")
                            .font(.title3)
                            .foregroundColor(.theme.text)
                        
                        Toggle("Enable Daily Reminder", isOn: Binding(
                            get: { viewModel.state.isDailyReminderEnabled },
                            set: { viewModel.handle(.toggleDailyReminder(isEnabled: $0)) }
                        ))
                        .tint(.theme.accent)
                        
                        DatePicker("Time", selection: Binding(
                            get: { viewModel.state.dailyReminderTime },
                            set: { viewModel.handle(.updateDailyReminderTime(time: $0)) }
                        ), displayedComponents: .hourAndMinute)
                        .datePickerStyle(.compact)
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
                    
                    // Streak Reminder
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Streak Reminder")
                            .font(.title3)
                            .foregroundColor(.theme.text)
                        
                        Toggle("Enable Streak Reminder", isOn: Binding(
                            get: { viewModel.state.isStreakReminderEnabled },
                            set: { viewModel.handle(.toggleStreakReminder(isEnabled: $0)) }
                        ))
                        .tint(.theme.accent)
                        
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
        }
    }
}

struct ReminderTabView_Previews: PreviewProvider {
    static var previews: some View {
        ReminderTabView()
            .environmentObject(SubscriptionService.shared)
    }
} 