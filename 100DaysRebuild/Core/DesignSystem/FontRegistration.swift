import SwiftUI
import UIKit
import CoreText

/// Utility for registering custom fonts with the system
public enum FontRegistration {
    
    /// Register all custom fonts used in the app
    /// Call this method once at app startup
    public static func registerFonts() {
        // Log that font registration was called
        print("FontRegistration: Registering custom fonts")
        
        // This is where you would register custom fonts from your bundle
        // For now, we don't have any custom fonts to register, so this is a placeholder
        
        // Example of how to register a custom font:
        // registerFont(withName: "CustomFont-Regular", withExtension: "ttf")
    }
    
    /// Register a specific font with the system
    /// - Parameters:
    ///   - name: The name of the font file without extension
    ///   - fileExtension: The file extension (ttf, otf)
    private static func registerFont(withName name: String, withExtension fileExtension: String) {
        guard let fontURL = Bundle.main.url(forResource: name, withExtension: fileExtension),
              let fontDataProvider = CGDataProvider(url: fontURL as CFURL),
              let font = CGFont(fontDataProvider) else {
            print("FontRegistration: Failed to load font \(name).\(fileExtension)")
            return
        }
        
        var error: Unmanaged<CFError>?
        if !CTFontManagerRegisterGraphicsFont(font, &error) {
            print("FontRegistration: Failed to register font \(name).\(fileExtension)")
            if let error = error?.takeRetainedValue() {
                print("FontRegistration: Error: \(error)")
            }
        } else {
            print("FontRegistration: Successfully registered font \(name).\(fileExtension)")
        }
    }
    
    /// List all available font names in the app
    /// Useful for debugging font issues
    public static func listAvailableFonts() {
        let fontFamilies = UIFont.familyNames.sorted()
        
        print("FontRegistration: === Available Font Families ===")
        for family in fontFamilies {
            print("FontRegistration: • \(family)")
            let names = UIFont.fontNames(forFamilyName: family).sorted()
            for name in names {
                print("FontRegistration:   - \(name)")
            }
        }
        print("FontRegistration: === End of Font List ===")
    }
} 