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
        // Choose renderer size based on layout
        let size: CGSize
        switch layout {
        case .modern:
            size = CGSize(width: 1200, height: 1200)
        case .classic:
            size = CGSize(width: 1080, height: 1350)
        case .minimal:
            size = CGSize(width: 1080, height: 1080)
        }
        
        // Create the renderer
        let renderer = UIGraphicsImageRenderer(size: size)
        
        // Generate the image
        return renderer.image { context in
            // Set up the background
            let rect = CGRect(origin: .zero, size: size)
            
            // Apply background style
            switch backgroundStyle {
            case .solid(let color):
                UIColor(color).setFill()
                context.fill(rect)
                
            case .gradient(let colors):
                let gradient = CGGradient(
                    colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: colors.map { UIColor($0).cgColor } as CFArray,
                    locations: nil
                )!
                
                context.cgContext.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: 0, y: 0),
                    end: CGPoint(x: size.width, y: size.height),
                    options: []
                )
                
            case .pattern(let imageName):
                if let image = UIImage(named: imageName) {
                    image.draw(in: rect)
                } else {
                    // Fallback to accent color if image not found
                    UIColor(Color.theme.accent).setFill()
                    context.fill(rect)
                }
            }
            
            // Render content based on layout
            switch layout {
            case .modern:
                renderModernLayout(
                    context: context,
                    size: size,
                    day: currentDay,
                    title: challengeTitle,
                    quote: quote
                )
                
            case .classic:
                renderClassicLayout(
                    context: context,
                    size: size,
                    day: currentDay,
                    title: challengeTitle,
                    quote: quote
                )
                
            case .minimal:
                renderMinimalLayout(
                    context: context,
                    size: size,
                    day: currentDay,
                    title: challengeTitle,
                    quote: quote
                )
            }
            
            // Add app branding/watermark
            addWatermark(context: context, size: size)
        }
    }
    
    // MARK: - Private Layout Methods
    
    private static func renderModernLayout(
        context: UIGraphicsImageRendererContext,
        size: CGSize,
        day: Int,
        title: String,
        quote: Quote?
    ) {
        let padding: CGFloat = 60
        
        // Create rounded rectangle for content
        let contentRect = CGRect(
            x: padding,
            y: padding,
            width: size.width - (padding * 2),
            height: size.height - (padding * 2)
        )
        
        let roundedPath = UIBezierPath(
            roundedRect: contentRect,
            cornerRadius: 40
        )
        UIColor.white.withAlphaComponent(0.15).setFill()
        roundedPath.fill()
        
        // Draw day number
        let dayString = "\(day)"
        let dayAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 240, weight: .bold),
            .foregroundColor: UIColor.white
        ]
        
        let dayStringSize = dayString.size(withAttributes: dayAttributes)
        let dayX = (size.width - dayStringSize.width) / 2
        let dayY = contentRect.minY + 150
        
        dayString.draw(
            at: CGPoint(x: dayX, y: dayY),
            withAttributes: dayAttributes
        )
        
        // Draw "Day of 100" text
        let daysText = "DAY OF 100"
        let daysAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 48, weight: .bold),
            .foregroundColor: UIColor.white
        ]
        
        let daysTextSize = daysText.size(withAttributes: daysAttributes)
        let daysX = (size.width - daysTextSize.width) / 2
        let daysY = dayY + dayStringSize.height + 20
        
        daysText.draw(
            at: CGPoint(x: daysX, y: daysY),
            withAttributes: daysAttributes
        )
        
        // Draw challenge title
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 48, weight: .semibold),
            .foregroundColor: UIColor.white
        ]
        
        let titleWidth = contentRect.width - 40
        let titleRect = CGRect(
            x: contentRect.minX + 20,
            y: daysY + daysTextSize.height + 60,
            width: titleWidth,
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
                x: contentRect.minX + 80,
                y: titleRect.maxY + 80,
                width: contentRect.width - 160,
                height: 200
            )
            
            drawQuote(quote, in: quoteRect, textColor: .white)
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
    
    private static func drawQuote(
        _ quote: Quote,
        in rect: CGRect,
        textColor: UIColor
    ) {
        // Quote text
        let quoteTextRect = CGRect(
            x: rect.minX,
            y: rect.minY,
            width: rect.width,
            height: rect.height - 40
        )
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineBreakMode = .byWordWrapping
        
        let attributedQuote = NSMutableAttributedString(
            string: "\"",
            attributes: [
                .font: UIFont.systemFont(ofSize: 60, weight: .bold),
                .foregroundColor: textColor.withAlphaComponent(0.7)
            ]
        )
        
        attributedQuote.append(NSAttributedString(
            string: "\(quote.text)",
            attributes: [
                .font: UIFont.italicSystemFont(ofSize: 32),
                .foregroundColor: textColor.withAlphaComponent(0.9),
                .paragraphStyle: paragraphStyle
            ]
        ))
        
        attributedQuote.append(NSAttributedString(
            string: "\"",
            attributes: [
                .font: UIFont.systemFont(ofSize: 60, weight: .bold),
                .foregroundColor: textColor.withAlphaComponent(0.7)
            ]
        ))
        
        attributedQuote.draw(in: quoteTextRect)
        
        // Author
        let authorText = "—\(quote.author)"
        let authorAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 24, weight: .medium),
            .foregroundColor: textColor.withAlphaComponent(0.8)
        ]
        
        let authorSize = authorText.size(withAttributes: authorAttributes)
        let authorX = rect.maxX - authorSize.width
        let authorY = quoteTextRect.maxY + 12
        
        authorText.draw(
            at: CGPoint(x: authorX, y: authorY),
            withAttributes: authorAttributes
        )
    }
    
    private static func addWatermark(context: UIGraphicsImageRendererContext, size: CGSize) {
        // Draw app branding
        let appName = "@100DaysApp"
        let watermarkAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 24, weight: .semibold),
            .foregroundColor: UIColor.white.withAlphaComponent(0.7)
        ]
        
        let watermarkSize = appName.size(withAttributes: watermarkAttributes)
        let watermarkX = size.width - watermarkSize.width - 20
        let watermarkY = size.height - watermarkSize.height - 20
        
        appName.draw(
            at: CGPoint(x: watermarkX, y: watermarkY),
            withAttributes: watermarkAttributes
        )
    }
} 