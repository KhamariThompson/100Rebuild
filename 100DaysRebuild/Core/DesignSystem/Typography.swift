import SwiftUI
import CoreGraphics

/// Core Design System Typography
/// Provides consistent text styles across the application
public enum AppTypography {
    // MARK: - Font Family

    /// Standard system font used throughout the app
    public static func font(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
        return Font.system(size: size, weight: weight, design: design)
    }

    // MARK: - Font Sizes

    /// Font sizes used across the app
    public enum FontSize {
        /// Display: 40pt - Used for main headlines
        public static let display: CGFloat = 40
        /// Large Title: 32pt - Used for screen titles
        public static let largeTitle: CGFloat = 32
        /// Title 1: 28pt - Used for major section headers
        public static let title1: CGFloat = 28
        /// Title 2: 22pt - Used for section headers
        public static let title2: CGFloat = 22
        /// Title 3: 20pt - Used for subsection headers
        public static let title3: CGFloat = 20
        /// Headline: 17pt - Used for emphasized text
        public static let headline: CGFloat = 17
        /// Body: 16pt - Used for regular text
        public static let body: CGFloat = 16
        /// Callout: 15pt - Used for slightly emphasized text
        public static let callout: CGFloat = 15
        /// Subheadline: 14pt - Used for secondary text
        public static let subhead: CGFloat = 14
        /// Footnote: 13pt - Used for tertiary information
        public static let footnote: CGFloat = 13
        /// Caption 1: 12pt - Used for small labels
        public static let caption1: CGFloat = 12
        /// Caption 2: 11pt - Used for very small text
        public static let caption2: CGFloat = 11
    }
    
    // MARK: - Font Weights
    
    /// Font weights used across the app
    public enum FontWeight {
        /// Regular: For regular text
        public static let regular = Font.Weight.regular
        /// Medium: For medium emphasis
        public static let medium = Font.Weight.medium
        /// Semibold: For stronger emphasis
        public static let semibold = Font.Weight.semibold
        /// Bold: For maximum emphasis
        public static let bold = Font.Weight.bold
    }
    
    // MARK: - Text Style Functions
    
    /// Display text style - largest, most prominent text
    public static func display(_ weight: Font.Weight = .bold) -> Font {
        return font(size: FontSize.display, weight: weight)
    }
    
    /// Large title text style - for screen titles
    public static func largeTitle(_ weight: Font.Weight = .bold) -> Font {
        return font(size: FontSize.largeTitle, weight: weight)
    }
    
    /// Title 1 text style - for major section headers
    public static func title1(_ weight: Font.Weight = .semibold) -> Font {
        return font(size: FontSize.title1, weight: weight)
    }
    
    /// Title 2 text style - for section headers
    public static func title2(_ weight: Font.Weight = .semibold) -> Font {
        return font(size: FontSize.title2, weight: weight)
    }
    
    /// Title 3 text style - for subsection headers
    public static func title3(_ weight: Font.Weight = .semibold) -> Font {
        return font(size: FontSize.title3, weight: weight)
    }
    
    /// Headline text style - for emphasized text
    public static func headline(_ weight: Font.Weight = .semibold) -> Font {
        return font(size: FontSize.headline, weight: weight)
    }
    
    /// Body text style - for regular text
    public static func body(_ weight: Font.Weight = .regular) -> Font {
        return font(size: FontSize.body, weight: weight)
    }
    
    /// Callout text style - for slightly emphasized text
    public static func callout(_ weight: Font.Weight = .regular) -> Font {
        return font(size: FontSize.callout, weight: weight)
    }
    
    /// Subheadline text style - for secondary text
    public static func subhead(_ weight: Font.Weight = .regular) -> Font {
        return font(size: FontSize.subhead, weight: weight)
    }
    
    /// Footnote text style - for tertiary information
    public static func footnote(_ weight: Font.Weight = .regular) -> Font {
        return font(size: FontSize.footnote, weight: weight)
    }
    
    /// Caption 1 text style - for small labels
    public static func caption1(_ weight: Font.Weight = .regular) -> Font {
        return font(size: FontSize.caption1, weight: weight)
    }
    
    /// Caption 2 text style - for very small text
    public static func caption2(_ weight: Font.Weight = .regular) -> Font {
        return font(size: FontSize.caption2, weight: weight)
    }
}

// MARK: - Font Extensions

/// Extensions to simplify font creation in SwiftUI
public extension Font {
    /// Create a display font - largest, most prominent text
    static var displayBold: Font {
        AppTypography.display(.bold)
    }
    
    /// Create a large title font - for screen titles
    static var largeTitleBold: Font {
        AppTypography.largeTitle(.bold)
    }
    
    /// Create a title 1 font - for major section headers
    static var title1Semibold: Font {
        AppTypography.title1(.semibold)
    }
    
    /// Create a title 2 font - for section headers
    static var title2Semibold: Font {
        AppTypography.title2(.semibold)
    }
    
    /// Create a title 3 font - for subsection headers
    static var title3Semibold: Font {
        AppTypography.title3(.semibold)
    }
    
    /// Create a headline font - for emphasized text
    static var headlineSemibold: Font {
        AppTypography.headline(.semibold)
    }
    
    /// Create a body font - for regular text
    static var bodyRegular: Font {
        AppTypography.body(.regular)
    }
    
    /// Create a body font with medium weight - for medium emphasis
    static var bodyMedium: Font {
        AppTypography.body(.medium)
    }
    
    /// Create a callout font - for slightly emphasized text
    static var calloutRegular: Font {
        AppTypography.callout(.regular)
    }
    
    /// Create a subheadline font - for secondary text
    static var subheadRegular: Font {
        AppTypography.subhead(.regular)
    }
    
    /// Create a footnote font - for tertiary information
    static var footnoteRegular: Font {
        AppTypography.footnote(.regular)
    }
    
    /// Create a caption 1 font - for small labels
    static var caption1Regular: Font {
        AppTypography.caption1(.regular)
    }
    
    /// Create a caption 2 font - for very small text
    static var caption2Regular: Font {
        AppTypography.caption2(.regular)
    }
}

// MARK: - Text Style View Modifiers

/// Text style modifiers for consistent typography
public struct TextStyleModifier: ViewModifier {
    let font: Font
    let lineSpacing: CGFloat
    let letterSpacing: CGFloat
    
    public func body(content: Content) -> some View {
        content
            .font(font)
            .lineSpacing(lineSpacing)
            .tracking(letterSpacing)
    }
}

/// View extension for applying text styles
public extension View {
    /// Apply a display text style
    func displayStyle(weight: Font.Weight = .bold, lineSpacing: CGFloat = 0, letterSpacing: CGFloat = -0.5) -> some View {
        self.modifier(TextStyleModifier(
            font: AppTypography.display(weight),
            lineSpacing: lineSpacing,
            letterSpacing: letterSpacing
        ))
    }
    
    /// Apply a large title text style
    func largeTitleStyle(weight: Font.Weight = .bold, lineSpacing: CGFloat = 0, letterSpacing: CGFloat = -0.5) -> some View {
        self.modifier(TextStyleModifier(
            font: AppTypography.largeTitle(weight),
            lineSpacing: lineSpacing,
            letterSpacing: letterSpacing
        ))
    }
    
    /// Apply a title 1 text style
    func title1Style(weight: Font.Weight = .semibold, lineSpacing: CGFloat = 0, letterSpacing: CGFloat = -0.3) -> some View {
        self.modifier(TextStyleModifier(
            font: AppTypography.title1(weight),
            lineSpacing: lineSpacing,
            letterSpacing: letterSpacing
        ))
    }
    
    /// Apply a title 2 text style
    func title2Style(weight: Font.Weight = .semibold, lineSpacing: CGFloat = 0, letterSpacing: CGFloat = -0.2) -> some View {
        self.modifier(TextStyleModifier(
            font: AppTypography.title2(weight),
            lineSpacing: lineSpacing,
            letterSpacing: letterSpacing
        ))
    }
    
    /// Apply a title 3 text style
    func title3Style(weight: Font.Weight = .semibold, lineSpacing: CGFloat = 0, letterSpacing: CGFloat = -0.1) -> some View {
        self.modifier(TextStyleModifier(
            font: AppTypography.title3(weight),
            lineSpacing: lineSpacing,
            letterSpacing: letterSpacing
        ))
    }
    
    /// Apply a headline text style
    func headlineStyle(weight: Font.Weight = .semibold, lineSpacing: CGFloat = 2, letterSpacing: CGFloat = 0) -> some View {
        self.modifier(TextStyleModifier(
            font: AppTypography.headline(weight),
            lineSpacing: lineSpacing,
            letterSpacing: letterSpacing
        ))
    }
    
    /// Apply a body text style
    func bodyStyle(weight: Font.Weight = .regular, lineSpacing: CGFloat = 4, letterSpacing: CGFloat = 0) -> some View {
        self.modifier(TextStyleModifier(
            font: AppTypography.body(weight),
            lineSpacing: lineSpacing,
            letterSpacing: letterSpacing
        ))
    }
    
    /// Apply a callout text style
    func calloutStyle(weight: Font.Weight = .regular, lineSpacing: CGFloat = 3, letterSpacing: CGFloat = 0) -> some View {
        self.modifier(TextStyleModifier(
            font: AppTypography.callout(weight),
            lineSpacing: lineSpacing,
            letterSpacing: letterSpacing
        ))
    }
    
    /// Apply a subheadline text style
    func subheadStyle(weight: Font.Weight = .regular, lineSpacing: CGFloat = 2, letterSpacing: CGFloat = 0.2) -> some View {
        self.modifier(TextStyleModifier(
            font: AppTypography.subhead(weight),
            lineSpacing: lineSpacing,
            letterSpacing: letterSpacing
        ))
    }
    
    /// Apply a footnote text style
    func footnoteStyle(weight: Font.Weight = .regular, lineSpacing: CGFloat = 1, letterSpacing: CGFloat = 0.2) -> some View {
        self.modifier(TextStyleModifier(
            font: AppTypography.footnote(weight),
            lineSpacing: lineSpacing,
            letterSpacing: letterSpacing
        ))
    }
    
    /// Apply a caption 1 text style
    func caption1Style(weight: Font.Weight = .regular, lineSpacing: CGFloat = 1, letterSpacing: CGFloat = 0.3) -> some View {
        self.modifier(TextStyleModifier(
            font: AppTypography.caption1(weight),
            lineSpacing: lineSpacing,
            letterSpacing: letterSpacing
        ))
    }
    
    /// Apply a caption 2 text style
    func caption2Style(weight: Font.Weight = .regular, lineSpacing: CGFloat = 0, letterSpacing: CGFloat = 0.3) -> some View {
        self.modifier(TextStyleModifier(
            font: AppTypography.caption2(weight),
            lineSpacing: lineSpacing,
            letterSpacing: letterSpacing
        ))
    }
} 