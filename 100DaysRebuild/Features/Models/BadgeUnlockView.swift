import SwiftUI

/// A celebration view shown when a user unlocks a new badge
struct BadgeUnlockView: View {
    let badge: Badge
    let onDismiss: () -> Void
    
    @State private var showBadge = false
    @State private var showDetails = false
    @State private var showConfetti = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Close button at top
            HStack {
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(AppTypography.title2())
                        .foregroundColor(.theme.subtext)
                        .padding()
                }
            }
            
            Spacer()
            
            // Badge and title
            VStack(spacing: 30) {
                // Badge
                ZStack {
                    if showBadge {
                        // Background glow
                        Circle()
                            .fill(badge.category.color.opacity(0.2))
                            .frame(width: 180, height: 180)
                            .blur(radius: 30)
                        
                        // Background circle
                        Circle()
                            .fill(badge.category.color.opacity(0.15))
                            .frame(width: 160, height: 160)
                        
                        // Border
                        Circle()
                            .strokeBorder(badge.category.color.opacity(0.3), lineWidth: 2)
                            .frame(width: 160, height: 160)
                        
                        // Icon
                        Image(systemName: badge.iconName)
                            .font(AppTypography.displayXL())
                            .foregroundColor(badge.category.color)
                            .scaleEffect(showBadge ? 1.2 : 1.0)
                            .animation(Animation.easeInOut(duration: 0.5).repeatCount(3, autoreverses: true), value: showBadge)
                    }
                }
                .opacity(showBadge ? 1 : 0)
                .scaleEffect(showBadge ? 1 : 0.5)
                .shadow(color: badge.category.color.opacity(0.5), radius: 15, x: 0, y: 5)
                
                if showDetails {
                    // Badge name
                    Text("Badge Unlocked!")
                        .font(AppTypography.title1(.bold))
                        .foregroundColor(.theme.text)
                        .padding(.top, 16)
                    
                    Text(badge.name)
                        .font(AppTypography.title2(.bold))
                        .foregroundColor(badge.category.color)
                        .padding(.top, 4)
                    
                    // Description
                    Text(badge.description)
                        .font(AppTypography.body(.medium))
                        .foregroundColor(.theme.subtext)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                        .padding(.horizontal, 24)
                    
                    // Category
                    HStack(spacing: 8) {
                        Image(systemName: badge.category.icon)
                            .font(AppTypography.body())
                            .foregroundColor(badge.category.color)
                        
                        Text(badge.category.rawValue)
                            .font(AppTypography.body(.medium))
                            .foregroundColor(.theme.subtext)
                    }
                    .padding(.top, 16)
                    
                    // Reward if any
                    if badge.reward.type != .none {
                        HStack {
                            Image(systemName: "gift.fill")
                                .font(AppTypography.body())
                                .foregroundColor(.yellow)
                            
                            Text("Reward: \(badge.reward.description)")
                                .font(AppTypography.body(.medium))
                                .foregroundColor(.yellow)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(
                            Capsule()
                                .fill(Color.yellow.opacity(0.1))
                                .overlay(
                                    Capsule()
                                        .strokeBorder(Color.yellow.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .padding(.top, 16)
                    }
                    
                    // Share button
                    Button(action: {
                        // Share functionality would go here
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share Achievement")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 24)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.theme.accent)
                                .shadow(color: Color.theme.accent.opacity(0.3), radius: 5, x: 0, y: 2)
                        )
                    }
                    .padding(.top, 32)
                    
                    // Continue button
                    Button(action: onDismiss) {
                        Text("Continue")
                            .font(AppTypography.body(.medium))
                            .foregroundColor(.theme.subtext)
                            .padding(.top, 16)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 40)
            .opacity(showDetails ? 1 : 0)
            .offset(y: showDetails ? 0 : 20)
            
            Spacer()
        }
        .background(Color.theme.background.ignoresSafeArea())
        .overlay {
            if showConfetti {
                ConfettiView(intensity: 1.0, duration: 2.0)
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            // Sequence the animations
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                    showBadge = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showConfetti = true
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            showDetails = true
                        }
                    }
                }
            }
        }
    }
}

/// View extension to show badge unlock celebration
extension View {
    func badgeDetailCelebration(badge: Badge?, isPresented: Binding<Bool>) -> some View {
        ZStack {
            self
            
            if isPresented.wrappedValue, let badge = badge {
                Color.black.opacity(0.7)
                    .ignoresSafeArea()
                    .transition(.opacity)
                
                BadgeUnlockView(badge: badge) {
                    withAnimation {
                        isPresented.wrappedValue = false
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: isPresented.wrappedValue)
    }
}

// MARK: - Preview
struct BadgeUnlockView_Previews: PreviewProvider {
    static var previews: some View {
        BadgeUnlockView(
            badge: BadgeConfig.firestarter,
            onDismiss: {}
        )
        .preferredColorScheme(.dark)
    }
} 