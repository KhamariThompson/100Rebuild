import SwiftUI

/// A button style that applies a subtle scale animation when pressed
public struct AppScaleButtonStyle: ButtonStyle {
    private let scale: CGFloat
    
    public init(scale: CGFloat = 0.95) {
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
        horizontalPadding: CGFloat = 20,
        verticalPadding: CGFloat = 14
    ) {
        self.cornerRadius = cornerRadius
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.body(.medium))
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
        horizontalPadding: CGFloat = 20,
        verticalPadding: CGFloat = 14
    ) {
        self.cornerRadius = cornerRadius
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.body(.medium))
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
            .font(AppTypography.subhead(.medium))
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
            .font(AppTypography.body(.medium))
            .foregroundColor(foregroundColor)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
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

// MARK: - Button Styles

/// Primary button style - used for main CTAs
public struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme
    
    private let height: CGFloat
    
    public init(height: CGFloat = 44) {
        self.height = height
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .medium))
            .frame(maxWidth: .infinity, minHeight: height)
            .foregroundColor(isEnabled ? .white : .white.opacity(0.7))
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isEnabled 
                          ? Color.theme.accent
                          : Color.theme.accent.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.theme.border.opacity(colorScheme == .dark ? 0.3 : 0.1), lineWidth: 1)
            )
            .shadow(
                color: Color.theme.shadow.opacity(isEnabled ? 0.1 : 0.05),
                radius: 8,
                x: 0,
                y: 4
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

/// Secondary button style - used for secondary actions
public struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme
    
    private let height: CGFloat
    
    public init(height: CGFloat = 44) {
        self.height = height
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .medium))
            .frame(maxWidth: .infinity, minHeight: height)
            .foregroundColor(isEnabled ? Color.theme.text : Color.theme.text.opacity(0.5))
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color.theme.surface : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.theme.border.opacity(0.5), lineWidth: 1)
            )
            .shadow(
                color: Color.theme.shadow.opacity(isEnabled ? 0.06 : 0.03),
                radius: 6,
                x: 0,
                y: 3
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

/// Text button style - used for text-only buttons
public struct TextButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    
    private let fontSize: CGFloat
    private let fontWeight: Font.Weight
    
    public init(fontSize: CGFloat = 16, fontWeight: Font.Weight = .medium) {
        self.fontSize = fontSize
        self.fontWeight = fontWeight
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: fontSize, weight: fontWeight))
            .foregroundColor(isEnabled ? Color.theme.accent : Color.theme.accent.opacity(0.5))
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

/// Icon button style - used for icon-only buttons
public struct IconButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme
    
    private let size: CGFloat
    private let backgroundColor: Color?
    
    public init(size: CGFloat = 44, backgroundColor: Color? = nil) {
        self.size = size
        self.backgroundColor = backgroundColor
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(backgroundColor ?? (colorScheme == .dark ? Color.theme.surface : Color.white))
                    .shadow(color: Color.theme.shadow.opacity(0.06), radius: 8, x: 0, y: 4)
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1.0) : 0.5)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

/// Minimal chrome-like button style - used for modern minimal buttons
public struct ChromeButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme
    
    private let height: CGFloat
    
    public init(height: CGFloat = 44) {
        self.height = height
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .medium))
            .frame(maxWidth: .infinity, minHeight: height)
            .foregroundColor(isEnabled ? Color.theme.text : Color.theme.text.opacity(0.6))
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        colorScheme == .dark
                        ? LinearGradient.darkChrome
                        : LinearGradient.chrome
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        colorScheme == .dark 
                        ? Color.white.opacity(0.2) 
                        : Color.black.opacity(0.08),
                        lineWidth: 1
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .shadow(
                color: Color.theme.shadow.opacity(configuration.isPressed ? 0.0 : 0.1),
                radius: 5,
                x: 0,
                y: 2
            )
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
            .animation(.easeInOut(duration: 0.2), value: isEnabled)
    }
}

// MARK: - Button Style Extensions
public extension View {
    /// Apply the primary button style
    func primaryButtonStyle(height: CGFloat = 44) -> some View {
        self.buttonStyle(PrimaryButtonStyle(height: height))
    }
    
    /// Apply the secondary button style
    func secondaryButtonStyle(height: CGFloat = 44) -> some View {
        self.buttonStyle(SecondaryButtonStyle(height: height))
    }
    
    /// Apply the text button style
    func textButtonStyle(fontSize: CGFloat = 16, fontWeight: Font.Weight = .medium) -> some View {
        self.buttonStyle(TextButtonStyle(fontSize: fontSize, fontWeight: fontWeight))
    }
    
    /// Apply the icon button style
    func iconButtonStyle(size: CGFloat = 44, backgroundColor: Color? = nil) -> some View {
        self.buttonStyle(IconButtonStyle(size: size, backgroundColor: backgroundColor))
    }
    
    /// Apply the chrome button style
    func chromeButtonStyle(height: CGFloat = 44) -> some View {
        self.buttonStyle(ChromeButtonStyle(height: height))
    }
}

// MARK: - Button Modifiers
public extension View {
    /// Add a standard button frame with the specified height
    func buttonFrame(height: CGFloat = 44) -> some View {
        self
            .frame(maxWidth: .infinity, minHeight: height)
    }
    
    /// Apply a card-like style to a button (for use with buttonStyle)
    func buttonCard(cornerRadius: CGFloat = 12) -> some View {
        self
            .background(Color.theme.surface)
            .cornerRadius(cornerRadius)
            .cardShadow()
    }
} 