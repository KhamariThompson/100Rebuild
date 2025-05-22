import SwiftUI

/// A standalone tooltip view that can be presented as an overlay
struct TooltipView: View {
    let text: String
    let style: TooltipStyle
    
    init(text: String, style: TooltipStyle = .default) {
        self.text = text
        self.style = style
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Icon if present
            if let icon = style.icon {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(style.iconColor)
                    .padding(.top, 4)
            }
            
            // Text content
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(style.textColor)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: style.cornerRadius)
                .fill(style.backgroundColor)
                .shadow(
                    color: Color.black.opacity(0.15),
                    radius: 8,
                    x: 0,
                    y: 4
                )
        )
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }
}

/// Style configuration for tooltips
struct TooltipStyle {
    let backgroundColor: Color
    let textColor: Color
    let iconColor: Color
    let cornerRadius: CGFloat
    let icon: String?
    
    /// Default tooltip style
    static let `default` = TooltipStyle(
        backgroundColor: Color.theme.accent,
        textColor: .white,
        iconColor: .white,
        cornerRadius: 10,
        icon: nil
    )
    
    /// Info style tooltip with info icon
    static let info = TooltipStyle(
        backgroundColor: Color.theme.accent,
        textColor: .white,
        iconColor: .white,
        cornerRadius: 10,
        icon: "info.circle"
    )
    
    /// Pro feature style tooltip
    static let proFeature = TooltipStyle(
        backgroundColor: Color(hex: "#7D4CDB"), // Purple color for pro features
        textColor: .white,
        iconColor: .white,
        cornerRadius: 10,
        icon: "star.fill"
    )
    
    /// Help style tooltip
    static let help = TooltipStyle(
        backgroundColor: Color.theme.surface,
        textColor: Color.theme.text,
        iconColor: Color.theme.accent,
        cornerRadius: 10,
        icon: "questionmark.circle"
    )
    
    /// Success style tooltip
    static let success = TooltipStyle(
        backgroundColor: Color.theme.success,
        textColor: .white,
        iconColor: .white,
        cornerRadius: 10,
        icon: "checkmark.circle"
    )
    
    /// Warning style tooltip
    static let warning = TooltipStyle(
        backgroundColor: Color.orange,
        textColor: .white,
        iconColor: .white,
        cornerRadius: 10,
        icon: "exclamationmark.triangle"
    )
}

/// A view modifier to apply a tooltip to any view
struct EnhancedTooltipModifier: ViewModifier {
    @State private var showTooltip = false
    let text: String
    let style: TooltipStyle
    let position: TooltipPosition
    let width: CGFloat?
    let dismissOnTap: Bool
    let dismissAfter: Double?
    
    enum TooltipPosition {
        case top, bottom, leading, trailing
    }
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    if showTooltip {
                        tooltipPositionedView(for: geometry)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showTooltip)
                    }
                }
            )
            .onTapGesture {
                withAnimation {
                    if dismissOnTap {
                        showTooltip.toggle()
                    } else {
                        showTooltip = true
                    }
                    
                    // Auto-dismiss if dismissAfter is set
                    if showTooltip, let dismissTime = dismissAfter {
                        DispatchQueue.main.asyncAfter(deadline: .now() + dismissTime) {
                            withAnimation {
                                showTooltip = false
                            }
                        }
                    }
                }
            }
    }
    
    @ViewBuilder
    private func tooltipPositionedView(for geometry: GeometryProxy) -> some View {
        let tooltipView = TooltipView(text: text, style: style)
            .frame(width: width)
        
        switch position {
        case .top:
            VStack {
                tooltipView
                Spacer()
            }
            .frame(width: geometry.size.width)
            .offset(y: -geometry.size.height * 0.1)
            
        case .bottom:
            VStack {
                Spacer()
                tooltipView
            }
            .frame(width: geometry.size.width)
            .offset(y: geometry.size.height * 0.1)
            
        case .leading:
            HStack(alignment: .center) {
                tooltipView
                Spacer()
            }
            .frame(height: geometry.size.height)
            .offset(x: -geometry.size.width * 0.05)
            
        case .trailing:
            HStack(alignment: .center) {
                Spacer()
                tooltipView
            }
            .frame(height: geometry.size.height)
            .offset(x: geometry.size.width * 0.05)
        }
    }
}

/// An extension to present tooltips in a standard way
extension View {
    /// Adds an enhanced tooltip to a view
    /// - Parameters:
    ///   - text: The tooltip text to display
    ///   - style: The style of the tooltip
    ///   - position: The position of the tooltip relative to the view
    ///   - width: Optional fixed width for the tooltip
    ///   - dismissOnTap: Whether the tooltip should be dismissed when tapped
    ///   - dismissAfter: Time in seconds after which the tooltip automatically dismisses
    /// - Returns: A view with a tooltip
    func enhancedTooltip(
        _ text: String,
        style: TooltipStyle = .default,
        position: EnhancedTooltipModifier.TooltipPosition = .bottom,
        width: CGFloat? = nil,
        dismissOnTap: Bool = true,
        dismissAfter: Double? = 3.0
    ) -> some View {
        self.modifier(
            EnhancedTooltipModifier(
                text: text,
                style: style,
                position: position,
                width: width,
                dismissOnTap: dismissOnTap,
                dismissAfter: dismissAfter
            )
        )
    }
}

// Helper to enable Color from hex code for styling tooltips
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Preview
struct TooltipView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            Button("Default Tooltip") { }
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
                .enhancedTooltip("This is a default tooltip")
            
            Button("Info Tooltip") { }
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
                .enhancedTooltip("Here's some helpful information", style: .info)
            
            Button("Pro Feature") { }
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
                .enhancedTooltip("Unlock this with Pro", style: .proFeature)
            
            Button("Help Tooltip") { }
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
                .enhancedTooltip("Need help with this feature?", style: .help, position: .leading)
            
            Button("Warning Tooltip") { }
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
                .enhancedTooltip("This action cannot be undone", style: .warning, position: .trailing)
        }
        .padding(50)
    }
} 