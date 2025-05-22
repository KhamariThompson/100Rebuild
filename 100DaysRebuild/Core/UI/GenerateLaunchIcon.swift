import SwiftUI
import UIKit

/// Helper utility to generate the LaunchIcon programmatically
/// This can be called from a debug menu or during development
class LaunchIconUtil {
    
    /// Generate and save the LaunchIcon
    static func generateAndSaveLaunchIcon() {
        // Create the icon
        let iconView = LaunchIconGenerator()
        
        // Generate images at different scales
        let sizes = [
            ("1x", CGSize(width: 300, height: 300)),
            ("2x", CGSize(width: 600, height: 600)),
            ("3x", CGSize(width: 900, height: 900))
        ]
        
        for (scale, size) in sizes {
            // Generate image
            let image = iconView.asImage(size: size)
            
            // Get the image data
            if let imageData = image.pngData() {
                // Determine the filename
                let filename = "LaunchIcon\(scale == "1x" ? "" : "@\(scale)").png"
                
                // Find the path to the Assets.xcassets directory
                guard let assetCatalogURL = Bundle.main.url(forResource: "Assets", withExtension: "xcassets") else {
                    print("Could not find Assets.xcassets")
                    continue
                }
                
                // Create the URL for the image
                let imageURL = assetCatalogURL
                    .appendingPathComponent("LaunchIcon.imageset")
                    .appendingPathComponent(filename)
                
                // Save the image data to the file
                do {
                    try imageData.write(to: imageURL)
                    print("Saved \(filename) to \(imageURL.path)")
                } catch {
                    print("Failed to save \(filename): \(error.localizedDescription)")
                }
            }
        }
    }
}

#if DEBUG
// Automatically generate the launch icon when the app is run in DEBUG mode
extension LaunchIconUtil {
    static func autoGenerateOnFirstLaunch() {
        let defaults = UserDefaults.standard
        let key = "hasGeneratedLaunchIcon"
        
        if !defaults.bool(forKey: key) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                generateAndSaveLaunchIcon()
                defaults.set(true, forKey: key)
            }
        }
    }
}
#endif 