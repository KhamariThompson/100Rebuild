import Foundation

/// Manages the 5-minute welcome offer window with founders offer consumption tracking
/// Starts when funnel is completed for NEW users, expires after 5 minutes
struct FoundersWindowState: Codable {
    /// Schema version for future migrations
    let version: Int

    /// When the window was started (nil if never started)
    var startedAt: Date?

    /// Whether the user has consumed the founders intro offer
    var foundersOfferConsumed: Bool

    /// Check if window is still active (within 5 minutes of start)
    var isActive: Bool {
        guard let start = startedAt else { return false }
        return Date().timeIntervalSince(start) < 5 * 60
    }

    /// Time remaining in seconds
    var timeRemaining: TimeInterval {
        guard let start = startedAt else { return 0 }
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

    /// Create a new window state
    init(version: Int = 1, startedAt: Date? = nil, foundersOfferConsumed: Bool = false) {
        self.version = version
        self.startedAt = startedAt
        self.foundersOfferConsumed = foundersOfferConsumed
    }

    /// Start a new 5-minute window
    static func start() -> FoundersWindowState {
        FoundersWindowState(version: 1, startedAt: Date(), foundersOfferConsumed: false)
    }
}

// MARK: - Legacy Support (backwards compatibility)

/// Legacy struct name for backwards compatibility with existing persisted data
typealias FiveMinuteWindow = FoundersWindowState
