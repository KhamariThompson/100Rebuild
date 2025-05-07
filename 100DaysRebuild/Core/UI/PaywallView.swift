import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var subscriptionService: SubscriptionService
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header & Price
                    headerView
                    
                    // Feature Sections
                    unlockPotentialSection
                    levelUpSection
                    stayMotivatedSection
                    
                    // Subscribe Button
                    subscribeButton
                    
                    // Restore Purchases
                    restorePurchasesButton
                }
                .padding(.bottom, 30)
                .padding(.horizontal)
            }
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.theme.background, Color.theme.background.opacity(0.95)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationBarItems(trailing: Button("Close") {
                dismiss()
            })
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private var headerView: some View {
        VStack(spacing: 12) {
            Text("100Days Pro")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.theme.accent)
                .padding(.top, 24)
            
            Text("$5.99/month")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.theme.text)
                .padding(.bottom, 4)
            
            Text("Cancel anytime")
                .font(.subheadline)
                .foregroundColor(.theme.subtext)
                .padding(.bottom, 16)
        }
    }
    
    private var unlockPotentialSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("🔓 Unlock Your Potential")
                .font(.headline)
                .foregroundColor(.theme.text)
                .padding(.horizontal, 8)
            
            PaywallFeatureCard(
                title: "Unlimited Challenges",
                description: "Track all your habits without limits.",
                checkmark: true
            )
            
            PaywallFeatureCard(
                title: "Advanced Analytics",
                description: "See detailed stats and performance trends.",
                checkmark: true
            )
        }
        .padding(.vertical, 10)
    }
    
    private var levelUpSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("🤝 Level Up Together")
                .font(.headline)
                .foregroundColor(.theme.text)
                .padding(.horizontal, 8)
            
            PaywallFeatureCard(
                title: "Group Challenges",
                description: "Stay accountable by joining challenges with friends.",
                checkmark: true
            )
            
            PaywallFeatureCard(
                title: "Add More Than 5 Friends",
                description: "Expand your network for better support.",
                checkmark: true
            )
        }
        .padding(.vertical, 10)
    }
    
    private var stayMotivatedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("🎯 Stay Motivated")
                .font(.headline)
                .foregroundColor(.theme.text)
                .padding(.horizontal, 8)
            
            PaywallFeatureCard(
                title: "Shareable Milestones",
                description: "Celebrate progress with visual cards.",
                checkmark: true
            )
            
            PaywallFeatureCard(
                title: "No Ads",
                description: "Enjoy a clean and focused experience.",
                checkmark: true
            )
        }
        .padding(.vertical, 10)
    }
    
    private var subscribeButton: some View {
        Button(action: {
            isPurchasing = true
            Task {
                do {
                    try await subscriptionService.purchaseSubscription(plan: .monthly)
                    dismiss()
                } catch {
                    errorMessage = "Failed to purchase: \(error.localizedDescription)"
                    showError = true
                }
                isPurchasing = false
            }
        }) {
            if isPurchasing {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
            } else {
                Text("Subscribe Now")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.theme.accent)
                .shadow(color: Color.theme.accent.opacity(0.3), radius: 8, x: 0, y: 4)
        )
        .disabled(isPurchasing)
        .padding(.top, 16)
    }
    
    private var restorePurchasesButton: some View {
        Button("Restore Purchases") {
            isPurchasing = true
            Task {
                do {
                    try await subscriptionService.purchaseSubscription(plan: .monthly)
                    isPurchasing = false
                    dismiss()
                } catch {
                    errorMessage = "Failed to restore: \(error.localizedDescription)"
                    showError = true
                    isPurchasing = false
                }
            }
        }
        .font(.subheadline)
        .foregroundColor(.theme.accent)
        .padding(.top, 12)
    }
}

struct PaywallFeatureCard: View {
    let title: String
    let description: String
    let checkmark: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if checkmark {
                        Text("✅")
                            .font(.subheadline)
                    }
                    
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.theme.text)
                }
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.theme.subtext)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.theme.surface)
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
}

struct PaywallView_Previews: PreviewProvider {
    static var previews: some View {
        PaywallView()
            .environmentObject(SubscriptionService.shared)
    }
} 