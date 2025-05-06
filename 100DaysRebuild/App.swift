import SwiftUI
import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        return true
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
}

@main
struct App100Days: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var userSession = UserSession.shared
    @StateObject private var subscriptionService = SubscriptionService.shared
    
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            AppContentView()
                .environmentObject(userSession)
                .environmentObject(subscriptionService)
        }
    }
}

struct AppContentView: View {
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var subscriptionService: SubscriptionService
    
    var body: some View {
        Group {
            if userSession.isAuthenticated {
                if userSession.hasCompletedOnboarding {
                    MainAppView()
                        .environmentObject(subscriptionService)
                } else {
                    OnboardingView()
                        .environmentObject(subscriptionService)
                }
            } else {
                AuthView()
                    .environmentObject(subscriptionService)
            }
        }
    }
}

