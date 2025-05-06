import Foundation

enum RemindersAction {
    case toggleDailyReminder(isEnabled: Bool)
    case updateDailyReminderTime(time: Date)
    case toggleStreakReminder(isEnabled: Bool)
    case updateNotificationSettings(sound: Bool, vibration: Bool)
}

struct RemindersState {
    var isDailyReminderEnabled: Bool = false
    var dailyReminderTime: Date = Date()
    var isStreakReminderEnabled: Bool = false
    var notificationSettings: NotificationSettings = .init()
    var isLoading: Bool = false
    var error: String?
}

struct NotificationSettings {
    var soundEnabled: Bool = true
    var vibrationEnabled: Bool = true
}

class RemindersViewModel: ViewModel<RemindersState, RemindersAction> {
    init() {
        super.init(initialState: RemindersState())
    }
    
    override func handle(_ action: RemindersAction) {
        switch action {
        case .toggleDailyReminder(let isEnabled):
            // Update the state with the new value
            var newState = state
            newState.isDailyReminderEnabled = isEnabled
            state = newState
        case .updateDailyReminderTime(let time):
            // Update the state with the new time
            var newState = state
            newState.dailyReminderTime = time
            state = newState
        case .toggleStreakReminder(let isEnabled):
            // Update the state with the new value
            var newState = state
            newState.isStreakReminderEnabled = isEnabled
            state = newState
        case .updateNotificationSettings(let sound, let vibration):
            // Update the notification settings
            var newState = state
            newState.notificationSettings.soundEnabled = sound
            newState.notificationSettings.vibrationEnabled = vibration
            state = newState
        }
    }
} 