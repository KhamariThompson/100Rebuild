import SwiftUI

struct FloatingActionButton: View {
    var icon: String = "plus"
    var size: CGFloat = 56
    var action: () -> Void
    
    @State private var isAnimating = false
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                isAnimating = true
            }
            
            // Slight delay before executing action to allow animation to show
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                action()
                
                // Reset animation state
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isAnimating = false
                }
            }
            
            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }) {
            ZStack {
                // Ripple effect on press
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .scaleEffect(isAnimating ? 1.15 : 0.01)
                    .opacity(isAnimating ? 0 : 0.01)
                
                // Main button background with gradient
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.theme.accent, Color.theme.accent.opacity(0.8)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.theme.accent.opacity(0.3), radius: 8, x: 0, y: 4)
                    .scaleEffect(isAnimating ? 0.95 : 1.0)
                
                // Inner highlight for 3D effect
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.white.opacity(0.5), Color.white.opacity(0.0)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(0.85)
                    .blendMode(.overlay)
                
                // Icon
                Image(systemName: icon)
                    .font(.system(size: size * 0.4, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .rotationEffect(Angle(degrees: isAnimating ? 180 : 0))
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(FloatingActionButtonStyle())
    }
}

struct FloatingActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

// Menu version of FAB that expands to show multiple options
struct FloatingActionMenu<Content: View>: View {
    var icon: String = "plus"
    var size: CGFloat = 56
    @ViewBuilder var content: () -> Content
    @Binding var isExpanded: Bool
    
    var body: some View {
        ZStack {
            // Background overlay when expanded
            if isExpanded {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isExpanded = false
                        }
                    }
                    .transition(.opacity)
            }
            
            // Menu content
            VStack {
                if isExpanded {
                    content()
                        .padding(.bottom, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // Main FAB button
                FloatingActionButton(icon: isExpanded ? "xmark" : icon, size: size) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isExpanded.toggle()
                    }
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isExpanded)
    }
}

// A single menu item for use in the FloatingActionMenu
struct FloatingActionMenuItem: View {
    var icon: String
    var title: String
    var color: Color = Color.theme.accent
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Title first (on the left)
                Text(title)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.leading, 4)
                
                Spacer()
                
                // Icon with background
                ZStack {
                    Circle()
                        .fill(color)
                        .frame(width: 40, height: 40)
                        .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 2)
                    
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.5))
                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
            )
            .padding(.horizontal, 20)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// Scale animation for menu items
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// Preview
struct FloatingActionButton_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.theme.background.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 40) {
                // Standard FAB
                FloatingActionButton(action: {
                    print("FAB tapped")
                })
                
                // Menu FAB
                FloatingActionMenu(content: {
                    VStack(spacing: 12) {
                        FloatingActionMenuItem(
                            icon: "flag.fill",
                            title: "New Challenge",
                            color: .blue
                        ) {
                            print("New Challenge")
                        }
                        
                        FloatingActionMenuItem(
                            icon: "pencil",
                            title: "Custom Challenge",
                            color: .green
                        ) {
                            print("Custom Challenge")
                        }
                        
                        FloatingActionMenuItem(
                            icon: "doc.text.fill",
                            title: "From Template",
                            color: .purple
                        ) {
                            print("From Template")
                        }
                    }
                }, isExpanded: .constant(true))
            }
        }
    }
} 