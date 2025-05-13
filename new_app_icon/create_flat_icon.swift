import SwiftUI

// This script creates a modern, flat-style app icon without borders
// Run this with Swift Playgrounds or in Xcode

// MARK: - App Icon Generation

struct FlatAppIconGenerator {
    // Define the icon size (1024x1024 is standard for App Store)
    static let size: CGFloat = 1024
    
    // Generate the app icon
    static func generateAppIcon() -> some View {
        ZStack {
            // Solid color background
            Color(hex: "#4361EE") // Primary app color (blue)
                .frame(width: size, height: size)
            
            // Center content
            VStack(spacing: size * 0.05) {
                // Large "100" number
                Text("100")
                    .font(.system(size: size * 0.4, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                
                // "DAYS" text
                Text("DAYS")
                    .font(.system(size: size * 0.18, weight: .heavy, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
                    .tracking(size * 0.01) // Letter spacing
                
                // Checkmark indicator
                Image(systemName: "checkmark.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.white)
                    .frame(width: size * 0.2, height: size * 0.2)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.225)) // iOS app icons have rounded corners
    }
}

// MARK: - Helper Extension for Color from Hex
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        
        switch hex.count {
        case 3: // RGB (12-bit)
            (r, g, b) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (1, 1, 1)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255
        )
    }
}

// MARK: - Preview
struct FlatAppIconPreview: PreviewProvider {
    static var previews: some View {
        Group {
            // Main preview
            FlatAppIconGenerator.generateAppIcon()
                .previewLayout(.fixed(width: 200, height: 200))
                .previewDisplayName("App Icon")
            
            // Small size preview (to check clarity at small sizes)
            FlatAppIconGenerator.generateAppIcon()
                .previewLayout(.fixed(width: 60, height: 60))
                .previewDisplayName("Small Icon")
        }
    }
}

// MARK: - How to export this image
/*
 To use this icon:
 
 1. Run this in Xcode or Swift Playgrounds
 2. Take a screenshot of the preview (make sure it's clean and exact)
 3. Open the screenshot in Preview or Photoshop
 4. Crop it to exactly 1024x1024 pixels
 5. Export as PNG
 6. Replace the Icon-1024.png file in your Assets.xcassets/AppIcon.appiconset folder
 
 Or use an app icon generator tool online to create all required sizes:
 - Upload the exported 1024x1024 image to https://appicon.co/ or similar tool
 - Download the generated iconset
 - Replace your existing AppIcon.appiconset folder
 */ 