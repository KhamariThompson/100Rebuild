import SwiftUI

struct AppIcon: View {
    let size: CGFloat = 1024 // Standard App Store icon size
    
    var body: some View {
        ZStack {
            // Background with gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "#4361EE"), // Primary blue
                    Color(hex: "#3F37C9")  // Darker blue
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Circle background for checkmark
            Circle()
                .fill(Color.white.opacity(0.15))
                .frame(width: size * 0.75, height: size * 0.75)
            
            // Checkmark symbol
            Image(systemName: "checkmark.circle.fill")
                .resizable()
                .scaledToFit()
                .foregroundColor(.white)
                .frame(width: size * 0.6, height: size * 0.6)
                .shadow(color: Color.black.opacity(0.2), radius: 15, x: 0, y: 10)
            
            // Text at the bottom
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
        // iOS-style rounded corners - no border
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
struct AppIcon_Previews: PreviewProvider {
    static var previews: some View {
        AppIcon()
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