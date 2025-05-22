import SwiftUI

/// Design tokens inspired by CalAI design language
/// These values provide a consistent reference for styling across the app
public enum CalAIDesignTokens {
    // MARK: - Radii
    
    /// Standard corner radius for most elements
    public static let cornerRadius: CGFloat = 20
    
    /// Button corner radius
    public static let buttonRadius: CGFloat = 14
    
    /// Small corner radius for minor elements
    public static let smallRadius: CGFloat = 10
    
    // MARK: - Spacing
    
    /// Standard card padding
    public static let cardPadding: CGFloat = 16
    
    /// Screen edge padding
    public static let screenPadding: CGFloat = 16
    
    /// Item spacing in lists
    public static let listSpacing: CGFloat = 14
    
    // MARK: - Elevation
    
    /// Card shadow radius
    public static let cardShadowRadius: CGFloat = 4
    
    /// Card shadow opacity
    public static let cardShadowOpacity: Double = 0.06
    
    /// Card shadow y-offset
    public static let cardShadowY: CGFloat = 1
    
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
    
    // MARK: - Animation Timing
    
    /// Standard animation duration for UI elements
    public static let animationDuration: Double = 0.3
    
    /// Progress animation duration
    public static let progressAnimationDuration: Double = 1.0
    
    // MARK: - Font Sizes
    
    /// Large title size
    public static let largeTitleSize: CGFloat = 30
    
    /// Title size
    public static let titleSize: CGFloat = 22
    
    /// Subtitle size
    public static let subtitleSize: CGFloat = 18
    
    /// Body text size
    public static let bodySize: CGFloat = 16
    
    /// Caption size
    public static let captionSize: CGFloat = 13
    
    /// Headline size
    public static let headlineSize: CGFloat = 18
    
    // MARK: - Component Heights
    
    /// Standard button height
    public static let buttonHeight: CGFloat = 44
    
    /// Tab bar height
    public static let tabBarHeight: CGFloat = 78
    
    /// Navigation bar height
    public static let navBarHeight: CGFloat = 56
    
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
                .foregroundColor(color.opacity(0.2))
            
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
}

// MARK: - View Extension for Design Tokens

public extension View {
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
} 