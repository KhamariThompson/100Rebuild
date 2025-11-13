import SwiftUI

/// A banner that shows subscription renewal issues or expiration warnings
struct SubscriptionBanner: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var entitlementsAdapter: EntitlementsAdapter
    @State private var showBanner = false

    var body: some View {
        VStack {
            // Note: subscriptionRenewalIssue and subscriptionExpirationDate removed from SubscriptionStore
            // TODO: Implement via customerInfo if needed
            // if subscriptionStore.state.isProUser && showBanner {
            //     // Billing issue banner would go here
            // }

            Spacer()
        }
        .animation(.easeInOut, value: showBanner)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation {
                    showBanner = true
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SubscriptionRenewalIssue"))) { _ in
            withAnimation {
                showBanner = true
            }
        }
    }
    
    // Banner for billing issues
    private var renewalIssueBanner: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            
            Text("Billing issue detected. Please update your payment method.")
                .font(AppTypography.subhead())
                .foregroundColor(Color.theme.text)
            
            Spacer()
            
            Button {
                if let url = URL(string: "https://apps.apple.com/account/billing") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Fix")
                    .font(.footnote.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.theme.accent)
                    .foregroundColor(Color.white)
                    .cornerRadius(12)
            }
            
            Button {
                withAnimation {
                    showBanner = false
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(Color.theme.subtext)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.theme.surface)
                .shadow(color: Color.theme.shadow.opacity(0.1), radius: 5, x: 0, y: 2)
        )
        .padding(.horizontal)
        .padding(.top, 4)
        .transition(.move(edge: .top))
    }
    
    // Banner for subscription expiration warning
    private func expirationWarningBanner(date: Date) -> some View {
        HStack {
            Image(systemName: "clock.fill")
                .foregroundColor(.yellow)
            
            Text("Your subscription expires on \(formattedDate(date))")
                .font(AppTypography.subhead())
                .foregroundColor(Color.theme.text)
            
            Spacer()
            
            Button {
                withAnimation {
                    showBanner = false
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(Color.theme.subtext)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.theme.surface)
                .shadow(color: Color.theme.shadow.opacity(0.1), radius: 5, x: 0, y: 2)
        )
        .padding(.horizontal)
        .padding(.top, 4)
        .transition(.move(edge: .top))
    }
    
    // Format date to readable string
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

struct SubscriptionBanner_Previews: PreviewProvider {
    static var previews: some View {
        SubscriptionBanner()
            .environmentObject(SubscriptionStore.shared)
            .environmentObject(EntitlementsAdapter.shared)
    }
} 