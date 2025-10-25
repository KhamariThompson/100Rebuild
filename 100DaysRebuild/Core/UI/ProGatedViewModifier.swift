import SwiftUI

/// A view modifier that gates content behind a Pro subscription
struct ProGatedFeature: ViewModifier {
    @StateObject private var entitlements = Entitlements.shared

    func body(content: Content) -> some View {
        if entitlements.effectiveIsProUser {
            content
        } else {
            ProLockedView {
                content
            }
        }
    }
}

/// Extension to easily apply Pro-gating to any view
extension View {
    /// Gates the content behind a Pro subscription, showing a lock overlay for non-Pro users
    func proGated() -> some View {
        modifier(ProGatedFeature())
    }
    
    /// Disables the view and shows upgrade button for non-Pro users
    func proGatedAction(action: @escaping () async throws -> Void) -> some View {
        self.modifier(ProGatedActionModifier(action: action))
    }
}

/// A view modifier for actions that require Pro subscription
struct ProGatedActionModifier: ViewModifier {
    @StateObject private var entitlements = Entitlements.shared
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var entitlementsAdapter: EntitlementsAdapter
    let action: () async throws -> Void

    func body(content: Content) -> some View {
        Button {
            if entitlements.effectiveIsProUser {
                Task {
                    try? await action()
                }
            } else {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                // TODO: Trigger paywall through navigation - showPaywall removed from SSOT
            }
        } label: {
            content
        }
    }
}

/// A modifier to blur content with an upgrade prompt
struct ProBlurredPreview: ViewModifier {
    @StateObject private var entitlements = Entitlements.shared
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var entitlementsAdapter: EntitlementsAdapter
    let message: String

    func body(content: Content) -> some View {
        ZStack {
            // Blur content for non-pro users
            content
                .blur(radius: entitlements.effectiveIsProUser ? 0 : 10)
                .overlay(
                    // Show overlay only for non-pro users
                    ZStack {
                        if !entitlements.effectiveIsProUser {
                            VStack(spacing: AppSpacing.s) {
                                Text(message)
                                    .font(AppTypography.headline())
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(Color.theme.text)
                                    .padding(.bottom, AppSpacing.xs)
                                
                                Button {
                                    // TODO: Trigger paywall through navigation - showPaywall removed from SSOT
                                } label: {
                                    Text("Upgrade to Pro")
                                        .font(AppTypography.subhead().bold())
                                        .foregroundColor(.white)
                                        .padding(.horizontal, AppSpacing.m)
                                        .padding(.vertical, AppSpacing.xs)
                                        .background(
                                            Capsule()
                                                .fill(Color.theme.accent)
                                        )
                                }
                            }
                            .padding(AppSpacing.m)
                            .background(
                                RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                                    .fill(Color.theme.surface.opacity(0.95))
                                    .shadow(color: Color.theme.shadow, radius: 10)
                            )
                            .padding(AppSpacing.m)
                        }
                    }
                )
        }
        // Note: Sheet handling removed as showPaywall is no longer in SSOT
        // TODO: Implement paywall navigation through proper routing
    }
}

// Extension for blurred preview
extension View {
    /// Blurs content with an upgrade message for non-Pro users
    func proBlurredPreview(message: String = "Upgrade to Pro to access this feature") -> some View {
        modifier(ProBlurredPreview(message: message))
    }
} 