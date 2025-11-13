import Foundation
import UserNotifications
import SwiftUI
import FirebaseCore
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
    @Published var isStreakExpirationWarningEnabled: Bool = false
    @Published var streakExpirationWarningHours: Int = 3 // Default to 3 hours before expiration
    
    private let subscriptionStore = SubscriptionStore.shared
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
            Task { @MainActor in
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    // MARK: - Pro Feature Requirements
    
    /// Helper to check if Pro features can be used
    private func requireProSubscription() async throws {
        guard subscriptionStore.isPro else {
            // Not Pro - cannot use notification features
            // Note: showPaywall removed from SubscriptionStore - handle in UI layer
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
        
        let challenges: [Challenge]
        do {
            challenges = try await ChallengeService.shared.loadChallenges(for: userId)
        } catch {
            print("NotificationService: Failed to load challenges for streak reminder: \(error)")
            return
        }

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
            do {
                try await UNUserNotificationCenter.current().add(request)
            } catch {
                print("NotificationService: Failed to add streak reminder notification: \(error)")
                return
            }
            
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
        isStreakExpirationWarningEnabled = false
        
        UserDefaults.standard.set(false, forKey: "isDailyReminderEnabled")
        UserDefaults.standard.set(false, forKey: "isStreakReminderEnabled")
        UserDefaults.standard.set(false, forKey: "isStreakExpirationWarningEnabled")
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
        isStreakExpirationWarningEnabled = UserDefaults.standard.bool(forKey: "isStreakExpirationWarningEnabled")
        streakExpirationWarningHours = UserDefaults.standard.integer(forKey: "streakExpirationWarningHours")
        
        // Set default value if it doesn't exist
        if UserDefaults.standard.object(forKey: "streakExpirationWarningHours") == nil {
            streakExpirationWarningHours = 3
            UserDefaults.standard.set(3, forKey: "streakExpirationWarningHours")
        }
        
        // Load from Firestore if user is logged in and Firebase is configured
        Task {
            if FirebaseApp.app() != nil {
                await loadSettingsFromFirestore()
            } else {
                print("NotificationService: Firebase not configured yet - skipping Firestore load")
            }
        }
    }
    
    /// Load notification settings from Firestore for the current user
    func loadSettingsFromFirestore() async {
        // Defensive: ensure Firebase is configured before touching Firestore
        guard FirebaseApp.app() != nil else {
            print("NotificationService: Firebase not configured yet - skipping Firestore load")
            return
        }

        guard let userId = userSession.currentUser?.uid else { return }

        do {
            let document = try await Firestore.firestore()
                .collection("users")
                .document(userId)
                .collection("preferences")
                .document("notifications")
                .getDocument()

            guard document.exists, let data = document.data() else { return }

            // Load the settings from Firestore and update local state
            await MainActor.run {
                // Daily reminder
                if let dailyReminderEnabled = data["dailyReminderEnabled"] as? Bool {
                    self.isDailyReminderEnabled = dailyReminderEnabled
                    UserDefaults.standard.set(dailyReminderEnabled, forKey: "isDailyReminderEnabled")
                }

                // Reminder time
                if let reminderTimestamp = data["reminderTime"] as? Timestamp {
                    self.reminderTime = reminderTimestamp.dateValue()
                    UserDefaults.standard.set(self.reminderTime, forKey: "reminderTime")
                }

                // Streak reminder
                if let streakReminderEnabled = data["streakReminderEnabled"] as? Bool {
                    self.isStreakReminderEnabled = streakReminderEnabled
                    UserDefaults.standard.set(streakReminderEnabled, forKey: "isStreakReminderEnabled")
                }

                // Streak expiration warning
                if let streakExpirationWarningEnabled = data["streakExpirationWarningEnabled"] as? Bool {
                    self.isStreakExpirationWarningEnabled = streakExpirationWarningEnabled
                    UserDefaults.standard.set(streakExpirationWarningEnabled, forKey: "isStreakExpirationWarningEnabled")
                }

                // Streak expiration warning hours
                if let hours = data["streakExpirationWarningHours"] as? Int {
                    self.streakExpirationWarningHours = hours
                    UserDefaults.standard.set(hours, forKey: "streakExpirationWarningHours")
                }
            }

            // Schedule notifications if they're enabled. Wrap each scheduling call to avoid unhandled errors
            if isAuthorized {
                if isDailyReminderEnabled {
                    do { try await scheduleDailyReminder() } catch { print("NotificationService: Failed to schedule daily reminder: \(error)") }
                }

                if isStreakReminderEnabled {
                    do { try await scheduleStreakReminder() } catch { print("NotificationService: Failed to schedule streak reminder: \(error)") }
                }

                if isStreakExpirationWarningEnabled {
                    do { try await scheduleStreakExpirationWarning() } catch { print("NotificationService: Failed to schedule streak expiration warning: \(error)") }
                }
            }
        } catch {
            print("Error loading notification settings from Firestore: \(error.localizedDescription)")
        }
    }
    
    /// Reset all state to initial values
    @MainActor
    func reset() {
        // Reset all published properties
        reminderTime = Calendar.current.date(from: DateComponents(hour: 20, minute: 0)) ?? Date()
        isDailyReminderEnabled = false
        isStreakReminderEnabled = false
        isStreakExpirationWarningEnabled = false
        streakExpirationWarningHours = 3
        isAuthorized = false
        pendingAuthorization = false
        
        // Cancel all pending notifications
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        // Reset UserDefaults
        UserDefaults.standard.set(false, forKey: "isDailyReminderEnabled")
        UserDefaults.standard.set(false, forKey: "isStreakReminderEnabled")
        UserDefaults.standard.set(false, forKey: "isStreakExpirationWarningEnabled")
        UserDefaults.standard.set(3, forKey: "streakExpirationWarningHours")
        
        print("NotificationService - Reset complete")
    }
    
    deinit {
        print("✅ Singleton released: \(Self.self)")
    }
    
    // MARK: - Streak Expiration Warning Methods
    
    /// Schedule a warning notification that fires when a streak is about to expire
    func scheduleStreakExpirationWarning() async throws {
        guard isAuthorized else {
            throw NotificationError.notAuthorized
        }
        
        // Remove any existing expiration warnings
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["streakExpirationWarning"])
        
        // Get active challenges
        let userId = userSession.currentUser?.uid
        guard let userId = userId else { return }
        
        let challenges: [Challenge]
        do {
            challenges = try await ChallengeService.shared.loadChallenges(for: userId)
        } catch {
            print("NotificationService: Failed to load challenges for expiration warning: \(error)")
            return
        }

        let activeChallenges = challenges.filter { !$0.isCompleted && $0.streakCount > 0 && !$0.hasStreakExpired }
        
        if !activeChallenges.isEmpty {
            // Create notification content
            let content = UNMutableNotificationContent()
            content.title = "Streak About to Expire!"
            
            // If we have a specific challenge with the highest streak, mention it
            if let highestStreakChallenge = activeChallenges.max(by: { $0.streakCount < $1.streakCount }) {
                content.title = "🔥 Your \(highestStreakChallenge.streakCount)-day Streak is at Risk!"
                content.body = "Check in to \"\(highestStreakChallenge.title)\" in the next \(streakExpirationWarningHours) hours to keep your streak alive!"
            } else {
                content.body = "You have active challenges that need a check-in soon to maintain your streak!"
            }
            
            content.sound = .default
            
            // Calculate when to fire the notification - at midnight minus the warning hours
            let calendar = Calendar.current
            let now = Date()
            
            // Get tomorrow's date and calculate midnight
            guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) else {
                throw NotificationError.schedulingFailed
            }
            
            let midnight = calendar.startOfDay(for: tomorrow)
            
            // Calculate warning time (e.g., 3 hours before midnight)
            guard let warningTime = calendar.date(byAdding: .hour, value: -streakExpirationWarningHours, to: midnight) else {
                throw NotificationError.schedulingFailed
            }
            
            // If it's already past the warning time for today, schedule for tomorrow
            let schedulingDate = now > warningTime ? warningTime : warningTime
            
            // Extract components for a daily repeating trigger at the calculated warning time
            let components = calendar.dateComponents([.hour, .minute], from: schedulingDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            
            // Create request
            let request = UNNotificationRequest(
                identifier: "streakExpirationWarning",
                content: content,
                trigger: trigger
            )
            
            // Schedule notification
            do {
                try await UNUserNotificationCenter.current().add(request)
            } catch {
                print("NotificationService: Failed to add streak expiration warning notification: \(error)")
                return
            }
            
            // Update settings
            isStreakExpirationWarningEnabled = true
            UserDefaults.standard.set(true, forKey: "isStreakExpirationWarningEnabled")
        }
    }
    
    func cancelStreakExpirationWarning() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["streakExpirationWarning"])
        isStreakExpirationWarningEnabled = false
        UserDefaults.standard.set(false, forKey: "isStreakExpirationWarningEnabled")
    }
    
    func updateStreakExpirationWarningHours(_ hours: Int) async throws {
        streakExpirationWarningHours = hours
        UserDefaults.standard.set(hours, forKey: "streakExpirationWarningHours")
        
        // If warnings are enabled, reschedule with new time
        if isStreakExpirationWarningEnabled {
            try await scheduleStreakExpirationWarning()
        }
    }

    // MARK: - Social Notification Helpers (used by Social features)

    /// Schedule a simple encouragement notification sent from one user to another
    func scheduleEncouragementNotification(fromUser: String, message: String) async throws {
        guard isAuthorized else { throw NotificationError.notAuthorized }

        let content = createNotificationContent(title: "Encouragement from @\(fromUser)", body: message)
        let identifier = "encouragement-\(UUID().uuidString)"

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    /// Schedule a notification when someone reacts to a post
    func scheduleReactionNotification(friendName: String, emoji: String, challengeTitle: String) async throws {
        guard isAuthorized else { throw NotificationError.notAuthorized }

        let title = "\(friendName) reacted to your post"
        let body = "\(friendName) reacted with \(emoji) on \(challengeTitle)"
        let content = createNotificationContent(title: title, body: body)
        let identifier = "reaction-\(UUID().uuidString)"

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    /// Schedule a notification when a friend checks in
    func scheduleFriendCheckInNotification(friendName: String, challengeTitle: String) async throws {
        guard isAuthorized else { throw NotificationError.notAuthorized }

        let title = "\(friendName) checked in"
        let body = "\(friendName) checked in for \(challengeTitle) — cheer them on!"
        let content = createNotificationContent(title: title, body: body)
        let identifier = "friendCheckIn-\(UUID().uuidString)"

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    /// Schedule a notification for milestone achievements
    func scheduleMilestoneNotification(friendName: String, milestone: Int, challengeTitle: String) async throws {
        guard isAuthorized else { throw NotificationError.notAuthorized }

        let title = "\(friendName) hit a milestone!"
        let body = "\(friendName) reached day \(milestone) of \(challengeTitle) — celebrate their progress!"
        let content = createNotificationContent(title: title, body: body)
        let identifier = "milestone-\(UUID().uuidString)"

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    /// Schedule a notification for challenge completion
    func scheduleChallengeCompletionNotification(friendName: String, challengeTitle: String) async throws {
        guard isAuthorized else { throw NotificationError.notAuthorized }

        let title = "\(friendName) completed a challenge!"
        let body = "\(friendName) completed \(challengeTitle). Congratulate them!"
        let content = createNotificationContent(title: title, body: body)
        let identifier = "challengeComplete-\(UUID().uuidString)"

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
} 