import SwiftUI

struct SubscriptionView: View {
    @StateObject private var viewModel = SubscriptionViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showMigrationInfo = false
    
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
                    
                    // Restore and Migration
                    subscriptionActionsView
                    
                    // Migration Result
                    if viewModel.migrationCompleted {
                        migrationResultView
                    }
                    
                    // Migration Info Button
                    Button {
                        showMigrationInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                            .foregroundColor(.theme.accent)
                    }
                    .padding(.top, -16)
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
            .alert("About Subscription Migration", isPresented: $showMigrationInfo) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("If you purchased a subscription before logging in, use this feature to transfer it to your account. This ensures your subscription is properly linked to your user profile in our system.")
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
    
    private var subscriptionActionsView: some View {
        HStack(spacing: 20) {
            // Restore Purchases Button
            Button("Restore Purchases") {
                Task {
                    await viewModel.restorePurchases()
                }
            }
            .font(.subheadline)
            .foregroundColor(.theme.accent)
            
            // Migration Button
            Button("Migrate Subscription") {
                Task {
                    await viewModel.migrateAnonymousSubscription()
                }
            }
            .font(.subheadline)
            .foregroundColor(.theme.accent)
            .disabled(viewModel.migrationInProgress)
        }
    }
    
    private var migrationResultView: some View {
        Text(viewModel.migrationResult)
            .font(.caption)
            .foregroundColor(viewModel.migrationResult.contains("Successfully") ? .green : .secondary)
            .padding(.horizontal)
            .padding(.top, -20)
    }
}

struct SubscriptionView_Previews: PreviewProvider {
    static var previews: some View {
        SubscriptionView()
    }
} 