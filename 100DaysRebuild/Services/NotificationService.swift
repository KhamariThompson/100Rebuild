import Foundation
import UserNotifications

@MainActor
class NotificationService: ObservableObject {
    static let shared = NotificationService()
    
    @Published private(set) var reminderTime: Date = {
        let components = DateComponents(hour: 20, minute: 0)
        return Calendar.current.date(from: components) ?? Date()
    }()
    
    private let subscriptionService = SubscriptionService.shared
    private let challengeService = ChallengeService.shared
    
    private init() {
        loadReminderTime()
    }
    
    // MARK: - Permission Methods
    func requestPermission() async throws {
        let options: UNAuthorizationOptions = [.alert, .sound, .badge]
        try await UNUserNotificationCenter.current().requestAuthorization(options: options)
    }
    
    // MARK: - Reminder Methods
    func scheduleDailyReminder() async throws {
        // Remove any existing notifications
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = "Daily Check-In Reminder"
        content.body = "Time to check in for your 100-day challenge!"
        content.sound = .default
        
        // Set up trigger for the stored time
        let components = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        
        // Create request
        let request = UNNotificationRequest(
            identifier: "dailyCheckInReminder",
            content: content,
            trigger: trigger
        )
        
        // Schedule notification
        try await UNUserNotificationCenter.current().add(request)
    }
    
    func scheduleStreakReminder() async throws {
        // Remove any existing streak notifications
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["streakReminder"])
        
        // Check if user has active challenges and hasn't checked in today
        let userId = UserSessionService.shared.currentUser?.uid
        guard let userId = userId else { return }
        
        let challenges = try await challengeService.loadChallenges(for: userId)
        let hasActiveChallenges = !challenges.isEmpty
        let hasCheckedInToday = challenges.contains { $0.isCompletedToday }
        
        if hasActiveChallenges && !hasCheckedInToday {
            // Create notification content
            let content = UNMutableNotificationContent()
            content.title = "Don't Break Your Streak!"
            content.body = "Check in before 8AM to keep your streak alive!"
            content.sound = .default
            
            // Set up trigger for 8:00 PM
            var dateComponents = DateComponents()
            dateComponents.hour = 20 // 8:00 PM
            dateComponents.minute = 0
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            
            // Create request
            let request = UNNotificationRequest(
                identifier: "streakReminder",
                content: content,
                trigger: trigger
            )
            
            // Schedule notification
            try await UNUserNotificationCenter.current().add(request)
        }
    }
    
    func updateReminderTime(_ newTime: Date) async throws {
        guard subscriptionService.isSubscribed else {
            throw NotificationError.proFeature
        }
        
        reminderTime = newTime
        saveReminderTime()
        try await scheduleDailyReminder()
    }
    
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    // MARK: - Helper Methods
    private func createNotificationContent(title: String, body: String) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        return content
    }
    
    private func loadReminderTime() {
        if let storedTime = UserDefaults.standard.object(forKey: "reminderTime") as? Date {
            reminderTime = storedTime
        }
    }
    
    private func saveReminderTime() {
        UserDefaults.standard.set(reminderTime, forKey: "reminderTime")
    }
}

enum NotificationError: Error {
    case proFeature
    case schedulingFailed
    case permissionDenied
} 