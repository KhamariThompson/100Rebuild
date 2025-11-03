import SwiftUI
import GoogleMobileAds

/// A SwiftUI view that displays a Google AdMob banner ad
/// NOTE: Ads are DISABLED in the new Pro-only model - this view never shows
struct AdMobBannerView: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var entitlementsAdapter: EntitlementsAdapter
    @StateObject private var adManager = AdManager.shared

    var body: some View {
        // Always return EmptyView - no ads in Pro-only model
        if false {
            VStack(spacing: 0) {
                // Header with upgrade option
                HStack {
                    Text("Ad-free experience with Pro")
                        .font(AppTypography.footnote())
                        .foregroundColor(.theme.subtext)
                    
                    Spacer()
                    
                    Button(action: {
                        // TODO: Trigger paywall through navigation - showPaywall removed from SSOT

                        // Add haptic feedback for better user experience
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                    }) {
                        Text("Upgrade")
                            .font(AppTypography.footnote())
                            .fontWeight(.semibold)
                            .foregroundColor(.theme.accent)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                
                // Real AdMob banner
                BannerViewController()
                    .frame(height: 50)
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

/// UIViewControllerRepresentable for displaying Google AdMob banner ads in SwiftUI
struct BannerViewController: UIViewControllerRepresentable {
    let bannerView = BannerView(adSize: AdSizeBanner)
    
    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        
        // Configure the banner view with the ad unit ID
        bannerView.adUnitID = "ca-app-pub-3606640656667523/6924064590"
        bannerView.rootViewController = viewController
        
        // Add constraints to properly position the banner
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        viewController.view.addSubview(bannerView)
        NSLayoutConstraint.activate([
            bannerView.topAnchor.constraint(equalTo: viewController.view.topAnchor),
            bannerView.leadingAnchor.constraint(equalTo: viewController.view.leadingAnchor),
            bannerView.widthAnchor.constraint(equalTo: viewController.view.widthAnchor),
            bannerView.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Load the ad when the view updates
        bannerView.load(Request())
    }
}

struct AdMobBannerView_Previews: PreviewProvider {
    static var previews: some View {
        AdMobBannerView()
            .environmentObject(SubscriptionStore.shared)
            .environmentObject(EntitlementsAdapter.shared)
    }
} 