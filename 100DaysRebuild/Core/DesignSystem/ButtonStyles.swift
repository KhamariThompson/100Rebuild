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

/// A primary button style with accent color background
public struct AppPrimaryButtonStyle: ButtonStyle {
    private let cornerRadius: CGFloat
    private let horizontalPadding: CGFloat
    private let verticalPadding: CGFloat
    
    public init(
        cornerRadius: CGFloat = AppSpacing.cardCornerRadius, 
        horizontalPadding: CGFloat = AppSpacing.buttonHorizontalPadding,
        verticalPadding: CGFloat = AppSpacing.buttonVerticalPadding
    ) {
        self.cornerRadius = cornerRadius
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.headline)
            .foregroundColor(.white)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.theme.accent)
                    .shadow(color: Color.theme.accent.opacity(0.3), radius: 5, x: 0, y: 2)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

/// A secondary button style with outline
public struct AppSecondaryButtonStyle: ButtonStyle {
    private let cornerRadius: CGFloat
    private let horizontalPadding: CGFloat
    private let verticalPadding: CGFloat
    
    public init(
        cornerRadius: CGFloat = AppSpacing.cardCornerRadius, 
        horizontalPadding: CGFloat = AppSpacing.buttonHorizontalPadding,
        verticalPadding: CGFloat = AppSpacing.buttonVerticalPadding
    ) {
        self.cornerRadius = cornerRadius
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.headline)
            .foregroundColor(.theme.accent)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.theme.accent, lineWidth: 1.5)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

/// A minimal text button style
public struct AppTextButtonStyle: ButtonStyle {
    private let color: Color
    
    public init(color: Color = .theme.accent) {
        self.color = color
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.subheadline)
            .foregroundColor(color)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
} 