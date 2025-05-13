import SwiftUI

struct ProLockedView<Content: View>: View {
    let content: Content
    @EnvironmentObject var subscriptionService: SubscriptionService
    @State private var isShowingPaywall = false
    @State private var isContentVisible = false
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            // Content with dynamic blur based on pro status
            content
                .blur(radius: subscriptionService.isProUser ? 0 : 3)
                .opacity(subscriptionService.isProUser ? 1 : 0.5)
                .onChange(of: subscriptionService.isProUser) { oldValue, newValue in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isContentVisible = newValue
                    }
                }
            
            // Overlay for non-pro users
            if !subscriptionService.isProUser {
                VStack(spacing: 12) {
                    // Lock icon
                    Image(systemName: "lock.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.theme.accent)
                        .padding(16)
                        .background(
                            Circle()
                                .fill(Color.theme.surface)
                                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                        )
                    
                    // Text & Button
                    VStack(spacing: 8) {
                        Text("Pro Feature")
                            .font(.headline)
                            .foregroundColor(.theme.text)
                        
                        Text("This feature requires a Pro subscription")
                            .font(.subheadline)
                            .foregroundColor(.theme.subtext)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button {
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            isShowingPaywall = true
                        } label: {
                            Text("Upgrade to Pro")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.theme.accent)
                                        .shadow(color: Color.theme.accent.opacity(0.3), radius: 4, x: 0, y: 2)
                                )
                        }
                        .padding(.top, 8)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.theme.surface.opacity(0.95))
                            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                    )
                    .padding()
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .animation(.easeInOut(duration: 0.2), value: subscriptionService.isProUser)
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
            // Check subscription status on appear
            Task {
                await subscriptionService.refreshSubscriptionStatus()
            }
        }
    }
}

// Scale button style for interactive feedback
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// Preview
struct ProLockedView_Previews: PreviewProvider {
    static var previews: some View {
        ProLockedView {
            VStack {
                Text("Pro Content")
                    .font(.title)
                Image(systemName: "star.fill")
                    .font(.largeTitle)
            }
            .frame(width: 300, height: 300)
            .background(Color.theme.surface)
        }
        .environmentObject(SubscriptionService.shared)
        .padding()
    }
} 