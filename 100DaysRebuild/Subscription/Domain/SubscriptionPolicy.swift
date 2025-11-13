import Foundation

enum SubscriptionPolicy {
    /// ⚠️ SINGLE SOURCE OF TRUTH for grandfather cutoff
    /// Users who created accounts BEFORE this date get 1 year free Pro
    /// Date: November 1, 2025 at 00:00:00 UTC
    /// Referenced from: Constants.Onboarding.newFunnelStartDate (should use this instead)
    static let grandfatherCutoffUTC: Date = {
        var comps = DateComponents()
        comps.year = 2025
        comps.month = 11
        comps.day = 1
        comps.hour = 0
        comps.minute = 0
        comps.second = 0
        comps.timeZone = TimeZone(secondsFromGMT: 0)  // UTC
        return Calendar(identifier: .iso8601).date(from: comps)!
    }()

    /// @deprecated Use grandfatherCutoffUTC instead
    static var cutoff: Date { grandfatherCutoffUTC }

    /// Grandfather duration: 1 year from account creation
    static let grandfatherDurationYears: Int = 1

    /// Returns true if the user is grandfathered (pre-cutoff) AND still within 1 year of accountCreatedAt.
    static func isGrandfathered(accountCreatedAt: Date, now: Date = Date()) -> Bool {
        guard accountCreatedAt < grandfatherCutoffUTC else { return false }
        guard let expiry = Calendar(identifier: .iso8601)
            .date(byAdding: .year, value: grandfatherDurationYears, to: accountCreatedAt) else { return false }
        return now < expiry
    }
}
