import SwiftUI
import Foundation

/// Feature row component for displaying feature lists
public struct FeatureRow: View {
    let icon: String?
    let title: String
    let description: String?
    
    public init(icon: String, title: String) {
        self.icon = icon
        self.title = title
        self.description = nil
    }
    
    public init(icon: String, title: String, description: String?) {
        self.icon = icon
        self.title = title
        self.description = description
    }
    
    public var body: some View {
        HStack(spacing: 16) {
            if let icon = icon {
                Text(icon)
                    .font(.title2)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.theme.text)
                
                if let description = description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.theme.subtext)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.theme.surface)
        )
    }
} 