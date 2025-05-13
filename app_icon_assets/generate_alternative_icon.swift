import SwiftUI

struct AlternativeAppIcon: View {
    let size: CGFloat = 1024 // Standard App Store icon size
    
    var body: some View {
        ZStack {
            // Solid color background that fills the entire space
            Color(hex: "#4361EE") // Primary app color
                .frame(width: size, height: size)
            
            // Main content
            VStack(spacing: size * 0.05) {
                // Large "100" text
                Text("100")
                    .font(.system(size: size * 0.4, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                
                // "DAYS" text underneath
                Text("DAYS")
                    .font(.system(size: size * 0.15, weight: .heavy, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.top, -size * 0.05)
                
                // Small checkmark indicator
                Image(systemName: "checkmark.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.white)
                    .frame(width: size * 0.15, height: size * 0.15)
                    .padding(.top, size * 0.02)
            }
        }
        .frame(width: size, height: size)
        // iOS-style rounded corners
        .clipShape(RoundedRectangle(cornerRadius: size * 0.225))
    }
}

// Color extension to support hex values
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

// Preview for Xcode
struct AlternativeAppIcon_Previews: PreviewProvider {
    static var previews: some View {
        AlternativeAppIcon()
            .previewLayout(.fixed(width: 200, height: 200))
    }
}

/*
Instructions to use this app icon:

1. Run this file in Xcode or Swift Playgrounds
2. Take a screenshot of the preview at 1024x1024 resolution
3. Use the image as your app icon in the AppIcon.appiconset folder
4. Make sure to replace all sizes in the asset catalog

Alternative: Export this as a 1024x1024 PNG and use a tool like appicon.co
to generate all required icon sizes automatically.
*/ 