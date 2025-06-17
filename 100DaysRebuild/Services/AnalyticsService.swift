import Foundation
import FirebaseAnalytics

/// Analytics event constants
struct AppAnalytics {
    // Button tap events
    static let button_tap = "button_tap"
    
    // Screen view events
    static let screen_view = "screen_view"
    
    // Feature usage events
    static let feature_used = "feature_used"
    
    // User engagement events
    static let user_engagement = "user_engagement"
}

/// Service to track analytics events throughout the app
class AnalyticsService {
    static let shared = AnalyticsService()
    
    private init() {
        // Private initializer to ensure singleton pattern
        print("AnalyticsService initialized")
    }
    
    /// Track an analytics event
    func trackEvent(_ name: String, properties: [String: Any] = [:]) {
        #if DEBUG
        print("Analytics event: \(name), properties: \(properties)")
        #endif
        
        // Log to Firebase Analytics
        Analytics.logEvent(name, parameters: properties)
    }
    
    /// Track screen view
    func trackScreenView(screenName: String, screenClass: String) {
        trackEvent(AppAnalytics.screen_view, properties: [
            "screen_name": screenName,
            "screen_class": screenClass
        ])
    }
    
    /// Track button tap
    func trackButtonTap(buttonName: String, screenName: String) {
        trackEvent(AppAnalytics.button_tap, properties: [
            "button_name": buttonName,
            "screen": screenName
        ])
    }
    
    /// Track feature usage
    func trackFeatureUsed(featureName: String) {
        trackEvent(AppAnalytics.feature_used, properties: [
            "feature_name": featureName
        ])
    }
} 