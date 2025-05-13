import SwiftUI

/// Core Design System Typography
/// Provides consistent text styles across the application
public enum AppTypography {
    public enum FontSize {
        public static let display: CGFloat = 42
        public static let largeTitle: CGFloat = 34
        public static let title1: CGFloat = 28
        public static let title2: CGFloat = 22
        public static let title3: CGFloat = 20
        public static let headline: CGFloat = 17
        public static let body: CGFloat = 17
        public static let callout: CGFloat = 16
        public static let subheadline: CGFloat = 15
        public static let footnote: CGFloat = 13
        public static let caption: CGFloat = 12
        public static let small: CGFloat = 10
    }
    
    public enum FontWeight {
        public static let regular = Font.Weight.regular
        public static let medium = Font.Weight.medium
        public static let semibold = Font.Weight.semibold
        public static let bold = Font.Weight.bold
    }
    
    // Typography styles
    public static let display = Font.custom(FontSize.display, weight: .bold)
    public static let largeTitle = Font.custom(FontSize.largeTitle, weight: .bold)
    public static let title1 = Font.custom(FontSize.title1, weight: .bold)
    public static let title2 = Font.custom(FontSize.title2, weight: .semibold)
    public static let title3 = Font.custom(FontSize.title3, weight: .semibold)
    public static let headline = Font.custom(FontSize.headline, weight: .semibold)
    public static let body = Font.custom(FontSize.body, weight: .regular)
    public static let callout = Font.custom(FontSize.callout, weight: .regular)
    public static let subheadline = Font.custom(FontSize.subheadline, weight: .regular)
    public static let footnote = Font.custom(FontSize.footnote, weight: .regular)
    public static let caption = Font.custom(FontSize.caption, weight: .regular)
    public static let small = Font.custom(FontSize.small, weight: .regular)
    
    // Additional styles with custom weights
    public static let bodyMedium = Font.custom(FontSize.body, weight: .medium)
    public static let subheadlineMedium = Font.custom(FontSize.subheadline, weight: .medium)
    public static let captionMedium = Font.custom(FontSize.caption, weight: .medium)
}

// MARK: - Font Extensions
public extension Font {
    static func custom(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        return Font.system(size: size, weight: weight, design: .rounded)
    }
    
    // Convenience methods to create fonts with specific sizes and weights
    static func displayRounded(weight: Font.Weight = .regular) -> Font {
        return .system(size: AppTypography.FontSize.display, weight: weight, design: .rounded)
    }
    
    static func titleRounded(weight: Font.Weight = .regular) -> Font {
        return .system(size: AppTypography.FontSize.title1, weight: weight, design: .rounded)
    }
    
    static func headlineRounded(weight: Font.Weight = .regular) -> Font {
        return .system(size: AppTypography.FontSize.headline, weight: weight, design: .rounded)
    }
    
    static func bodyRounded(weight: Font.Weight = .regular) -> Font {
        return .system(size: AppTypography.FontSize.body, weight: weight, design: .rounded)
    }
}

// MARK: - Font Modifiers
public struct FontModifier: ViewModifier {
    let font: Font
    
    public init(font: Font) {
        self.font = font
    }
    
    public func body(content: Content) -> some View {
        content
            .font(font)
    }
}

// MARK: - View Extensions
public extension View {
    func appFont(_ font: Font) -> some View {
        self.modifier(FontModifier(font: font))
    }
}

// MARK: - Typography Shorthand
public extension View {
    func display() -> some View { appFont(AppTypography.display) }
    func largeTitle() -> some View { appFont(AppTypography.largeTitle) }
    func title() -> some View { appFont(AppTypography.title1) }
    func title2() -> some View { appFont(AppTypography.title2) }
    func title3() -> some View { appFont(AppTypography.title3) }
    func headline() -> some View { appFont(AppTypography.headline) }
    func body() -> some View { appFont(AppTypography.body) }
    func bodyMedium() -> some View { appFont(AppTypography.bodyMedium) }
    func callout() -> some View { appFont(AppTypography.callout) }
    func subheadline() -> some View { appFont(AppTypography.subheadline) }
    func subheadlineMedium() -> some View { appFont(AppTypography.subheadlineMedium) }
    func footnote() -> some View { appFont(AppTypography.footnote) }
    func caption() -> some View { appFont(AppTypography.caption) }
    func captionMedium() -> some View { appFont(AppTypography.captionMedium) }
    func small() -> some View { appFont(AppTypography.small) }
} 