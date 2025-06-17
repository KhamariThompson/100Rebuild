import SwiftUI

/// A standard view for gating pro features consistently throughout the app
struct ProGateView: View {
    // Required properties
    let title: String
    let description: String
    let iconName: String
    let featureName: String
    
    // Optional properties with defaults
    var showUpgradeButton: Bool = true
    var alternateActionTitle: String? = nil
    var alternateAction: (() -> Void)? = nil
    var proRequiredMessage: String = "Pro subscription required"
    var gradientColors: [Color] = [.theme.accent, .theme.accent.opacity(0.7)]
    
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 24) {
            // Pro badge and icon
            VStack(spacing: 16) {
                // Feature icon
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: gradientColors),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 80, height: 80)
                        .shadow(
                            color: gradientColors[0].opacity(colorScheme == .dark ? 0.3 : 0.2),
                            radius: 8,
                            x: 0,
                            y: 4
                        )
                    
                    Image(systemName: iconName)
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                }
                
                // Pro badge
                HStack(spacing: 6) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.yellow)
                    
                    Text(proRequiredMessage)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.theme.text)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.theme.surface)
                        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                )
            }
            .padding(.top, 20)
            
            // Title and description
            VStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.theme.text)
                    .multilineTextAlignment(.center)
                
                Text(description)
                    .font(.system(size: 16))
                    .foregroundColor(.theme.subtext)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            
            Spacer()
                .frame(height: 20)
            
            // State-based actions
            if subscriptionService.isLoading {
                // Loading state
                ProgressView()
                    .scaleEffect(1.2)
                    .padding()
            } else if subscriptionService.isProUser {
                // Already a pro user - shouldn't see this, but just in case
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.green)
                    
                    Text("You already have Pro access!")
                        .font(.headline)
                        .foregroundColor(.theme.text)
                }
                .padding()
            } else if !subscriptionService.isPurchasingEnabled {
                // Purchasing is disabled (App Store review mode)
                Text("Purchases are currently unavailable")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.theme.subtext)
                    .padding()
            } else {
                // Normal upsell buttons
                VStack(spacing: 16) {
                    if showUpgradeButton {
                        // Upgrade button
                        Button {
                            subscriptionService.presentSubscriptionSheet()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 16))
                                
                                Text("Upgrade to Pro")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: gradientColors),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                            .shadow(color: gradientColors[0].opacity(0.3), radius: 5, x: 0, y: 3)
                        }
                        .buttonStyle(AppScaleButtonStyle())
                        .padding(.horizontal, 32)
                    }
                    
                    // Alternate action if provided
                    if let alternateTitle = alternateActionTitle, let action = alternateAction {
                        Button(action: action) {
                            Text(alternateTitle)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.theme.subtext)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(AppScaleButtonStyle())
                    }
                    
                    // Network error message if applicable
                    if !NetworkMonitor.shared.isConnected {
                        HStack(spacing: 6) {
                            Image(systemName: "wifi.slash")
                                .font(.system(size: 12))
                            
                            Text("You're offline. Connect to see Pro features.")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(.theme.error)
                        .padding(.top, 8)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.theme.background)
    }
}

/// A wrapper for Pro features that provides a consistent gate with fallback content
struct ProFeatureWrapper<Content: View, Fallback: View>: View {
    let featureName: String
    let content: Content
    let fallback: Fallback
    @EnvironmentObject private var subscriptionService: SubscriptionService
    
    init(featureName: String, @ViewBuilder content: () -> Content, @ViewBuilder fallback: () -> Fallback) {
        self.featureName = featureName
        self.content = content()
        self.fallback = fallback()
    }
    
    var body: some View {
        ZStack {
            if subscriptionService.isProUser {
                content
            } else {
                fallback
            }
        }
        .onAppear {
            // Log analytics for feature access attempts
            if !subscriptionService.isProUser {
                AnalyticsService.shared.trackEvent(
                    "pro_feature_accessed",
                    properties: ["feature": featureName, "has_access": false]
                )
            } else {
                AnalyticsService.shared.trackEvent(
                    "pro_feature_accessed", 
                    properties: ["feature": featureName, "has_access": true]
                )
            }
        }
    }
}

/// Extension on View to easily wrap any feature in Pro gate
extension View {
    func gatedProFeature(
        name: String,
        title: String,
        description: String,
        iconName: String = "star.fill"
    ) -> some View {
        ProFeatureWrapper(featureName: name) {
            self
        } fallback: {
            ProGateView(
                title: title,
                description: description,
                iconName: iconName,
                featureName: name
            )
        }
    }
}

// Preview
struct ProGateView_Previews: PreviewProvider {
    static var previews: some View {
        ProGateView(
            title: "Advanced Analytics",
            description: "Get detailed insights and statistics for your challenges with Pro.",
            iconName: "chart.bar.fill",
            featureName: "analytics"
        )
        .environmentObject(SubscriptionService.shared)
    }
} 