import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var subscriptionService: SubscriptionService
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 32) {
            // Logo and Title
            VStack(spacing: 16) {
                Image(systemName: "trophy.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.theme.accent)
                    .scaleEffect(isAnimating ? 1.0 : 0.8)
                    .opacity(isAnimating ? 1.0 : 0.0)
                
                Text("Welcome to 100Days")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.theme.text)
                    .opacity(isAnimating ? 1.0 : 0.0)
                    .offset(y: isAnimating ? 0 : 20)
            }
            
            // Description
            Text("Build habits, track progress, and achieve your goals with our 100-day challenge platform.")
                .font(.body)
                .foregroundColor(.theme.subtext)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .opacity(isAnimating ? 1.0 : 0.0)
                .offset(y: isAnimating ? 0 : 20)
            
            Spacer()
            
            // CTA Buttons
            VStack(spacing: 16) {
                NavigationLink(destination: NewChallengeView()) {
                    Text("Start Your First Challenge")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.theme.accent)
                                .shadow(color: Color.theme.accent.opacity(0.3), radius: 8, x: 0, y: 4)
                        )
                }
                
                if !subscriptionService.isProUser {
                    NavigationLink(destination: PaywallView()) {
                        HStack {
                            Text("Try Pro for Free")
                                .font(.headline)
                                .foregroundColor(.theme.accent)
                            
                            Image(systemName: "sparkles")
                                .foregroundColor(.theme.accent)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.theme.accent, lineWidth: 2)
                        )
                    }
                }
            }
            .padding(.horizontal)
            .opacity(isAnimating ? 1.0 : 0.0)
            .offset(y: isAnimating ? 0 : 20)
        }
        .padding()
        .background(Color.theme.background.ignoresSafeArea())
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2)) {
                isAnimating = true
            }
        }
    }
} 