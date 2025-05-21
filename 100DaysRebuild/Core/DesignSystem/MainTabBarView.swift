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
    private let fabIcon: String = TabBarIcons.plus
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Custom tab bar background with notch
            TabBarBackground(notchWidth: notchWidth, notchHeight: notchHeight, cornerRadius: cornerRadius)
                .fill(
                    Color.theme.surface.opacity(0.98)
                )
                .shadow(color: Color.theme.shadow.opacity(0.15), radius: 8, x: 0, y: -3)
                .frame(height: tabBarHeight)
            
            // Tab items
            HStack(spacing: 0) {
                // Left tabs
                HStack(spacing: 0) {
                    tabButton(tab: 0, title: "Home", 
                             icon: TabBarIcons.homeOutline, 
                             activeIcon: TabBarIcons.home)
                    
                    tabButton(tab: 1, title: "Progress", 
                             icon: TabBarIcons.insightsOutline, 
                             activeIcon: TabBarIcons.insights)
                }
                .frame(maxWidth: .infinity)
                
                // Center spacer for FAB
                Spacer()
                    .frame(width: notchWidth)
                
                // Right tabs
                HStack(spacing: 0) {
                    tabButton(tab: 2, title: "Social", 
                             icon: TabBarIcons.socialOutline, 
                             activeIcon: TabBarIcons.social,
                             badgeCount: socialBadgeCount)
                    
                    tabButton(tab: 3, title: "Profile", 
                             icon: TabBarIcons.profileOutline, 
                             activeIcon: TabBarIcons.profile)
                }
                .frame(maxWidth: .infinity)
            }
            .frame(height: tabBarHeight)
            .padding(.horizontal, 16)
            
            // Floating action button using our enhanced component
            FloatingActionButton(
                icon: fabIcon,
                size: fabSize,
                action: onNewChallengeButtonTapped
            )
            .offset(y: -notchHeight / 2)
        }
        .edgesIgnoringSafeArea(.bottom)
    }
    
    // Tab button with custom TabBarIcon
    private func tabButton(tab: Int, title: String, icon: String, activeIcon: String, badgeCount: Int? = nil) -> some View {
        Button(action: {
            if selectedTab != tab {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedTab = tab
                }
                // Provide haptic feedback when changing tabs
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            }
        }) {
            TabBarIcon(
                isSelected: selectedTab == tab,
                icon: icon,
                activeIcon: activeIcon,
                title: title
            )
            .withBadge(badgeCount)
        }
        .buttonStyle(TabButtonStyle())
    }
}

// Custom button style for tab buttons to handle press animation
struct TabButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

// Custom shape for the tab bar with a center notch
struct TabBarBackground: Shape {
    let notchWidth: CGFloat
    let notchHeight: CGFloat
    let cornerRadius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        let width = rect.width
        let height = rect.height
        let centerX = width / 2
        let notchStartX = centerX - notchWidth / 2
        let notchEndX = centerX + notchWidth / 2
        
        var path = Path()
        
        // Start at top left with corner radius
        path.move(to: CGPoint(x: cornerRadius, y: 0))
        
        // Top edge to notch start
        path.addLine(to: CGPoint(x: notchStartX, y: 0))
        
        // Notch curve (smoother than a straight cut)
        path.addCurve(
            to: CGPoint(x: notchEndX, y: 0),
            control1: CGPoint(x: notchStartX + notchWidth * 0.3, y: notchHeight),
            control2: CGPoint(x: notchEndX - notchWidth * 0.3, y: notchHeight)
        )
        
        // Top edge from notch end to top right corner
        path.addLine(to: CGPoint(x: width - cornerRadius, y: 0))
        
        // Top right corner
        path.addArc(
            center: CGPoint(x: width - cornerRadius, y: cornerRadius),
            radius: cornerRadius,
            startAngle: Angle(degrees: -90),
            endAngle: Angle(degrees: 0),
            clockwise: false
        )
        
        // Right edge
        path.addLine(to: CGPoint(x: width, y: height - cornerRadius))
        
        // Bottom right corner
        path.addArc(
            center: CGPoint(x: width - cornerRadius, y: height - cornerRadius),
            radius: cornerRadius,
            startAngle: Angle(degrees: 0),
            endAngle: Angle(degrees: 90),
            clockwise: false
        )
        
        // Bottom edge
        path.addLine(to: CGPoint(x: cornerRadius, y: height))
        
        // Bottom left corner
        path.addArc(
            center: CGPoint(x: cornerRadius, y: height - cornerRadius),
            radius: cornerRadius,
            startAngle: Angle(degrees: 90),
            endAngle: Angle(degrees: 180),
            clockwise: false
        )
        
        // Left edge
        path.addLine(to: CGPoint(x: 0, y: cornerRadius))
        
        // Top left corner
        path.addArc(
            center: CGPoint(x: cornerRadius, y: cornerRadius),
            radius: cornerRadius,
            startAngle: Angle(degrees: 180),
            endAngle: Angle(degrees: 270),
            clockwise: false
        )
        
        path.closeSubpath()
        return path
    }
}

// Preview
struct MainTabBarView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ZStack {
                Color.theme.background.edgesIgnoringSafeArea(.all)
                
                VStack {
                    Spacer()
                    MainTabBarView(
                        selectedTab: .constant(0),
                        onNewChallengeButtonTapped: {},
                        socialBadgeCount: 3
                    )
                }
            }
            .previewDisplayName("Light Mode")
            
            ZStack {
                Color.theme.background.edgesIgnoringSafeArea(.all)
                
                VStack {
                    Spacer()
                    MainTabBarView(
                        selectedTab: .constant(2),
                        onNewChallengeButtonTapped: {},
                        socialBadgeCount: 3
                    )
                }
            }
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")
        }
    }
} 