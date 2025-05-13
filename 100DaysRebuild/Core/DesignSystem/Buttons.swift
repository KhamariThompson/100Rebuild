import SwiftUI

/// Primary button style with accent color background
public struct PrimaryButtonStyle: ButtonStyle {
    private var isGradient: Bool
    
    public init(isGradient: Bool = true) {
        self.isGradient = isGradient
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .background(
                Group {
                    if isGradient {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(LinearGradient.accent)
                            .shadow(color: Color.theme.accent.opacity(0.4), radius: 8, x: 0, y: 4)
                    } else {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.theme.accent)
                            .shadow(color: Color.theme.accent.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                }
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// Secondary button style with outlined border
public struct SecondaryButtonStyle: ButtonStyle {
    private var hasShadow: Bool
    
    public init(hasShadow: Bool = false) {
        self.hasShadow = hasShadow
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(Color.theme.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.theme.accent, lineWidth: 2)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.theme.surface)
                    )
                    .shadow(color: hasShadow ? Color.theme.shadow : .clear, radius: 8, x: 0, y: 4)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// Glass button style with blur effect
public struct GlassButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    
    public init() {}
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(colorScheme == .dark ? .white : Color.theme.text)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.theme.surface.opacity(colorScheme == .dark ? 0.5 : 0.8))
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.theme.border, lineWidth: 1)
                    )
                    .shadow(color: Color.theme.shadow, radius: 10, x: 0, y: 4)
                    .blur(radius: 0.5)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// Icon button style for circular icon buttons
public struct IconButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    private var hasShadow: Bool
    private var size: CGFloat
    
    public init(hasShadow: Bool = true, size: CGFloat = 44) {
        self.hasShadow = hasShadow
        self.size = size
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.theme.text)
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(Color.theme.surface)
                    .shadow(
                        color: hasShadow ? Color.theme.shadow : .clear,
                        radius: 8, x: 0, y: 3
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// Simple scale effect button style
public struct AppScaleButtonStyle: ButtonStyle {
    public init() {}
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Button Style Extensions
public extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
    static var primarySolid: PrimaryButtonStyle { PrimaryButtonStyle(isGradient: false) }
}

public extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
    static var secondaryWithShadow: SecondaryButtonStyle { SecondaryButtonStyle(hasShadow: true) }
}

public extension ButtonStyle where Self == GlassButtonStyle {
    static var glass: GlassButtonStyle { GlassButtonStyle() }
}

public extension ButtonStyle where Self == IconButtonStyle {
    static var icon: IconButtonStyle { IconButtonStyle() }
    static var iconSmall: IconButtonStyle { IconButtonStyle(size: 36) }
    static var iconLarge: IconButtonStyle { IconButtonStyle(size: 56) }
    static var iconWithoutShadow: IconButtonStyle { IconButtonStyle(hasShadow: false) }
}

public extension ButtonStyle where Self == AppScaleButtonStyle {
    static var scale: AppScaleButtonStyle { AppScaleButtonStyle() }
} 