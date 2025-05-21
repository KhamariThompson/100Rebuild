import SwiftUI

/// A consistent global header component to be used across the app
/// Provides a standardized header with title, optional trailing icon, and styling
public struct AppHeader: View {
    // Main title to display
    let title: String
    
    // Optional trailing icon (chart, gear, etc.)
    var trailingIcon: (symbol: String, action: () -> Void)?
    
    // Optional subtitle text
    var subtitle: String?
    
    // Optional accent gradient for title
    var accentGradient: LinearGradient?
    
    // Whether to add a shadow to the header (default is false)
    var showShadow: Bool = false
    
    public init(
        title: String,
        subtitle: String? = nil,
        accentGradient: LinearGradient? = nil,
        showShadow: Bool = false,
        trailingIcon: (symbol: String, action: () -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.accentGradient = accentGradient
        self.showShadow = showShadow
        self.trailingIcon = trailingIcon
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .top) {
                // Title with optional gradient
                if let gradient = accentGradient {
                    Text(title)
                        .font(.largeTitle)
                        .fontWeight(.semibold)
                        .foregroundStyle(gradient)
                } else {
                    Text(title)
                        .font(.largeTitle)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.theme.text)
                }
                
                Spacer()
                
                // Optional trailing icon button
                if let icon = trailingIcon {
                    Button(action: icon.action) {
                        Image(systemName: icon.symbol)
                            .font(.system(size: AppSpacing.iconSizeMedium, weight: .semibold))
                            .foregroundColor(.theme.accent)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(AppScaleButtonStyle())
                }
            }
            
            // Optional subtitle
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(Color.theme.subtext)
            }
        }
        .padding(.horizontal, AppSpacing.screenHorizontalPadding)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.theme.background)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

// Sticky header modifier to keep header fixed at the top
public struct StickyHeaderModifier: ViewModifier {
    public func body(content: Content) -> some View {
        VStack(spacing: 0) {
            content
                .frame(maxWidth: .infinity)
                .ignoresSafeArea(edges: .top)
            Spacer()
        }
    }
}

public extension View {
    func stickyHeader() -> some View {
        self.modifier(StickyHeaderModifier())
    }
}

// Preview for the AppHeader
struct AppHeader_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            AppHeader(
                title: "Progress",
                subtitle: "Track your journey",
                accentGradient: LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                trailingIcon: ("chart.bar.fill", { print("Icon tapped") })
            )
            
            Spacer()
        }
        .previewLayout(.sizeThatFits)
        .background(Color.theme.background)
        .preferredColorScheme(.dark)
        
        VStack {
            AppHeader(
                title: "Challenges",
                trailingIcon: ("plus", { print("Add tapped") })
            )
            
            Spacer()
        }
        .previewLayout(.sizeThatFits)
        .background(Color.theme.background)
        .preferredColorScheme(.light)
    }
} 