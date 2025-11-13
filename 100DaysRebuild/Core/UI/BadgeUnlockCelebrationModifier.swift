import SwiftUI

struct BadgeUnlockCelebrationModifier: ViewModifier {
    let badge: Badge?
    @Binding var isPresented: Bool
    
    @State private var animationProgress = 0.0
    @State private var showConfetti = false
    
    func body(content: Content) -> some View {
        content
            .overlay {
                if isPresented, let badge = badge {
                    celebrationOverlay(for: badge)
                }
            }
    }
    
    // Extracted main overlay content
    private func celebrationOverlay(for badge: Badge) -> some View {
        ZStack {
            // Dimmed background
            dimmedBackground
            
            // Confetti effect
            BadgeConfettiView()
                .opacity(showConfetti ? 1 : 0)
            
            // Badge celebration card
            badgeCelebrationCard(for: badge)
        }
        .transition(.opacity)
        .onAppear(perform: performEntryAnimations)
        .onDisappear(perform: resetAnimationStates)
    }
    
    // Dimmed background
    private var dimmedBackground: some View {
        Color.black.opacity(0.7)
            .ignoresSafeArea()
            .onTapGesture {
                withAnimation {
                    isPresented = false
                }
            }
    }
    
    // Badge celebration card
    private func badgeCelebrationCard(for badge: Badge) -> some View {
        VStack(spacing: 24) {
            // Animated badge icon
            animatedBadgeIcon(for: badge)
            
            // Badge info
            badgeInfoSection(for: badge)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.black.opacity(0.8))
                .shadow(color: badge.category.color.opacity(0.3), radius: 20, x: 0, y: 10)
        )
        .padding(32)
    }
    
    // Animated badge icon
    private func animatedBadgeIcon(for badge: Badge) -> some View {
        ZStack {
            // Glow effect
            Circle()
                .fill(badge.category.color.opacity(0.2))
                .frame(width: 140, height: 140)
                .blur(radius: 15)
            
            // Starburst effect
            starburstEffect(for: badge)
            
            // Badge background
            Circle()
                .fill(badge.category.color.opacity(0.15))
                .frame(width: 100, height: 100)
            
            // Badge icon
            if #available(iOS 17.0, *) {
                Image(systemName: badge.iconName)
                    .font(AppTypography.font(size: 50, weight: .bold))
                    .foregroundColor(badge.category.color)
                    .symbolEffect(.bounce, options: .repeating, value: isPresented)
            } else {
                // Fallback on earlier versions
                Image(systemName: badge.iconName)
                    .font(AppTypography.font(size: 50, weight: .bold))
                    .foregroundColor(badge.category.color)
            }
        }
        .scaleEffect(animationProgress)
    }
    
    // Starburst rays effect
    private func starburstEffect(for badge: Badge) -> some View {
        ForEach(0..<8, id: \.self) { i in
            Rectangle()
                .fill(badge.category.color.opacity(0.4))
                .frame(width: 50, height: 4)
                .offset(x: 35)
                .rotationEffect(.degrees(Double(i) * 45 + animationProgress * 30))
        }
    }
    
    // Badge info section
    private func badgeInfoSection(for badge: Badge) -> some View {
        VStack(spacing: 16) {
            // Badge unlocked text
            Text("Badge Unlocked!")
                .font(AppTypography.title1(.bold))
                .foregroundColor(.white)
                .opacity(animationProgress)
            
            // Badge name
            Text(badge.name)
                .font(AppTypography.title2(.bold))
                .foregroundColor(badge.category.color)
                .opacity(animationProgress)
            
            // Description
            Text(badge.description)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 32)
                .opacity(animationProgress)
            
            // Category
            badgeCategoryPill(for: badge)
            
            // Reward if any
            if badge.reward.type != .none {
                badgeRewardSection(for: badge)
            }
            
            // Continue button
            continueButton(with: badge.category.color)
        }
    }
    
    // Badge category pill
    private func badgeCategoryPill(for badge: Badge) -> some View {
        HStack {
            Image(systemName: badge.category.icon)
                .foregroundColor(badge.category.color)
            
            Text(badge.category.rawValue)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(badge.category.color.opacity(0.2))
        )
        .opacity(animationProgress)
    }
    
    // Badge reward section
    private func badgeRewardSection(for badge: Badge) -> some View {
        VStack(spacing: 4) {
            Text("Reward Earned")
                .font(.headline)
                .foregroundColor(.yellow)
            
            Text(badge.reward.description)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.yellow.opacity(0.1))
        )
        .opacity(animationProgress)
    }
    
    // Continue button
    private func continueButton(with color: Color) -> some View {
        Button {
            withAnimation {
                isPresented = false
            }
        } label: {
            Text("Continue")
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 200)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color)
                )
        }
        .buttonStyle(BadgeScaleButtonStyle())
        .opacity(animationProgress)
        .padding(.top, 16)
    }
    
    // Animation functions
    private func performEntryAnimations() {
        // Create staggered animations
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            animationProgress = 1.0
        }
        
        // Small delay before confetti
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeIn(duration: 0.3)) {
                showConfetti = true
            }
        }
        
        // Play haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    private func resetAnimationStates() {
        // Reset animation states
        animationProgress = 0.0
        showConfetti = false
    }
}

// Simple confetti view
struct BadgeConfettiView: View {
    let colors: [Color] = [.red, .blue, .green, .yellow, .pink, .purple, .orange]
    let confettiCount = 100
    
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            ForEach(0..<confettiCount, id: \.self) { i in
                ConfettiPiece(
                    color: colors.randomElement()!,
                    size: CGFloat.random(in: 5...12),
                    rotation: Double.random(in: 0...360),
                    position: CGPoint(
                        x: CGFloat.random(in: -200...200),
                        y: isAnimating ? CGFloat.random(in: 300...500) : -50
                    ),
                    animationDelay: Double.random(in: 0...0.5)
                )
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 3.0)) {
                isAnimating = true
            }
        }
    }
}

// Individual confetti piece
struct ConfettiPiece: View {
    let color: Color
    let size: CGFloat
    let rotation: Double
    let position: CGPoint
    let animationDelay: Double
    
    @State private var animationProgress = 0.0
    
    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: size, height: size)
            .rotationEffect(.degrees(rotation + animationProgress * 180))
            .position(
                x: UIScreen.main.bounds.midX + position.x,
                y: UIScreen.main.bounds.midY + position.y * animationProgress
            )
            .opacity(1.0 - animationProgress)
            .onAppear {
                withAnimation(
                    .easeOut(duration: 3.0)
                    .delay(animationDelay)
                ) {
                    animationProgress = 1.0
                }
            }
    }
}

// View extension for easier use
extension View {
    func badgeUnlockCelebration(badge: Badge?, isPresented: Binding<Bool>) -> some View {
        self.modifier(BadgeUnlockCelebrationModifier(badge: badge, isPresented: isPresented))
    }
}

// Simple scale button style
struct BadgeScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

#Preview {
    Text("Background Content")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.blue.opacity(0.2))
        .badgeUnlockCelebration(
            badge: Badge(
                id: "test_badge",
                name: "Milestone Master",
                description: "You've achieved a significant milestone in your journey!",
                category: .milestone,
                iconName: "star.fill",
                tier: .gold,
                reward: BadgeReward(
                    type: .streakSaveToken,
                    value: 1,
                    description: "1 Streak Save Token"
                ),
                requiredValue: 10
            ),
            isPresented: .constant(true)
        )
} 
