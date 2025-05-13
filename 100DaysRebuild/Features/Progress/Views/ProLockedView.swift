import SwiftUI

struct ProLockedView<Content: View>: View {
    let content: Content
    @EnvironmentObject var subscriptionService: SubscriptionService
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            // Show the actual content but blurred and with reduced opacity
            content
                .blur(radius: 3)
                .opacity(0.4)
            
            // Lock overlay
            VStack(spacing: 16) {
                // Pro badge
                HStack(spacing: 4) {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.yellow)
                    
                    Text("PRO")
                        .font(.caption.bold())
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
                )
                
                // Lock icon
                Image(systemName: "lock.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.theme.accent)
                
                // Unlock button
                Button(action: {
                    // Open subscription sheet
                    subscriptionService.showPaywall = true
                }) {
                    Text("Unlock")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.theme.accent, Color.theme.accent.opacity(0.8)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        )
                        .shadow(color: Color.theme.accent.opacity(0.3), radius: 6, x: 0, y: 3)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.theme.surface.opacity(0.9))
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
            )
            .padding(.horizontal, 30)
        }
    }
}

// Preview
struct ProLockedView_Previews: PreviewProvider {
    static var previews: some View {
        ProLockedView {
            VStack(spacing: 12) {
                Text("This is premium content")
                    .font(.headline)
                
                Text("This content is only visible to Pro users")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .padding()
                
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.blue)
            }
            .frame(height: 200)
            .frame(maxWidth: .infinity)
            .background(Color.white)
        }
        .environmentObject(SubscriptionService.shared)
        .previewLayout(.sizeThatFits)
        .padding()
        .background(Color.gray.opacity(0.1))
    }
} 