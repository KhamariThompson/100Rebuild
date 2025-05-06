import Foundation
import UserNotifications
import SwiftUI

@MainActor
class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()
    
    @Published private(set) var reminderTime: Date = {
        let components = DateComponents(hour: 20, minute: 0)
        return Calendar.current.date(from: components) ?? Date()
    }()
    
    private let subscriptionService = SubscriptionService.shared
    private let userSession = UserSession.shared
    
    @Published var isAuthorized = false
    @Published private(set) var pendingAuthorization = false
    
    override init() {
        super.init()
        loadReminderTime()
        checkAuthorizationStatus()
    }
    
    // MARK: - Permission Methods
    func requestAuthorization() async throws {
        pendingAuthorization = true
        defer { pendingAuthorization = false }
        
        let options: UNAuthorizationOptions = [.alert, .sound, .badge]
        let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: options)
        
        await MainActor.run {
            isAuthorized = granted
        }
    }
    
    private func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
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
        let userId = userSession.currentUser?.uid
        guard let userId = userId else { return }
        
        let challenges = try await ChallengeService.shared.loadChallenges(for: userId)
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
        guard subscriptionService.isProUser else {
            throw NotificationError.proFeature
        }
        
        reminderTime = newTime
        saveReminderTime()
        try await scheduleDailyReminder()
    }
    
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    func scheduleReminder(for challenge: Challenge, at time: Date) async throws {
        guard isAuthorized else {
            throw NSError(domain: "NotificationService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Notifications not authorized"])
        }
        
        guard subscriptionService.isProUser else {
            throw NSError(domain: "NotificationService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Pro subscription required for reminders"])
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Daily Check-in Reminder"
        content.body = "Don't forget to check in for your challenge: \(challenge.title)"
        content.sound = .default
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        
        let request = UNNotificationRequest(
            identifier: "challenge-\(challenge.id)",
            content: content,
            trigger: trigger
        )
        
        try await UNUserNotificationCenter.current().add(request)
    }
    
    func cancelReminder(for challenge: Challenge) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["challenge-\(challenge.id)"])
    }
    
    func cancelAllReminders() {
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
    case notAuthorized
} 