import SwiftUI

struct MainTabBarView: View {
    @Binding var selectedTab: Int
    @EnvironmentObject var router: NavigationRouter
    var onNewChallengeButtonTapped: () -> Void
    var socialBadgeCount: Int?
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        // Base container
        ZStack(alignment: .top) {
            // Divider at the top
            Divider()
                .frame(height: 0.5)
                .background(Color.theme.border)
                .opacity(0.5)
            
            // Main tab bar content
            HStack(spacing: 0) {
                // Home tab
                tabButton(
                    icon: "house.fill",
                    label: "Home",
                    isSelected: selectedTab == 0,
                    action: { selectTab(0) }
                )
                
                // Progress tab
                tabButton(
                    icon: "chart.line.uptrend.xyaxis",
                    label: "Progress",
                    isSelected: selectedTab == 1,
                    action: { selectTab(1) }
                )
                
                // Center add button
                Spacer()
                    .frame(width: 65)
                
                // Social tab with optional badge
                tabButton(
                    icon: "person.2.fill",
                    label: "Social",
                    isSelected: selectedTab == 2,
                    badge: socialBadgeCount,
                    action: { selectTab(2) }
                )
                
                // Profile tab
                tabButton(
                    icon: "person.crop.circle.fill",
                    label: "Profile",
                    isSelected: selectedTab == 3,
                    action: { selectTab(3) }
                )
            }
            .padding(.top, 8)
            .padding(.bottom, 30) // Extra padding for bottom safe area
            .frame(maxWidth: .infinity)
            .background(tabBarBackground)
            
            // Enhanced floating action button for new challenge
            Button(action: onNewChallengeButtonTapped) {
                ZStack {
                    // Outer glow effect
                    Circle()
                        .fill(
                            colorScheme == .light 
                                ? Color.black.opacity(0.1) 
                                : Color.white.opacity(0.15)
                        )
                        .frame(width: 64, height: 64)
                        .blur(radius: 4)
                    
                    // Main button background
                    Circle()
                        .fill(
                            colorScheme == .light
                                ? LinearGradient( // Black gradient in light mode
                                    gradient: Gradient(colors: [
                                        Color.black,
                                        Color.black.opacity(0.9)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient( // Silver/chrome gradient in dark mode
                                    gradient: Gradient(colors: [
                                        Color.white,
                                        Color.white.opacity(0.85)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                        )
                        .frame(width: 56, height: 56)
                        .shadow(
                            color: colorScheme == .light 
                                ? Color.black.opacity(0.25) 
                                : Color.white.opacity(0.3),
                            radius: 8, 
                            x: 0, 
                            y: 4
                        )
                    
                    // Plus icon with contrast
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(colorScheme == .light ? .white : .black)
                }
                .scaleEffect(1.0)
                .shadow(
                    color: colorScheme == .light
                        ? Color.black.opacity(0.2)
                        : Color.white.opacity(0.15),
                    radius: 4,
                    x: 0,
                    y: 2
                )
            }
            .buttonStyle(FloatingButtonStyle())
            .offset(y: -10) // Slightly move up for overlap effect
        }
        .background(Color.clear) // Ensure background is clear
    }
    
    // Helper method to select a tab with proper transition handling
    private func selectTab(_ index: Int) {
        guard selectedTab != index else { return }
        
        // Use the router's controlled transition to prevent flickering
        withAnimation(.easeInOut(duration: 0.2)) {
            router.changeTab(to: index)
        }
        
        // Provide haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    // Consistent tab bar background
    private var tabBarBackground: some View {
        Color.theme.surface
            .shadow(color: Color.theme.shadow.opacity(0.1), radius: 8, x: 0, y: -4)
            .edgesIgnoringSafeArea(.bottom)
    }
    
    // Tab button with consistent animations
    private func tabButton(
        icon: String,
        label: String,
        isSelected: Bool,
        badge: Int? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    // Badge if needed
                    if let badge = badge, badge > 0 {
                        ZStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 18, height: 18)
                                .overlay(
                                    Text("\(min(badge, 99))")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                )
                        }
                        .offset(x: 10, y: -10)
                        .zIndex(10)
                    }
                    
                    // Tab icon
                    Image(systemName: icon)
                        .font(.system(size: isSelected ? 22 : 20, weight: .semibold))
                        .foregroundColor(isSelected ? Color.theme.accent : Color.theme.subtext)
                        .frame(height: 24)
                }
                
                // Tab label
                Text(label)
                    .font(.system(size: 11, weight: isSelected ? .medium : .regular))
                    .foregroundColor(isSelected ? Color.theme.accent : Color.theme.subtext)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
        .buttonStyle(TabButtonStyle())
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

// Button style for the floating action button with hover and press effects
struct FloatingButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .brightness(configuration.isPressed ? 0.05 : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .contentShape(Circle())
    }
}

// Preview
struct MainTabBarView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
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
            .preferredColorScheme(.light)
            .previewDisplayName("Light Mode")
            
            ZStack {
                Color.black.opacity(0.8).ignoresSafeArea()
                
                VStack {
                    Spacer()
                    MainTabBarView(
                        selectedTab: .constant(0),
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