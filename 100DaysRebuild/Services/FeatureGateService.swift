import Foundation

/// Lightweight on-device feature gate service
/// Allows registering simple feature flags with defaults and checking if enabled.
final class FeatureGateService: @unchecked Sendable {
    nonisolated(unsafe) static let shared = FeatureGateService()

    private let storageKey = "feature_gates"
    private var flags: [String: Bool] = [:]

    private init() {
        loadFromDefaults()

        // Register app features and defaults here
        register("momentum_predictor", default: true)
        register("progress_forecast", default: true)
    }

    func register(_ feature: String, default defaultValue: Bool) {
        if flags[feature] == nil {
            flags[feature] = defaultValue
            saveToDefaults()
        }
    }

    func isEnabled(_ feature: String) -> Bool {
        return flags[feature] ?? false
    }

    func set(_ feature: String, enabled: Bool) {
        flags[feature] = enabled
        saveToDefaults()
    }

    private func loadFromDefaults() {
        if let dict = UserDefaults.standard.dictionary(forKey: storageKey) as? [String: Bool] {
            flags = dict
        }
    }

    private func saveToDefaults() {
        UserDefaults.standard.set(flags, forKey: storageKey)
    }
}
