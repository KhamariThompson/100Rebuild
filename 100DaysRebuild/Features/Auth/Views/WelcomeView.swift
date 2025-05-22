import SwiftUI
import FirebaseAuth
import GoogleSignIn
import AuthenticationServices
import CryptoKit

struct WelcomeView: View {
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var themeManager: ThemeManager
    @State private var isShowingAuthView = false
    @State private var animationCompleted = false
    @State private var animateElements = false
    @State private var showTerms = false
    @State private var showPrivacy = false
    @State private var activeTab = 0
    @State private var testimonialIndex = 0
    
    // Timer for automatic testimonial cycling
    let testimonialTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    
    // State for Apple Sign In
    @State private var currentNonce: String?
    
    // Testimonials
    private let testimonials = [
        (quote: "100Days helped me finally stick with my meditation practice. I'm on day 87!", name: "Sarah K."),
        (quote: "I've tried many habit apps, but this one actually keeps me accountable.", name: "Michael T."),
        (quote: "The streaks visualization makes it so satisfying to stay consistent.", name: "James R.")
    ]
    
    var body: some View {
        ZStack {
            // Background with gradient overlay
            backgroundView
            
            // Main content
            ScrollView {
                VStack(spacing: 0) {
                    // Logo and hero section
                    heroSection
                    
                    // Testimonials
                    testimonialsSection
                        .padding(.top, 40)
                    
                    // Feature cards with animations
                    featuresSection
                        .padding(.top, 60)
                    
                    // Stats section
                    statsSection
                        .padding(.top, 50)
                    
                    // Call to action
                    callToActionSection
                        .padding(.top, 50)
                        .padding(.bottom, 30)
                }
                .padding(.horizontal)
            }
            
            // Bottom action bar that stays fixed
            VStack {
                Spacer()
                actionBar
            }
        }
        .onAppear {
            // Start animations
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                animateElements = true
            }
        }
        .onReceive(testimonialTimer) { _ in
            withAnimation(.easeInOut(duration: 0.5)) {
                testimonialIndex = (testimonialIndex + 1) % testimonials.count
            }
        }
        .fullScreenCover(isPresented: $isShowingAuthView) {
            AuthView()
        }
        .fullScreenCover(isPresented: $showTerms) {
            TermsAndPrivacyView(mode: .terms)
        }
        .fullScreenCover(isPresented: $showPrivacy) {
            TermsAndPrivacyView(mode: .privacy)
        }
    }
    
    // MARK: - View Components
    
    // Background view with gradient
    private var backgroundView: some View {
        ZStack {
            Color.theme.background.ignoresSafeArea()
            
            // Top gradient for hero section
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.theme.accent.opacity(0.2),
                    Color.theme.background.opacity(0.0)
                ]),
                startPoint: .topLeading,
                endPoint: .center
            )
            .ignoresSafeArea()
            
            // Bottom gradient for action bar
            VStack {
                Spacer()
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.theme.background.opacity(0.0),
                        Color.theme.background
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 120)
                .ignoresSafeArea()
            }
        }
    }
    
    // Hero section with logo and tagline
    private var heroSection: some View {
        VStack(spacing: 20) {
            // Logo with highlighting glow effect
            ZStack {
                // Glow effect
                Circle()
                    .fill(Color.theme.accent.opacity(0.15))
                    .frame(width: 130, height: 130)
                    .blur(radius: 20)
                
                Image(systemName: "checkmark.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.theme.accent)
                    .shadow(color: Color.theme.accent.opacity(0.3), radius: 10, x: 0, y: 5)
            }
            .offset(y: animateElements ? 0 : -20)
            .opacity(animateElements ? 1 : 0)
            .padding(.top, 60)
            
            // App name with larger font
            Text("100Days")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(.theme.text)
                .opacity(animateElements ? 1 : 0)
                .offset(y: animateElements ? 0 : 10)
            
            // Tagline with emphasis
            VStack(spacing: 12) {
                Text("Build habits that last")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.theme.text)
                    .multilineTextAlignment(.center)
                
                Text("The science-backed approach to transform your life through consistent action")
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundColor(.theme.subtext)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 4)
            }
            .opacity(animateElements ? 1 : 0)
            .offset(y: animateElements ? 0 : 15)
        }
        .padding(.bottom, 20)
    }
    
    // Testimonials section
    private var testimonialsSection: some View {
        VStack(spacing: 16) {
            // Section title
            Text("People love 100Days")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.theme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 5)
                .opacity(animateElements ? 1 : 0)
            
            // Testimonial card
            TabView(selection: $testimonialIndex) {
                ForEach(0..<testimonials.count, id: \.self) { index in
                    testimonialCard(
                        quote: testimonials[index].quote,
                        name: testimonials[index].name
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .frame(height: 160)
            .opacity(animateElements ? 1 : 0)
            
            // Indicators
            HStack(spacing: 8) {
                ForEach(0..<testimonials.count, id: \.self) { index in
                    Circle()
                        .fill(testimonialIndex == index ? Color.theme.accent : Color.theme.border.opacity(0.5))
                        .frame(width: 8, height: 8)
                        .animation(.spring(), value: testimonialIndex)
                }
            }
            .padding(.top, 8)
            .opacity(animateElements ? 1 : 0)
        }
    }
    
    // Features section
    private var featuresSection: some View {
        VStack(spacing: 16) {
            // Section title
            Text("Why 100Days works")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.theme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 5)
                .offset(y: animateElements ? 0 : 20)
                .opacity(animateElements ? 1 : 0)
            
            // Feature cards with improved styling
            VStack(spacing: 16) {
                featureCard(
                    icon: "chart.bar.fill",
                    title: "Visualize Your Progress",
                    description: "Track your streaks and see your consistency grow day by day",
                    delay: 0.3
                )
                
                featureCard(
                    icon: "bell.fill",
                    title: "Smart Reminders",
                    description: "Get timely notifications that adapt to your schedule",
                    delay: 0.4
                )
                
                featureCard(
                    icon: "brain.head.profile",
                    title: "Science-Backed System",
                    description: "Based on proven habit formation psychology",
                    delay: 0.5
                )
                
                featureCard(
                    icon: "trophy.fill",
                    title: "Achieve Your Goals",
                    description: "88% of users report significant habit improvement",
                    delay: 0.6
                )
            }
        }
    }
    
    // Stats section
    private var statsSection: some View {
        VStack(spacing: 20) {
            // Stats title
            Text("Proven Results")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.theme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 5)
                .padding(.bottom, 10)
                .opacity(animateElements ? 1 : 0)
            
            // Stats row
            HStack(spacing: 0) {
                statItem(number: "100", text: "DAYS", delay: 0.1)
                
                Divider()
                    .frame(width: 1, height: 50)
                    .background(Color.theme.border.opacity(0.3))
                    .padding(.horizontal)
                
                statItem(number: "10K+", text: "USERS", delay: 0.2)
                
                Divider()
                    .frame(width: 1, height: 50)
                    .background(Color.theme.border.opacity(0.3))
                    .padding(.horizontal)
                
                statItem(number: "88%", text: "SUCCESS", delay: 0.3)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.theme.surface)
                    .shadow(color: Color.theme.shadow.opacity(0.08), radius: 12, x: 0, y: 6)
            )
            .opacity(animateElements ? 1 : 0)
        }
        .padding(.bottom, 10)
    }
    
    // Call to action section
    private var callToActionSection: some View {
        VStack(spacing: 24) {
            // CTA title
            Text("Start your journey today")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(.theme.text)
                .multilineTextAlignment(.center)
                .opacity(animateElements ? 1 : 0)
            
            // CTA description
            Text("Join thousands of people who have transformed their habits with the 100-day method")
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundColor(.theme.subtext)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 20)
                .opacity(animateElements ? 1 : 0)
        }
    }
    
    // Fixed action bar at bottom
    private var actionBar: some View {
        VStack(spacing: 16) {
            // Primary button
            Button {
                isShowingAuthView = true
            } label: {
                Text("Get Started Free")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.theme.accent,
                                Color.theme.accent.opacity(0.8)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: Color.theme.accent.opacity(0.3), radius: 10, x: 0, y: 5)
                    )
            }
            .padding(.horizontal, 20)
            
            // Sign in with Apple
            SignInWithAppleButton(
                text: .signIn,
                onRequest: { request in
                    let nonce = randomNonceString()
                    currentNonce = nonce
                    request.requestedScopes = [.email]
                    request.nonce = sha256(nonce)
                },
                onCompletion: { result in
                    Task {
                        await handleAppleSignIn(result: result)
                    }
                }
            )
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 56)
            .cornerRadius(16)
            .padding(.horizontal, 20)
            
            // Sign in link
            Button {
                isShowingAuthView = true
            } label: {
                Text("Already have an account? Sign In")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(Color.theme.accent)
                    .padding(.top, 4)
            }
            
            // Terms and privacy
            HStack(spacing: 3) {
                Text("By continuing, you agree to our")
                    .font(.system(size: 13))
                    .foregroundColor(.theme.subtext)
                
                Button(action: { showTerms = true }) {
                    Text("Terms")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.theme.accent)
                }
                
                Text("and")
                    .font(.system(size: 13))
                    .foregroundColor(.theme.subtext)
                
                Button(action: { showPrivacy = true }) {
                    Text("Privacy Policy")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.theme.accent)
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 16)
        }
        .padding(.bottom, 20)
        .background(
            Rectangle()
                .fill(Color.theme.background)
                .shadow(color: Color.theme.shadow.opacity(0.1), radius: 10, x: 0, y: -5)
                .edgesIgnoringSafeArea(.bottom)
        )
    }
    
    // MARK: - Helper Components
    
    // Feature card component
    private func featureCard(icon: String, title: String, description: String, delay: Double) -> some View {
        HStack(spacing: 16) {
            // Icon with accent color
            Image(systemName: icon)
                .font(.system(size: 26, weight: .medium))
                .foregroundColor(Color.theme.accent)
            
            // Text content
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.theme.text)
                
                Text(description)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(.theme.subtext)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.theme.accent.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: Color.theme.shadow.opacity(0.12), radius: 15, x: 0, y: 4)
        )
        .offset(x: animateElements ? 0 : -30, y: 0)
        .opacity(animateElements ? 1 : 0)
        .animation(.easeOut(duration: 0.7).delay(delay), value: animateElements)
    }
    
    // Testimonial card
    private func testimonialCard(quote: String, name: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Quote with quote marks
            HStack(alignment: .top, spacing: 8) {
                Text("\u{201C}")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(Color.theme.accent.opacity(0.3))
                    .offset(y: -8)
                
                Text(quote)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.theme.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(3)
                
                Spacer()
            }
            
            // Name with user icon
            HStack {
                Spacer()
                
                HStack(spacing: 8) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.theme.subtext)
                    
                    Text(name)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.theme.subtext)
                }
            }
        }
        .padding(20)
        .frame(width: UIScreen.main.bounds.width - 40, height: 140)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.theme.accent.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: Color.theme.shadow.opacity(0.15), radius: 15, x: 0, y: 5)
        )
    }
    
    // Stat item
    private func statItem(number: String, text: String, delay: Double) -> some View {
        VStack(spacing: 6) {
            Text(number)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(.theme.accent)
                .offset(y: animateElements ? 0 : 20)
                .opacity(animateElements ? 1 : 0)
                .animation(.easeOut(duration: 0.5).delay(delay), value: animateElements)
            
            Text(text)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.theme.subtext)
                .offset(y: animateElements ? 0 : 20)
                .opacity(animateElements ? 1 : 0)
                .animation(.easeOut(duration: 0.5).delay(delay + 0.1), value: animateElements)
        }
        .frame(maxWidth: .infinity)
        .fixedSize(horizontal: false, vertical: true)
    }
    
    // Environment properties
    @Environment(\.colorScheme) private var systemColorScheme
    
    private var colorScheme: ColorScheme {
        // Get the current color scheme from the theme manager
        if themeManager.currentTheme == .system {
            return systemColorScheme
        }
        return themeManager.currentTheme == .dark ? .dark : .light
    }
    
    // MARK: - Helper Methods
    
    private func handleAppleSignIn(result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                // Process Apple ID credential
                await signInWithApple(credential: appleIDCredential)
            }
        case .failure(let error):
            print("Apple Sign In failed: \(error.localizedDescription)")
        }
    }
    
    private func signInWithApple(credential: ASAuthorizationAppleIDCredential) async {
        // Extract tokens from credential
        guard let tokenData = credential.identityToken,
              let token = String(data: tokenData, encoding: .utf8),
              let nonce = currentNonce else {
            print("Unable to fetch identity token or nonce is missing")
            return
        }
        
        // Create Firebase credential
        let firebaseCredential = OAuthProvider.credential(withProviderID: "apple.com",
                                                         idToken: token,
                                                         rawNonce: nonce)
        
        // Sign in with Firebase
        do {
            let authResult = try await Auth.auth().signIn(with: firebaseCredential)
            
            // Check if this is a new user and name data is available
            if authResult.additionalUserInfo?.isNewUser == true,
               let givenName = credential.fullName?.givenName,
               !givenName.isEmpty {
                
                // Create a display name from the Apple credential data
                var components: [String] = []
                if let givenName = credential.fullName?.givenName {
                    components.append(givenName)
                }
                if let familyName = credential.fullName?.familyName {
                    components.append(familyName)
                }
                
                if !components.isEmpty {
                    let displayName = components.joined(separator: " ")
                    
                    // Use Firebase's profile change request
                    let changeRequest = authResult.user.createProfileChangeRequest()
                    changeRequest.displayName = displayName
                    try await changeRequest.commitChanges()
                    
                    print("Updated user display name to: \(displayName)")
                }
            }
            
            // Disable showing paywall immediately after authentication
            // This prevents the paywall from showing right after login
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let subscriptionService = windowScene.windows.first?.rootViewController?.view.window?.windowScene?.windows.first?.rootViewController?.view.window?.rootViewController as? EnvironmentObject<SubscriptionService> {
                DispatchQueue.main.async {
                    // Ensure we don't show the paywall immediately
                    subscriptionService.wrappedValue.showPaywall = false
                }
            }
            
        } catch {
            print("Error signing in with Apple: \(error.localizedDescription)")
        }
    }
    
    // Generate a random nonce for authentication
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 { return }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
    
    // Compute the SHA256 hash of the nonce
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
}

// MARK: - Preview Provider
struct WelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeView()
            .environmentObject(UserSession.shared)
            .environmentObject(ThemeManager.shared)
    }
} 
