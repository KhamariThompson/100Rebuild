import SwiftUI

enum AppColors {
    static let background = Color("Background")
    static let surface = Color("Surface")
    static let primary = Color("Primary")
    static let secondary = Color("Secondary")
    static let accent = Color("Accent")
    static let text = Color("Text")
    static let subtext = Color("Subtext")
    static let error = Color("Error")
    static let success = Color("Success")
}

// MARK: - Color Assets
extension Color {
    static let theme = AppColors.self
} 