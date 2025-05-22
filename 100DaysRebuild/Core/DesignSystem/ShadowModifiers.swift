import SwiftUI

/// A collection of shadow styles for creating consistent elevation in the UI
public enum ShadowStyle {
    /// Subtle shadow for card elements
    case card
    /// Medium shadow for elevated content
    case elevated
    /// Strong shadow for floating elements
    case floating
    /// Custom shadow with specific parameters
    case custom(radius: CGFloat, y: CGFloat, opacity: Double)
    
    /// Get the shadow radius for this style
    public var radius: CGFloat {
        switch self {
        case .card: return 10
        case .elevated: return 16
        case .floating: return 24
        case .custom(let radius, _, _): return radius
        }
    }
    
    /// Get the y-offset for this style
    public var yOffset: CGFloat {
        switch self {
        case .card: return 4
        case .elevated: return 8
        case .floating: return 12
        case .custom(_, let y, _): return y
        }
    }
    
    /// Get the opacity for this style
    public var opacity: Double {
        switch self {
        case .card: return 0.06
        case .elevated: return 0.08
        case .floating: return 0.12
        case .custom(_, _, let opacity): return opacity
        }
    }
}

/// A modifier that applies a shadow to a view
public struct ShadowModifier: ViewModifier {
    private let style: ShadowStyle
    
    /// Initialize with a shadow style
    /// - Parameter style: The shadow style to apply
    public init(style: ShadowStyle) {
        self.style = style
    }
    
    public func body(content: Content) -> some View {
        content
            .shadow(
                color: Color.theme.shadow.opacity(style.opacity),
                radius: style.radius,
                x: 0,
                y: style.yOffset
            )
    }
}

/// A modifier that applies a card-like appearance with shadow and background
public struct CardModifier: ViewModifier {
    private let cornerRadius: CGFloat
    private let shadowStyle: ShadowStyle
    
    /// Initialize with a corner radius and shadow style
    /// - Parameters:
    ///   - cornerRadius: The corner radius for the card
    ///   - shadowStyle: The shadow style to apply
    public init(cornerRadius: CGFloat = 12, shadowStyle: ShadowStyle = .card) {
        self.cornerRadius = cornerRadius
        self.shadowStyle = shadowStyle
    }
    
    public func body(content: Content) -> some View {
        content
            .background(Color.theme.surface)
            .cornerRadius(cornerRadius)
            .modifier(ShadowModifier(style: shadowStyle))
    }
}

/// View modifiers for applying consistent shadows
public extension View {
    /// Apply a shadow style to a view
    /// - Parameter style: The shadow style to apply
    /// - Returns: A view with the shadow applied
    func applyShadow(_ style: ShadowStyle) -> some View {
        self.modifier(ShadowModifier(style: style))
    }
    
    /// Apply a card style to a view
    /// - Parameters:
    ///   - cornerRadius: The corner radius for the card
    ///   - shadowStyle: The shadow style to apply
    /// - Returns: A view with the card style applied
    func cardStyle(cornerRadius: CGFloat = 12, shadowStyle: ShadowStyle = .card) -> some View {
        self.modifier(CardModifier(cornerRadius: cornerRadius, shadowStyle: shadowStyle))
    }
    
    /// Apply a subtle shadow suitable for card elements
    /// - Returns: A view with a subtle shadow
    func cardShadow() -> some View {
        self.applyShadow(.card)
    }
    
    /// Apply a medium shadow suitable for elevated content
    /// - Returns: A view with a medium shadow
    func elevatedShadow() -> some View {
        self.applyShadow(.elevated)
    }
    
    /// Apply a strong shadow suitable for floating elements
    /// - Returns: A view with a strong shadow
    func floatingShadow() -> some View {
        self.applyShadow(.floating)
    }
    
    /// Apply a custom shadow with specific parameters
    /// - Parameters:
    ///   - radius: The shadow radius
    ///   - y: The shadow y-offset
    ///   - opacity: The shadow opacity
    /// - Returns: A view with a custom shadow
    func customShadow(radius: CGFloat, y: CGFloat, opacity: Double) -> some View {
        self.applyShadow(.custom(radius: radius, y: y, opacity: opacity))
    }
    
    /// Apply a clean, minimal card style with subtle shadow
    func minimalCard(cornerRadius: CGFloat = 12) -> some View {
        self
            .padding()
            .background(Color.theme.surface)
            .cornerRadius(cornerRadius)
            .cardShadow()
    }
    
    /// Apply a clean, modern elevated style for important UI elements
    func modernElevated(cornerRadius: CGFloat = 12) -> some View {
        self
            .padding()
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.theme.surface)
            )
            .elevatedShadow()
    }
    
    /// Apply a subtle inner shadow effect (for pressed states)
    func innerShadow(radius: CGFloat = 2, opacity: Double = 0.1) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.theme.shadow.opacity(opacity), lineWidth: 1)
                .blur(radius: radius)
                .mask(RoundedRectangle(cornerRadius: 12).fill(LinearGradient(
                    gradient: Gradient(colors: [Color.black, Color.clear]),
                    startPoint: .top,
                    endPoint: .bottom
                )))
                .padding(-1)
        )
    }
} 