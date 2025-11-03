import Foundation
import SwiftUI

/// Momentum predictor: computes a simple momentum score from the last 14 days
final class MomentumService: @unchecked Sendable {
    nonisolated(unsafe) static let shared = MomentumService()

    enum MomentumState: String, Codable {
        case strong
        case steady
        case atRisk

        var emoji: String {
            switch self {
            case .strong: return "🔥"
            case .steady: return "⚡️"
            case .atRisk: return "⚠️"
            }
        }

        var label: String {
            switch self {
            case .strong: return "Strong Momentum"
            case .steady: return "Steady"
            case .atRisk: return "At Risk"
            }
        }
    }

    private let cacheKey = "momentum_state_cached"
    private let analytics = AnalyticsService.shared

    private init() {}

    /// Current computed state (reads cached value if computed today)
    var currentState: MomentumState? {
        if !FeatureGateService.shared.isEnabled("momentum_predictor") { return nil }
        if let cached = readCached(), Calendar.current.isDateInToday(cached.computedAt) {
            return cached.state
        }
        // compute lazily
        computeInBackground()
        return readCached()?.state
    }

    /// Compute momentum based on the last 14 days using ProgressDashboardViewModel's dateIntensityMap
    func computeInBackground() {
        Task.detached { [weak self] in
            await self?.compute()
        }
    }

    /// Perform compute off the main thread; persist and log analytics on the main actor.
    private func compute() async {
        guard FeatureGateService.shared.isEnabled("momentum_predictor") else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Pull check-in intensity map from ProgressDashboardViewModel (SSOT) on MainActor
        let map: [Date: Int] = await MainActor.run {
            return ProgressDashboardViewModel.shared.dateIntensityMap
        }

        var completedDays = 0
        for i in 0..<14 {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                let normalized = calendar.startOfDay(for: date)
                if let intensity = map[normalized], intensity > 0 {
                    completedDays += 1
                }
            }
        }

        let momentumScore = Double(completedDays) / 14.0
        let state: MomentumState
        switch momentumScore {
        case 0.8...1.0: state = .strong
        case 0.5..<0.8: state = .steady
        default: state = .atRisk
        }

        // Persist & analytics on MainActor to avoid threading issues with UserDefaults/Analytics SDK
        await MainActor.run {
            let payload = CachedMomentum(state: state, score: momentumScore, computedAt: Date())
            if let data = try? JSONEncoder().encode(payload) {
                UserDefaults.standard.set(data, forKey: cacheKey)
            }

            analytics.trackEvent("momentum_score", properties: ["score": momentumScore])
            analytics.trackFeatureUsed(featureName: "momentum_predictor")
        }
    }

    struct CachedMomentum: Codable {
        let state: MomentumState
        let score: Double
        let computedAt: Date
    }

    private func readCached() -> CachedMomentum? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return nil }
        return try? JSONDecoder().decode(CachedMomentum.self, from: data)
    }
}
