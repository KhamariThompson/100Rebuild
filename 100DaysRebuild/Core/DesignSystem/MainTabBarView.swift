import SwiftUI

struct MainTabBarView: View {
    @Binding var selectedTab: Int
    var onNewChallengeButtonTapped: () -> Void
    
    // Social tab notification badge count (optional)
    var socialBadgeCount: Int? = nil
    
    // Constants for layout
    private let tabBarHeight: CGFloat = 60
    private let fabSize: CGFloat = 56
    private let notchWidth: CGFloat = 80
    private let notchHeight: CGFloat = 32
    private let cornerRadius: CGFloat = 24
    
    // FAB constants
    private let fabIcon: String = "plus" // Direct string instead of using enum
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Custom tab bar background with notch
            TabBarBackground(notchWidth: notchWidth, notchHeight: notchHeight, cornerRadius: cornerRadius)
                .frame(height: tabBarHeight)
                .shadow(color: Color.theme.shadow.opacity(0.2), radius: 8, x: 0, y: -4)
            
            // Tab items with content
            HStack(spacing: 0) {
                // Home tab
                TabItemButton(
                    isSelected: selectedTab == 0,
                    icon: "house",
                    iconSelected: "house.fill",
                    title: "Home"
                ) {
                    selectedTab = 0
                }
                
                // Progress tab
                TabItemButton(
                    isSelected: selectedTab == 1,
                    icon: "chart.bar",
                    iconSelected: "chart.bar.fill",
                    title: "Progress"
                ) {
                    selectedTab = 1
                }
                
                // Empty space for FAB
                Spacer()
                    .frame(width: notchWidth)
                
                // Social tab with notification badge
                TabItemButton(
                    isSelected: selectedTab == 2,
                    icon: "person.2",
                    iconSelected: "person.2.fill",
                    title: "Social",
                    badgeCount: socialBadgeCount
                ) {
                    selectedTab = 2
                }
                
                // Profile tab
                TabItemButton(
                    isSelected: selectedTab == 3,
                    icon: "person",
                    iconSelected: "person.fill",
                    title: "Profile"
                ) {
                    selectedTab = 3
                }
            }
            .frame(height: tabBarHeight)
            .padding(.horizontal, 16)
            
            // Floating Action Button
            Button(action: onNewChallengeButtonTapped) {
                ZStack {
                    // Outer shadow for elevation
                    Circle()
                        .fill(Color.theme.accent)
                        .frame(width: fabSize, height: fabSize)
                        .shadow(color: Color.theme.accent.opacity(0.3), radius: 8, x: 0, y: 4)
                    
                    // Icon
                    Image(systemName: fabIcon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .offset(y: -28) // Pull up to overlap with the tab bar notch
        }
    }
}

// Tab bar item button with icon and label
struct TabItemButton: View {
    let isSelected: Bool
    let icon: String
    let iconSelected: String
    let title: String
    var badgeCount: Int? = nil
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                // Icon with potential badge
                ZStack {
                    Image(systemName: isSelected ? iconSelected : icon)
                        .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? Color.theme.accent : Color.theme.subtext)
                        .frame(height: 24) // Fixed height for icon
                    
                    // Badge overlay
                    if let count = badgeCount, count > 0 {
                        Text("\(min(count, 99))")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .frame(minWidth: 16, minHeight: 16)
                            .background(Color.red)
                            .clipShape(Circle())
                            .offset(x: 10, y: -10)
                    }
                }
                
                // Label
                Text(title)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? Color.theme.accent : Color.theme.subtext)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(TabButtonStyle())
    }
}

// Custom background shape for tab bar with notch
struct TabBarBackground: View {
    let notchWidth: CGFloat
    let notchHeight: CGFloat
    let cornerRadius: CGFloat
    
    var body: some View {
        TabBarShape(
            notchWidth: notchWidth,
            notchHeight: notchHeight,
            cornerRadius: cornerRadius
        )
        .fill(
            // Use blur material for a modern look
            Material.regularMaterial
        )
        .overlay(
            // Add thin border at the top
            TabBarShape(
                notchWidth: notchWidth,
                notchHeight: notchHeight,
                cornerRadius: cornerRadius
            )
            .stroke(Color.theme.border.opacity(0.3), lineWidth: 0.5)
        )
    }
}

// Custom shape for tab bar with center notch
struct TabBarShape: Shape {
    let notchWidth: CGFloat
    let notchHeight: CGFloat
    let cornerRadius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        let width = rect.width
        let height = rect.height
        
        // Calculate notch position
        let notchX = (width - notchWidth) / 2
        
        var path = Path()
        
        // Start from top left
        path.move(to: CGPoint(x: 0, y: cornerRadius))
        
        // Top left corner
        path.addArc(
            center: CGPoint(x: cornerRadius, y: cornerRadius),
            radius: cornerRadius,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )
        
        // Top edge left of notch
        path.addLine(to: CGPoint(x: notchX, y: 0))
        
        // Notch curve up (left side)
        path.addCurve(
            to: CGPoint(x: notchX + (notchWidth / 2), y: -notchHeight),
            control1: CGPoint(x: notchX + (notchWidth * 0.2), y: 0),
            control2: CGPoint(x: notchX + (notchWidth * 0.3), y: -notchHeight)
        )
        
        // Notch curve down (right side)
        path.addCurve(
            to: CGPoint(x: notchX + notchWidth, y: 0),
            control1: CGPoint(x: notchX + (notchWidth * 0.7), y: -notchHeight),
            control2: CGPoint(x: notchX + (notchWidth * 0.8), y: 0)
        )
        
        // Top edge right of notch
        path.addLine(to: CGPoint(x: width - cornerRadius, y: 0))
        
        // Top right corner
        path.addArc(
            center: CGPoint(x: width - cornerRadius, y: cornerRadius),
            radius: cornerRadius,
            startAngle: .degrees(270),
            endAngle: .degrees(0),
            clockwise: false
        )
        
        // Right edge
        path.addLine(to: CGPoint(x: width, y: height))
        
        // Bottom edge
        path.addLine(to: CGPoint(x: 0, y: height))
        
        // Left edge
        path.addLine(to: CGPoint(x: 0, y: cornerRadius))
        
        return path
    }
}

// Button style for tab bar items with spring effect on press
struct TabButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// Preview
struct MainTabBarView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray.opacity(0.2).ignoresSafeArea()
            
            VStack {
                Spacer()
                MainTabBarView(
                    selectedTab: .constant(0),
                    onNewChallengeButtonTapped: {},
                    socialBadgeCount: 3
                )
            }
        }
    }
} 