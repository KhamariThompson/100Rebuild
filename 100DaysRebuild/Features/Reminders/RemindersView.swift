import SwiftUI

struct RemindersView: View {
    @StateObject private var viewModel = RemindersViewModel()
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Daily Reminder
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Daily Reminder")
                            .font(.title3)
                            .foregroundColor(.theme.text)
                        
                        Toggle("Enable Daily Reminder", isOn: .constant(true))
                            .tint(.theme.accent)
                        
                        DatePicker("Time", selection: .constant(Date()), displayedComponents: .hourAndMinute)
                            .datePickerStyle(.compact)
                            .tint(.theme.accent)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.theme.surface)
                            .shadow(
                                color: Color.primary.opacity(colorScheme == .dark ? 0.2 : 0.1),
                                radius: 8, x: 0, y: 4
                            )
                    )
                    .padding(.horizontal)
                    
                    // Streak Reminder
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Streak Reminder")
                            .font(.title3)
                            .foregroundColor(.theme.text)
                        
                        Toggle("Enable Streak Reminder", isOn: .constant(true))
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
                            .shadow(
                                color: Color.primary.opacity(colorScheme == .dark ? 0.2 : 0.1),
                                radius: 8, x: 0, y: 4
                            )
                    )
                    .padding(.horizontal)
                    
                    // Notification Settings
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Notification Settings")
                            .font(.title3)
                            .foregroundColor(.theme.text)
                        
                        Toggle("Sound", isOn: .constant(true))
                            .tint(.theme.accent)
                        
                        Toggle("Vibration", isOn: .constant(true))
                            .tint(.theme.accent)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.theme.surface)
                            .shadow(
                                color: Color.primary.opacity(colorScheme == .dark ? 0.2 : 0.1),
                                radius: 8, x: 0, y: 4
                            )
                    )
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Color.theme.background.ignoresSafeArea())
            .navigationTitle("Reminders")
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// MARK: - Preview
struct RemindersView_Previews: PreviewProvider {
    static var previews: some View {
        RemindersView()
    }
} 