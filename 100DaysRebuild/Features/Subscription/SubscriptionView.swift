import SwiftUI

struct SubscriptionView: View {
    @StateObject private var viewModel = SubscriptionViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // Header
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
                    
                    // Features List
                    ForEach(ProFeatureSection.allCases, id: \.self) { section in
                        VStack(alignment: .leading, spacing: 16) {
                            Text(section.rawValue)
                                .font(.headline)
                                .foregroundColor(.theme.text)
                            
                            ForEach(viewModel.features.filter { $0.section == section }) { feature in
                                FeatureRow(feature: feature)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Purchase Button
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
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal)
                    
                    // Restore Purchases
                    Button("Restore Purchases") {
                        Task {
                            await viewModel.restorePurchases()
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.theme.accent)
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
    }
}

private struct FeatureRow: View {
    let feature: ProFeature
    
    var body: some View {
        HStack(spacing: 16) {
            Text(feature.icon)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(feature.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.theme.text)
                
                Text(feature.description)
                    .font(.caption)
                    .foregroundColor(.theme.subtext)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.theme.surface)
        )
    }
}

// Preview provider
struct SubscriptionView_Previews: PreviewProvider {
    static var previews: some View {
        SubscriptionView()
    }
} 