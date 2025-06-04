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
    private let monthlySKU = "100days_premium_monthlyv2"
    
    var body: some View {
        ZStack {
            // Background with gradient animation
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.theme.background,
                    Color.theme.accent.opacity(0.1),
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
            
            // Close button - positioned in top corner
            VStack {
                HStack {
                    Spacer()
                    
                    Button {
                        dismissPaywall()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(Color.theme.subtext)
                            .padding(14)
                            .background(
                                Circle()
                                    .fill(Color.theme.surface.opacity(0.8))
                                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                            )
                            .contentShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.top, 10)
                    .padding(.trailing, 10)
                    .accessibility(label: Text("Close"))
                }
                
                Spacer()
            }
            .zIndex(99)
            
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
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Close") {
                    dismissPaywall()
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
        
        // Check if we're in a sandbox environment (App Store review)
        if subscriptionService.isSandboxUser {
            // Show special message for sandbox users (App Store reviewers)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.isLoading = false
                self.showingError = true
                self.errorMessage = "This is a sandbox environment. In the production app, this would initiate a real purchase. For testing purposes, premium features are already enabled."
            }
            return
        }
        
        // Regular purchase flow
        Task {
            do {
                // Attempt to purchase using the service
                try await subscriptionService.purchaseSubscription(plan: .monthly)
                
                isLoading = false
                
                // Dismiss paywall on successful purchase
                dismissPaywall()
                
                // Show success feedback
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            } catch {
                isLoading = false
                showingError = true
                
                // Handle specific errors
                if let subscriptionError = error as? SubscriptionError {
                    switch subscriptionError {
                    case .notSignedIntoAppStore:
                        errorMessage = "Please sign in to your App Store account to complete this purchase."
                    case .purchaseFailed:
                        errorMessage = "The purchase could not be completed. Please try again later."
                    case .restoreFailed:
                        errorMessage = "Could not restore your previous purchase. Please try again later."
                    case .timeout:
                        errorMessage = "The purchase timed out. Please check your internet connection and try again."
                    case .networkOffline:
                        errorMessage = "You appear to be offline. Please check your internet connection and try again."
                    case .networkError:
                        errorMessage = "There was a network error. Please check your connection and try again."
                    case .purchasePending:
                        errorMessage = "Your purchase is pending approval. It will be available once approved."
                    case .receiptInUse:
                        errorMessage = "This receipt is already in use with a different account."
                    case .productNotFound:
                        errorMessage = "The subscription product could not be found. Please try again later."
                    case .verificationFailed:
                        errorMessage = "Purchase verification failed. Please contact support if this persists."
                    case .userCancelled:
                        errorMessage = "The purchase was cancelled."
                    case .unknown:
                        errorMessage = "An unknown error occurred. Please try again later."
                    }
                } else {
                    // Generic error message
                    errorMessage = "Could not complete purchase: \(error.localizedDescription)"
                }
                
                // Haptic feedback for error
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)
            }
        }
    }
    
    // Add a custom dismiss method to ensure both the Environment dismiss and showPaywall property are handled
    private func dismissPaywall() {
        // Call the environment dismiss action
        dismiss()
        
        // Also set the subscription service flag to false
        subscriptionService.showPaywall = false
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    // Helper function to open a URL
    private func openURL(_ url: URL) {
        UIApplication.shared.open(url)
    }
    
    private func restorePurchases() {
        isLoading = true
        
        // Check if we're in a sandbox environment (App Store review)
        if subscriptionService.isSandboxUser {
            // Show special message for sandbox users (App Store reviewers)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.isLoading = false
                self.showingError = true
                self.errorMessage = "This is a sandbox environment. For testing purposes, premium features are already enabled without requiring restoration."
            }
            return
        }
        
        // Regular restore flow
        Task {
            do {
                try await subscriptionService.restorePurchases()
                
                isLoading = false
                
                // Check if user has active subscription after restoration
                if subscriptionService.isProUser {
                    // Successful restoration with active subscription
                    dismissPaywall()
                    
                    // Success feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                } else {
                    // No subscription found
                    showingError = true
                    errorMessage = "No active subscription was found on your account."
                }
            } catch {
                isLoading = false
                showingError = true
                
                // Handle specific errors
                if let subscriptionError = error as? SubscriptionError {
                    switch subscriptionError {
                    case .notSignedIntoAppStore:
                        errorMessage = "Please sign in to your App Store account to restore purchases."
                    case .restoreFailed:
                        errorMessage = "Could not restore your previous purchase. Please try again later."
                    case .timeout:
                        errorMessage = "The restore operation timed out. Please check your internet connection and try again."
                    case .networkOffline:
                        errorMessage = "You appear to be offline. Please check your internet connection and try again."
                    case .networkError:
                        errorMessage = "There was a network error. Please check your connection and try again."
                    case .purchasePending:
                        errorMessage = "Your purchase is pending approval. It will be available once approved."
                    case .receiptInUse:
                        errorMessage = "This receipt is already in use with a different account."
                    case .productNotFound:
                        errorMessage = "The subscription product could not be found. Please try again later."
                    case .verificationFailed:
                        errorMessage = "Purchase verification failed. Please contact support if this persists."
                    case .userCancelled:
                        errorMessage = "The restore operation was cancelled."
                    case .purchaseFailed:
                        errorMessage = "There was an error with your previous purchase. Please contact support."
                    case .unknown:
                        errorMessage = "An error occurred while restoring purchases. Please try again."
                    }
                } else {
                    // Generic error message
                    errorMessage = "Could not restore purchases: \(error.localizedDescription)"
                }
                
                // Error feedback
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)
            }
        }
    }
    
    // MARK: - Child Views
    
    struct SectionHeader: View {
        let icon: String
        let title: String
        
        var body: some View {
            HStack(spacing: AppSpacing.s) {
                Text(icon)
                    .font(AppTypography.title2())
                    .frame(width: 32)
                
                Text(title)
                    .font(AppTypography.title3())
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
                        .font(AppTypography.headline())
                        .foregroundColor(Color.theme.text)
                    
                    Text(description)
                        .font(AppTypography.subhead())
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
                    .font(AppTypography.subhead())
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
        VStack(spacing: 12) {
            Text("Upgrade to PRO for")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.theme.text)
                
            HStack(spacing: 0) {
                // Left price tag shape
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.theme.accent, Color.theme.accent.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 65, height: 65)
                        .shadow(color: Color.theme.accent.opacity(0.2), radius: 4, x: 0, y: 2)
                    
                    Text(price)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(colorScheme == .dark ? .black : .white)
                }
                .zIndex(1)
                
                // Right price tag description
                ZStack {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.theme.accent.opacity(0.8), Color.theme.accent.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 50)
                        .cornerRadius(8, corners: [.topRight, .bottomRight])
                        .shadow(color: Color.theme.accent.opacity(0.2), radius: 4, x: 2, y: 2)
                    
                    Text("per month")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(colorScheme == .dark ? .black : .white)
                        .padding(.leading, 30)
                }
                .padding(.leading, -15)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, AppSpacing.m)
        .padding(.vertical, AppSpacing.s)
    }
    
    // Header with app icon and title
    private var paywallHeader: some View {
        VStack(spacing: AppSpacing.m) {
            // Pro image with enhanced styling
            Image("PaywallImages")
                .resizable()
                .scaledToFit()
                .frame(width: 90, height: 90)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.theme.accent.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: Color.theme.shadow.opacity(0.2), radius: 8, x: 0, y: 4)
                .scaleEffect(isAnimating ? 1.0 : 0.8)
                .opacity(isAnimating ? 1.0 : 0.0)
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: isAnimating)
            
            // Title with gradient
            Text("Unlock 100Days Pro")
                .font(.system(size: 30, weight: .bold, design: .rounded))
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
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.theme.subtext)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .opacity(isAnimating ? 1.0 : 0.0)
                .offset(y: isAnimating ? 0 : 10)
                .animation(.easeOut(duration: 0.4).delay(0.2), value: isAnimating)
        }
        .padding(.top, AppSpacing.xl)
        .padding(.bottom, AppSpacing.m)
    }
    
    private var featuresSection: some View {
        VStack(spacing: AppSpacing.l) {
            // Enhanced features section with stronger glow effects
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                Text("Pro Features")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color.theme.text)
                    .padding(.horizontal, AppSpacing.m)
                
                // Combined feature cards with enhanced styling
                ForEach(proFeatures) { feature in
                    EnhancedFeatureCard(
                        title: feature.title,
                        description: feature.description,
                        iconName: feature.iconName,
                        category: feature.category
                    )
                    .padding(.bottom, AppSpacing.xxs)
                }
            }
            .padding(AppSpacing.s)
            .background(
                RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                    .fill(Color.theme.background)
                    .shadow(color: Color.theme.shadow.opacity(0.08), radius: 10, x: 0, y: 5)
            )
            .opacity(isAnimating ? 1.0 : 0.0)
            .offset(y: isAnimating ? 0 : 20)
            .animation(.easeOut(duration: 0.5).delay(0.4), value: isAnimating)
        }
    }
    
    // Consolidated feature data model
    private var proFeatures: [ProFeatureItem] {
        [
            ProFeatureItem(
                title: "Unlimited Challenges", 
                description: "No limits on the number of habits and challenges you can track simultaneously.", 
                iconName: "infinity",
                category: "🔓 Unlock Your Potential"
            ),
            ProFeatureItem(
                title: "Advanced Analytics", 
                description: "Gain deeper insights with detailed stats, charts, and performance trends.", 
                iconName: "chart.bar.xaxis",
                category: "🔓 Unlock Your Potential"
            ),
            ProFeatureItem(
                title: "Group Challenges", 
                description: "Create and join challenges with friends to stay accountable and motivated together.", 
                iconName: "person.3.fill",
                category: "🤝 Level Up Together"
            ),
            ProFeatureItem(
                title: "Extended Network", 
                description: "Connect with more than 5 friends to expand your support system.", 
                iconName: "person.badge.plus",
                category: "🤝 Level Up Together"
            ),
            ProFeatureItem(
                title: "Shareable Milestones", 
                description: "Create beautiful cards to share your progress and achievements on social media.", 
                iconName: "square.and.arrow.up",
                category: "🎯 Stay Motivated"
            ),
            ProFeatureItem(
                title: "Ad-Free Experience", 
                description: "Enjoy a clean, distraction-free environment focused on your growth.", 
                iconName: "hand.raised",
                category: "🎯 Stay Motivated"
            )
        ]
    }
    
    // Enhanced feature card with better glow effects
    struct EnhancedFeatureCard: View {
        let title: String
        let description: String
        let iconName: String
        let category: String
        @State private var isHovered = false
        @Environment(\.colorScheme) private var colorScheme
        
        var body: some View {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                // Category label
                Text(category)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color.theme.accent)
                    .padding(.leading, 60)
                    .padding(.bottom, 2)
                
                HStack(alignment: .top, spacing: AppSpacing.m) {
                    // Enhanced icon with stronger glow effect
                    ZStack {
                        // Outer glow
                        Circle()
                            .fill(Color.theme.accent.opacity(0.3))
                            .frame(width: 48, height: 48)
                            .blur(radius: isHovered ? 8 : 6)
                        
                        // Inner circle
                        Circle()
                            .fill(colorScheme == .dark ? 
                                Color.theme.surface.opacity(0.9) : 
                                Color.theme.surface)
                            .frame(width: 40, height: 40)
                        
                        // Icon
                        Image(systemName: iconName)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color.theme.accent)
                    }
                    .scaleEffect(isHovered ? 1.05 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)
                    
                    // Feature text
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color.theme.text)
                        
                        Text(description)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(Color.theme.subtext)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(colorScheme == .dark ? 
                          Color.theme.surface.opacity(0.7) : 
                          Color.theme.surface)
                    .shadow(color: Color.theme.shadow.opacity(isHovered ? 0.2 : 0.1), 
                            radius: isHovered ? 8 : 5, 
                            x: 0, 
                            y: isHovered ? 4 : 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.theme.accent.opacity(isHovered ? 0.2 : 0.05), lineWidth: 1)
                    )
            )
            .onAppear {
                // Create a random delay for hover animation to stagger effects
                DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 0.5...2.5)) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isHovered = true
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            isHovered = false
                        }
                    }
                }
            }
        }
    }
    
    // Feature item model for single source of truth
    struct ProFeatureItem: Identifiable {
        let id = UUID()
        let title: String
        let description: String
        let iconName: String
        let category: String
    }
    
    private var actionButtons: some View {
        VStack(spacing: AppSpacing.m) {
            // Subscribe button with improved styling
            Button {
                purchaseSubscription()
            } label: {
                HStack {
                    Text("Upgrade Now")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(colorScheme == .dark ? .black : .white)
                    
                    Text("• \(price)/month")
                        .font(.system(size: 16))
                        .foregroundColor(colorScheme == .dark ? .black : .white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.m)
                .background(
                    LinearGradient(
                        colors: [Color.theme.accent, Color.theme.accent.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .cornerRadius(14)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(colorScheme == .dark ? Color.black.opacity(0.2) : Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: Color.theme.accent.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(AppScaleButtonStyle())
            .opacity(isAnimating ? 1.0 : 0.0)
            .animation(.easeOut(duration: 0.4).delay(0.8), value: isAnimating)
            
            // Restore button with improved styling
            Button {
                restorePurchases()
            } label: {
                Text("Restore Purchases")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.theme.accent)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.theme.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.theme.accent.opacity(0.3), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(AppScaleButtonStyle())
            .opacity(isAnimating ? 1.0 : 0.0)
            .animation(.easeOut(duration: 0.4).delay(0.9), value: isAnimating)
            
            // Terms and conditions
            Text("Subscription auto-renews until cancelled")
                .font(AppTypography.caption1().bold())
                .foregroundColor(Color.theme.text.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.top, AppSpacing.s)
                .opacity(isAnimating ? 1.0 : 0.0)
                .animation(.easeOut(duration: 0.4).delay(1.0), value: isAnimating)
                
            // Legal text in a card for better visibility
            VStack {
                Text("Payment will be charged to your Apple ID account at confirmation of purchase. Subscription automatically renews unless it is canceled at least 24 hours before the end of the current period. Your account will be charged for renewal within 24 hours prior to the end of the current period. Manage or cancel your subscription in Settings.")
                    .font(AppTypography.caption2())
                    .foregroundColor(Color.theme.text.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(AppSpacing.s)
            }
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.theme.surface)
                    .shadow(color: Color.theme.shadow.opacity(0.05), radius: 3, x: 0, y: 1)
            )
            .padding(.horizontal, AppSpacing.xs)
            .opacity(isAnimating ? 1.0 : 0.0)
            .animation(.easeOut(duration: 0.4).delay(1.1), value: isAnimating)
                
            // Terms and Privacy links
            HStack(spacing: 20) {
                Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                    .font(AppTypography.caption1().bold())
                    .foregroundColor(Color.theme.accent)
                
                Link("Privacy Policy", destination: URL(string: "https://100days.site/privacy")!)
                    .font(AppTypography.caption1().bold())
                    .foregroundColor(Color.theme.accent)
            }
            .padding(.top, AppSpacing.s)
            .padding(.bottom, AppSpacing.m)
            .opacity(isAnimating ? 1.0 : 0.0)
            .animation(.easeOut(duration: 0.4).delay(1.2), value: isAnimating)
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
                    .padding(.bottom, 8)
                
                Text("Processing...")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(AppSpacing.xl)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.7))
                    .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
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