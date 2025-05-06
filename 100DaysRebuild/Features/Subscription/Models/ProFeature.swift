import Foundation

public struct ProFeature: Identifiable {
    public let id = UUID()
    public let icon: String
    public let title: String
    public let description: String
    public let section: ProFeatureSection
    
    public init(icon: String, title: String, description: String, section: ProFeatureSection) {
        self.icon = icon
        self.title = title
        self.description = description
        self.section = section
    }
}

public enum ProFeatureSection: String, CaseIterable {
    case unlockPotential = "🔓 Unlock Your Potential"
    case levelUp = "🤝 Level Up Together"
    case stayMotivated = "🎯 Stay Motivated"
} 