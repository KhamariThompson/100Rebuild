import SwiftUI
import FirebaseCore
import FirebaseAuth

@main
struct App100Days: App {
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
                SimpleAuthView()
                    .environmentObject(subscriptionService)
            }
        }
    }
}

struct SimpleAuthView: View {
    @State private var email = ""
    @State private var password = ""
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var subscriptionService: SubscriptionService
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Text("Welcome to 100Days")
                    .font(.largeTitle)
                    .bold()
                
                Spacer().frame(height: 40)
                
                VStack {
                    TextField("Email", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal)
                
                Button("Sign In") {
                    // Sign in logic would go here
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Sign In")
            .navigationBarHidden(true)
        }
    }
} 