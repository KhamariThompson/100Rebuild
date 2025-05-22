import SwiftUI

struct ProLockedView<Content: View>: View {
    let content: Content
    @EnvironmentObject var subscriptionService: SubscriptionService
    @State private var isShowingPaywall = false
    @State private var isContentVisible = false
    @State private var animateElements = false
    
    // For visual appeal
    @State private var pulseAnimation = false
    @State private var hoverEffect = false
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            // Content with enhanced visual treatment
            content
                .blur(radius: subscriptionService.isProUser ? 0 : 5)
                .opacity(subscriptionService.isProUser ? 1 : 0.4)
                .scaleEffect(subscriptionService.isProUser ? 1 : 0.98)
                .animation(.easeInOut(duration: 0.5), value: subscriptionService.isProUser)
                .onChange(of: subscriptionService.isProUser) { oldValue, newValue in
                    withAnimation(.easeInOut(duration: 0.5)) {
                        isContentVisible = newValue
                    }
                }
            
            // Enhanced overlay for non-pro users
            if !subscriptionService.isProUser {
                VStack(spacing: AppSpacing.m) {
                    // Animated lock icon with glow effect
                    ZStack {
                        // Background glow that animates
                        Circle()
                            .fill(Color.theme.accent.opacity(0.2))
                            .frame(width: pulseAnimation ? 90 : 70, height: pulseAnimation ? 90 : 70)
                            .blur(radius: 10)
                            .animation(
                                Animation.easeInOut(duration: 2.0)
                                    .repeatForever(autoreverses: true),
                                value: pulseAnimation
                            )
                        
                        // Lock icon with animated appearance
                        Image(systemName: "lock.fill")
                            .font(.system(size: AppSpacing.iconSizeLarge, weight: .semibold))
                            .foregroundColor(.theme.accent)
                            .padding(AppSpacing.m)
                            .background(
                                Circle()
                                    .fill(Color.theme.surface)
                                    .shadow(color: Color.theme.shadow, radius: 10, x: 0, y: 5)
                            )
                            .rotationEffect(Angle(degrees: animateElements ? 0 : -10))
                            .scaleEffect(animateElements ? 1 : 0.7)
                    }
                    
                    // Text & Button with enhanced styling
                    VStack(spacing: AppSpacing.s) {
                        Text("Pro Feature")
                            .font(AppTypography.title3())
                            .foregroundColor(.theme.text)
                            .opacity(animateElements ? 1 : 0)
                            .offset(y: animateElements ? 0 : 10)
                        
                        Text("Unlock advanced insights and powerful analytics with a Pro subscription")
                            .font(AppTypography.subhead())
                            .foregroundColor(.theme.subtext)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, AppSpacing.xs)
                            .padding(.bottom, AppSpacing.xxs)
                            .opacity(animateElements ? 1 : 0)
                            .offset(y: animateElements ? 0 : 10)
                        
                        // Value proposition
                        HStack(spacing: AppSpacing.l) {
                            ProFeatureItem(icon: "chart.xyaxis.line", text: "Advanced Analytics")
                            ProFeatureItem(icon: "calendar.badge.clock", text: "Detailed History")
                        }
                        .padding(.vertical, AppSpacing.xxs)
                        .opacity(animateElements ? 1 : 0)
                        .offset(y: animateElements ? 0 : 10)
                        
                        // Upgrade button with hover effect
                        Button {
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                hoverEffect = false
                            }
                            
                            isShowingPaywall = true
                        } label: {
                            HStack(spacing: AppSpacing.xs) {
                                Text("Upgrade to Pro")
                                    .font(AppTypography.headline())
                                
                                Image(systemName: "arrow.right")
                                    .font(AppTypography.footnote().bold())
                                    .opacity(hoverEffect ? 1 : 0.7)
                                    .offset(x: hoverEffect ? 4 : 0)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, AppSpacing.buttonHorizontalPadding)
                            .padding(.vertical, AppSpacing.s)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.theme.accent, Color.theme.accent.opacity(0.8)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                .cornerRadius(AppSpacing.cardCornerRadius)
                                .shadow(color: Color.theme.shadow, radius: 8, x: 0, y: 4)
                            )
                        }
                        .buttonStyle(AppScaleButtonStyle())
                        .padding(.top, AppSpacing.s)
                        .opacity(animateElements ? 1 : 0)
                        .offset(y: animateElements ? 0 : 10)
                        
                        // Maybe later option
                        Button {
                            // Dismiss the overlay with animation
                            withAnimation {
                                animateElements = false
                                
                                // Add a small delay before setting isContentVisible to true
                                // This allows the user to still see the content even without Pro
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    isContentVisible = true
                                }
                            }
                        } label: {
                            Text("Maybe later")
                                .font(AppTypography.footnote())
                                .foregroundColor(.theme.subtext)
                                .padding(.vertical, AppSpacing.xs)
                        }
                        .opacity(animateElements ? 1 : 0)
                    }
                    .padding(AppSpacing.l)
                    .frame(maxWidth: 360)
                    .background(
                        RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                            .fill(Color.theme.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                                    .stroke(Color.theme.accent.opacity(0.1), lineWidth: 1)
                            )
                            .shadow(color: Color.theme.shadow, radius: 16, x: 0, y: 8)
                    )
                    .padding()
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                .animation(.easeInOut(duration: 0.3), value: subscriptionService.isProUser)
            }
        }
        .sheet(isPresented: $isShowingPaywall, onDismiss: {
            // Check subscription status when paywall is dismissed
            Task {
                await subscriptionService.refreshSubscriptionStatus()
            }
        }) {
            PaywallView()
                .environmentObject(subscriptionService)
        }
        .onAppear {
            // Start the pulse animation
            withAnimation(.easeInOut(duration: 0.1)) {
                pulseAnimation = true
            }
            
            // Animate elements in sequence
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                animateElements = true
            }
            
            // Check subscription status on appear
            Task {
                await subscriptionService.refreshSubscriptionStatus()
            }
        }
    }
}

// Feature item for the pro locked view
struct ProFeatureItem: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: AppSpacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.theme.accent)
            
            Text(text)
                .font(AppTypography.caption1())
                .foregroundColor(.theme.subtext)
        }
        .padding(.horizontal, AppSpacing.xs)
        .padding(.vertical, AppSpacing.xxs)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.theme.accent.opacity(0.1))
        )
    }
}

// Preview
struct ProLockedView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ProLockedView {
                VStack {
                    Text("Pro Content")
                        .font(AppTypography.title1())
                    Image(systemName: "star.fill")
                        .font(.largeTitle)
                }
                .frame(width: 300, height: 300)
                .background(Color.theme.surface)
            }
            .previewDisplayName("Default Theme")
            
            ProLockedView {
                VStack {
                    Text("Pro Content")
                        .font(AppTypography.title1())
                    Image(systemName: "star.fill")
                        .font(.largeTitle)
                }
                .frame(width: 300, height: 300)
                .background(Color.theme.surface)
            }
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Theme")
        }
    }
} 