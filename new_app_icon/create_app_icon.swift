import SwiftUI

// This script programmatically creates a perfect fit app icon without any border issues
// Run this with Swift Playgrounds or in Xcode

// MARK: - App Icon Generation

struct AppIconGenerator {
    // Define the icon size (1024x1024 is standard for App Store)
    static let size: CGFloat = 1024
    
    // Generate the app icon
    static func generateAppIcon() -> some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "#4361EE"), // Primary blue
                    Color(hex: "#3F37C9")  // Darker blue
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(width: size, height: size)
            
            // Checkmark circle symbol
            Circle()
                .fill(Color.white.opacity(0.15))
                .frame(width: size * 0.75, height: size * 0.75)
            
            Image(systemName: "checkmark.circle.fill")
                .resizable()
                .scaledToFit()
                .foregroundColor(.white)
                .frame(width: size * 0.6, height: size * 0.6)
                .shadow(color: Color.black.opacity(0.2), radius: 15, x: 0, y: 10)
            
            // Optional: Add text at the bottom
            VStack {
                Spacer()
                Text("100DAYS")
                    .font(.system(size: size * 0.12, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 3)
                    .padding(.bottom, size * 0.10)
            }
            .frame(width: size, height: size)
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
struct AppIconPreview: PreviewProvider {
    static var previews: some View {
        AppIconGenerator.generateAppIcon()
            .previewLayout(.fixed(width: 200, height: 200))
            .previewDisplayName("App Icon")
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