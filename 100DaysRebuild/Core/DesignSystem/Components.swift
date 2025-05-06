import SwiftUI
import Foundation

/// Collection of reusable UI components for consistent application styling
public enum AppComponents {
    
    /// Standard card container with shadowed background
    public struct Card<Content: View>: View {
        let content: Content
        
        public init(@ViewBuilder content: () -> Content) {
            self.content = content()
        }
        
        public var body: some View {
            content
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.theme.surface)
                        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                )
        }
    }
    
    /// Divider with standard styling
    public struct AppDivider: View {
        public init() {}
        
        public var body: some View {
            Divider()
                .background(Color.theme.subtext.opacity(0.3))
                .padding(.vertical, 8)
        }
    }
    
    /// Badge component for status indicators
    public struct Badge: View {
        let text: String
        let color: Color
        
        public init(text: String, color: Color = Color.theme.accent) {
            self.text = text
            self.color = color
        }
        
        public var body: some View {
            Text(text)
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color)
                )
        }
    }
} 