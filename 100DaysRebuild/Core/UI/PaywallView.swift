import SwiftUI
import RevenueCat
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var subscriptionService: SubscriptionService
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var offering: Offering?
    @State private var monthlyPackage: Package?
    @State private var price: String = "$5.99" // Default fallback price
    @State private var offeringsFailedToLoad = false
    
    // Animation states
    @State private var animateContent = false
    @State private var headerScale: CGFloat = 0.9
    @State private var opacity: CGFloat = 0
    @State private var offset: CGFloat = 20
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.theme.background,
                    Color.theme.background.opacity(0.95)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Content
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerView
                        .scaleEffect(animateContent ? 1.0 : headerScale)
                        .opacity(animateContent ? 1.0 : opacity)
                    
                    if offeringsFailedToLoad {
                        offeringsFailedView
                            .offset(y: animateContent ? 0 : offset)
                            .opacity(animateContent ? 1.0 : opacity)
                    } else {
                        // Feature sections with staggered animation
                        VStack(spacing: 32) {
                            unlockPotentialSection
                                .offset(y: animateContent ? 0 : offset)
                                .opacity(animateContent ? 1.0 : opacity)
                            
                            levelUpSection
                                .offset(y: animateContent ? 0 : offset * 1.5)
                                .opacity(animateContent ? 1.0 : opacity)
                            
                            stayMotivatedSection
                                .offset(y: animateContent ? 0 : offset * 2)
                                .opacity(animateContent ? 1.0 : opacity)
                        }
                        .padding(.top)
                    }
                    
                    // Pricing & Subscribe
                    VStack(spacing: 8) {
                        subscribeButton
                            .offset(y: animateContent ? 0 : offset * 2.5)
                            .opacity(animateContent ? 1.0 : opacity)
                        
                        restorePurchasesButton
                            .offset(y: animateContent ? 0 : offset * 2.5)
                            .opacity(animateContent ? 1.0 : opacity)
                    }
                    .padding(.top)
                }
                .padding()
            }
            
            // Close button
            VStack {
                HStack {
                    Spacer()
                    
                    Button(action: { dismiss() }) {
                        ZStack {
                            Circle()
                                .fill(Color.theme.surface.opacity(0.8))
                                .frame(width: 36, height: 36)
                                .shadow(color: Color.theme.shadow.opacity(0.2), radius: 4, x: 0, y: 2)
                            
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color.theme.text)
                        }
                    }
                    .buttonStyle(.scale)
                    .padding()
                }
                
                Spacer()
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            // Check subscription service error status first
            if subscriptionService.errorLoadingOfferings {
                offeringsFailedToLoad = true
                Task {
                    await loadFallbackPricing()
                }
            } else {
                loadOffering()
            }
            
            // Animate content appearance
            withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
                animateContent = true
            }
        }
    }
    
    private func loadOffering() {
        Task {
            do {
                // Reset state
                self.offering = nil 
                self.monthlyPackage = nil
                
                // Check subscription service for existing offerings status
                if subscriptionService.errorLoadingOfferings {
                    self.offeringsFailedToLoad = true
                    await loadFallbackPricing()
                    return
                }
                
                // Fetch offerings from RevenueCat
                print("Fetching RevenueCat offerings...")
                let offerings = try await Purchases.shared.offerings()
                
                // Get the default offering
                if let currentOffering = offerings.current {
                    print("Found current offering: \(currentOffering.identifier)")
                    
                    await MainActor.run {
                        self.offering = currentOffering
                        self.offeringsFailedToLoad = false
                        
                        // Find monthly package
                        if let monthlyPkg = currentOffering.availablePackages.first(where: { $0.packageType == .monthly }) {
                            print("Found monthly package: \(monthlyPkg.identifier) with price: \(monthlyPkg.localizedPriceString)")
                            self.monthlyPackage = monthlyPkg
                            self.price = monthlyPkg.localizedPriceString
                        } else {
                            print("No monthly package found in offering")
                            self.offeringsFailedToLoad = true
                            // Use fallback pricing since no monthly package was found
                            Task {
                                await loadFallbackPricing()
                            }
                        }
                    }
                } else {
                    print("No current offering available from RevenueCat")
                    await MainActor.run {
                        self.offeringsFailedToLoad = true
                    }
                    errorMessage = "Could not load subscription options. Please try again later."
                    showError = true
                    
                    // Try fetching StoreKit products as fallback
                    await loadFallbackPricing()
                }
            } catch {
                print("Failed to load offerings: \(error.localizedDescription)")
                await MainActor.run {
                    self.offeringsFailedToLoad = true
                }
                errorMessage = "Failed to load subscription options: \(error.localizedDescription)"
                showError = true
                
                // Try fetching StoreKit products as fallback
                await loadFallbackPricing()
            }
        }
    }
    
    private func loadFallbackPricing() async {
        // Try fetching StoreKit products directly as fallback
        do {
            let products = try await Product.products(for: ["com.KhamariThompson.100Days.monthly"])
            if let monthlyProduct = products.first {
                print("Loaded fallback product from StoreKit: \(monthlyProduct.id) - \(monthlyProduct.displayPrice)")
                
                await MainActor.run {
                    self.price = monthlyProduct.displayPrice
                }
            } else {
                print("No products found in StoreKit fallback")
                
                await MainActor.run {
                    // Use hardcoded fallback price
                    self.price = "$5.99"
                }
            }
        } catch {
            print("Failed to load StoreKit products as fallback: \(error.localizedDescription)")
            
            await MainActor.run {
                // Use hardcoded fallback price
                self.price = "$5.99"
            }
        }
    }
    
    // View shown when offerings fail to load
    private var offeringsFailedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.yellow)
                .padding(.bottom, 10)
            
            Text("Subscription Information Unavailable")
                .font(.title3)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text("We're having trouble connecting to our subscription service. You can still try to purchase or restore a subscription, or check back later.")
                .font(.subheadline)
                .foregroundColor(.theme.subtext)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Key features list
            VStack(alignment: .leading, spacing: 12) {
                FailbackFeatureRow(text: "Unlimited Challenges", icon: "infinity")
                FailbackFeatureRow(text: "Advanced Analytics", icon: "chart.bar.xaxis")
                FailbackFeatureRow(text: "Group Challenges", icon: "person.2")
                FailbackFeatureRow(text: "No Ads", icon: "hand.raised")
            }
            .padding()
            .background(Color.theme.surface.opacity(0.5))
            .cornerRadius(12)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
    
    // Fallback feature row
    private struct FailbackFeatureRow: View {
        let text: String
        let icon: String
        
        var body: some View {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(.theme.accent)
                    .frame(width: 24)
                
                Text(text)
                    .font(.subheadline)
                    .foregroundColor(.theme.text)
                
                Spacer()
                
                Image(systemName: "checkmark")
                    .font(.footnote)
                    .foregroundColor(.green)
            }
        }
    }
    
    // Header with app icon and title
    private var headerView: some View {
        VStack(spacing: 16) {
            // Use our new image extension for proper fallback
            Image.appIconWithFallback(size: 80)
            
            Text("Upgrade to Pro")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.theme.text)
            
            Text("Unlock all features and get the most out of your experience")
                .font(.system(size: 16))
                .foregroundColor(.theme.subtext)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Text(price + " / Month")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.theme.accent)
                .padding(.top, 4)
        }
    }
    
    private var unlockPotentialSection: some View {
        VStack(alignment: .leading, spacing: 16) {
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
        VStack(alignment: .leading, spacing: 16) {
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
        VStack(alignment: .leading, spacing: 16) {
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
    
    private var subscribeButton: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            
            isPurchasing = true
            Task {
                do {
                    if let monthlyPackage = monthlyPackage {
                        // Use RevenueCat package if available
                        print("Purchasing package using RevenueCat: \(monthlyPackage.identifier)")
                        let result = try await Purchases.shared.purchase(package: monthlyPackage)
                        // Success if pro entitlement is active
                        if result.customerInfo.entitlements["pro"]?.isActive == true {
                            print("Purchase successful - Pro entitlement is active")
                            await subscriptionService.refreshSubscriptionStatus()
                            dismiss()
                        } else {
                            print("Purchase completed but Pro entitlement is not active")
                            errorMessage = "Purchase completed but Pro entitlement is not active. Please try restoring purchases."
                            showError = true
                        }
                    } else {
                        // Fallback to SubscriptionService
                        print("Using SubscriptionService fallback for purchase")
                        try await subscriptionService.purchaseSubscription(plan: .monthly)
                        await subscriptionService.refreshSubscriptionStatus()
                        dismiss()
                    }
                } catch {
                    print("Purchase failed: \(error.localizedDescription)")
                    errorMessage = "Failed to purchase: \(error.localizedDescription)"
                    showError = true
                }
                isPurchasing = false
            }
        }) {
            if isPurchasing {
                HStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text("Processing...")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
            } else {
                Text(offeringsFailedToLoad ? "Subscriptions Unavailable" : "Subscribe Now")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
            }
        }
        .buttonStyle(.primary)
        .disabled(isPurchasing || offeringsFailedToLoad || !subscriptionService.isPurchasingEnabled)
        .overlay(
            Group {
                if offeringsFailedToLoad || !subscriptionService.isPurchasingEnabled {
                    Text(offeringsFailedToLoad ? "Subscriptions unavailable. Please try again later." : "Subscriptions coming soon")
                        .font(.caption)
                        .foregroundColor(.theme.subtext)
                        .padding(.horizontal, 4)
                        .padding(.top, 2)
                        .frame(maxWidth: .infinity)
                        .offset(y: 32)
                }
            }
        )
    }
    
    private var restorePurchasesButton: some View {
        Button(action: {
            isPurchasing = true
            Task {
                do {
                    print("Restoring purchases...")
                    try await subscriptionService.restorePurchases()
                    
                    // Refresh subscription status
                    await subscriptionService.refreshSubscriptionStatus()
                    
                    // Check if Pro was successfully restored
                    if subscriptionService.isProUser {
                        print("Restore successful - Pro status activated")
                        dismiss()
                    } else {
                        print("No purchases found to restore")
                        errorMessage = "No previous purchases found"
                        showError = true
                    }
                } catch {
                    print("Restore failed: \(error.localizedDescription)")
                    errorMessage = "Failed to restore: \(error.localizedDescription)"
                    showError = true
                }
                isPurchasing = false
            }
        }) {
            HStack(spacing: 8) {
                if isPurchasing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color.theme.accent))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.footnote)
                }
                Text("Restore Purchases")
                    .font(.subheadline)
            }
            .foregroundColor(.theme.accent)
        }
        .buttonStyle(.scale)
        .padding(.vertical, 8)
        .disabled(isPurchasing)
    }
}

// MARK: - Supporting Views

struct SectionHeader: View {
    let icon: String
    let title: String
    
    var body: some View {
        HStack(spacing: 10) {
            Text(icon)
                .font(.system(size: 22))
            
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.theme.text)
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 4)
    }
}

struct PaywallFeatureCard: View {
    let title: String
    let description: String
    let iconName: String
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            // Feature icon
            ZStack {
                Circle()
                    .fill(Color.theme.accent.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color.theme.accent)
            }
            
            // Feature text
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.theme.text)
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.theme.subtext)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Checkmark
            Image(systemName: "checkmark")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.theme.accent)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 18)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.theme.surface)
                .shadow(color: Color.theme.shadow.opacity(0.1), radius: 8, x: 0, y: 2)
        )
        .accessibilityElement(children: .combine)
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