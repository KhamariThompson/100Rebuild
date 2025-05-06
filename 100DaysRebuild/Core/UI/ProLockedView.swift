import SwiftUI

struct ProLockedView<Content: View>: View {
    let content: Content
    @EnvironmentObject var subscriptionService: SubscriptionService
    @State private var isShowingPaywall = false
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            content
                .blur(radius: subscriptionService.isProUser ? 0 : 3)
                .opacity(subscriptionService.isProUser ? 1 : 0.5)
            
            if !subscriptionService.isProUser {
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    isShowingPaywall = true
                }) {
                    VStack(spacing: 12) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.theme.accent)
                        
                        Text("Pro Feature")
                            .font(.headline)
                            .foregroundColor(.theme.text)
                        
                        Text("Upgrade to unlock")
                            .font(.subheadline)
                            .foregroundColor(.theme.subtext)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.theme.surface)
                            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                    )
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .sheet(isPresented: $isShowingPaywall) {
            PaywallView()
        }
    }
} 