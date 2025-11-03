import SwiftUI

/// Production-ready commitment screen shown to authenticated users without Pro subscription
/// Replaces static splash screen with motivational purchase prompt
struct CommitNowView: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var userSession: UserSession
    @State private var animateContent = false
    @State private var showPaywall = false

    var body: some View {
        ZStack {
            // Background gradient that adapts to light/dark mode
            LinearGradient(
                colors: [
                    DS.Colors.gradientA,
                    DS.Colors.gradientB
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Logout button in top-right corner
                HStack {
                    Spacer()
                    Button(action: {
                        Task {
                            try await userSession.signOut()
                        }
                    }) {
                        Text("Log Out")
                            .font(AppTypography.caption1())
                            .foregroundStyle(Color.primary)
                            .padding(.horizontal, DS.Spacing.md)
                            .padding(.vertical, DS.Spacing.xs)
                            .background(
                                Capsule()
                                    .fill(Color.primary.opacity(0.12))
                            )
                    }
                }
                .padding(.top, DS.Spacing.lg)
                .padding(.horizontal, DS.Spacing.xl)

                Spacer()

                // Hero section
                heroSection
                    .opacity(animateContent ? 1 : 0)
                    .offset(y: animateContent ? 0 : 20)

                Spacer()

                // Social proof
                socialProofSection
                    .opacity(animateContent ? 1 : 0)
                    .offset(y: animateContent ? 0 : 20)

                Spacer()

                // CTA section
                ctaSection
                    .opacity(animateContent ? 1 : 0)
                    .offset(y: animateContent ? 0 : 20)
            }
            .padding(DS.Spacing.xl)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                animateContent = true
            }
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView()
                .environmentObject(subscriptionStore)
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: DS.Spacing.lg) {
            // PREMIUM Icon with multi-layer glow animation
            ZStack {
                // Outer glow - pulsating
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.primary.opacity(0.2),
                                Color.primary.opacity(0.08),
                                .clear
                            ],
                            center: .center,
                            startRadius: 30,
                            endRadius: 90
                        )
                    )
                    .frame(width: 180, height: 180)
                    .blur(radius: 20)
                    .scaleEffect(animateContent ? 1.05 : 0.95)
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: animateContent)

                // Mid glow
                Circle()
                    .fill(Color.primary.opacity(0.12))
                    .frame(width: 130, height: 130)
                    .blur(radius: 15)

                // Inner circle background
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.primary.opacity(0.18),
                                Color.primary.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)

                // Icon with gradient
                Image(systemName: "flame.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 56, height: 56)
                    .foregroundStyle(.white)
                    .shadow(color: .white.opacity(0.3), radius: 8, x: 0, y: 4)
            }

            VStack(spacing: DS.Spacing.md) {
                Text("Ready to Commit?")
                    .font(AppTypography.largeTitle(.bold))
                    .foregroundStyle(Color.primary)
                    .multilineTextAlignment(.center)

                Text("Your transformation starts with one decision")
                    .font(AppTypography.title2())
                    .foregroundStyle(Color.primary.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Social Proof

    private var socialProofSection: some View {
        VStack(spacing: DS.Spacing.md) {
            // Stats grid
            HStack(spacing: DS.Spacing.lg) {
                statCard(number: "10K+", label: "Active Users")
                statCard(number: "4.9", label: "App Rating")
                statCard(number: "92%", label: "Success Rate")
            }

            // Testimonial quote with profile picture
            VStack(spacing: DS.Spacing.sm) {
                HStack(alignment: .top, spacing: DS.Spacing.sm) {
                    // Profile picture
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [DS.Colors.gradientA, DS.Colors.gradientB],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(.white)
                        )

                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        Text("\"100Days changed my life. The commitment was worth it.\"")
                            .font(AppTypography.callout()).italic()
                            .foregroundStyle(Color.primary)
                            .lineLimit(3)

                        Text("— Sarah M., Year 2 member")
                            .font(AppTypography.caption1())
                            .foregroundStyle(Color.primary.opacity(0.7))
                    }
                }
            }
            .padding(DS.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DS.Spacing.cardCornerRadius)
                    .fill(Color.primary.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Spacing.cardCornerRadius)
                            .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }

    private func statCard(number: String, label: String) -> some View {
        VStack(spacing: DS.Spacing.xxs) {
            Text(number)
                .font(AppTypography.title2())
                .foregroundStyle(Color.primary)

            Text(label)
                .font(AppTypography.caption1())
                .foregroundStyle(Color.primary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DS.Spacing.cardCornerRadius)
                .fill(Color.primary.opacity(0.15))
        )
    }

    // MARK: - CTA Section

    private var ctaSection: some View {
        VStack(spacing: DS.Spacing.md) {
            // Primary CTA - uses gradient background with white text
            Button {
                showPaywall = true
            } label: {
                HStack(spacing: DS.Spacing.sm) {
                    Text("Start Your Journey")
                        .font(AppTypography.headline())
                        .foregroundStyle(.white)

                    Image(systemName: "arrow.right")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(DS.Spacing.md)
                .background(
                    LinearGradient(
                        colors: [DS.Colors.gradientA, DS.Colors.gradientB],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: DS.Spacing.cardCornerRadius))
                .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 5)
            }
            .scaleEffect(animateContent ? 1 : 0.9)
            .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.4), value: animateContent)

            // Benefits preview
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                benefitRow(icon: "checkmark.seal.fill", text: "Unlimited challenges")
                benefitRow(icon: "checkmark.seal.fill", text: "Advanced analytics")
                benefitRow(icon: "checkmark.seal.fill", text: "Premium features")
            }
            .padding(.top, DS.Spacing.xs)
        }
    }

    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.primary)

            Text(text)
                .font(AppTypography.footnote())
                .foregroundStyle(Color.primary)
        }
    }
}

// MARK: - Preview

struct CommitNowView_Previews: PreviewProvider {
    static var previews: some View {
        CommitNowView()
            .environmentObject(SubscriptionStore.shared)
    }
}
