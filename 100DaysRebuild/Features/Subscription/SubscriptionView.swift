import SwiftUI

struct SubscriptionView: View {
    @StateObject private var viewModel = SubscriptionViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    headerView
                    
                    // Features List
                    featuresListView
                    
                    // Purchase Button
                    purchaseButtonView
                    
                    // Restore Purchases
                    restorePurchasesButton
                }
            }
            .navigationBarItems(trailing: Button("Close") {
                dismiss()
            })
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private var headerView: some View {
        VStack(spacing: 16) {
            Text("Unlock Pro Features")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.theme.text)
            
            Text("Take your journey to the next level")
                .font(.subheadline)
                .foregroundColor(.theme.subtext)
                .multilineTextAlignment(.center)
        }
        .padding(.top)
    }
    
    private var featuresListView: some View {
        ForEach(ProFeatureSection.allCases, id: \.self) { section in
            featureSectionView(for: section)
        }
    }
    
    private func featureSectionView(for section: ProFeatureSection) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(section.rawValue)
                .font(.headline)
                .foregroundColor(.theme.text)
            
            ForEach(viewModel.features.filter { $0.section == section }) { feature in
                FeatureRow(icon: feature.icon, title: feature.title, description: feature.description)
            }
        }
        .padding(.horizontal)
    }
    
    private var purchaseButtonView: some View {
        Button(action: {
            Task {
                await viewModel.purchase()
            }
        }) {
            if viewModel.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            } else {
                Text("Upgrade to Pro")
                    .font(.headline)
            }
        }
        .buttonStyle(AppPrimaryButtonStyle())
        .padding(.horizontal)
    }
    
    private var restorePurchasesButton: some View {
        Button("Restore Purchases") {
            Task {
                await viewModel.restorePurchases()
            }
        }
        .font(.subheadline)
        .foregroundColor(.theme.accent)
    }
}

struct SubscriptionView_Previews: PreviewProvider {
    static var previews: some View {
        SubscriptionView()
    }
} 