import Foundation

/// Protocol for providing the current date/time
/// Allows deterministic testing by injecting controlled time
protocol ClockProvider: Sendable {
    func now() -> Date
}

/// Production clock that returns actual system time
struct SystemClock: ClockProvider {
    func now() -> Date {
        return Date()
    }
}

/// Test clock that returns a fixed, controllable date
actor DeterministicClock: ClockProvider {
    private var currentDate: Date

    init(fixedDate: Date) {
        self.currentDate = fixedDate
    }

    /// Get the current date
    func now() -> Date {
        return currentDate
    }

    /// Advance time by the specified interval
    func advance(by interval: TimeInterval) {
        currentDate = currentDate.addingTimeInterval(interval)
    }

    /// Set the clock to a specific date
    func set(to date: Date) {
        currentDate = date
    }
}

/// Helper to create common test dates
enum TestDates {
    /// October 15, 2025 00:00:00 UTC - Pre-cutoff (grandfathered)
    static let preCutoff = makeDateUTC(year: 2025, month: 10, day: 15)

    /// November 1, 2025 00:00:00 UTC - Cutoff date (NEW user boundary)
    static let cutoff = makeDateUTC(year: 2025, month: 11, day: 1)

    /// November 2, 2025 00:00:00 UTC - Post-cutoff (new user)
    static let postCutoff = makeDateUTC(year: 2025, month: 11, day: 2)

    /// October 15, 2026 00:00:01 UTC - 1 year + 1 second after preCutoff (grandfather expired)
    static let grandfatherExpired = makeDateUTC(year: 2026, month: 10, day: 15, hour: 0, minute: 0, second: 1)

    /// Helper to create UTC dates
    private static func makeDateUTC(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0, second: Int = 0) -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = hour
        comps.minute = minute
        comps.second = second
        comps.timeZone = TimeZone(secondsFromGMT: 0)  // UTC
        return Calendar(identifier: .iso8601).date(from: comps)!
    }
}
