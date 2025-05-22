import SwiftUI

/// A view for generating the app's launch icon programmatically.
/// This can be rendered to an image and exported to the asset catalog.
struct LaunchIconGenerator: View {
    var body: some View {
        ZStack {
            // Background - clear to use the background color from Info.plist
            Color.clear
            
            // Circle with gradient
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.27, green: 0.47, blue: 0.9), // Primary accent color
                            Color(red: 0.34, green: 0.56, blue: 0.98)  // Lighter variant
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 180, height: 180)
                .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
            
            // Checkmark
            Image(systemName: "checkmark")
                .font(.system(size: 90, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(width: 300, height: 300)
        .background(Color.clear)
    }
}

#Preview {
    LaunchIconGenerator()
        .previewLayout(.sizeThatFits)
        .padding()
        .background(Color.black.opacity(0.1))
}

// Helper function to export the view as an image if needed
extension View {
    func asImage(size: CGSize) -> UIImage {
        let controller = UIHostingController(rootView: self)
        controller.view.bounds = CGRect(origin: .zero, size: size)
        controller.view.backgroundColor = .clear
        
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }
} 