import SwiftUI

/// AppSpacing defines standard spacing values to be used throughout the app
/// for consistent layout and spacing between elements.
public enum AppSpacing {
    // MARK: - Base Spacing Scale
    
    /// Extra extra small spacing (4pt)
    public static let xxs: CGFloat = 4
    
    /// Extra small spacing (8pt)
    public static let xs: CGFloat = 8
    
    /// Small spacing (12pt)
    public static let s: CGFloat = 12
    
    /// Medium spacing (16pt)
    public static let m: CGFloat = 16
    
    /// Large spacing (24pt)
    public static let l: CGFloat = 24
    
    /// Extra large spacing (32pt)
    public static let xl: CGFloat = 32
    
    /// Extra extra large spacing (48pt)
    public static let xxl: CGFloat = 48
    
    // MARK: - Component-Specific Spacing
    
    /// Standard padding inside cards
    public static let cardPadding: CGFloat = 16
    
    /// Standard corner radius for cards
    public static let cardCornerRadius: CGFloat = 16
    
    /// Spacing between sections
    public static let sectionSpacing: CGFloat = 24
    
    /// Spacing between items in a stack
    public static let itemSpacing: CGFloat = 12
    
    /// Spacing for lists and grouped content
    public static let listSpacing: CGFloat = 16
    
    /// Horizontal screen padding
    public static let screenHorizontalPadding: CGFloat = 20
    
    /// Vertical padding for buttons
    public static let buttonVerticalPadding: CGFloat = 16
    
    /// Horizontal padding for buttons
    public static let buttonHorizontalPadding: CGFloat = 20
    
    // MARK: - Specialized Spacing
    
    /// Small icon size
    public static let iconSizeSmall: CGFloat = 18
    
    /// Medium icon size
    public static let iconSizeMedium: CGFloat = 24
    
    /// Large icon size
    public static let iconSizeLarge: CGFloat = 32
} 