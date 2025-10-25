import Foundation

/// Minimal telemetry/analytics shim for critical events
final class TelemetryService {
    static let shared = TelemetryService()
    private init() {}

    func track(event: String, properties: [String: Any]? = nil) {
        // Placeholder: integrate with FirebaseAnalytics or another provider in production.
        // For now we log to console for debugging.
        var output = "Telemetry - \(event)"
        if let props = properties {
            output += " - \(props)"
        }
        print(output)
    }
}
