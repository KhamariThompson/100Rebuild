import SwiftUI

/// Reusable plan selection row for paywall
struct PriceOptionRow: View {
    let plan: SubscriptionPlan
    let isSelected: Bool
    let productInfo: ProductInfo?
    let showIntroOffer: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.md) {
                // Selection indicator
                DS.Icon(
                    isSelected ? "checkmark.circle.fill" : "circle",
                    size: 24,
                    color: isSelected ? DS.Colors.accent : DS.Colors.onSurfaceSecondary
                )

                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    // Plan name + badge
                    HStack(spacing: DS.Spacing.xs) {
                        Text(plan.displayName)
                            .font(AppTypography.headline())
                            .foregroundStyle(DS.Colors.onSurface)

                        if let badge = plan.highlightBadge {
                            Text(badge)
                                .font(AppTypography.caption1())
                                .foregroundStyle(.white)
                                .padding(.horizontal, DS.Spacing.xs)
                                .padding(.vertical, 2)
                                .background(DS.Colors.accent)
                                .clipShape(Capsule())
                        }
                    }

                    // Price
                    if showIntroOffer, let introPrice = productInfo?.introOfferPrice {
                        // Show intro offer pricing
                        Text(introPrice)
                            .font(AppTypography.body(.semibold))
                            .foregroundStyle(DS.Colors.accent)

                        Text("Then \(productInfo?.displayPrice ?? plan.displayPrice)")
                            .font(AppTypography.caption1())
                            .foregroundStyle(DS.Colors.onSurfaceSecondary)
                    } else {
                        // Show standard pricing
                        Text(productInfo?.displayPrice ?? plan.displayPrice)
                            .font(AppTypography.body())
                            .foregroundStyle(DS.Colors.onSurface)

                        if plan == .annual {
                            Text("Best value for long-term commitment")
                                .font(AppTypography.caption1())
                                .foregroundStyle(DS.Colors.onSurfaceSecondary)
                        }
                    }
                }

                Spacer()
            }
            .padding(DS.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DS.Spacing.cardCornerRadius)
                    .fill(DS.Colors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Spacing.cardCornerRadius)
                            .stroke(
                                isSelected ? DS.Colors.accent : DS.Colors.border,
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(plan.displayName) plan, \(productInfo?.displayPrice ?? plan.displayPrice)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Preview

struct PriceOptionRow_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: DS.Spacing.md) {
            PriceOptionRow(
                plan: .annual,
                isSelected: true,
                productInfo: ProductInfo(
                    productId: Constants.ProductID.annualIntro,
                    displayPrice: "$29.99/year",
                    localizedDescription: "Annual subscription",
                    hasIntroOffer: true,
                    introOfferPrice: "$19.99 for first year",
                    introOfferPeriod: "1 year"
                ),
                showIntroOffer: true
            ) {}

            PriceOptionRow(
                plan: .monthly,
                isSelected: false,
                productInfo: ProductInfo(
                    productId: Constants.ProductID.monthly,
                    displayPrice: "$14.99/month",
                    localizedDescription: "Monthly subscription",
                    hasIntroOffer: false,
                    introOfferPrice: nil,
                    introOfferPeriod: nil
                ),
                showIntroOffer: false
            ) {}
        }
        .padding()
        .background(DS.Colors.background)
    }
}
