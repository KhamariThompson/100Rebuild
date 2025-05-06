import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var subscriptionService: SubscriptionService
    @State private var selectedPlan: SubscriptionPlan = .monthly
    @State private var isPurchasing = false
    
    enum SubscriptionPlan: String, CaseIterable {
        case monthly = "Monthly"
        
        var price: String {
            return "$5.99"
        }
        
        var savings: String {
            return ""
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    headerView
                    featuresView
                    plansView
                    subscribeButton
                    termsText
                }
                .padding(.bottom)
            }
            .background(Color.theme.background.ignoresSafeArea())
            .navigationBarItems(trailing: Button("Close") {
                dismiss()
            })
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 16) {
            Image(systemName: "crown.fill")
                .font(.system(size: 48))
                .foregroundColor(.theme.accent)
            
            Text("Upgrade to Pro")
                .font(.title)
                .bold()
            
            Text("Unlock all premium features")
                .font(.subheadline)
                .foregroundColor(.theme.subtext)
        }
        .padding(.top, 32)
    }
    
    private var featuresView: some View {
        VStack(alignment: .leading, spacing: 16) {
            FeatureRow(icon: "chart.bar.fill", title: "Advanced Analytics")
            FeatureRow(icon: "bell.fill", title: "Custom Reminders")
            FeatureRow(icon: "calendar", title: "Streak Calendar")
            FeatureRow(icon: "person.2.fill", title: "Social Features")
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.theme.surface)
        )
    }
    
    private var plansView: some View {
        VStack(spacing: 16) {
            ForEach(SubscriptionPlan.allCases, id: \.self) { plan in
                PlanButton(
                    plan: plan,
                    isSelected: selectedPlan == plan,
                    action: { selectedPlan = plan }
                )
            }
        }
        .padding(.horizontal)
    }
    
    private var subscribeButton: some View {
        Button(action: {
            isPurchasing = true
            Task {
                try? await subscriptionService.purchaseSubscription(plan: .monthly)
                isPurchasing = false
            }
        }) {
            if isPurchasing {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            } else {
                Text("Subscribe Now")
                    .font(.headline)
                    .foregroundColor(.white)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.theme.accent)
        )
        .buttonStyle(.primary)
        .padding(.horizontal)
        .disabled(isPurchasing)
    }
    
    private var termsText: some View {
        Text("By subscribing, you agree to our Terms of Service and Privacy Policy")
            .font(.caption)
            .foregroundColor(.theme.subtext)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
    }
}

struct PlanButton: View {
    let plan: PaywallView.SubscriptionPlan
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.rawValue)
                        .font(.headline)
                    
                    if !plan.savings.isEmpty {
                        Text(plan.savings)
                            .font(.caption)
                            .foregroundColor(.theme.accent)
                    }
                }
                
                Spacer()
                
                Text(plan.price)
                    .font(.headline)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.theme.accent.opacity(0.1) : Color.theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.theme.accent : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.scale)
    }
}

struct PaywallView_Previews: PreviewProvider {
    static var previews: some View {
        PaywallView()
            .environmentObject(SubscriptionService.shared)
    }
} 