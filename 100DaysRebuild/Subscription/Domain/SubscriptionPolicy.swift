import Foundation

enum SubscriptionPolicy {
    // Grandfather cutoff: Nov 1, 2025 00:00:00 UTC
    static let cutoff: Date = {
        var comps = DateComponents()
        comps.year = 2025; comps.month = 11; comps.day = 1
        comps.hour = 0; comps.minute = 0; comps.second = 0
        comps.timeZone = TimeZone(secondsFromGMT: 0)
        return Calendar(identifier: .iso8601).date(from: comps)!
    }()

    /// Returns true if the user is grandfathered (pre-cutoff) AND still within 1 year of accountCreatedAt.
    static func isGrandfathered(accountCreatedAt: Date, now: Date = Date()) -> Bool {
        guard accountCreatedAt < cutoff else { return false }
        guard let expiry = Calendar(identifier: .iso8601)
            .date(byAdding: .year, value: 1, to: accountCreatedAt) else { return false }
        return now < expiry
    }
}
