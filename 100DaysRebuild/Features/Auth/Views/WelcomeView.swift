import SwiftUI
import FirebaseAuth
import GoogleSignIn
import AuthenticationServices
import CryptoKit

struct WelcomeView: View {
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var isShowingAuthView = false
    @State private var showTerms = false
    @State private var showPrivacy = false
    @State private var currentNonce: String?

    var body: some View {
        ZStack {
            // Background
            Color.theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Scrollable content
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 48) {
                        // Hero Section
                        heroSection
                            .padding(.top, 80)

                        // Features
                        featuresSection

                        // Social Proof
                        socialProofSection

                        Spacer(minLength: 200)
                    }
                    .padding(.horizontal, 24)
                }

                Spacer()
            }

            // Fixed bottom CTA
            VStack {
                Spacer()
                ctaSection
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

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: 28) {
            // App Icon with enhanced glow
            ZStack {
                // Outer glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.theme.accent.opacity(0.15),
                                Color.theme.accent.opacity(0.05),
                                .clear
                            ],
                            center: .center,
                            startRadius: 40,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)

                // Main circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.theme.accent.opacity(0.2),
                                Color.theme.accent.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)

                // Icon
                Image(systemName: "flame.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 56, height: 56)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color.theme.accent,
                                Color.theme.accent.opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.theme.accent.opacity(0.3), radius: 8, x: 0, y: 4)
            }

            // Title
            VStack(spacing: 16) {
                Text("100Days")
                    .font(AppTypography.largeTitle(.bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color.theme.accent,
                                Color.theme.accent.opacity(0.8)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Text("Build lasting habits through\nconsistent daily action")
                    .font(AppTypography.title3())
                    .foregroundColor(.theme.subtext)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)

                // Trust badge
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.theme.accent)

                    Text("Trusted by 10,000+ habit builders")
                        .font(AppTypography.footnote())
                        .foregroundColor(.theme.subtext)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.theme.surface)
                        .shadow(color: Color.theme.shadow.opacity(0.05), radius: 8, x: 0, y: 2)
                )
                .padding(.top, 8)
            }
        }
    }

    // MARK: - Features Section

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Why it works")
                .font(AppTypography.title2(.bold))
                .foregroundColor(.theme.text)

            VStack(spacing: 16) {
                FeatureRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Track Your Progress",
                    subtitle: "Visual streaks and insights keep you motivated",
                    iconColor: Color.theme.accent
                )

                FeatureRow(
                    icon: "bell.badge.fill",
                    title: "Smart Reminders",
                    subtitle: "Daily notifications that actually help",
                    iconColor: Color.theme.accent
                )

                FeatureRow(
                    icon: "checkmark.shield.fill",
                    title: "Science-Backed",
                    subtitle: "100-day method proven to build lasting habits",
                    iconColor: Color.theme.accent
                )
            }
        }
    }

    // MARK: - Social Proof

    private var socialProofSection: some View {
        VStack(spacing: 24) {
            // Stats Grid
            HStack(spacing: 24) {
                statItem(value: "10K+", label: "Active Users")
                statItem(value: "4.9★", label: "App Store")
                statItem(value: "92%", label: "Success Rate")
            }

            // Testimonials Header
            VStack(spacing: 8) {
                Text("Loved by thousands")
                    .font(AppTypography.title2(.bold))
                    .foregroundColor(.theme.text)

                Text("Real people. Real results.")
                    .font(AppTypography.body())
                    .foregroundColor(.theme.subtext)
            }
            .padding(.top, 8)

            // Testimonials
            VStack(spacing: 20) {
                enhancedTestimonialCard(
                    text: "This app completely changed how I approach my goals. I've been using it for 6 months and haven't missed a single day. The streak tracking is so motivating!",
                    author: "Sarah Martinez",
                    role: "Marketing Director",
                    days: "156",
                    avatarColor: Color(red: 0.2, green: 0.6, blue: 0.9),
                    avatarIcon: "person.fill"
                )

                enhancedTestimonialCard(
                    text: "Finally hit my 100-day milestone for meditation! This app kept me accountable when nothing else could. The daily reminders are perfect.",
                    author: "Michael Chen",
                    role: "Software Engineer",
                    days: "127",
                    avatarColor: Color(red: 0.3, green: 0.7, blue: 0.5),
                    avatarIcon: "person.fill"
                )

                enhancedTestimonialCard(
                    text: "Love the streak tracking and the simple design. Makes building habits feel like a game! I've built 3 habits simultaneously with 100Days.",
                    author: "Jessica Williams",
                    role: "Fitness Coach",
                    days: "89",
                    avatarColor: Color(red: 0.9, green: 0.5, blue: 0.6),
                    avatarIcon: "person.fill"
                )

                enhancedTestimonialCard(
                    text: "I've tried every habit app out there. This one actually works. The consistency heatmap is brilliant - seeing my progress visually keeps me going.",
                    author: "David Thompson",
                    role: "Product Manager",
                    days: "203",
                    avatarColor: Color(red: 0.7, green: 0.4, blue: 0.9),
                    avatarIcon: "person.fill"
                )
            }
        }
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(AppTypography.title2(.bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color.theme.accent,
                            Color.theme.accent.opacity(0.8)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            Text(label)
                .font(AppTypography.caption1())
                .foregroundColor(.theme.subtext)
        }
        .frame(maxWidth: .infinity)
    }

    private func enhancedTestimonialCard(
        text: String,
        author: String,
        role: String,
        days: String,
        avatarColor: Color,
        avatarIcon: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with avatar and info
            HStack(spacing: 12) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    avatarColor,
                                    avatarColor.opacity(0.8)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)

                    Image(systemName: avatarIcon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .foregroundColor(.white)
                }

                // Name and role
                VStack(alignment: .leading, spacing: 2) {
                    Text(author)
                        .font(AppTypography.headline(.semibold))
                        .foregroundColor(.theme.text)

                    Text(role)
                        .font(AppTypography.caption1())
                        .foregroundColor(.theme.subtext)
                }

                Spacer()

                // Day streak badge
                VStack(spacing: 2) {
                    Text(days)
                        .font(AppTypography.title3(.bold))
                        .foregroundColor(.theme.accent)

                    Text("days")
                        .font(AppTypography.caption2())
                        .foregroundColor(.theme.subtext)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.theme.accent.opacity(0.1))
                )
            }

            // Testimonial text
            Text(text)
                .font(AppTypography.body())
                .foregroundColor(.theme.text)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            // Star rating
            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.theme.accent)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.theme.surface)
                .shadow(color: Color.theme.shadow.opacity(0.08), radius: 12, x: 0, y: 4)
        )
    }

    // MARK: - CTA Section

    private var ctaSection: some View {
        VStack(spacing: 16) {
            // Primary CTA
            Button(action: {
                isShowingAuthView = true
            }) {
                Text("Get Started Free")
                    .font(AppTypography.headline(.semibold))
                    .foregroundColor(DS.Colors.primaryButtonFg(colorScheme))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            colors: [
                                Color.theme.accent,
                                Color.theme.accent.opacity(0.9)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
                    .shadow(color: Color.theme.accent.opacity(0.3), radius: 12, x: 0, y: 6)
            }

            // Sign in with Apple
            SignInWithAppleButton(
                text: .signIn,
                onRequest: { request in
                    let nonce = randomNonceString()
                    currentNonce = nonce
                    request.requestedScopes = [.fullName, .email]
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

            // Already have account
            Button(action: {
                isShowingAuthView = true
            }) {
                Text("Already have an account? Sign In")
                    .font(AppTypography.body())
                    .foregroundColor(.theme.accent)
            }
            .padding(.top, 8)

            // Legal
            HStack(spacing: 4) {
                Text("By continuing, you agree to our")
                    .font(AppTypography.caption1())
                    .foregroundColor(.theme.subtext)

                Button("Terms") {
                    showTerms = true
                }
                .font(AppTypography.caption1())
                .foregroundColor(.theme.accent)

                Text("and")
                    .font(AppTypography.caption1())
                    .foregroundColor(.theme.subtext)

                Button("Privacy Policy") {
                    showPrivacy = true
                }
                .font(AppTypography.caption1())
                .foregroundColor(.theme.accent)
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
        .background(
            LinearGradient(
                colors: [
                    Color.theme.background.opacity(0),
                    Color.theme.background.opacity(0.95),
                    Color.theme.background
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 300)
            .offset(y: -100)
        )
    }

    // MARK: - Apple Sign In Helpers

    private func handleAppleSignIn(result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                await signInWithApple(credential: appleIDCredential)
            }
        case .failure(let error):
            print("Apple Sign In failed: \(error.localizedDescription)")
        }
    }

    private func signInWithApple(credential: ASAuthorizationAppleIDCredential) async {
        guard let tokenData = credential.identityToken,
              let token = String(data: tokenData, encoding: .utf8),
              let nonce = currentNonce else {
            print("Unable to fetch identity token or nonce is missing")
            return
        }

        let firebaseCredential = OAuthProvider.credential(
            withProviderID: "apple.com",
            idToken: token,
            rawNonce: nonce
        )

        do {
            // Run the Auth SDK call off the MainActor so the non-Sendable
            // AuthDataResult doesn't need to be transported across actor
            // boundaries. We don't need the AuthDataResult here; auth state
            // changes are observed elsewhere in the app.
            Task.detached(priority: .userInitiated) {
                do {
                    _ = try await Auth.auth().signIn(with: firebaseCredential)
                } catch {
                    await MainActor.run {
                        print("Error authenticating: \(error.localizedDescription)")
                    }
                }
            }
        } catch {
            print("Error preparing credential: \(error.localizedDescription)")
        }
    }

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }

        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }
        return String(nonce)
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        return hashString
    }
}

#Preview {
    WelcomeView()
        .environmentObject(UserSession.shared)
        .environmentObject(ThemeManager.shared)
}
