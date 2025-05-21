import SwiftUI

/// A custom tab bar styled after CalAI's minimal design
public struct CalAITabBar: View {
    @Binding var selectedTab: Int
    let items: [TabItem]
    
    public init(selectedTab: Binding<Int>, items: [TabItem]) {
        self._selectedTab = selectedTab
        self.items = items
    }
    
    public var body: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = index
                        // Add haptic feedback
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: item.icon)
                            .font(.system(size: 20, weight: selectedTab == index ? .semibold : .regular))
                            .foregroundColor(selectedTab == index ? Color.theme.accent : Color.theme.subtext.opacity(0.8))
                        
                        Text(item.text)
                            .font(.system(size: 10, weight: selectedTab == index ? .semibold : .medium, design: .rounded))
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
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(
                        Circle()
                            .fill(Color.theme.accent)
                    )
                    .shadow(color: Color.theme.accent.opacity(0.25), radius: 6, x: 0, y: 4)
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
                    CalAITabBar.TabItem(icon: "chart.bar", text: "Progress"),
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
                    CalAITabBar.TabItem(icon: "chart.bar", text: "Progress"),
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