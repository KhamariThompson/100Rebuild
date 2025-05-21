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
        return "$5.99" // Fallback price if unavailable
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
    @State private var animateGradient = false
    
    // RevenueCat integration
    private let monthlySKU = "100days_premium_monthly"
    
    var body: some View {
        ZStack {
            // Background with gradient animation
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.theme.background,
                    Color.theme.accent.opacity(0.08),
                    Color.theme.background
                ]),
                startPoint: animateGradient ? .topLeading : .bottomTrailing,
                endPoint: animateGradient ? .bottomTrailing : .topLeading
            )
            .ignoresSafeArea()
            .animation(Animation.easeInOut(duration: 5).repeatForever(autoreverses: true), value: animateGradient)
            .onAppear {
                animateGradient = true
            }
            
            ScrollView {
                VStack(spacing: AppSpacing.l) {
                    // Header
                    paywallHeader
                    
                    // Price tag
                    priceTagBanner
                        .opacity(isAnimating ? 1.0 : 0.0)
                        .offset(y: isAnimating ? 0 : 10)
                        .animation(.easeOut(duration: 0.4).delay(0.3), value: isAnimating)
                    
                    // Feature highlights
                    featuresSection
                    
                    // Action buttons
                    actionButtons
                        .padding(.vertical, AppSpacing.l)
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
            isLoading = true
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
            isLoading = false
        }
    }
    
    private func purchaseSubscription() {
        isLoading = true
        
        Task {
            do {
                // Purchase the package using the correct method in SubscriptionService
                if let package = monthlyPackage {
                    try await subscriptionService.purchaseSubscription(plan: .monthly)
                    dismiss()
                } else {
                    errorMessage = "Subscription package not available"
                    showingError = true
                }
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
            
            isLoading = false
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
        @State private var isHovered = false
        
        var body: some View {
            HStack(alignment: .top, spacing: AppSpacing.m) {
                // Feature icon with glow effect
                ZStack {
                    Circle()
                        .fill(Color.theme.accent.opacity(0.2))
                        .frame(width: 50, height: 50)
                        .blur(radius: isHovered ? 8 : 5)
                    
                    Circle()
                        .fill(Color.theme.surface)
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: iconName)
                        .font(.system(size: AppSpacing.iconSizeMedium))
                        .foregroundColor(Color.theme.accent)
                }
                .scaleEffect(isHovered ? 1.05 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)
                
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
                    .shadow(color: Color.theme.shadow.opacity(isHovered ? 0.15 : 0.1), radius: isHovered ? 8 : 6, x: 0, y: isHovered ? 4 : 3)
            )
            .onAppear {
                // Randomly toggle the hover effect for a subtle animation
                DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 1...3)) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isHovered = true
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            isHovered = false
                        }
                    }
                }
            }
        }
    }
    
    struct ProFeature: View {
        let text: String
        let icon: String
        @State private var isHighlighted = false
        
        var body: some View {
            HStack(spacing: AppSpacing.s) {
                // Feature icon
                ZStack {
                    Circle()
                        .fill(Color.theme.accent.opacity(0.15))
                        .frame(width: 30, height: 30)
                    
                    Image(systemName: icon)
                        .font(.system(size: AppSpacing.iconSizeSmall))
                        .foregroundColor(Color.theme.accent)
                }
                .scaleEffect(isHighlighted ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHighlighted)
                
                Text(text)
                    .font(AppTypography.subheadline)
                    .foregroundColor(Color.theme.text)
                
                Spacer()
                
                // Checkmark with pulse animation
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.green)
                    .opacity(isHighlighted ? 1.0 : 0.9)
                    .scaleEffect(isHighlighted ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHighlighted)
            }
            .padding(.vertical, AppSpacing.xs)
            .padding(.horizontal, AppSpacing.m)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.theme.surface)
                    .shadow(color: Color.theme.shadow.opacity(0.05), radius: 3, x: 0, y: 1)
            )
            .onAppear {
                // Cycle through highlighting features
                DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 1...3)) {
                    withAnimation {
                        isHighlighted = true
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        withAnimation {
                            isHighlighted = false
                        }
                    }
                }
            }
        }
    }
    
    // Attractive price tag banner
    private var priceTagBanner: some View {
        HStack(spacing: 0) {
            // Left price tag shape
            ZStack {
                Circle()
                    .fill(Color.theme.accent)
                    .frame(width: 60, height: 60)
                
                Text("$5.99")
                    .font(AppTypography.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            .zIndex(1)
            
            // Right price tag description
            ZStack {
                Rectangle()
                    .fill(Color.theme.accent)
                    .frame(height: 48)
                    .cornerRadius(8, corners: [.topRight, .bottomRight])
                
                Text("per month")
                    .font(AppTypography.headline)
                    .foregroundColor(.white)
                    .padding(.leading, 30)
            }
            .padding(.leading, -15)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, AppSpacing.l)
        .padding(.bottom, AppSpacing.s)
    }
    
    // Header with app icon and title
    private var paywallHeader: some View {
        VStack(spacing: AppSpacing.m) {
            // Icon with glow effect
            ZStack {
                Circle()
                    .fill(Color.theme.accent.opacity(0.2))
                    .frame(width: 100, height: 100)
                    .blur(radius: 15)
                
                // App icon with animation
                Image.appIconWithFallback(size: 90)
                    .scaleEffect(isAnimating ? 1.0 : 0.8)
                    .opacity(isAnimating ? 1.0 : 0.0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: isAnimating)
            }
            
            // Title with gradient
            Text("Unlock Pro")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(LinearGradient(
                    colors: [Color.theme.accent, Color.theme.accent.opacity(0.7)],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                .opacity(isAnimating ? 1.0 : 0.0)
                .offset(y: isAnimating ? 0 : 10)
                .animation(.easeOut(duration: 0.4).delay(0.1), value: isAnimating)
            
            // Subtitle
            Text("Elevate your journey with premium features")
                .font(AppTypography.headline)
                .foregroundColor(Color.theme.subtext)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .opacity(isAnimating ? 1.0 : 0.0)
                .offset(y: isAnimating ? 0 : 10)
                .animation(.easeOut(duration: 0.4).delay(0.2), value: isAnimating)
        }
        .padding(.vertical, AppSpacing.l)
    }
    
    private var featuresSection: some View {
        VStack(spacing: AppSpacing.xl) {
            // Key features grid
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                Text("Pro Features")
                    .font(AppTypography.title2)
                    .fontWeight(.bold)
                    .padding(.horizontal, AppSpacing.m)
                
                VStack(spacing: AppSpacing.m) {
                    ProFeature(text: "Unlimited Challenges", icon: "infinity")
                    ProFeature(text: "Group Challenges", icon: "person.3.fill")
                    ProFeature(text: "Advanced Analytics", icon: "chart.bar.xaxis")
                    ProFeature(text: "Shareable Milestones", icon: "square.and.arrow.up")
                    ProFeature(text: "More Than 5 Friends", icon: "person.badge.plus")
                    ProFeature(text: "No Ads", icon: "hand.raised")
                }
                .padding(AppSpacing.s)
                .background(
                    RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                        .fill(Color.theme.background)
                        .shadow(color: Color.theme.shadow.opacity(0.08), radius: 8, x: 0, y: 4)
                )
            }
            .opacity(isAnimating ? 1.0 : 0.0)
            .offset(y: isAnimating ? 0 : 20)
            .animation(.easeOut(duration: 0.5).delay(0.4), value: isAnimating)
            
            // Feature themes
            VStack(alignment: .leading, spacing: AppSpacing.l) {
                // Unlock Your Potential
                unlockPotentialSection
                    .opacity(isAnimating ? 1.0 : 0.0)
                    .offset(y: isAnimating ? 0 : 20)
                    .animation(.easeOut(duration: 0.5).delay(0.5), value: isAnimating)
                
                // Level Up Together
                levelUpSection
                    .opacity(isAnimating ? 1.0 : 0.0)
                    .offset(y: isAnimating ? 0 : 20)
                    .animation(.easeOut(duration: 0.5).delay(0.6), value: isAnimating)
                
                // Stay Motivated
                stayMotivatedSection
                    .opacity(isAnimating ? 1.0 : 0.0)
                    .offset(y: isAnimating ? 0 : 20)
                    .animation(.easeOut(duration: 0.5).delay(0.7), value: isAnimating)
            }
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: AppSpacing.m) {
            // Subscribe button
            Button {
                purchaseSubscription()
            } label: {
                HStack {
                    Text("Upgrade Now")
                        .font(.system(size: 18, weight: .bold))
                    
                    Text("- \(price)/month")
                        .font(.system(size: 16))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.m)
                .background(
                    LinearGradient(
                        colors: [Color.theme.accent, Color.theme.accent.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(14)
                .shadow(color: Color.theme.accent.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(AppScaleButtonStyle())
            .opacity(isAnimating ? 1.0 : 0.0)
            .animation(.easeOut(duration: 0.4).delay(0.8), value: isAnimating)
            
            // Restore button
            Button {
                restorePurchases()
            } label: {
                Text("Restore Purchases")
                    .font(AppTypography.subheadline)
                    .foregroundColor(Color.theme.subtext)
            }
            .padding(.vertical, AppSpacing.xs)
            .opacity(isAnimating ? 1.0 : 0.0)
            .animation(.easeOut(duration: 0.4).delay(0.9), value: isAnimating)
            
            // Terms and conditions
            Text("Subscription auto-renews until cancelled")
                .font(AppTypography.caption)
                .foregroundColor(Color.theme.subtext.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.top, AppSpacing.xs)
                .opacity(isAnimating ? 1.0 : 0.0)
                .animation(.easeOut(duration: 0.4).delay(1.0), value: isAnimating)
        }
    }
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: AppSpacing.m) {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                
                Text("Processing...")
                    .font(AppTypography.headline)
                    .foregroundColor(.white)
            }
            .padding(AppSpacing.xl)
            .background(
                RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                    .fill(Color.theme.surface.opacity(0.9))
                    .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
            )
        }
    }
    
    private var unlockPotentialSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            SectionHeader(icon: "🔓", title: "Unlock Your Potential")
                .id("unlock-potential")
            
            PaywallFeatureCard(
                title: "Unlimited Challenges",
                description: "No limits on the number of habits and challenges you can track simultaneously.",
                iconName: "infinity"
            )
            
            PaywallFeatureCard(
                title: "Advanced Analytics",
                description: "Gain deeper insights with detailed stats, charts, and performance trends.",
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
                description: "Create and join challenges with friends to stay accountable and motivated together.",
                iconName: "person.3.fill"
            )
            
            PaywallFeatureCard(
                title: "Extended Friends Network",
                description: "Connect with more than 5 friends to expand your support system.",
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
                description: "Create beautiful cards to share your progress and achievements on social media.",
                iconName: "square.and.arrow.up"
            )
            
            PaywallFeatureCard(
                title: "Ad-Free Experience",
                description: "Enjoy a clean, distraction-free environment focused on your growth.",
                iconName: "hand.raised"
            )
        }
    }
}

// MARK: - Extensions

#if os(iOS)
extension View {
    func onHover(_ perform: @escaping (Bool) -> Void) -> some View {
        self // On iOS, just return the original view since hover isn't supported
    }
}
#endif

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
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