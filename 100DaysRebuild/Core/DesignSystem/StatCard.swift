import SwiftUI

// Text extension for tight text rendering
extension Text {
    func tightText() -> some View {
        self.minimumScaleFactor(0.9)
            .lineLimit(1)
    }
}

/// A standardized card component for displaying statistics with a title, value and optional icon.
public struct StatCard: View {
    private let title: String
    private let value: String
    private let icon: String?
    private let color: Color
    private let hasShadow: Bool
    @Environment(\.colorScheme) private var colorScheme
    
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
        VStack(alignment: .leading, spacing: AppSpacing.itemSpacing) {
            // Title and icon
            HStack(spacing: AppSpacing.xs) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: AppSpacing.iconSizeSmall))
                        .foregroundColor(color)
                }
                
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.theme.subtext)
            }
            
            // Value
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Color.theme.text)
        }
        .padding(CalAISpacing.medium)
        .background(colorScheme == .dark ? Color.theme.surface : Color.white)
        .cornerRadius(CalAIDesignTokens.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: CalAIDesignTokens.cornerRadius)
                .stroke(Color.theme.border.opacity(0.1), lineWidth: 1)
        )
        .if(hasShadow) { view in
            view.shadow(
                color: Color.theme.shadow.opacity(CalAIDesignTokens.shadowOpacitySubtle),
                radius: CalAIDesignTokens.shadowRadiusMedium,
                x: 0,
                y: 4
            )
        }
    }
}

/// A small statistic card that shows a single value with optional subtitle
public struct MiniStatCard: View {
    private let value: String
    private let subtitle: String?
    private let color: Color
    private let hasShadow: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    /// Initializes a new MiniStatCard
    /// - Parameters:
    ///   - value: The main value to display
    ///   - subtitle: Optional subtitle
    ///   - color: Optional accent color
    ///   - hasShadow: Whether to show shadow
    public init(
        value: String,
        subtitle: String? = nil,
        color: Color = Color.theme.accent,
        hasShadow: Bool = true
    ) {
        self.value = value
        self.subtitle = subtitle
        self.color = color
        self.hasShadow = hasShadow
    }
    
    public var body: some View {
        VStack(alignment: .center, spacing: AppSpacing.xs) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color.theme.text)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.theme.subtext)
            }
        }
        .frame(minWidth: 80)
        .padding(CalAISpacing.small)
        .background(colorScheme == .dark ? Color.theme.surface : Color.white)
        .cornerRadius(CalAIDesignTokens.smallRadius)
        .overlay(
            RoundedRectangle(cornerRadius: CalAIDesignTokens.smallRadius)
                .stroke(Color.theme.border.opacity(0.1), lineWidth: 1)
        )
        .if(hasShadow) { view in
            view.shadow(
                color: Color.theme.shadow.opacity(CalAIDesignTokens.shadowOpacitySubtle),
                radius: CalAIDesignTokens.shadowRadiusSubtle,
                x: 0,
                y: 2
            )
        }
    }
}

/// A horizontal stat card for displaying a statistic with icon, title, and value
public struct HorizontalStatCard: View {
    private let title: String
    private let value: String
    private let icon: String?
    private let color: Color
    private let hasShadow: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    /// Initializes a new HorizontalStatCard
    /// - Parameters:
    ///   - title: The title of the stat
    ///   - value: The value to display
    ///   - icon: Optional SF Symbol name
    ///   - color: Optional accent color
    ///   - hasShadow: Whether to show shadow
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
        HStack(spacing: CalAISpacing.medium) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: CalAIDesignTokens.iconSize))
                    .foregroundColor(color)
                    .frame(width: CalAIDesignTokens.iconSize, height: CalAIDesignTokens.iconSize)
            }
            
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.theme.subtext)
                
                Text(value)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color.theme.text)
            }
            
            Spacer()
        }
        .padding(CalAISpacing.medium)
        .background(colorScheme == .dark ? Color.theme.surface : Color.white)
        .cornerRadius(CalAIDesignTokens.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: CalAIDesignTokens.cornerRadius)
                .stroke(Color.theme.border.opacity(0.1), lineWidth: 1)
        )
        .if(hasShadow) { view in
            view.shadow(
                color: Color.theme.shadow.opacity(CalAIDesignTokens.shadowOpacitySubtle),
                radius: CalAIDesignTokens.shadowRadiusMedium,
                x: 0,
                y: 4
            )
        }
    }
}

/// A circular stat card with modern aesthetic
public struct CircularStatCard: View {
    private let title: String
    private let value: String
    private let progress: Double?
    private let color: Color
    @Environment(\.colorScheme) private var colorScheme
    
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
                            color.opacity(0.1),
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
                        .animation(.easeOut(duration: CalAIDesignTokens.progressAnimationDuration), value: progress)
                    
                    // Value text
                    Text(value)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.theme.text)
                        .tightText()
                }
                .frame(width: AppSpacing.circularProgressSizeSmall, height: AppSpacing.circularProgressSizeSmall)
            } else {
                // Just the value if no progress
                Text(value)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.theme.text)
                    .tightText()
            }
            
            // Title
            Text(title)
                .font(.system(size: AppTypography.FontSize.subhead, weight: .medium))
                .foregroundColor(Color.theme.subtext)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(minWidth: 100)
        .background(
            RoundedRectangle(cornerRadius: CalAIDesignTokens.cornerRadius)
                .fill(Color.theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CalAIDesignTokens.cornerRadius)
                .stroke(
                    colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.04),
                    lineWidth: 1
                )
        )
        .cardShadow()
    }
}

// MARK: - View Extension for Conditional Modifiers

extension View {
    /// Applies the given transform if the given condition evaluates to `true`.
    /// - Parameters:
    ///   - condition: The condition to evaluate.
    ///   - transform: The transform to apply to the source `View`.
    /// - Returns: Either the modified or unmodified view, depending on the condition.
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Previews

struct StatCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            StatCard(
                title: "Days Complete",
                value: "42",
                icon: "calendar",
                color: .purple
            )
            
            MiniStatCard(
                value: "87%",
                subtitle: "Completion"
            )
            
            HorizontalStatCard(
                title: "Steps Today",
                value: "8,547",
                icon: "figure.walk"
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
} 