import SwiftUI

/// Wrapper view to preview content with different theme settings
public struct ThemePreviewWrapper<Content: View>: View {
    let content: Content
    let theme: AppThemeMode
    
    public init(theme: AppThemeMode, @ViewBuilder content: () -> Content) {
        self.theme = theme
        self.content = content()
    }
    
    public var body: some View {
        content
            .onAppear {
                // Set the theme for this preview
                ThemeManager.shared.setTheme(theme)
            }
            .withAppTheme()
    }
}

/// Helper extension for PreviewProvider to easily add theme variations
public extension PreviewProvider {
    /// Generate previews with all theme options (light, dark, system)
    /// - Parameters:
    ///   - title: Optional title to display above each preview
    ///   - deviceType: Optional device type to use for the preview
    ///   - content: View builder for the content to preview
    /// - Returns: Array of previews, one for each theme
    static func themeVariants<Content: View>(
        title: String? = nil,
        device: PreviewDevice? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        Group {
            ForEach(AppThemeMode.allCases) { theme in
                VStack {
                    if let title = title {
                        Text("\(title) - \(theme.displayName) Theme")
                            .font(.caption)
                            .padding(5)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gray.opacity(0.2))
                            )
                    }
                    
                    ThemePreviewWrapper(theme: theme) {
                        content()
                    }
                }
                .previewDisplayName("\(theme.displayName) Theme")
                .previewDevice(device)
            }
        }
    }
    
    /// Generate previews for light and dark themes (skips system)
    /// - Parameters:
    ///   - title: Optional title to display above each preview
    ///   - deviceType: Optional device type to use for the preview
    ///   - content: View builder for the content to preview
    /// - Returns: Array of previews for light and dark themes
    static func lightDarkVariants<Content: View>(
        title: String? = nil,
        device: PreviewDevice? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        Group {
            VStack {
                if let title = title {
                    Text("\(title) - Light")
                        .font(.caption)
                        .padding(5)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                        )
                }
                
                ThemePreviewWrapper(theme: .light) {
                    content()
                }
            }
            .previewDisplayName("Light Theme")
            .previewDevice(device)
            
            VStack {
                if let title = title {
                    Text("\(title) - Dark")
                        .font(.caption)
                        .padding(5)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                        )
                }
                
                ThemePreviewWrapper(theme: .dark) {
                    content()
                }
            }
            .previewDisplayName("Dark Theme")
            .previewDevice(device)
        }
    }
}

// Example preview usage (commented out)
/*
struct ThemePreviewDemo_Previews: PreviewProvider {
    static var previews: some View {
        themeVariants(title: "Button Example") {
            Button("Hello World") {
                print("Button tapped")
            }
            .padding()
            .background(Color.theme.accent)
            .foregroundColor(.white)
            .cornerRadius(8)
            .themeShadow()
        }
    }
}
*/ 