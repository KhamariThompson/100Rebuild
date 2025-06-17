import SwiftUI

/// A reusable sheet view for promoting Pro features
struct ProUpgradeSheetView: View {
    let title: String
    let description: String
    let features: [String]
    let onUpgrade: () -> Void
    let onDismiss: () -> Void
    
    @EnvironmentObject var subscriptionService: SubscriptionService
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    @State private var animateContent = false
    
    var body: some View {
        ZStack {
            // Background
            Color.theme.background.ignoresSafeArea()
            
            // Scrollable content
            ScrollView {
                VStack(spacing: 24) {
                    // Header section
                    ProHeaderView(
                        title: title,
                        description: description,
                        animate: animateContent
                    )
                    
                    // Features list
                    ProFeaturesView(
                        features: features,
                        animate: animateContent
                    )
                    
                    // Subscription status
                    ProSubscriptionStatusView(
                        subscriptionService: subscriptionService,
                        animate: animateContent
                    )
                    
                    // Action buttons
                    ProActionButtonsView(
                        subscriptionService: subscriptionService,
                        animate: animateContent,
                        onUpgrade: onUpgrade,
                        onDismiss: {
                            dismiss()
                            onDismiss()
                        }
                    )
                    
                    Spacer(minLength: 20)
                }
                .padding(.bottom, 32)
            }
        }
        .onAppear {
            // Animate content appearing
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeOut(duration: 0.5)) {
                    animateContent = true
                }
            }
        }
    }
}

// MARK: - Extracted Subviews

// Header view component
struct ProHeaderView: View {
    let title: String
    let description: String
    let animate: Bool
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 16) {
            // Pro badge with animation
            ZStack {
                // Glowing background
                Circle()
                    .fill(Color.yellow.opacity(0.2))
                    .frame(width: 100, height: 100)
                    .blur(radius: 15)
                
                // Crown icon
                Image(systemName: "crown.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.yellow)
                    .shadow(color: Color.yellow.opacity(0.5), radius: 10, x: 0, y: 5)
                    .padding(10)
                    .background(
                        Circle()
                            .fill(colorScheme == .dark ? Color.black.opacity(0.5) : Color.white.opacity(0.8))
                            .shadow(color: Color.black.opacity(0.15), radius: 15, x: 0, y: 10)
                    )
            }
            .offset(y: animate ? 0 : -20)
            .opacity(animate ? 1 : 0)
            
            // Title with gradient
            Text(title)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.yellow, .orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .offset(y: animate ? 0 : 10)
                .opacity(animate ? 1 : 0)
            
            // Description
            Text(description)
                .font(.body)
                .foregroundColor(.theme.subtext)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .offset(y: animate ? 0 : 10)
                .opacity(animate ? 1 : 0)
        }
        .padding(.top, 20)
    }
}

// Features list component
struct ProFeaturesView: View {
    let features: [String]
    let animate: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("PRO FEATURES")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.theme.subtext)
                .padding(.horizontal, 32)
            
            ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                ProFeatureRow(
                    feature: feature,
                    isEvenRow: index % 2 == 0,
                    animate: animate,
                    animationDelay: 0.1 + Double(index) * 0.1
                )
            }
        }
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.theme.surface)
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
        .padding(.horizontal, 20)
    }
}

// Individual feature row component
struct ProFeatureRow: View {
    let feature: String
    let isEvenRow: Bool
    let animate: Bool
    let animationDelay: Double
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.yellow)
                .font(.system(size: 20))
            
            Text(feature)
                .font(.body)
                .foregroundColor(.theme.text)
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 32)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.theme.accent.opacity(0.05))
                .opacity(isEvenRow ? 1 : 0)
        )
        .offset(x: animate ? 0 : -20)
        .opacity(animate ? 1 : 0)
        .animation(
            .spring(response: 0.3, dampingFraction: 0.8)
            .delay(animationDelay),
            value: animate
        )
    }
}

// Subscription status component
struct ProSubscriptionStatusView: View {
    let subscriptionService: SubscriptionService
    let animate: Bool
    
    var body: some View {
        Group {
            if subscriptionService.isProUser {
                // Already a Pro user
                VStack(spacing: 8) {
                    Text("You're already a Pro user!")
                        .font(.headline)
                        .foregroundColor(.green)
                    
                    if let expiryDate = subscriptionService.renewalDate {
                        Text("Your subscription is active until \(expiryDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.subheadline)
                            .foregroundColor(.theme.subtext)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.green.opacity(0.1))
                )
                .padding(.horizontal, 32)
            } else {
                // Price display
                VStack(spacing: 8) {
                    Text("Unlock all Pro features")
                        .font(.headline)
                        .foregroundColor(.theme.text)
                    
                    HStack(alignment: .bottom, spacing: 4) {
                        Text("$4.99")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.theme.accent)
                        
                        Text("/ month")
                            .font(.subheadline)
                            .foregroundColor(.theme.subtext)
                            .padding(.bottom, 4)
                    }
                    
                    Text("or $49.99/year (save 20%)")
                        .font(.caption)
                        .foregroundColor(.theme.subtext)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.theme.surface)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                )
                .padding(.horizontal, 32)
            }
        }
        .offset(y: animate ? 0 : 20)
        .opacity(animate ? 1 : 0)
        .animation(.easeOut.delay(0.3), value: animate)
    }
}

// Action buttons component
struct ProActionButtonsView: View {
    let subscriptionService: SubscriptionService
    let animate: Bool
    let onUpgrade: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            if subscriptionService.isProUser {
                Button(action: onDismiss) {
                    Text("Continue")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.theme.accent)
                                .shadow(color: Color.theme.accent.opacity(0.3), radius: 10, x: 0, y: 5)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 32)
            } else {
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    
                    // In a real app, this would launch the paywall
                    onUpgrade()
                }) {
                    Text("Upgrade to Pro")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        colors: [.yellow, .orange],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .shadow(color: Color.orange.opacity(0.3), radius: 10, x: 0, y: 5)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 32)
                
                Button(action: onDismiss) {
                    Text("Maybe Later")
                        .font(.subheadline)
                        .foregroundColor(.theme.subtext)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .offset(y: animate ? 0 : 20)
        .opacity(animate ? 1 : 0)
        .animation(.easeOut.delay(0.4), value: animate)
    }
}

#Preview {
    ProUpgradeSheetView(
        title: "Unlock Advanced Badge Filtering",
        description: "Filter badges by category, track progress, and get personalized recommendations",
        features: [
            "Filter badges by any category",
            "Track badge progress over time",
            "Receive personalized badge recommendations",
            "Sync badges across all your devices"
        ],
        onUpgrade: {},
        onDismiss: {}
    )
    .environmentObject(SubscriptionService.shared)
} 