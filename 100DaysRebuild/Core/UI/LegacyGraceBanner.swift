import SwiftUI

/// Banner that shows remaining time in legacy grace period for early users
struct LegacyGraceBanner: View {
    @State private var showBanner = false
    @State private var daysRemaining: Int = 0

    var body: some View {
        VStack {
            if showBanner && daysRemaining > 0 {
                gracePeriodBanner
            }
            Spacer()
        }
        .animation(.easeInOut, value: showBanner)
        .onAppear {
            // Calculate days remaining
            daysRemaining = MigrationManager.shared.daysRemainingInGracePeriod()

            // Show banner with slight delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation {
                    showBanner = true
                }
            }
        }
    }

    private var gracePeriodBanner: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: "gift.fill")
                .font(AppTypography.title3())
                .foregroundColor(.green)

            // Message
            VStack(alignment: .leading, spacing: 2) {
                Text("Early User Benefit")
                    .font(AppTypography.font(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.theme.text)

                Text("You have \(daysRemaining) \(daysRemaining == 1 ? "day" : "days") of free Pro access")
                    .font(AppTypography.font(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(Color.theme.subtext)
            }

            Spacer()

            // Dismiss button
            Button {
                withAnimation {
                    showBanner = false
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(AppTypography.title3())
                    .foregroundColor(Color.theme.subtext.opacity(0.6))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.green.opacity(0.1),
                            Color.blue.opacity(0.08)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.green.opacity(0.3),
                                    Color.blue.opacity(0.2)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.theme.shadow.opacity(0.08), radius: 4, x: 0, y: 2)
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// MARK: - Preview
struct LegacyGraceBanner_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            LegacyGraceBanner()
            Spacer()
        }
        .background(Color.theme.background)
        .preferredColorScheme(.light)
        .previewDisplayName("Light Mode")

        VStack {
            LegacyGraceBanner()
            Spacer()
        }
        .background(Color.theme.background)
        .preferredColorScheme(.dark)
        .previewDisplayName("Dark Mode")
    }
}
