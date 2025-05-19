import SwiftUI
import RevenueCat
import StoreKit

/// A paywall view that shows Pro subscription benefits and a purchase button
struct PaywallView: View {
    // Environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var subscriptionService: SubscriptionService
    
    // Constants
    var price: String {
        if let formattedPrice = formattedPrice, !formattedPrice.isEmpty {
            return formattedPrice
        }
        return "$4.99" // Fallback price if unavailable
    }
    
    // State for UI
    @State private var selectedPlanIndex = 0
    @State private var isAnimating = false
    @State private var isLoading = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var monthlyPackage: Package?
    @State private var offeringsFailedToLoad = false
    @State private var formattedPrice: String?
    @State private var activeTab: String = "unlock-potential"
    @State private var currentOfferingIdentifier: String?
    
    // RevenueCat integration
    private let monthlySKU = "100days_premium_monthly"
    
    var body: some View {
        ZStack {
            // Background
            Color.theme.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: AppSpacing.l) {
                    // Header
                    paywallHeader
                    
                    // Feature highlights
                    featuresSection
                    
                    // Pricing plans
                    pricingSection
                    
                    // Action buttons
                    actionButtons
                }
                .padding(AppSpacing.m)
            }
            
            // Loading overlay
            if isLoading {
                loadingOverlay
            }
        }
        .navigationTitle("Upgrade to Pro")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Close") {
                    dismiss()
                }
            }
        }
        .alert("Subscription Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            animateContent()
            loadSubscriptionOfferings()
        }
        .fixNavigationLayout()
    }
    
    // MARK: - Helper Methods
    
    private func animateContent() {
        // Set initial state
        self.isAnimating = false
        
        // Animate after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeInOut(duration: 0.5)) {
                self.isAnimating = true
            }
        }
    }
    
    private func loadSubscriptionOfferings() {
        Task {
            do {
                let offerings = try await subscriptionService.getOfferings()
                print("Received offerings: \(offerings)")
                
                // Look for monthly package
                if let current = offerings?.current, let monthlyPackage = current.availablePackages.first(where: { $0.identifier == monthlySKU || $0.packageType == .monthly }) {
                    self.monthlyPackage = monthlyPackage
                    self.formattedPrice = monthlyPackage.storeProduct.localizedPriceString
                    print("Found monthly package: \(monthlyPackage.identifier) at \(monthlyPackage.storeProduct.localizedPriceString)")
                } else {
                    print("No monthly package found in available packages")
                }
                
                if let current = offerings?.current {
                    self.currentOfferingIdentifier = current.identifier
                }
            } catch {
                print("Failed to load offerings: \(error.localizedDescription)")
                formattedPrice = nil
                offeringsFailedToLoad = true
            }
        }
    }
    
    // Helper function to open a URL
    private func openURL(_ url: URL) {
        UIApplication.shared.open(url)
    }
    
    private func restorePurchases() {
        isLoading = true
        Task {
            do {
                try await subscriptionService.restorePurchases()
                
                // If pro was successfully restored, dismiss the view
                if subscriptionService.isProUser {
                    dismiss()
                } else {
                    // Show an error if no purchases were found
                    errorMessage = "No previous purchases found to restore"
                    showingError = true
                }
            } catch {
                // Show error message if restoration fails
                errorMessage = error.localizedDescription
                showingError = true
            }
            isLoading = false
        }
    }
    
    // MARK: - Child Views
    
    struct SectionHeader: View {
        let icon: String
        let title: String
        
        var body: some View {
            HStack(spacing: AppSpacing.s) {
                Text(icon)
                    .font(AppTypography.title2)
                    .frame(width: 32)
                
                Text(title)
                    .font(AppTypography.title3)
                    .foregroundColor(Color.theme.text)
            }
        }
    }
    
    struct PaywallFeatureCard: View {
        let title: String
        let description: String
        let iconName: String
        
        var body: some View {
            HStack(alignment: .top, spacing: AppSpacing.m) {
                // Feature icon
                ZStack {
                    Circle()
                        .fill(Color.theme.accent.opacity(0.1))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: iconName)
                        .font(.system(size: AppSpacing.iconSizeSmall))
                        .foregroundColor(Color.theme.accent)
                }
                
                // Feature text
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(title)
                        .font(AppTypography.headline)
                        .foregroundColor(Color.theme.text)
                    
                    Text(description)
                        .font(AppTypography.subheadline)
                        .foregroundColor(Color.theme.subtext)
                        .lineSpacing(2)
                }
            }
            .padding(AppSpacing.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                    .fill(Color.theme.surface)
                    .shadow(color: Color.theme.shadow, radius: 6, x: 0, y: 3)
            )
        }
    }
    
    struct ProFeature: View {
        let text: String
        let icon: String
        
        var body: some View {
            HStack(spacing: AppSpacing.s) {
                Image(systemName: icon)
                    .font(.system(size: AppSpacing.iconSizeSmall))
                    .foregroundColor(Color.theme.accent)
                    .frame(width: 24)
                
                Text(text)
                    .font(AppTypography.subheadline)
                    .foregroundColor(Color.theme.text)
                
                Spacer()
                
                Image(systemName: "checkmark")
                    .font(AppTypography.footnote)
                    .foregroundColor(.green)
            }
        }
    }
    
    // Header with app icon and title
    private var paywallHeader: some View {
        VStack(spacing: AppSpacing.m) {
            // Use our new image extension for proper fallback
            Image.appIconWithFallback(size: 80)
                .scaleEffect(isAnimating ? 1.0 : 0.8)
                .opacity(isAnimating ? 1.0 : 0.0)
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: isAnimating)
            
            Text("Upgrade to Pro")
                .font(AppTypography.title1)
                .foregroundColor(Color.theme.text)
                .opacity(isAnimating ? 1.0 : 0.0)
                .offset(y: isAnimating ? 0 : 10)
                .animation(.easeOut(duration: 0.4).delay(0.1), value: isAnimating)
            
            Text("Unlock all features and get the most out of your experience")
                .font(AppTypography.callout)
                .foregroundColor(Color.theme.subtext)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .opacity(isAnimating ? 1.0 : 0.0)
                .offset(y: isAnimating ? 0 : 10)
                .animation(.easeOut(duration: 0.4).delay(0.2), value: isAnimating)
            
            Text(price + " / Month")
                .font(AppTypography.title2)
                .foregroundColor(Color.theme.accent)
                .padding(.top, AppSpacing.xxs)
                .opacity(isAnimating ? 1.0 : 0.0)
                .offset(y: isAnimating ? 0 : 10)
                .animation(.easeOut(duration: 0.4).delay(0.3), value: isAnimating)
        }
    }
    
    private var featuresSection: some View {
        VStack(spacing: AppSpacing.xl) {
            unlockPotentialSection
                .opacity(isAnimating ? 1.0 : 0.0)
                .offset(y: isAnimating ? 0 : 20)
                .transition(.opacity)
            
            levelUpSection
                .opacity(isAnimating ? 1.0 : 0.0)
                .offset(y: isAnimating ? 0 : 20)
                .transition(.opacity)
                .animation(Animation.easeOut(duration: 0.5).delay(0.2), value: isAnimating)
            
            stayMotivatedSection
                .opacity(isAnimating ? 1.0 : 0.0)
                .offset(y: isAnimating ? 0 : 20)
                .transition(.opacity)
                .animation(Animation.easeOut(duration: 0.5).delay(0.4), value: isAnimating)
        }
    }
    
    private var pricingSection: some View {
        // Implementation of pricingSection
        Text("Pricing Section")
    }
    
    private var actionButtons: some View {
        // Implementation of actionButtons
        Text("Action Buttons")
    }
    
    private var loadingOverlay: some View {
        // Implementation of loadingOverlay
        Text("Loading Overlay")
    }
    
    private var unlockPotentialSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            SectionHeader(icon: "🔓", title: "Unlock Your Potential")
                .id("unlock-potential")
            
            PaywallFeatureCard(
                title: "Unlimited Challenges",
                description: "Track all your habits without limits.",
                iconName: "infinity"
            )
            
            PaywallFeatureCard(
                title: "Advanced Analytics",
                description: "See detailed stats and performance trends.",
                iconName: "chart.bar.xaxis"
            )
        }
    }
    
    private var levelUpSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            SectionHeader(icon: "🤝", title: "Level Up Together")
                .id("level-up")
            
            PaywallFeatureCard(
                title: "Group Challenges",
                description: "Stay accountable by joining challenges with friends.",
                iconName: "person.2"
            )
            
            PaywallFeatureCard(
                title: "Add More Than 5 Friends",
                description: "Expand your network for better support.",
                iconName: "person.badge.plus"
            )
        }
    }
    
    private var stayMotivatedSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            SectionHeader(icon: "🎯", title: "Stay Motivated")
                .id("stay-motivated")
            
            PaywallFeatureCard(
                title: "Shareable Milestones",
                description: "Celebrate progress with visual cards.",
                iconName: "square.and.arrow.up"
            )
            
            PaywallFeatureCard(
                title: "No Ads",
                description: "Enjoy a clean and focused experience.",
                iconName: "hand.raised"
            )
        }
    }
}

struct PaywallView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PaywallView()
                .environmentObject(SubscriptionService.shared)
                .preferredColorScheme(.light)
            
            PaywallView()
                .environmentObject(SubscriptionService.shared)
                .preferredColorScheme(.dark)
        }
    }
} 