import Foundation
import UserNotifications
import SwiftUI
import FirebaseFirestore

// Using canonical Challenge model
// (No import needed as it will be accessed directly)

enum NotificationError: Error, LocalizedError {
    case proFeature
    case schedulingFailed
    case permissionDenied
    case notAuthorized
    
    var errorDescription: String? {
        switch self {
        case .proFeature:
            return "Custom notification settings require a Pro subscription"
        case .schedulingFailed:
            return "Failed to schedule notification"
        case .permissionDenied:
            return "Notification permission was denied"
        case .notAuthorized:
            return "Please enable notifications in your device settings"
        }
    }
}

@MainActor
class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()
    
    @Published var reminderTime: Date = {
        let components = DateComponents(hour: 20, minute: 0)
        return Calendar.current.date(from: components) ?? Date()
    }()
    
    @Published var isDailyReminderEnabled: Bool = false
    @Published var isStreakReminderEnabled: Bool = false
    
    private let subscriptionService = SubscriptionService.shared
    private let userSession = UserSession.shared
    
    @Published var isAuthorized = false
    @Published private(set) var pendingAuthorization = false
    
    override init() {
        super.init()
        loadReminderTime()
        loadNotificationSettings()
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
    
    // Method to request notification permission with return value
    func requestNotificationPermission() async throws -> Bool {
        pendingAuthorization = true
        defer { pendingAuthorization = false }
        
        let options: UNAuthorizationOptions = [.alert, .sound, .badge]
        let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: options)
        
        await MainActor.run {
            isAuthorized = granted
        }
        
        return granted
    }
    
    private func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    // MARK: - Pro Feature Requirements
    
    /// Helper to check if Pro features can be used
    private func requireProSubscription() async throws {
        guard subscriptionService.isProUser else {
            // Show paywall on the main thread
            await MainActor.run {
                subscriptionService.showPaywall = true
            }
            throw NotificationError.proFeature
        }
    }
    
    // MARK: - Reminder Methods
    func scheduleDailyReminder() async throws {
        // Daily reminders are available to all users
        guard isAuthorized else {
            throw NotificationError.notAuthorized
        }
        
        // Remove any existing daily reminders
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["dailyCheckInReminder"])
        
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
        
        // Update local state
        isDailyReminderEnabled = true
        UserDefaults.standard.set(true, forKey: "isDailyReminderEnabled")
    }
    
    func cancelDailyReminder() async throws {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["dailyCheckInReminder"])
        isDailyReminderEnabled = false
        UserDefaults.standard.set(false, forKey: "isDailyReminderEnabled")
    }
    
    func scheduleStreakReminder() async throws {
        // Streak reminders are available to all users
        guard isAuthorized else {
            throw NotificationError.notAuthorized
        }
        
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
            
            // Update local state
            isStreakReminderEnabled = true
            UserDefaults.standard.set(true, forKey: "isStreakReminderEnabled")
        }
    }
    
    func cancelStreakReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["streakReminder"])
        isStreakReminderEnabled = false
        UserDefaults.standard.set(false, forKey: "isStreakReminderEnabled")
    }
    
    func updateReminderTime(_ newTime: Date) async throws {
        // Custom notification time is a Pro feature
        try await requireProSubscription()
        
        reminderTime = newTime
        saveReminderTime()
        
        // If daily reminders are enabled, reschedule with new time
        if isDailyReminderEnabled {
            try await scheduleDailyReminder()
        }
    }
    
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        isDailyReminderEnabled = false
        isStreakReminderEnabled = false
        UserDefaults.standard.set(false, forKey: "isDailyReminderEnabled")
        UserDefaults.standard.set(false, forKey: "isStreakReminderEnabled")
    }
    
    func scheduleReminder(for challenge: Challenge, at time: Date) async throws {
        guard isAuthorized else {
            throw NotificationError.notAuthorized
        }
        
        // Per-challenge reminders are a Pro feature
        try await requireProSubscription()
        
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
    
    func cancelReminder(for challenge: Challenge) async throws {
        // Per-challenge notification management is a Pro feature
        try await requireProSubscription()
        
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["challenge-\(challenge.id)"])
    }
    
    // MARK: - Helper Methods
    private func createNotificationContent(title: String, body: String) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        return content
    }
    
    private func saveReminderTime() {
        UserDefaults.standard.set(reminderTime, forKey: "reminderTime")
    }
    
    private func loadReminderTime() {
        if let savedTime = UserDefaults.standard.object(forKey: "reminderTime") as? Date {
            reminderTime = savedTime
        }
    }
    
    private func loadNotificationSettings() {
        isDailyReminderEnabled = UserDefaults.standard.bool(forKey: "isDailyReminderEnabled")
        isStreakReminderEnabled = UserDefaults.standard.bool(forKey: "isStreakReminderEnabled")
    }
} 