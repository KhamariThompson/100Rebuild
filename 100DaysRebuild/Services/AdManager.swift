import SwiftUI

/// Manager for handling ad-related functionality and logic in the app
/// NOTE: Ads are now DISABLED in the new Pro-only model
@MainActor
class AdManager: ObservableObject {
    static let shared = AdManager()

    @Published private(set) var isShowingAds = false

    private init() {
        // New model: Everyone is Pro after completing funnel + subscribing
        // No ads are shown
        isShowingAds = false
    }

    /// Updates the internal ad state based on Pro status
    func updateAdState() {
        // Always false - no ads in Pro-only model
        isShowingAds = false
    }

    /// Should we show ads to this user?
    func shouldShowAds() -> Bool {
        // Always false - everyone is Pro
        return false
    }
    
    /// Call this method when subscription status changes to update ad state
    func refreshAdState() {
        updateAdState()
    }
    
    deinit {
        print("✅ Singleton released: \(Self.self)")
    }
}

/// View that shows ads for non-Pro users
struct DummyAdBannerView: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var entitlementsAdapter: EntitlementsAdapter
    @StateObject private var adManager = AdManager.shared
    
    var body: some View {
        if adManager.shouldShowAds() {
            VStack(spacing: 0) {
                HStack {
                    Text("Ad-free experience with Pro")
                        .font(AppTypography.footnote())
                        .foregroundColor(.theme.subtext)
                    
                    Spacer()
                    
                    Button(action: {
                        // TODO: Trigger paywall through navigation - showPaywall removed from SSOT
                    }) {
                        Text("Upgrade")
                            .font(AppTypography.footnote())
                            .fontWeight(.semibold)
                            .foregroundColor(.theme.accent)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                
                // Simulated ad banner
                ZStack {
                    Rectangle()
                        .fill(Color.theme.surface)
                        .frame(height: 50)
                    
                    Text("Advertisement")
                        .foregroundColor(.theme.subtext)
                        .font(AppTypography.caption1())
                }
                .frame(height: 50)
                .contentShape(Rectangle())
                .onTapGesture {
                    // Ad tap action would go here
                    // TODO: Trigger paywall through navigation - showPaywall removed from SSOT
                }
            }
            .background(Color.theme.surface.opacity(0.8))
            .overlay(
                Rectangle()
                    .stroke(Color.theme.subtext.opacity(0.2), lineWidth: 1)
            )
            .cornerRadius(8)
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        } else {
            EmptyView()
        }
    }
}

/// Banner that offers Pro to users who are seeing ads
struct ProUpgradeBanner: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var entitlementsAdapter: EntitlementsAdapter
    @StateObject private var adManager = AdManager.shared
    
    var body: some View {
        if adManager.shouldShowAds() {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                    
                    Text("Enjoy 100Days Without Ads")
                        .font(AppTypography.headline())
                        .foregroundColor(.theme.text)
                    
                    Spacer()
                }
                
                Text("Upgrade to Pro for an ad-free experience and unlock all premium features.")
                    .font(AppTypography.caption1())
                    .foregroundColor(.theme.subtext)
                
                Button(action: {
                    // TODO: Trigger paywall through navigation - showPaywall removed from SSOT
                }) {
                    HStack {
                        Text("Go Pro")
                            .fontWeight(.semibold)
                        Image(systemName: "arrow.right")
                            .font(AppTypography.caption1())
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.theme.accent)
                    .cornerRadius(8)
                }
                .buttonStyle(AppScaleButtonStyle())
                .padding(.top, 4)
            }
            .padding(12)
            .background(Color.theme.surface)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.theme.accent.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            .padding(.horizontal)
        } else {
            EmptyView()
        }
    }
} 