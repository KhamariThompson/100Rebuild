import SwiftUI

enum AppTypography {
    enum FontSize {
        static let largeTitle: CGFloat = 34
        static let title1: CGFloat = 28
        static let title2: CGFloat = 22
        static let title3: CGFloat = 20
        static let headline: CGFloat = 17
        static let body: CGFloat = 17
        static let callout: CGFloat = 16
        static let subheadline: CGFloat = 15
        static let footnote: CGFloat = 13
        static let caption: CGFloat = 12
    }
    
    enum FontWeight {
        static let regular = Font.Weight.regular
        static let medium = Font.Weight.medium
        static let semibold = Font.Weight.semibold
        static let bold = Font.Weight.bold
    }
}

// MARK: - Font Extensions
extension Font {
    static func custom(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        return Font.system(size: size, weight: weight, design: .rounded)
    }
    
    static let largeTitle = Font.custom(AppTypography.FontSize.largeTitle, weight: .bold)
    static let title1 = Font.custom(AppTypography.FontSize.title1, weight: .bold)
    static let title2 = Font.custom(AppTypography.FontSize.title2, weight: .semibold)
    static let title3 = Font.custom(AppTypography.FontSize.title3, weight: .semibold)
    static let headline = Font.custom(AppTypography.FontSize.headline, weight: .semibold)
    static let body = Font.custom(AppTypography.FontSize.body, weight: .regular)
    static let callout = Font.custom(AppTypography.FontSize.callout, weight: .regular)
    static let subheadline = Font.custom(AppTypography.FontSize.subheadline, weight: .regular)
    static let footnote = Font.custom(AppTypography.FontSize.footnote, weight: .regular)
    static let caption = Font.custom(AppTypography.FontSize.caption, weight: .regular)
} 