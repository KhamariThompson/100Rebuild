import SwiftUI
import CoreText
import CoreGraphics

/// Core Design System Typography
/// Provides consistent text styles across the application
public enum AppTypography {
    /// Font family constants
    public enum FontFamily {
        public static let primary = "SFProDisplay-Regular"
        public static let primaryMedium = "SFProDisplay-Medium"
        public static let primarySemibold = "SFProDisplay-Semibold"
        public static let primaryBold = "SFProDisplay-Bold"
    }
    
    public enum FontSize {
        public static let display: CGFloat = 40
        public static let largeTitle: CGFloat = 32
        public static let title1: CGFloat = 26
        public static let title2: CGFloat = 20
        public static let title3: CGFloat = 18
        public static let headline: CGFloat = 16
        public static let body: CGFloat = 16
        public static let callout: CGFloat = 15
        public static let subheadline: CGFloat = 14
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
    public static let display = Font.custom(FontSize.display, weight: .semibold)
    public static let largeTitle = Font.custom(FontSize.largeTitle, weight: .semibold)
    public static let title1 = Font.custom(FontSize.title1, weight: .semibold)
    public static let title2 = Font.custom(FontSize.title2, weight: .medium)
    public static let title3 = Font.custom(FontSize.title3, weight: .medium)
    public static let headline = Font.custom(FontSize.headline, weight: .medium)
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
    
    // Dynamic Type Styles
    // These styles automatically adapt to user's text size preferences
    public static let dynamicDisplay = Font.system(.largeTitle, design: .rounded).weight(.semibold)
    public static let dynamicLargeTitle = Font.system(.largeTitle, design: .rounded).weight(.semibold)
    public static let dynamicTitle1 = Font.system(.title, design: .rounded).weight(.semibold)
    public static let dynamicTitle2 = Font.system(.title2, design: .rounded).weight(.medium)
    public static let dynamicTitle3 = Font.system(.title3, design: .rounded).weight(.medium)
    public static let dynamicHeadline = Font.system(.headline, design: .rounded)
    public static let dynamicBody = Font.system(.body, design: .rounded)
    public static let dynamicCallout = Font.system(.callout, design: .rounded)
    public static let dynamicSubheadline = Font.system(.subheadline, design: .rounded)
    public static let dynamicFootnote = Font.system(.footnote, design: .rounded)
    public static let dynamicCaption = Font.system(.caption, design: .rounded)
    public static let dynamicCaption2 = Font.system(.caption2, design: .rounded)
    
    /// Maps AppTypography font to a Dynamic Type text style
    public static func dynamicTextStyle(for font: Font) -> Font {
        switch font {
        case display, largeTitle:
            return dynamicLargeTitle
        case title1:
            return dynamicTitle1
        case title2:
            return dynamicTitle2
        case title3:
            return dynamicTitle3
        case headline:
            return dynamicHeadline
        case body, bodyMedium:
            return dynamicBody
        case callout:
            return dynamicCallout
        case subheadline, subheadlineMedium:
            return dynamicSubheadline
        case footnote:
            return dynamicFootnote
        case caption, captionMedium:
            return dynamicCaption
        case small:
            return dynamicCaption2
        default:
            return dynamicBody
        }
    }
    
    /// Get a dynamic version of a custom font
    public static func dynamicCustomFont(name: String, size: CGFloat, style: Font.TextStyle) -> Font {
        return Font.custom(name, size: size, relativeTo: style)
    }
    
    /// Get the font name for a specified weight
    private static func fontName(for weight: Font.Weight) -> String {
        switch weight {
        case .bold:
            return FontFamily.primaryBold
        case .semibold:
            return FontFamily.primarySemibold
        case .medium:
            return FontFamily.primaryMedium
        default:
            return FontFamily.primary
        }
    }
}

// MARK: - Font Extensions
public extension Font {
    static func custom(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        // In real implementation, we would use actual custom fonts
        // For now, we'll continue using system fonts with rounded design to maintain consistency
        return .system(size: size, weight: weight, design: .rounded)
        
        // When SF Pro Display is properly added to the project:
        // let fontName = AppTypography.fontName(for: weight)
        // return .custom(fontName, size: size)
    }
    
    // Convenience methods to create fonts with specific sizes and weights
    static func displayRounded(weight: Font.Weight = .semibold) -> Font {
        return .system(size: CalAIDesignTokens.largeTitleSize, weight: weight, design: .rounded)
    }
    
    static func titleRounded(weight: Font.Weight = .semibold) -> Font {
        return .system(size: CalAIDesignTokens.titleSize, weight: weight, design: .rounded)
    }
    
    static func headlineRounded(weight: Font.Weight = .medium) -> Font {
        return .system(size: CalAIDesignTokens.headlineSize, weight: weight, design: .rounded)
    }
    
    static func bodyRounded(weight: Font.Weight = .regular) -> Font {
        return .system(size: CalAIDesignTokens.bodySize, weight: weight, design: .rounded)
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

/// Modifier that applies a dynamic font that scales with the user's text size preferences
public struct DynamicFontModifier: ViewModifier {
    let font: Font
    
    public init(font: Font) {
        self.font = font
    }
    
    public func body(content: Content) -> some View {
        content
            .font(AppTypography.dynamicTextStyle(for: font))
    }
}

// MARK: - View Extensions
public extension View {
    func appFont(_ font: Font) -> some View {
        self.modifier(FontModifier(font: font))
    }
    
    /// Apply a font that scales with Dynamic Type
    func dynamicFont(_ font: Font) -> some View {
        self.modifier(DynamicFontModifier(font: font))
    }
    
    /// Apply a ScaledMetric to any value that should scale with text size
    func scaledValue(_ value: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> CGFloat {
        let scaledMetric = ScaledMetric(wrappedValue: value, relativeTo: textStyle)
        return scaledMetric.wrappedValue
    }
}

// MARK: - Typography Shorthand
public extension View {
    func display() -> some View { appFont(AppTypography.display) }
    func largeTitle() -> some View { appFont(AppTypography.largeTitle) }
    func title1() -> some View { appFont(AppTypography.title1) }
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
    
    // Dynamic Type versions that adapt to user preferences
    func dynamicDisplay() -> some View { appFont(AppTypography.dynamicDisplay) }
    func dynamicLargeTitle() -> some View { appFont(AppTypography.dynamicLargeTitle) }
    func dynamicTitle1() -> some View { appFont(AppTypography.dynamicTitle1) }
    func dynamicTitle2() -> some View { appFont(AppTypography.dynamicTitle2) }
    func dynamicTitle3() -> some View { appFont(AppTypography.dynamicTitle3) }
    func dynamicHeadline() -> some View { appFont(AppTypography.dynamicHeadline) }
    func dynamicBody() -> some View { appFont(AppTypography.dynamicBody) }
    func dynamicCallout() -> some View { appFont(AppTypography.dynamicCallout) }
    func dynamicSubheadline() -> some View { appFont(AppTypography.dynamicSubheadline) }
    func dynamicFootnote() -> some View { appFont(AppTypography.dynamicFootnote) }
    func dynamicCaption() -> some View { appFont(AppTypography.dynamicCaption) }
    func dynamicCaption2() -> some View { appFont(AppTypography.dynamicCaption2) }
}

// MARK: - Font Registration

/// Manages font registration in the app
public struct FontRegistration {
    /// Register all custom fonts with the system
    public static func registerFonts() {
        // No custom fonts to register, we're using system fonts
        // This is a placeholder for future custom font registration
        
        // For custom fonts, registration would look like:
        // registerFont(bundle: .main, fontName: "CustomFont-Regular", fontExtension: "ttf")
    }
    
    /// Register a single font with the system
    private static func registerFont(bundle: Bundle, fontName: String, fontExtension: String) {
        guard let fontURL = bundle.url(forResource: fontName, withExtension: fontExtension),
              let fontDataProvider = CGDataProvider(url: fontURL as CFURL),
              let font = CGFont(fontDataProvider) else {
            print("ERROR: Failed to register font \(fontName).\(fontExtension)")
            return
        }
        
        var error: Unmanaged<CFError>?
        if !CTFontManagerRegisterGraphicsFont(font, &error) {
            if let error = error?.takeRetainedValue() {
                let errorDescription = CFErrorCopyDescription(error)
                print("ERROR: Failed to register font \(fontName): \(errorDescription)")
            }
        }
    }
} 