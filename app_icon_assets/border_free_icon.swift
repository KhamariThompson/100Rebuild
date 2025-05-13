import SwiftUI

struct BorderFreeIcon: View {
    let size: CGFloat = 1024 // Standard size
    
    var body: some View {
        // Using GeometryReader to make sure we fully occupy all available space
        GeometryReader { geometry in
            // Content that completely fills the space with no padding
            ZStack {
                // Background that extends to all edges
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(hex: "#3A0CA3"), // Deep purple
                                Color(hex: "#4361EE")  // Blue
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Large text that dominates the icon
                Text("100")
                    .font(.system(size: geometry.size.width * 0.6, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .offset(y: -geometry.size.height * 0.05)
                
                // Bottom text centered horizontally
                VStack {
                    Spacer()
                    Text("DAYS")
                        .font(.system(size: geometry.size.width * 0.2, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .tracking(5) // Letter spacing
                        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 2)
                    
                    // Push to the bottom with a little padding
                    Spacer().frame(height: geometry.size.height * 0.1)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipShape(RoundedRectangle(cornerRadius: geometry.size.width * 0.225))
            .edgesIgnoringSafeArea(.all)
        }
        .frame(width: size, height: size)
    }
}

// Hex color extension
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

struct BorderFreeIcon_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Regular preview
            BorderFreeIcon()
                .previewLayout(.fixed(width: 200, height: 200))
                .previewDisplayName("App Icon")
            
            // Phone icon size preview
            BorderFreeIcon()
                .previewLayout(.fixed(width: 60, height: 60))
                .previewDisplayName("Small Size")
        }
    }
}

/*
COMPLETE APP ICON IMPLEMENTATION STEPS:

1. Completely delete the app from your phone first
2. In Xcode, run this file and take a screenshot of the preview
3. Make sure it's EXACTLY 1024x1024 pixels with no transparency
4. Replace your current app icon:
   - 100DaysRebuild/Assets.xcassets/AppIcon.appiconset/Icon-1024.png

5. For best results:
   - Clean your build folder in Xcode (⇧⌘K then ⌥⇧⌘K)
   - Go to Product > Clean Build Folder
   - Delete derived data: ~/Library/Developer/Xcode/DerivedData
   - Use appicon.co to generate all icon sizes
   - Replace the entire AppIcon.appiconset folder

6. Build and install the app again
*/ 