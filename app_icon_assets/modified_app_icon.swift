import SwiftUI

struct FullScreenAppIcon: View {
    let size: CGFloat = 1024 // Standard App Store icon size
    
    var body: some View {
        // Create a container with the exact dimensions
        ZStack {
            // This rectangle will fill the entire icon space with no borders
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(hex: "#4361EE"), // Primary blue
                            Color(hex: "#3F37C9")  // Darker blue
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
            
            // Central element - larger circle that extends to the edges
            Circle()
                .fill(Color.white.opacity(0.12))
                .frame(width: size * 0.85, height: size * 0.85)
            
            // Centered content
            VStack(spacing: 0) {
                // Large "100" text
                Text("100")
                    .font(.system(size: size * 0.45, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                
                // Smaller "DAYS" text
                Text("DAYS")
                    .font(.system(size: size * 0.15, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.top, -size * 0.05)
                
                // Checkmark at the bottom
                Image(systemName: "checkmark.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.white)
                    .frame(width: size * 0.18, height: size * 0.18)
                    .padding(.top, size * 0.03)
            }
        }
        .frame(width: size, height: size)
        // iOS standard corner radius - but the entire content is filled
        .clipShape(RoundedRectangle(cornerRadius: size * 0.225))
    }
}

// Helper extension for hex colors
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

// Preview
struct FullScreenAppIcon_Previews: PreviewProvider {
    static var previews: some View {
        FullScreenAppIcon()
            .previewLayout(.fixed(width: 200, height: 200))
            .previewDisplayName("Full Screen App Icon")
    }
}

/*
INSTRUCTIONS FOR IMPLEMENTATION:

1. Run this file in Xcode and take a screenshot of the preview
2. Make sure it's EXACTLY 1024x1024 pixels
3. Export as PNG with no transparency 
4. Replace your current app icon in:
   - 100DaysRebuild/Assets.xcassets/AppIcon.appiconset/Icon-1024.png

IMPORTANT: Make sure to:
- Delete the app from your phone first
- Clean your Xcode build folder (Cmd+Shift+K, then Opt+Cmd+Shift+K)
- Build and install the app again

For optimal results:
- Use an app icon generator tool like appicon.co to generate ALL required sizes
- Replace the entire AppIcon.appiconset folder
*/ 