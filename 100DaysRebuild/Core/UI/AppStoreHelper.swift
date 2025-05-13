import Foundation
import SwiftUI
import StoreKit

/// Helper struct for App Store related functionality
enum AppStoreHelper {
    /// The App Store ID for the app
    static let appStoreId = "6451169428" // Replace with your actual App Store ID when available
    
    /// Opens the App Store review page for the app
    static func openAppStoreReview() {
        guard let writeReviewURL = URL(string: "https://apps.apple.com/app/id\(appStoreId)?action=write-review") else {
            return
        }
        
        UIApplication.shared.open(writeReviewURL)
    }
    
    /// Requests an in-app review when appropriate
    static func requestReview() {
        guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else {
            return
        }
        
        Task { @MainActor in
            if #available(iOS 18.0, *) {
                AppStore.requestReview(in: scene)
            } else {
                SKStoreReviewController.requestReview(in: scene)
            }
        }
    }
    
    /// Opens the App Store page for the app
    static func openAppStorePage() {
        guard let appStoreURL = URL(string: "https://apps.apple.com/app/id\(appStoreId)") else {
            return
        }
        
        UIApplication.shared.open(appStoreURL)
    }
    
    /// Opens the App Store subscription management page
    static func openSubscriptionManagement() {
        if let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }
    
    /// Generates a shareable link to the app
    static func getShareableAppLink() -> URL {
        URL(string: "https://apps.apple.com/app/id\(appStoreId)") ?? 
        URL(string: "https://100days.site")!
    }
    
    /// Returns the message for sharing the app
    static func getShareMessage() -> String {
        "I've been using 100Days to build better habits and track my goals. Check it out!"
    }
}

/// Button styles for App Store actions
struct AppStoreButton: ViewModifier {
    let icon: String
    
    func body(content: Content) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.theme.accent)
            content
        }
    }
}

extension View {
    /// Adds an icon to a button for App Store actions
    func appStoreButton(icon: String) -> some View {
        self.modifier(AppStoreButton(icon: icon))
    }
} 