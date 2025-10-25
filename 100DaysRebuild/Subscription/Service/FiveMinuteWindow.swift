import Foundation

/// Manages the 5-minute welcome offer window
/// Starts when funnel is completed, expires after 5 minutes
struct FiveMinuteWindow: Codable {
    let start: Date

    /// Check if window is still active
    var isActive: Bool {
        Date().timeIntervalSince(start) < 5 * 60
    }

    /// Time remaining in seconds
    var timeRemaining: TimeInterval {
        let elapsed = Date().timeIntervalSince(start)
        return max(0, 5 * 60 - elapsed)
    }

    /// Formatted time remaining (MM:SS)
    var formattedTimeRemaining: String {
        let remaining = Int(timeRemaining)
        let minutes = remaining / 60
        let seconds = remaining % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Start a new 5-minute window
    static func start() -> FiveMinuteWindow {
        FiveMinuteWindow(start: Date())
    }
}
