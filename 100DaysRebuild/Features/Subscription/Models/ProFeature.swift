import Foundation

struct ProFeature: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
    let section: ProFeatureSection
}

enum ProFeatureSection: String, CaseIterable {
    case unlockPotential = "🔓 Unlock Your Potential"
    case levelUp = "🤝 Level Up Together"
    case stayMotivated = "🎯 Stay Motivated"
} 