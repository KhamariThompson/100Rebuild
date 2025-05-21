import SwiftUI

/// A unified card for displaying Pro features and upgrade prompts
public struct ProFeatureCard: View {
    // Title for the Pro feature
    var title: String = "Unlock Pro Features"
    
    // Description of what users get with Pro
    var description: String = "Get advanced analytics, detailed insights, and more with Pro"
    
    // Action when the upgrade button is tapped
    var onUpgrade: () -> Void
    
    // Action when user wants to dismiss the card (optional)
    var onDismiss: (() -> Void)?
    
    // Optional preview content to display in blurred/locked state
    var previewContent: AnyView?
    
    // Standard initializer without ViewBuilder
    public init(
        title: String = "Unlock Pro Features",
        description: String = "Get advanced analytics, detailed insights, and more with Pro",
        onUpgrade: @escaping () -> Void,
        onDismiss: (() -> Void)? = nil
    ) {
        self.title = title
        self.description = description
        self.onUpgrade = onUpgrade
        self.onDismiss = onDismiss
        self.previewContent = nil
    }
    
    // Initializer with ViewBuilder for preview content
    public init<V: View>(
        title: String = "Unlock Pro Features",
        description: String = "Get advanced analytics, detailed insights, and more with Pro",
        onUpgrade: @escaping () -> Void,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder previewContent: () -> V
    ) {
        self.title = title
        self.description = description
        self.onUpgrade = onUpgrade
        self.onDismiss = onDismiss
        self.previewContent = AnyView(previewContent())
    }
    
    public var body: some View {
        VStack(spacing: AppSpacing.m) {
            // Card header with lock icon
            HStack {
                Image(systemName: "lock.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.theme.accent)
                
                Text("Pro Feature")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.theme.accent)
                
                Spacer()
            }
            
            // Title and description
            VStack(spacing: AppSpacing.s) {
                Text(title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.theme.text)
                    .multilineTextAlignment(.center)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.theme.subtext)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.s)
            }
            
            // Optional preview content with blur
            if let previewContent = previewContent {
                ZStack {
                    previewContent
                        .blur(radius: 3)
                        .opacity(0.7)
                    
                    // Gradient overlay
                    LinearGradient(
                        colors: [
                            Color.theme.background.opacity(0.8),
                            Color.theme.background.opacity(0.5),
                            Color.theme.background.opacity(0.8)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    
                    // Lock icon overlay
                    Image(systemName: "lock.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.theme.accent.opacity(0.8))
                }
                .frame(height: 150)
                .cornerRadius(AppSpacing.cardCornerRadius)
                .padding(.horizontal, AppSpacing.s)
                .padding(.vertical, AppSpacing.xs)
            }
            
            // Upgrade button
            Button {
                onUpgrade()
            } label: {
                Text("Upgrade to Pro")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, AppSpacing.l)
                    .padding(.vertical, AppSpacing.m)
                    .background(Color.theme.accent)
                    .cornerRadius(12)
                    .shadow(color: Color.theme.accent.opacity(0.3), radius: 5, x: 0, y: 3)
            }
            .buttonStyle(AppScaleButtonStyle())
            
            // Optional dismiss button
            if let onDismiss = onDismiss {
                Button {
                    onDismiss()
                } label: {
                    Text("Not Now")
                        .font(.subheadline)
                        .foregroundColor(.theme.subtext)
                }
            }
        }
        .padding(AppSpacing.l)
        .background(
            ZStack {
                // Blurred gradient background
                RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.theme.accent.opacity(0.1),
                                Color.theme.accent.opacity(0.05),
                                Color.theme.surface
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Subtle pattern overlay for texture
                RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                    .fill(Color.theme.accent.opacity(0.03))
                    .blur(radius: 15)
                    .offset(x: 20, y: -20)
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                .stroke(Color.theme.accent.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.theme.shadow.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// Preview for the ProFeatureCard
struct ProFeatureCard_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: AppSpacing.l) {
                // Basic card
                ProFeatureCard(
                    onUpgrade: { print("Upgrade tapped") }
                )
                
                // Card with preview content
                ProFeatureCard(
                    title: "Unlock Advanced Analytics",
                    description: "Track your progress with detailed charts, streak predictions, and more",
                    onUpgrade: { print("Upgrade tapped") },
                    onDismiss: { print("Dismiss tapped") }
                ) {
                    // Preview content
                    VStack(spacing: AppSpacing.m) {
                        HStack {
                            Capsule()
                                .fill(Color.theme.accent.opacity(0.7))
                                .frame(width: 100, height: 30)
                            Capsule()
                                .fill(Color.theme.accent.opacity(0.5))
                                .frame(width: 150, height: 30)
                            Capsule()
                                .fill(Color.theme.accent.opacity(0.3))
                                .frame(width: 80, height: 30)
                        }
                        
                        HStack(spacing: AppSpacing.s) {
                            ForEach(0..<4) { i in
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.theme.surface)
                                    .frame(width: 60, height: 60)
                            }
                        }
                    }
                    .padding()
                    .background(Color.theme.surface)
                    .cornerRadius(12)
                }
            }
            .padding()
        }
        .background(Color.theme.background)
        .preferredColorScheme(.dark)
    }
} 