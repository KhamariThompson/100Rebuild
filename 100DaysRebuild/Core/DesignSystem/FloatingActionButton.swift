import SwiftUI

struct FloatingActionButton: View {
    let icon: String
    var size: CGFloat = 56
    var action: () -> Void
    
    var body: some View {
        Button(action: {
            // Provide haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            
            // Perform the action
            action()
        }) {
            ZStack {
                // Background shape with gradient
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.theme.accent, Color.theme.accent.opacity(0.85)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
                    .shadow(
                        color: Color.theme.accent.opacity(0.3),
                        radius: 8,
                        x: 0,
                        y: 4
                    )
                
                // Icon
                Image(systemName: icon)
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(FloatingButtonStyle())
    }
}

struct FloatingActionMenu<Content: View>: View {
    @ViewBuilder var content: () -> Content
    @Binding var isExpanded: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            // Only show content when expanded
            if isExpanded {
                content()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Main button - shows X when expanded, + when collapsed
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                    isExpanded.toggle()
                }
                // Provide haptic feedback
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
            }) {
                ZStack {
                    // Background with gradient
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.theme.accent, Color.theme.accent.opacity(0.85)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                        .shadow(
                            color: Color.theme.accent.opacity(0.3),
                            radius: 8,
                            x: 0,
                            y: 4
                        )
                    
                    // Animated icon (+ rotates to X)
                    Image(systemName: isExpanded ? "xmark" : "plus")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .scaleEffect(isExpanded ? 1.1 : 1.0)
                }
            }
            .buttonStyle(FloatingButtonStyle())
        }
    }
}

struct FloatingActionMenuItem: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            // Provide haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            
            // Perform the action
            action()
        }) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(color)
                }
                
                // Title
                Text(title)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(Color.theme.text)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.theme.surface)
                    .shadow(color: Color.theme.shadow.opacity(0.1), radius: 4, x: 0, y: 2)
            )
        }
        .buttonStyle(MenuItemButtonStyle())
    }
}

// Button style for floating action button with spring animation
private struct FloatingButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// Button style for menu items with subtle press effect
private struct MenuItemButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// Preview
struct FloatingActionButton_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray.opacity(0.2).ignoresSafeArea()
            
            VStack {
                Spacer()
                
                // Preview the expanded menu
                FloatingActionMenu(content: {
                    VStack(spacing: 12) {
                        FloatingActionMenuItem(
                            icon: "flag.fill",
                            title: "New Challenge",
                            color: .blue
                        ) {}
                        
                        FloatingActionMenuItem(
                            icon: "pencil",
                            title: "Custom Challenge",
                            color: .green
                        ) {}
                        
                        FloatingActionMenuItem(
                            icon: "doc.text.fill",
                            title: "Template",
                            color: .purple
                        ) {}
                    }
                }, isExpanded: .constant(true))
                
                Spacer().frame(height: 100)
                
                // Preview just the button
                FloatingActionButton(icon: "plus") {}
                
                Spacer().frame(height: 40)
            }
        }
    }
} 