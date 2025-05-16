import SwiftUI
import UIKit

/// Utility class to generate milestone share cards
class MilestoneShareCardGenerator {
    /// Available card layouts
    enum CardLayout {
        case modern   // Clean, minimal with large day number
        case classic  // Traditional layout with border
        case minimal  // Simple text-only layout
    }
    
    /// Background style options
    enum BackgroundStyle {
        case solid(Color)
        case gradient([Color])
        case pattern(String) // Image name
    }
    
    /// Generate a shareable card image for a milestone day
    /// - Parameters:
    ///   - currentDay: The day number to display
    ///   - challengeTitle: The title of the challenge 
    ///   - quote: Optional quote to include
    ///   - backgroundStyle: The style of the background
    ///   - layout: The layout template to use
    /// - Returns: A UIImage representing the share card
    static func generateMilestoneCard(
        currentDay: Int,
        challengeTitle: String,
        quote: Quote? = nil,
        backgroundStyle: BackgroundStyle = .gradient([Color.theme.accent, Color.theme.accent.opacity(0.7)]),
        layout: CardLayout = .modern
    ) -> UIImage {
        // Create an image renderer with size optimized for social media sharing
        let size = CGSize(width: 1200, height: 1800)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // Render the background first
            renderBackground(context: context, size: size, style: backgroundStyle)
            
            // Select and render the appropriate layout
            switch layout {
            case .modern:
                renderModernLayout(context: context, size: size, day: currentDay, title: challengeTitle, quote: quote)
            case .classic:
                renderClassicLayout(context: context, size: size, day: currentDay, title: challengeTitle, quote: quote)
            case .minimal:
                renderMinimalLayout(context: context, size: size, day: currentDay, title: challengeTitle, quote: quote)
            }
            
            // Add app branding
            drawAppBranding(context: context, size: size)
        }
    }
    
    // MARK: - Background Renderers
    
    private static func renderBackground(context: UIGraphicsImageRendererContext, size: CGSize, style: BackgroundStyle) {
        switch style {
        case .solid(let color):
            let uiColor = UIColor(color)
            uiColor.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
        case .gradient(let colors):
            let uiColors = colors.map { UIColor($0) }
            
            // Create a gradient layer
            let gradientLayer = CAGradientLayer()
            gradientLayer.frame = CGRect(origin: .zero, size: size)
            gradientLayer.colors = uiColors.map { $0.cgColor }
            gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
            gradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
            
            // Render the gradient layer
            let context = UIGraphicsGetCurrentContext()!
            gradientLayer.render(in: context)
            
            // Add a subtle pattern overlay for texture
            if let patternImage = UIImage(named: "subtle_pattern")?.withTintColor(UIColor.white.withAlphaComponent(0.05)) {
                patternImage.draw(in: CGRect(origin: .zero, size: size), blendMode: .overlay, alpha: 0.2)
            }
            
        case .pattern(let name):
            if let patternImage = UIImage(named: name) {
                patternImage.draw(in: CGRect(origin: .zero, size: size))
            } else {
                // Fallback to a solid color if pattern not found
                UIColor.systemBlue.setFill()
                context.fill(CGRect(origin: .zero, size: size))
            }
        }
    }
    
    // MARK: - Layout Renderers
    
    private static func renderModernLayout(
        context: UIGraphicsImageRendererContext,
        size: CGSize,
        day: Int,
        title: String,
        quote: Quote?
    ) {
        let padding: CGFloat = 80
        
        // Create rounded rectangle with blurred backdrop
        let contentRect = CGRect(
            x: padding,
            y: padding,
            width: size.width - (padding * 2),
            height: size.height - (padding * 2)
        )
        
        // Draw a glassy card background
        let roundedPath = UIBezierPath(
            roundedRect: contentRect,
            cornerRadius: 60
        )
        UIColor.white.withAlphaComponent(0.1).setFill()
        roundedPath.fill()
        
        // Draw decorative elements - circles
        drawDecorativeElements(in: contentRect, context: context.cgContext)
        
        // Draw day number with enhanced typography
        let dayString = "\(day)"
        let dayAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 300, weight: .black),
            .foregroundColor: UIColor.white.withAlphaComponent(0.95)
        ]
        
        let dayStringSize = dayString.size(withAttributes: dayAttributes)
        let dayX = (size.width - dayStringSize.width) / 2
        let dayY = contentRect.minY + 120
        
        // Draw subtle shadow for depth
        let shadowAttributes = dayAttributes.merging([
            .foregroundColor: UIColor.black.withAlphaComponent(0.3)
        ]) { (_, new) in new }
        
        dayString.draw(
            at: CGPoint(x: dayX + 4, y: dayY + 4),
            withAttributes: shadowAttributes
        )
        
        dayString.draw(
            at: CGPoint(x: dayX, y: dayY),
            withAttributes: dayAttributes
        )
        
        // Draw "DAY OF 100" text with enhanced styling
        let daysText = "DAY OF 100"
        let daysAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 50, weight: .bold),
            .foregroundColor: UIColor.white.withAlphaComponent(0.9)
        ]
        
        let daysTextSize = daysText.size(withAttributes: daysAttributes)
        let daysX = (size.width - daysTextSize.width) / 2
        let daysY = dayY + dayStringSize.height + 20
        
        daysText.draw(
            at: CGPoint(x: daysX, y: daysY),
            withAttributes: daysAttributes
        )
        
        // Draw horizontal accent line
        let lineY = daysY + daysTextSize.height + 40
        let lineWidth: CGFloat = 180
        let lineRect = CGRect(
            x: (size.width - lineWidth) / 2,
            y: lineY,
            width: lineWidth,
            height: 4
        )
        UIColor.white.withAlphaComponent(0.8).setFill()
        context.fill(lineRect)
        
        // Draw challenge title with enhanced typography
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 58, weight: .semibold),
            .foregroundColor: UIColor.white,
            .paragraphStyle: {
                let style = NSMutableParagraphStyle()
                style.alignment = .center
                style.lineSpacing = 8
                return style
            }()
        ]
        
        let titleWidth = contentRect.width - 100
        let titleRect = CGRect(
            x: contentRect.minX + 50,
            y: lineY + 60,
            width: titleWidth,
            height: 180
        )
        
        drawMultilineText(
            title,
            in: titleRect,
            withAttributes: titleAttributes,
            alignment: .center
        )
        
        // Draw quote if available with enhanced styling
        if let quote = quote {
            let quoteRect = CGRect(
                x: contentRect.minX + 100,
                y: titleRect.maxY + 80,
                width: contentRect.width - 200,
                height: 300
            )
            
            drawQuote(quote, in: quoteRect, textColor: .white, modern: true)
        }
    }
    
    private static func drawDecorativeElements(in rect: CGRect, context: CGContext) {
        // Add some decorative elements like circles
        let circleCount = 8
        let maxRadius: CGFloat = 40
        
        for i in 0..<circleCount {
            let position = CGPoint(
                x: CGFloat.random(in: rect.minX...rect.maxX),
                y: CGFloat.random(in: rect.minY...rect.maxY)
            )
            let radius = CGFloat.random(in: 15...maxRadius)
            let circlePath = UIBezierPath(
                arcCenter: position,
                radius: radius,
                startAngle: 0,
                endAngle: 2 * .pi,
                clockwise: true
            )
            
            let opacity = CGFloat.random(in: 0.03...0.08)
            UIColor.white.withAlphaComponent(opacity).setFill()
            circlePath.fill()
        }
    }
    
    private static func renderClassicLayout(
        context: UIGraphicsImageRendererContext,
        size: CGSize,
        day: Int,
        title: String,
        quote: Quote?
    ) {
        let padding: CGFloat = 50
        
        // Draw border
        let borderRect = CGRect(
            x: padding,
            y: padding,
            width: size.width - (padding * 2),
            height: size.height - (padding * 2)
        )
        
        let borderPath = UIBezierPath(rect: borderRect)
        UIColor.white.setStroke()
        borderPath.lineWidth = 10
        borderPath.stroke()
        
        // Draw inner content area
        let innerPadding: CGFloat = 30
        let contentRect = borderRect.insetBy(dx: innerPadding, dy: innerPadding)
        
        // Draw header
        let headerText = "100 DAYS CHALLENGE"
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 36, weight: .bold),
            .foregroundColor: UIColor.white
        ]
        
        let headerSize = headerText.size(withAttributes: headerAttributes)
        let headerX = (size.width - headerSize.width) / 2
        
        headerText.draw(
            at: CGPoint(x: headerX, y: contentRect.minY + 20),
            withAttributes: headerAttributes
        )
        
        // Draw separator line
        let lineY = contentRect.minY + headerSize.height + 40
        let linePath = UIBezierPath()
        linePath.move(to: CGPoint(x: contentRect.minX, y: lineY))
        linePath.addLine(to: CGPoint(x: contentRect.maxX, y: lineY))
        UIColor.white.setStroke()
        linePath.lineWidth = 2
        linePath.stroke()
        
        // Draw day number
        let dayString = "\(day)"
        let dayAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 180, weight: .bold),
            .foregroundColor: UIColor.white
        ]
        
        let daySize = dayString.size(withAttributes: dayAttributes)
        let dayX = (size.width - daySize.width) / 2
        let dayY = lineY + 60
        
        dayString.draw(
            at: CGPoint(x: dayX, y: dayY),
            withAttributes: dayAttributes
        )
        
        // Draw "Day" text
        let daysText = "DAY"
        let daysAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 48, weight: .semibold),
            .foregroundColor: UIColor.white
        ]
        
        let daysSize = daysText.size(withAttributes: daysAttributes)
        let daysX = (size.width - daysSize.width) / 2
        let daysY = dayY + daySize.height + 10
        
        daysText.draw(
            at: CGPoint(x: daysX, y: daysY),
            withAttributes: daysAttributes
        )
        
        // Draw challenge title
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 42, weight: .semibold),
            .foregroundColor: UIColor.white
        ]
        
        let titleRect = CGRect(
            x: contentRect.minX + 20,
            y: daysY + daysSize.height + 60,
            width: contentRect.width - 40,
            height: 120
        )
        
        drawMultilineText(
            title,
            in: titleRect,
            withAttributes: titleAttributes,
            alignment: .center
        )
        
        // Draw quote if available
        if let quote = quote {
            let quoteRect = CGRect(
                x: contentRect.minX + 60,
                y: titleRect.maxY + 60,
                width: contentRect.width - 120,
                height: 180
            )
            
            drawQuote(quote, in: quoteRect, textColor: .white)
        }
    }
    
    private static func renderMinimalLayout(
        context: UIGraphicsImageRendererContext,
        size: CGSize,
        day: Int,
        title: String,
        quote: Quote?
    ) {
        // Draw day number
        let dayString = "DAY \(day)"
        let dayAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 120, weight: .bold),
            .foregroundColor: UIColor.white
        ]
        
        let daySize = dayString.size(withAttributes: dayAttributes)
        let dayX = (size.width - daySize.width) / 2
        let dayY = size.height * 0.25
        
        dayString.draw(
            at: CGPoint(x: dayX, y: dayY),
            withAttributes: dayAttributes
        )
        
        // Draw challenge title
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 48, weight: .medium),
            .foregroundColor: UIColor.white
        ]
        
        let titleRect = CGRect(
            x: 80,
            y: dayY + daySize.height + 60,
            width: size.width - 160,
            height: 120
        )
        
        drawMultilineText(
            title,
            in: titleRect,
            withAttributes: titleAttributes,
            alignment: .center
        )
        
        // Draw quote if available
        if let quote = quote {
            let quoteRect = CGRect(
                x: 80,
                y: titleRect.maxY + 60,
                width: size.width - 160,
                height: 180
            )
            
            drawQuote(quote, in: quoteRect, textColor: .white)
        }
    }
    
    // MARK: - Helper Methods
    
    private static func drawMultilineText(
        _ text: String,
        in rect: CGRect,
        withAttributes attributes: [NSAttributedString.Key: Any],
        alignment: NSTextAlignment = .left
    ) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        paragraphStyle.lineBreakMode = .byWordWrapping
        
        var newAttributes = attributes
        newAttributes[.paragraphStyle] = paragraphStyle
        
        let attributedString = NSAttributedString(string: text, attributes: newAttributes)
        attributedString.draw(in: rect)
    }
    
    private static func drawQuote(_ quote: Quote, in rect: CGRect, textColor: UIColor, modern: Bool = false) {
        let quoteText = "\"\(quote.text)\""
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineSpacing = 8
        
        let quoteAttributes: [NSAttributedString.Key: Any] = [
            .font: modern ? UIFont.systemFont(ofSize: 36, weight: .medium) : UIFont.italicSystemFont(ofSize: 34),
            .foregroundColor: textColor.withAlphaComponent(0.95),
            .paragraphStyle: paragraphStyle
        ]
        
        let authorAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 28, weight: .medium),
            .foregroundColor: textColor.withAlphaComponent(0.8),
            .paragraphStyle: paragraphStyle
        ]
        
        // Calculate text size
        let quoteSize = (quoteText as NSString).boundingRect(
            with: CGSize(width: rect.width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: quoteAttributes,
            context: nil
        )
        
        // Draw quote text
        (quoteText as NSString).draw(
            with: CGRect(
                x: rect.minX,
                y: rect.minY,
                width: rect.width,
                height: quoteSize.height
            ),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: quoteAttributes,
            context: nil
        )
        
        // Draw author attribution
        let authorText = "— \(quote.author)"
        let authorY = rect.minY + quoteSize.height + 24
        
        (authorText as NSString).draw(
            at: CGPoint(x: rect.midX - authorText.size(withAttributes: authorAttributes).width / 2, y: authorY),
            withAttributes: authorAttributes
        )
    }
    
    // Add app branding to the image
    private static func drawAppBranding(context: UIGraphicsImageRendererContext, size: CGSize) {
        let appNameAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 24, weight: .semibold),
            .foregroundColor: UIColor.white.withAlphaComponent(0.7)
        ]
        
        let appName = "100Days App"
        let appNameSize = appName.size(withAttributes: appNameAttributes)
        let appNameX = size.width - appNameSize.width - 40
        let appNameY = size.height - appNameSize.height - 40
        
        appName.draw(
            at: CGPoint(x: appNameX, y: appNameY),
            withAttributes: appNameAttributes
        )
    }
} 