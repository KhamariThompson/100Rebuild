import SwiftUI
import Foundation

/// Collection of reusable UI components for consistent application styling
public enum AppComponents {
    
    /// Standard card container with shadowed background
    public struct Card<Content: View>: View {
        let content: Content
        private var hasShadow: Bool
        private var cornerRadius: CGFloat
        @Environment(\.colorScheme) private var colorScheme
        
        public init(
            cornerRadius: CGFloat = 16,
            hasShadow: Bool = true,
            @ViewBuilder content: () -> Content
        ) {
            self.content = content()
            self.hasShadow = hasShadow
            self.cornerRadius = cornerRadius
        }
        
        public var body: some View {
            content
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color.theme.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .stroke(Color.theme.border, lineWidth: 1)
                                .opacity(colorScheme == .dark ? 0.3 : 0.1)
                        )
                        .shadow(
                            color: hasShadow ? Color.theme.shadow : .clear,
                            radius: colorScheme == .dark ? 12 : 8,
                            x: 0,
                            y: 4
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
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.theme.surface.opacity(colorScheme == .dark ? 0.4 : 0.8))
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.theme.border, lineWidth: 1)
                        )
                        .shadow(color: Color.theme.shadow, radius: 10, x: 0, y: 4)
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
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(gradient)
                        .shadow(color: Color.theme.shadow, radius: 10, x: 0, y: 4)
                )
        }
    }
    
    /// Divider with standard styling
    public struct AppDivider: View {
        private var color: Color
        private var verticalPadding: CGFloat
        
        public init(color: Color = Color.theme.subtext.opacity(0.3), verticalPadding: CGFloat = 8) {
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
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(style == .outlined ? color : .white)
                .padding(.horizontal, style == .capsule ? 10 : 8)
                .padding(.vertical, 4)
                .background(
                    Group {
                        switch style {
                        case .filled:
                            RoundedRectangle(cornerRadius: 8)
                                .fill(color)
                        case .outlined:
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(color, lineWidth: 1.5)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
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
    
    /// Progress bar with customizable colors
    public struct ProgressBar: View {
        let value: Double
        let color: Color
        let height: CGFloat
        
        public init(
            value: Double,
            color: Color = Color.theme.accent,
            height: CGFloat = 8
        ) {
            self.value = max(0, min(1, value))
            self.color = color
            self.height = height
        }
        
        public var body: some View {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(Color.theme.border)
                        .frame(height: height)
                    
                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(value), height: height)
                }
            }
            .frame(height: height)
        }
    }
} 