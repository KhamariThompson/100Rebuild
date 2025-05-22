import SwiftUI

/// Design tokens for consistent styling across the app
/// Updated to match landing page aesthetic
public enum CalAIDesignTokens {
    // MARK: - Radii
    
    /// Standard corner radius for most elements
    public static let cornerRadius: CGFloat = 12
    
    /// Button corner radius
    public static let buttonRadius: CGFloat = 12
    
    /// Small corner radius for minor elements
    public static let smallRadius: CGFloat = 8
    
    // MARK: - Spacing
    
    /// Standard card padding
    public static let cardPadding: CGFloat = 16
    
    /// Screen edge padding
    public static let screenPadding: CGFloat = 16
    
    /// Item spacing in lists
    public static let listSpacing: CGFloat = 16
    
    /// Extra small spacing - for tight elements
    public static let spacingXS: CGFloat = 4
    
    /// Small spacing - for related elements
    public static let spacingS: CGFloat = 8
    
    /// Medium spacing - standard spacing between elements
    public static let spacingM: CGFloat = 16
    
    /// Large spacing - for section separation
    public static let spacingL: CGFloat = 24
    
    /// Extra large spacing - for major section separation
    public static let spacingXL: CGFloat = 32
    
    /// Double extra large spacing - for very significant separation
    public static let spacingXXL: CGFloat = 48
    
    // MARK: - Component Sizes
    
    /// Standard button height
    public static let buttonHeight: CGFloat = 52
    
    /// Standard input field height
    public static let inputHeight: CGFloat = 52
    
    /// Tab bar height
    public static let tabBarHeight: CGFloat = 56
    
    /// Navigation bar height
    public static let navBarHeight: CGFloat = 44
    
    /// Standard icon size
    public static let iconSize: CGFloat = 24
    
    /// Small icon size
    public static let iconSizeSmall: CGFloat = 16
    
    /// Large icon size
    public static let iconSizeLarge: CGFloat = 32
    
    // MARK: - Animation
    
    /// Standard animation duration
    public static let animationDuration: Double = 0.2
    
    /// Slow animation duration
    public static let animationDurationSlow: Double = 0.4
    
    /// Standard spring animation
    public static let springAnimation = Animation.spring(response: 0.3, dampingFraction: 0.7)
    
    /// Progress animation duration
    public static let progressAnimationDuration: Double = 0.6
    
    // MARK: - Opacity
    
    /// Subtle opacity - for light backgrounds
    public static let opacitySubtle: Double = 0.05
    
    /// Low opacity - for backgrounds, disabled states
    public static let opacityLow: Double = 0.1
    
    /// Medium opacity - for borders, dividers
    public static let opacityMedium: Double = 0.3
    
    /// High opacity - for important UI elements that need some transparency
    public static let opacityHigh: Double = 0.7
    
    // MARK: - Shadow Values
    
    /// Subtle shadow radius
    public static let shadowRadiusSubtle: CGFloat = 4
    
    /// Medium shadow radius
    public static let shadowRadiusMedium: CGFloat = 8
    
    /// Large shadow radius
    public static let shadowRadiusLarge: CGFloat = 16
    
    /// Subtle shadow opacity
    public static let shadowOpacitySubtle: Double = 0.05
    
    /// Medium shadow opacity
    public static let shadowOpacityMedium: Double = 0.1
    
    /// Large shadow opacity
    public static let shadowOpacityLarge: Double = 0.15
    
    // MARK: - Elevation
    
    /// Card shadow radius
    public static let cardShadowRadius: CGFloat = 5
    
    /// Card shadow opacity
    public static let cardShadowOpacity: Double = 0.05
    
    /// Card shadow y-offset
    public static let cardShadowY: CGFloat = 2
    
    // MARK: - Progress Elements
    
    /// Circular progress ring stroke width
    public static let ringStrokeWidth: CGFloat = 4
    
    /// Medium progress ring stroke width
    public static let ringStrokeMedium: CGFloat = 6
    
    /// Large circular progress ring size
    public static let progressRingLarge: CGFloat = 120
    
    /// Medium circular progress ring size
    public static let progressRingMedium: CGFloat = 90
    
    /// Small circular progress ring size
    public static let progressRingSmall: CGFloat = 80
    
    // MARK: - Font Sizes
    
    /// Large title size
    public static let largeTitleSize: CGFloat = 32
    
    /// Title size
    public static let titleSize: CGFloat = 24
    
    /// Subtitle size
    public static let subtitleSize: CGFloat = 18
    
    /// Body text size
    public static let bodySize: CGFloat = 16
    
    /// Caption size
    public static let captionSize: CGFloat = 13
    
    /// Headline size
    public static let headlineSize: CGFloat = 18
    
    // MARK: - Component Heights
    
    /// Header height
    public static let headerHeight: CGFloat = 80
    
    /// Header padding top
    public static let headerPaddingTop: CGFloat = 16
    
    // MARK: - Apply Methods
    
    /// Apply standard corner radius to a view
    public static func applyCornerRadius<T: View>(_ view: T) -> some View {
        view.cornerRadius(cornerRadius)
    }
    
    /// Apply standard card style to a view
    public static func applyCardStyle<T: View>(_ view: T) -> some View {
        view
            .padding(cardPadding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.theme.surface)
                    .shadow(color: Color.theme.shadow.opacity(cardShadowOpacity), 
                            radius: cardShadowRadius, 
                            x: 0, 
                            y: cardShadowY)
            )
    }
    
    /// Apply standard circular progress ring style
    public static func circularProgress(progress: Double, color: Color = .theme.accent, size: CGFloat = progressRingMedium) -> some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(lineWidth: ringStrokeWidth)
                .foregroundColor(color.opacity(0.1))
            
            // Progress circle
            Circle()
                .trim(from: 0.0, to: CGFloat(min(progress, 1.0)))
                .stroke(style: StrokeStyle(lineWidth: ringStrokeWidth, lineCap: .round))
                .foregroundColor(color)
                .rotationEffect(Angle(degrees: -90))
                .animation(.easeInOut(duration: progressAnimationDuration), value: progress)
        }
        .frame(width: size, height: size)
    }
    
    /// Apply a modern gradient card background
    public static func modernGradientCard<T: View>(_ view: T, cornerRadius: CGFloat = cornerRadius) -> some View {
        view
            .padding(cardPadding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(LinearGradient.themeChrome)
                    .shadow(color: Color.theme.shadow.opacity(cardShadowOpacity),
                            radius: cardShadowRadius,
                            x: 0,
                            y: cardShadowY)
            )
    }
}

/// Spacing tokens for consistent spacing across the app
public enum CalAISpacing {
    /// Extra small spacing: 4pt
    public static let xs: CGFloat = CalAIDesignTokens.spacingXS
    
    /// Small spacing: 8pt
    public static let small: CGFloat = CalAIDesignTokens.spacingS
    
    /// Medium spacing: 16pt
    public static let medium: CGFloat = CalAIDesignTokens.spacingM
    
    /// Large spacing: 24pt
    public static let large: CGFloat = CalAIDesignTokens.spacingL
    
    /// Extra large spacing: 32pt
    public static let xl: CGFloat = CalAIDesignTokens.spacingXL
    
    /// Double extra large spacing: 48pt
    public static let xxl: CGFloat = CalAIDesignTokens.spacingXXL
    
    /// Standard padding for screen edges
    public static let screenEdge: CGFloat = CalAIDesignTokens.screenPadding
    
    /// Standard spacing between items in a list
    public static let itemSpacing: CGFloat = CalAIDesignTokens.listSpacing
    
    /// Standard icon size
    public static let iconSize: CGFloat = CalAIDesignTokens.iconSize
    
    /// Small icon size
    public static let iconSizeSmall: CGFloat = CalAIDesignTokens.iconSizeSmall
    
    /// Large icon size
    public static let iconSizeLarge: CGFloat = CalAIDesignTokens.iconSizeLarge
}

/// View extension for consistent padding
public extension View {
    /// Apply standard screen edge padding
    func screenPadding() -> some View {
        self.padding(.horizontal, CalAISpacing.screenEdge)
    }
    
    /// Apply standard card padding
    func cardPadding() -> some View {
        self.padding(CalAIDesignTokens.cardPadding)
    }
    
    /// Apply horizontal card padding
    func cardHorizontalPadding() -> some View {
        self.padding(.horizontal, CalAIDesignTokens.cardPadding)
    }
    
    /// Apply vertical card padding
    func cardVerticalPadding() -> some View {
        self.padding(.vertical, CalAIDesignTokens.cardPadding)
    }
    
    /// Apply CalAI card style
    func calAICard() -> some View {
        CalAIDesignTokens.applyCardStyle(self)
    }
    
    /// Apply CalAI corner radius
    func calAICornerRadius() -> some View {
        self.cornerRadius(CalAIDesignTokens.cornerRadius)
    }
    
    /// Apply CalAI shadow
    func calAIShadow() -> some View {
        self.shadow(
            color: Color.theme.shadow.opacity(CalAIDesignTokens.cardShadowOpacity),
            radius: CalAIDesignTokens.cardShadowRadius,
            x: 0,
            y: CalAIDesignTokens.cardShadowY
        )
    }
    
    /// Apply modern gradient card style
    func modernGradientCard() -> some View {
        CalAIDesignTokens.modernGradientCard(self)
    }
} 