import SwiftUI
import Foundation

/// Feature row component for displaying feature lists
/// Unified design using DS design system
public struct FeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String?
    let iconColor: Color

    // Legacy init for backward compatibility
    public init(icon: String, title: String) {
        self.icon = icon
        self.title = title
        self.subtitle = nil
        self.iconColor = DS.Colors.accent
    }

    // Legacy init with description (maps to subtitle)
    public init(icon: String, title: String, description: String?) {
        self.icon = icon
        self.title = title
        self.subtitle = description
        self.iconColor = DS.Colors.accent
    }

    // New DS-based init with full control
    public init(icon: String, title: String, subtitle: String, iconColor: Color = DS.Colors.accent) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.iconColor = iconColor
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(AppTypography.title2(.semibold))
                .foregroundStyle(iconColor)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(iconColor.opacity(0.15))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AppTypography.headline())
                    .foregroundStyle(DS.Colors.onSurface)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(AppTypography.footnote())
                        .foregroundStyle(DS.Colors.onSurfaceSecondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 6)
    }
} 