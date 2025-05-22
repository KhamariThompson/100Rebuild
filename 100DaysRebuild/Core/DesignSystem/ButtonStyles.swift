import SwiftUI

/// A button style that applies a subtle scale animation when pressed
public struct AppScaleButtonStyle: ButtonStyle {
    private let scale: CGFloat
    
    public init(scale: CGFloat = 0.97) {
        self.scale = scale
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

/// A primary button style with accent color background - CalAI style
public struct AppPrimaryButtonStyle: ButtonStyle {
    private let cornerRadius: CGFloat
    private let horizontalPadding: CGFloat
    private let verticalPadding: CGFloat
    
    public init(
        cornerRadius: CGFloat = 14, 
        horizontalPadding: CGFloat = AppSpacing.buttonHorizontalPadding,
        verticalPadding: CGFloat = AppSpacing.buttonVerticalPadding
    ) {
        self.cornerRadius = cornerRadius
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.bodyMedium)
            .foregroundColor(.white)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.theme.accent)
                    .shadow(color: Color.theme.accent.opacity(0.15), radius: 4, x: 0, y: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

/// A secondary button style with outline - CalAI style
public struct AppSecondaryButtonStyle: ButtonStyle {
    private let cornerRadius: CGFloat
    private let horizontalPadding: CGFloat
    private let verticalPadding: CGFloat
    
    public init(
        cornerRadius: CGFloat = 14, 
        horizontalPadding: CGFloat = AppSpacing.buttonHorizontalPadding,
        verticalPadding: CGFloat = AppSpacing.buttonVerticalPadding
    ) {
        self.cornerRadius = cornerRadius
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.bodyMedium)
            .foregroundColor(.theme.accent)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.theme.accent, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

/// A minimal text button style - CalAI style
public struct AppTextButtonStyle: ButtonStyle {
    private let color: Color
    
    public init(color: Color = .theme.accent) {
        self.color = color
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.subheadlineMedium)
            .foregroundColor(color)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

/// A bordered button style - CalAI style
public struct AppBorderedButtonStyle: ButtonStyle {
    private let cornerRadius: CGFloat
    private let borderColor: Color
    private let foregroundColor: Color
    private let backgroundColor: Color
    
    public init(
        cornerRadius: CGFloat = 14,
        borderColor: Color = Color.theme.border,
        foregroundColor: Color = Color.theme.text,
        backgroundColor: Color = Color.theme.surface
    ) {
        self.cornerRadius = cornerRadius
        self.borderColor = borderColor
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.bodyMedium)
            .foregroundColor(foregroundColor)
            .padding(.horizontal, AppSpacing.buttonHorizontalPadding)
            .padding(.vertical, AppSpacing.buttonVerticalPadding - 2)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(borderColor, lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
} 