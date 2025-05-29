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
                    ZStack {
                        // Dimmed background
                        Color.black.opacity(0.7)
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation {
                                    isPresented = false
                                }
                            }
                        
                        // Confetti effect
                        BadgeConfettiView()
                            .opacity(showConfetti ? 1 : 0)
                        
                        // Badge celebration card
                        VStack(spacing: 24) {
                            // Animated badge icon
                            ZStack {
                                // Glow effect
                                Circle()
                                    .fill(badge.category.color.opacity(0.2))
                                    .frame(width: 140, height: 140)
                                    .blur(radius: 15)
                                
                                // Starburst effect
                                ForEach(0..<8, id: \.self) { i in
                                    Rectangle()
                                        .fill(badge.category.color.opacity(0.4))
                                        .frame(width: 50, height: 4)
                                        .offset(x: 35)
                                        .rotationEffect(.degrees(Double(i) * 45 + animationProgress * 30))
                                }
                                
                                // Badge background
                                Circle()
                                    .fill(badge.category.color.opacity(0.15))
                                    .frame(width: 100, height: 100)
                                
                                // Badge icon
                                Image(systemName: badge.iconName)
                                    .font(.system(size: 50))
                                    .foregroundColor(badge.category.color)
                                    .symbolEffect(.bounce, options: .repeating, value: isPresented)
                            }
                            .scaleEffect(animationProgress)
                            
                            // Badge info
                            VStack(spacing: 16) {
                                // Badge unlocked text
                                Text("Badge Unlocked!")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.white)
                                    .opacity(animationProgress)
                                
                                // Badge name
                                Text(badge.name)
                                    .font(.system(size: 22, weight: .bold))
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
                                
                                // Reward if any
                                if badge.reward.type != .none {
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
                                                .fill(badge.category.color)
                                        )
                                }
                                .buttonStyle(ScaleButtonStyle())
                                .opacity(animationProgress)
                                .padding(.top, 16)
                            }
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
                    .transition(.opacity)
                    .onAppear {
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
                    .onDisappear {
                        // Reset animation states
                        animationProgress = 0.0
                        showConfetti = false
                    }
                }
            }
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
struct ScaleButtonStyle: ButtonStyle {
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