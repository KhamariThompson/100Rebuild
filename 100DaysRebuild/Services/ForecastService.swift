import Foundation
import SwiftUI

/// Forecast service: simple linear regression over recent days to estimate Day 100 finish date
final class ForecastService: @unchecked Sendable {
    nonisolated(unsafe) static let shared = ForecastService()

    struct ProgressPoint: Identifiable {
        let id = UUID()
        let day: Int
        let percent: Double
    }

    struct ForecastResult: Codable {
        let predictedDate: Date
        let confidence: Double
        let generatedAt: Date
    }

    private let cacheKey = "forecast_cached"
    private let analytics = AnalyticsService.shared
    private let checkedKey = "forecast_checked_at"

    private init() {}

    var latest: ForecastResult? {
        guard FeatureGateService.shared.isEnabled("progress_forecast") else { return nil }
        return readCached()
    }

    /// Compute forecast once per day (no-op if already computed today)
    func computeIfNeeded() {
        if let lastChecked = UserDefaults.standard.object(forKey: checkedKey) as? Date,
           Calendar.current.isDateInToday(lastChecked) {
            return
        }

        Task.detached { [weak self] in
            await self?.compute()
        }
    }

    /// Async compute: read SSOT on MainActor, do math off-main-thread, persist & analytics on MainActor
    private func compute() async {
        guard FeatureGateService.shared.isEnabled("progress_forecast") else { return }

        // Read required SSOT data on the MainActor
        let (points, completedDays): ([ProgressDailyCheckIn], Int) = await MainActor.run {
            let vm = ProgressDashboardViewModel.shared
            return (vm.dailyCheckInsData, vm.totalCompletedChallenges)
        }

        // Build series (x = index/day, y = cumulative completed challenges)
        var xs: [Double] = []
        var ys: [Double] = []

        let sorted = points.sorted { $0.date < $1.date }
        var cumulative = 0
        for (i, p) in sorted.enumerated() {
            cumulative += p.count
            xs.append(Double(i))
            ys.append(Double(cumulative))
        }

        // Perform regression off-main-thread
        let computedResult: ForecastResult? = await Task.detached { () -> ForecastResult? in
            guard xs.count >= 2 else { return nil }

            let n = Double(xs.count)
            let sumX = xs.reduce(0, +)
            let sumY = ys.reduce(0, +)
            let sumXY = zip(xs, ys).map(*).reduce(0, +)
            let sumX2 = xs.map { $0*$0 }.reduce(0, +)

            let denominator = (n * sumX2 - sumX * sumX)
            if denominator == 0 { return nil }

            let slope = (n * sumXY - sumX * sumY) / denominator
            let intercept = (sumY - slope * sumX) / n

            let slopePerDay = max(0.01, slope)
            let daysRemaining = Double(max(0, 100 - completedDays)) / slopePerDay
            let predictedDate = Calendar.current.date(byAdding: .day, value: Int(ceil(daysRemaining)), to: Date()) ?? Date()

            let residuals = zip(xs, ys).map { x, y in y - (slope * x + intercept) }
            let mse = residuals.map { $0*$0 }.reduce(0, +) / Double(residuals.count)
            let confidence = max(0.0, min(1.0, 1.0 - min(1.0, mse / max(1.0, sumY / n))))

            return ForecastResult(predictedDate: predictedDate, confidence: confidence, generatedAt: Date())
        }.value

        // Persist result (if any) and mark checked timestamp on MainActor
        await MainActor.run {
            if let res = computedResult, let data = try? JSONEncoder().encode(res) {
                UserDefaults.standard.set(data, forKey: cacheKey)
                analytics.trackEvent("forecast_date", properties: ["date": ISO8601DateFormatter().string(from: res.predictedDate)])
                analytics.trackFeatureUsed(featureName: "progress_forecast")
            }

            // Always mark that we checked today so we don't run again until the next day
            UserDefaults.standard.set(Date(), forKey: checkedKey)
        }
    }

    /// Trend points for charting (reads SSOT on MainActor)
    func trendPoints(limitDays: Int = 30) async -> [ProgressPoint] {
        let points: [ProgressDailyCheckIn] = await MainActor.run {
            return ProgressDashboardViewModel.shared.dailyCheckInsData
        }

        var out: [ProgressPoint] = []
        let sorted = points.sorted { $0.date < $1.date }
        var cumulative = 0
        let start = max(0, sorted.count - limitDays)
        for (i, p) in sorted[start...].enumerated() {
            cumulative += p.count
            out.append(ProgressPoint(day: i, percent: Double(cumulative) / 100.0))
        }
        return out
    }

    /// Synchronous variant for use from Views (runs on MainActor)
    @MainActor
    func trendPointsSync(limitDays: Int = 30) -> [ProgressPoint] {
        let points = ProgressDashboardViewModel.shared.dailyCheckInsData
        var out: [ProgressPoint] = []
        let sorted = points.sorted { $0.date < $1.date }
        var cumulative = 0
        let start = max(0, sorted.count - limitDays)
        for (i, p) in sorted[start...].enumerated() {
            cumulative += p.count
            out.append(ProgressPoint(day: i, percent: Double(cumulative) / 100.0))
        }
        return out
    }

    private func readCached() -> ForecastResult? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return nil }
        return try? JSONDecoder().decode(ForecastResult.self, from: data)
    }
}
