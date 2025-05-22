import SwiftUI

/// A standardized card component for displaying statistics with a title, value and optional icon.
public struct StatCard: View {
    private let title: String
    private let value: String
    private let icon: String?
    private let color: Color
    private let hasShadow: Bool
    
    /// Initializes a new StatCard
    /// - Parameters:
    ///   - title: The title of the stat (e.g. "Days Complete")
    ///   - value: The value to display (e.g. "42")
    ///   - icon: Optional SF Symbol name (e.g. "calendar")
    ///   - color: Optional accent color (defaults to theme accent)
    ///   - hasShadow: Whether to show card shadow
    public init(
        title: String,
        value: String,
        icon: String? = nil,
        color: Color = Color.theme.accent,
        hasShadow: Bool = true
    ) {
        self.title = title
        self.value = value
        self.icon = icon
        self.color = color
        self.hasShadow = hasShadow
    }
    
    public var body: some View {
        AppComponents.Card(hasShadow: hasShadow) {
            VStack(alignment: .leading, spacing: AppSpacing.itemSpacing) {
                // Title and icon
                HStack(spacing: AppSpacing.xs) {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: AppSpacing.iconSizeSmall))
                            .foregroundColor(color)
                    }
                    
                    Text(title)
                        .font(AppTypography.subheadline)
                        .foregroundColor(Color.theme.subtext)
                }
                
                // Value
                Text(value)
                    .font(AppTypography.title2)
                    .foregroundColor(Color.theme.text)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// A horizontal variant of the stat card for more compact layouts
public struct HorizontalStatCard: View {
    private let title: String
    private let value: String
    private let icon: String?
    private let color: Color
    private let hasShadow: Bool
    
    /// Initializes a new HorizontalStatCard
    /// - Parameters:
    ///   - title: The title of the stat (e.g. "Days Complete")
    ///   - value: The value to display (e.g. "42")
    ///   - icon: Optional SF Symbol name (e.g. "calendar")
    ///   - color: Optional accent color (defaults to theme accent)
    ///   - hasShadow: Whether to show card shadow
    public init(
        title: String,
        value: String,
        icon: String? = nil,
        color: Color = Color.theme.accent,
        hasShadow: Bool = true
    ) {
        self.title = title
        self.value = value
        self.icon = icon
        self.color = color
        self.hasShadow = hasShadow
    }
    
    public var body: some View {
        AppComponents.Card(hasShadow: hasShadow) {
            HStack(spacing: AppSpacing.m) {
                // Icon (if available)
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: AppSpacing.iconSizeMedium))
                        .foregroundColor(color)
                        .frame(width: AppSpacing.iconSizeMedium)
                }
                
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    // Title
                    Text(title)
                        .font(AppTypography.subheadline)
                        .foregroundColor(Color.theme.subtext)
                    
                    // Value
                    Text(value)
                        .font(AppTypography.title2)
                        .foregroundColor(Color.theme.text)
                }
                
                Spacer()
            }
        }
    }
}

/// A circular stat card in CalAI style
public struct CircularStatCard: View {
    private let title: String
    private let value: String
    private let progress: Double?
    private let color: Color
    
    public init(
        title: String,
        value: String,
        progress: Double? = nil,
        color: Color = Color.theme.accent
    ) {
        self.title = title
        self.value = value
        self.progress = progress
        self.color = color
    }
    
    public var body: some View {
        VStack(spacing: AppSpacing.s) {
            // Circular progress if available
            if let progress = progress {
                ZStack {
                    // Background circle
                    Circle()
                        .stroke(
                            color.opacity(0.2),
                            lineWidth: AppSpacing.progressRingStrokeWidth
                        )
                    
                    // Progress circle
                    Circle()
                        .trim(from: 0, to: CGFloat(min(progress, 1.0)))
                        .stroke(
                            color,
                            style: StrokeStyle(
                                lineWidth: AppSpacing.progressRingStrokeWidth,
                                lineCap: .round
                            )
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut, value: progress)
                    
                    // Value text
                    Text(value)
                        .font(.system(size: 22, weight: .medium, design: .rounded))
                        .foregroundColor(.theme.text)
                }
                .frame(width: AppSpacing.circularProgressSizeSmall, height: AppSpacing.circularProgressSizeSmall)
            } else {
                // Just the value if no progress
                Text(value)
                    .font(.system(size: 28, weight: .medium, design: .rounded))
                    .foregroundColor(.theme.text)
            }
            
            // Title
            Text(title)
                .font(.system(size: AppTypography.FontSize.subheadline, weight: .regular, design: .rounded))
                .foregroundColor(Color.theme.subtext)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(minWidth: 100)
        .background(
            RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                .fill(Color.theme.surface)
                .shadow(color: Color.theme.shadow.opacity(0.06), radius: 4, x: 0, y: 1)
        )
    }
}

// MARK: - Preview Provider
struct StatCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: AppSpacing.m) {
            StatCard(
                title: "Total Days",
                value: "87",
                icon: "calendar",
                color: .blue
            )
            
            HorizontalStatCard(
                title: "Completion Rate",
                value: "92%",
                icon: "chart.bar",
                color: .green
            )
            
            CircularStatCard(
                title: "Calories Left",
                value: "1962",
                progress: 0.75,
                color: .orange
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
        .preferredColorScheme(.light)
        .padding()
        
        VStack(spacing: AppSpacing.m) {
            StatCard(
                title: "Total Days",
                value: "87",
                icon: "calendar",
                color: .blue
            )
            
            HorizontalStatCard(
                title: "Completion Rate",
                value: "92%",
                icon: "chart.bar",
                color: .green
            )
            
            CircularStatCard(
                title: "Calories Left",
                value: "1962",
                progress: 0.75,
                color: .orange
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
        .preferredColorScheme(.dark)
        .padding()
    }
} 