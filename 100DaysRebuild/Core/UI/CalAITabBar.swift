import SwiftUI

/// A custom tab bar styled after CalAI's minimal design
public struct CalAITabBar: View {
    @Binding var selectedTab: Int
    let items: [TabItem]
    var router: NavigationRouter?
    
    init(selectedTab: Binding<Int>, items: [TabItem], router: NavigationRouter? = nil) {
        self._selectedTab = selectedTab
        self.items = items
        self.router = router
    }
    
    public var body: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                Button(action: {
                    tabSelectionChanged(to: index)
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: item.icon)
                            .font(AppTypography.title3(selectedTab == index ? .semibold : .regular))
                            .foregroundColor(selectedTab == index ? Color.theme.accent : Color.theme.subtext.opacity(0.8))
                        
                        Text(item.text)
                            .font(AppTypography.caption2(selectedTab == index ? .semibold : .medium))
                            .foregroundColor(selectedTab == index ? Color.theme.accent : Color.theme.subtext.opacity(0.8))
                    }
                    .frame(height: 46)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(TabBarButtonStyle())
                
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 16)
        .background(
            Rectangle()
                .fill(Color.theme.surface)
                .shadow(color: Color.theme.shadow.opacity(0.05), radius: 2, x: 0, y: -1)
        )
    }
    
    /// Defines a tab bar item
    public struct TabItem: Identifiable {
        public var id = UUID()
        var icon: String
        var text: String
        
        public init(icon: String, text: String) {
            self.icon = icon
            self.text = text
        }
    }
    
    // Modify the tab selection handling to use a consistent animation and prevent flicker
    func tabSelectionChanged(to index: Int) {
        // Guard against unnecessary tab changes
        guard selectedTab != index else { return }
        
        // Provide haptic feedback on tab change
        hapticFeedback(.light)
        
        // Use the NavigationRouter for controlled transitions if available
        if let router = router {
            router.changeTab(to: index)
        } else {
            // Fallback for direct binding when router is not available
            withAnimation(Animation.easeInOut(duration: 0.2)) {
                selectedTab = index
            }
        }
    }
    
    // Utility function for haptic feedback
    private func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}

/// Button style for tab items
private struct TabBarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// A FloatingTabBar variation with a circular add button 
/// (Kept for backward compatibility, not used in new implementation)
public struct CalAIFloatingTabBar: View {
    @Binding var selectedTab: Int
    let items: [CalAITabBar.TabItem]
    let addAction: () -> Void
    
    public init(selectedTab: Binding<Int>, items: [CalAITabBar.TabItem], addAction: @escaping () -> Void) {
        self._selectedTab = selectedTab
        self.items = items
        self.addAction = addAction
    }
    
    public var body: some View {
        ZStack(alignment: .top) {
            // Tab bar
            CalAITabBar(selectedTab: $selectedTab, items: items)
                .padding(.top, 28) // Add space for the floating button
            
            // Floating action button
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    addAction()
                    // Add haptic feedback
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                }
            }) {
                Image(systemName: "plus")
                    .font(AppTypography.title2(.semibold))
                    .foregroundColor(.black)
                    .frame(width: 50, height: 50)
                    .background(
                        Circle()
                            .fill(Color.white)
                    )
                    .shadow(color: Color.theme.accent.opacity(0.25), radius: 6, x: 0, y: 4)
                    .overlay(
                        Circle()
                            .stroke(Color.black.opacity(0.3), lineWidth: 1.5)
                    )
            }
            .offset(y: -25) // Position above the tab bar
        }
    }
}

// MARK: - Preview
struct CalAITabBar_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Spacer()
            
            CalAITabBar(
                selectedTab: .constant(1),
                items: [
                    CalAITabBar.TabItem(icon: "house", text: "Home"),
                    CalAITabBar.TabItem(icon: "chart.bar.fill", text: "Progress"),
                    CalAITabBar.TabItem(icon: "person.2", text: "Social"),
                    CalAITabBar.TabItem(icon: "person", text: "Profile")
                ]
            )
        }
        .previewLayout(.sizeThatFits)
        .background(Color.theme.background)
        .frame(height: 300)
        
        VStack {
            Spacer()
            
            CalAIFloatingTabBar(
                selectedTab: .constant(0),
                items: [
                    CalAITabBar.TabItem(icon: "house", text: "Home"),
                    CalAITabBar.TabItem(icon: "chart.bar.fill", text: "Progress"),
                    CalAITabBar.TabItem(icon: "person", text: "Profile"),
                    CalAITabBar.TabItem(icon: "gearshape", text: "Settings")
                ],
                addAction: {}
            )
        }
        .previewLayout(.sizeThatFits)
        .background(Color.theme.background)
        .frame(height: 300)
        .preferredColorScheme(.dark)
    }
} 