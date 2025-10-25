import Foundation
import FirebaseAnalytics
import SwiftUI
import Combine

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
    
    // MARK: - Funnel Events
    
    // Auth events
    static let auth_required = "auth_required"
    static let auth_success = "auth_success"
    static let auth_failure = "auth_failure"
    
    // Funnel flow events
    static let quiz_started = "quiz_started"
    static let quiz_next = "quiz_next"
    static let quiz_completed = "quiz_completed"
    static let funnel_completed = "funnel_completed"
    static let setup_shown = "setup_shown"
    static let setup_confirmed = "setup_confirmed"
    static let transform_cta_tap = "transform_cta_tap"
    
    // Paywall events
    static let paywall_shown = "paywall_shown"
    static let timer_start = "timer_start"
    static let timer_tick = "timer_tick"
    static let timer_expire = "timer_expire"
    static let purchase_tap = "purchase_tap"
    static let purchase_success = "purchase_success"
    static let restore_tap = "restore_tap"
    static let restore_success = "restore_success"
    static let restore_failure = "restore_failure"
    
    // User state events
    static let cohort_determined = "cohort_determined"
}

/// Service to track analytics events throughout the app
class AnalyticsService: ObservableObject {
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