import SwiftUI

@main
struct App100Days: App {
    @StateObject private var userSession = UserSessionService.shared
    @StateObject private var subscriptionService = SubscriptionService.shared
    
    var body: some Scene {
        WindowGroup {
            Group {
                switch userSession.authState {
                case .loading:
                    SplashView()
                    
                case .signedOut:
                    AuthView()
                    
                case .signedIn:
                    if userSession.shouldShowUsernameSetup {
                        UsernameSetupView()
                    } else if userSession.shouldShowMainApp {
                        MainAppView()
                    } else {
                        WelcomeView()
                    }
                }
            }
            .environmentObject(userSession)
            .environmentObject(subscriptionService)
        }
    }
} 