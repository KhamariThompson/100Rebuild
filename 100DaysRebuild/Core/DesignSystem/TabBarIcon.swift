import SwiftUI

struct TabBarIcon: View {
    let isSelected: Bool
    let icon: String
    let activeIcon: String
    let title: String
    
    // Animation properties
    @State private var iconOffset: CGFloat = 0
    @State private var titleOpacity: Double = 0
    @State private var iconScale: CGFloat = 1.0
    @State private var badgeCount: Int? = nil
    
    // Constants
    private let iconSize: CGFloat = 22
    private let selectedIconSize: CGFloat = 24
    private let selectedTextSize: CGFloat = 11
    private let textSize: CGFloat = 10
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // Background indicator for selected state
                if isSelected {
                    Circle()
                        .fill(Color.theme.accent.opacity(0.12))
                        .frame(width: 36, height: 36)
                        .scaleEffect(iconScale)
                }
                
                // Icon
                Image(systemName: isSelected ? activeIcon : icon)
                    .font(.system(size: isSelected ? selectedIconSize : iconSize, 
                                 weight: isSelected ? .semibold : .regular,
                                 design: .rounded))
                    .foregroundColor(isSelected ? Color.theme.accent : Color.theme.subtext)
                    .offset(y: iconOffset)
                    .scaleEffect(iconScale)
                
                // Optional badge (for notification counts)
                if let count = badgeCount, count > 0 {
                    ZStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 16, height: 16)
                        
                        if count < 10 {
                            Text("\(count)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                        } else {
                            Text("9+")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .offset(x: 12, y: -10)
                    .opacity(isSelected ? 0.8 : 1.0)
                }
            }
            .frame(height: 36)
            
            // Title
            Text(title)
                .font(.system(size: isSelected ? selectedTextSize : textSize, 
                             weight: isSelected ? .medium : .regular,
                             design: .rounded))
                .foregroundColor(isSelected ? Color.theme.accent : Color.theme.subtext)
                .opacity(titleOpacity)
        }
        .frame(maxWidth: .infinity)
        .onChange(of: isSelected) { oldValue, newValue in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                iconOffset = newValue ? -4 : 0
                titleOpacity = newValue ? 1.0 : 0.7
                iconScale = newValue ? 1.1 : 1.0
            }
        }
        .onAppear {
            // Set initial values without animation
            iconOffset = isSelected ? -4 : 0
            titleOpacity = isSelected ? 1.0 : 0.7
            iconScale = isSelected ? 1.1 : 1.0
        }
    }
    
    // Function to set badge count (can be called from parent)
    func withBadge(_ count: Int?) -> Self {
        var copy = self
        copy.badgeCount = count
        return copy
    }
}

// Set of custom icons for a more premium look
enum TabBarIcons {
    // Home tab
    static let home = "house.fill"
    static let homeOutline = "house"
    
    // Progress tab
    static let progress = "chart.bar.fill"
    static let progressOutline = "chart.bar"
    
    // Alternative progress icons
    static let insights = "chart.line.uptrend.xyaxis"
    static let insightsOutline = "chart.line.uptrend.xyaxis"
    
    // Social tab
    static let social = "person.2.fill"
    static let socialOutline = "person.2"
    
    // Alternative social icons
    static let community = "person.3.fill"
    static let communityOutline = "person.3"
    
    // Profile tab
    static let profile = "person.crop.circle.fill"
    static let profileOutline = "person.crop.circle"
    
    // Plus button icon options
    static let plus = "plus"
    static let plusCircle = "plus.circle.fill"
    static let plusSquare = "plus.square.fill"
    static let sparkle = "sparkles"
    
    // Challenge tab
    static let challenge = "flag.fill"
    static let challengeOutline = "flag"
    
    // Analytics tab
    static let analytics = "chart.pie.fill"
    static let analyticsOutline = "chart.pie"
    
    // Settings options
    static let settings = "gearshape.fill"
    static let settingsOutline = "gearshape"
}

// Preview
struct TabBarIcon_Previews: PreviewProvider {
    static var previews: some View {
        HStack {
            TabBarIcon(isSelected: true, 
                      icon: TabBarIcons.homeOutline, 
                      activeIcon: TabBarIcons.home, 
                      title: "Home")
            
            TabBarIcon(isSelected: false, 
                      icon: TabBarIcons.progressOutline, 
                      activeIcon: TabBarIcons.progress, 
                      title: "Progress")
            
            TabBarIcon(isSelected: false, 
                      icon: TabBarIcons.socialOutline, 
                      activeIcon: TabBarIcons.social, 
                      title: "Social")
                .withBadge(3)
            
            TabBarIcon(isSelected: false, 
                      icon: TabBarIcons.profileOutline, 
                      activeIcon: TabBarIcons.profile, 
                      title: "Profile")
        }
        .padding()
        .background(Color.theme.surface)
        .previewLayout(.sizeThatFits)
    }
} 