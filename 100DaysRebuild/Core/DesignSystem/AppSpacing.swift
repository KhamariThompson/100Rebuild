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
    
    /// Large spacing (20pt) - Changed from 24pt to match CalAI's more compact spacing
    public static let l: CGFloat = 20
    
    /// Extra large spacing (28pt) - Changed from 32pt to match CalAI
    public static let xl: CGFloat = 28
    
    /// Extra extra large spacing (40pt) - Changed from 48pt to match CalAI
    public static let xxl: CGFloat = 40
    
    // MARK: - Component-Specific Spacing
    
    /// Standard padding inside cards
    public static let cardPadding: CGFloat = 16
    
    /// Standard corner radius for cards - Increased to match CalAI's rounder corners
    public static let cardCornerRadius: CGFloat = 20
    
    /// Spacing between sections - Reduced to match CalAI's tighter layout
    public static let sectionSpacing: CGFloat = 20
    
    /// Spacing between items in a stack
    public static let itemSpacing: CGFloat = 12
    
    /// Spacing for lists and grouped content
    public static let listSpacing: CGFloat = 14
    
    /// Horizontal screen padding
    public static let screenHorizontalPadding: CGFloat = 16
    
    /// Vertical padding for buttons - Reduced slightly to match CalAI
    public static let buttonVerticalPadding: CGFloat = 14
    
    /// Horizontal padding for buttons
    public static let buttonHorizontalPadding: CGFloat = 20
    
    // MARK: - Specialized Spacing
    
    /// Small icon size
    public static let iconSizeSmall: CGFloat = 16
    
    /// Medium icon size
    public static let iconSizeMedium: CGFloat = 22
    
    /// Large icon size
    public static let iconSizeLarge: CGFloat = 28
    
    // MARK: - CalAI-Specific Components
    
    /// Thin progress ring stroke width
    public static let progressRingStrokeWidth: CGFloat = 4
    
    /// Medium progress ring stroke width
    public static let progressRingStrokeMedium: CGFloat = 6
    
    /// Circular progress ring size (standard)
    public static let circularProgressSize: CGFloat = 120
    
    /// Circular progress ring size (small)
    public static let circularProgressSizeSmall: CGFloat = 80
} 