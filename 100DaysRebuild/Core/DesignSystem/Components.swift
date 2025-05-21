import SwiftUI
import Foundation

/// Collection of reusable UI components for consistent application styling
public enum AppComponents {
    
    /// Standard card container with shadowed background
    public struct Card<Content: View>: View {
        let content: Content
        private var hasShadow: Bool
        private var includeBorder: Bool
        @Environment(\.colorScheme) private var colorScheme
        
        public init(
            hasShadow: Bool = true,
            includeBorder: Bool = false,
            @ViewBuilder content: () -> Content
        ) {
            self.content = content()
            self.hasShadow = hasShadow
            self.includeBorder = includeBorder
        }
        
        public var body: some View {
            content
                .padding(AppSpacing.cardPadding)
                .background(
                    RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                        .fill(Color.theme.surface)
                        .conditionalOverlay(includeBorder) {
                            RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                                .stroke(Color.theme.border, lineWidth: 1)
                                .opacity(colorScheme == .dark ? 0.2 : 0.08)
                        }
                        .shadow(
                            color: hasShadow ? Color.theme.shadow : .clear,
                            radius: colorScheme == .dark ? 8 : 4,
                            x: 0,
                            y: 2
                        )
                )
        }
    }
    
    /// Glass card with blur effect
    public struct GlassCard<Content: View>: View {
        let content: Content
        @Environment(\.colorScheme) private var colorScheme
        
        public init(@ViewBuilder content: () -> Content) {
            self.content = content()
        }
        
        public var body: some View {
            content
                .padding(AppSpacing.cardPadding)
                .background(
                    RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                        .fill(Color.theme.surface.opacity(colorScheme == .dark ? 0.3 : 0.7))
                        .background(
                            RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                                .stroke(Color.theme.border, lineWidth: 1)
                                .opacity(colorScheme == .dark ? 0.2 : 0.08)
                        )
                        .shadow(color: Color.theme.shadow, radius: 6, x: 0, y: 2)
                        .blur(radius: 0.5)
                )
        }
    }
    
    /// Gradient card with custom colors
    public struct GradientCard<Content: View>: View {
        let content: Content
        let gradient: LinearGradient
        
        public init(
            gradient: LinearGradient = .primary,
            @ViewBuilder content: () -> Content
        ) {
            self.content = content()
            self.gradient = gradient
        }
        
        public var body: some View {
            content
                .padding(AppSpacing.cardPadding)
                .background(
                    RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                        .fill(gradient)
                        .shadow(color: Color.theme.shadow, radius: 6, x: 0, y: 2)
                )
        }
    }
    
    /// Divider with standard styling
    public struct AppDivider: View {
        private var color: Color
        private var verticalPadding: CGFloat
        
        public init(color: Color = Color.theme.subtext.opacity(0.2), verticalPadding: CGFloat = 8) {
            self.color = color
            self.verticalPadding = verticalPadding
        }
        
        public var body: some View {
            Divider()
                .background(color)
                .padding(.vertical, verticalPadding)
        }
    }
    
    /// Badge component for status indicators
    public struct Badge: View {
        let text: String
        let color: Color
        let style: BadgeStyle
        
        public enum BadgeStyle {
            case filled
            case outlined
            case capsule
        }
        
        public init(
            text: String,
            color: Color = Color.theme.accent,
            style: BadgeStyle = .filled
        ) {
            self.text = text
            self.color = color
            self.style = style
        }
        
        public var body: some View {
            Text(text)
                .font(AppTypography.caption)
                .fontWeight(.medium)
                .foregroundColor(style == .outlined ? color : .white)
                .padding(.horizontal, style == .capsule ? AppSpacing.xs : AppSpacing.xs)
                .padding(.vertical, AppSpacing.xxs)
                .background(
                    Group {
                        switch style {
                        case .filled:
                            RoundedRectangle(cornerRadius: AppSpacing.xs)
                                .fill(color)
                        case .outlined:
                            RoundedRectangle(cornerRadius: AppSpacing.xs)
                                .stroke(color, lineWidth: 1.5)
                                .background(
                                    RoundedRectangle(cornerRadius: AppSpacing.xs)
                                        .fill(Color.theme.surface)
                                )
                        case .capsule:
                            Capsule()
                                .fill(color)
                        }
                    }
                )
        }
    }
    
    /// Progress bar with customizable colors - minimal CalAI style
    public struct ProgressBar: View {
        let value: Double
        let color: Color
        let height: CGFloat
        let showBackground: Bool
        
        public init(
            value: Double,
            color: Color = Color.theme.accent,
            height: CGFloat = AppSpacing.xs,
            showBackground: Bool = true
        ) {
            self.value = max(0, min(1, value))
            self.color = color
            self.height = height
            self.showBackground = showBackground
        }
        
        public var body: some View {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    if showBackground {
                        RoundedRectangle(cornerRadius: height / 2)
                            .fill(Color.theme.border.opacity(0.3))
                            .frame(height: height)
                    }
                    
                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(value), height: height)
                }
            }
            .frame(height: height)
        }
    }
    
    /// Circular progress ring in CalAI style
    public struct CircularProgressRing: View {
        let progress: Double
        let ringWidth: CGFloat
        let size: CGFloat
        let color: Color
        let backgroundColor: Color
        
        public init(
            progress: Double,
            ringWidth: CGFloat = AppSpacing.progressRingStrokeWidth,
            size: CGFloat = AppSpacing.circularProgressSize,
            color: Color = Color.theme.accent,
            backgroundColor: Color = Color.theme.border.opacity(0.3)
        ) {
            self.progress = max(0, min(1, progress))
            self.ringWidth = ringWidth
            self.size = size
            self.color = color
            self.backgroundColor = backgroundColor
        }
        
        public var body: some View {
            ZStack {
                // Background circle
                Circle()
                    .stroke(lineWidth: ringWidth)
                    .foregroundColor(backgroundColor)
                
                // Progress circle
                Circle()
                    .trim(from: 0, to: CGFloat(progress))
                    .stroke(style: StrokeStyle(
                        lineWidth: ringWidth,
                        lineCap: .round
                    ))
                    .foregroundColor(color)
                    .rotationEffect(Angle(degrees: -90))
                    .animation(.easeInOut(duration: 1.0), value: progress)
            }
            .frame(width: size, height: size)
        }
    }
    
    /// Metric card in CalAI style
    public struct MetricCard<Content: View>: View {
        let title: String
        let value: String
        let content: Content?
        let accentColor: Color
        
        public init(
            title: String,
            value: String,
            accentColor: Color = Color.theme.accent,
            @ViewBuilder content: () -> Content
        ) {
            self.title = title
            self.value = value
            self.content = content()
            self.accentColor = accentColor
        }
        
        public init(
            title: String,
            value: String,
            accentColor: Color = Color.theme.accent
        ) where Content == EmptyView {
            self.title = title
            self.value = value
            self.content = nil
            self.accentColor = accentColor
        }
        
        public var body: some View {
            VStack(alignment: .center, spacing: AppSpacing.xs) {
                // Title
                Text(title)
                    .font(AppTypography.caption)
                    .foregroundColor(Color.theme.subtext)
                
                // Value
                Text(value)
                    .font(.system(size: 28, weight: .medium, design: .rounded))
                    .foregroundColor(Color.theme.text)
                
                // Optional content
                if let content = content {
                    content
                }
            }
            .frame(maxWidth: .infinity)
            .padding(AppSpacing.m)
            .background(
                RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                    .fill(Color.theme.surface)
                    .shadow(color: Color.theme.shadow, radius: 4, x: 0, y: 1)
            )
        }
    }
} 