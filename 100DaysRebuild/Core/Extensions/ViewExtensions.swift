import SwiftUI

// MARK: - View Extensions
extension View {
    /// Apply a circular avatar style to an Image or other View
    func circularAvatarStyle(size: CGFloat, borderColor: Color = .theme.accent, borderWidth: CGFloat = 2) -> some View {
        return self
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(borderColor, lineWidth: borderWidth)
            )
    }
    
    /// Adds a checkmark success animation overlay in the corner of a view
    func successCheckmark(isShowing: Bool, size: CGFloat = 30, offset: CGPoint = CGPoint(x: 35, y: 35)) -> some View {
        ZStack {
            self
            
            if isShowing {
                Circle()
                    .fill(Color.green)
                    .frame(width: size, height: size)
                    .overlay(
                        Image(systemName: "checkmark")
                            .foregroundColor(.white)
                            .font(.system(size: size * 0.6, weight: .bold))
                    )
                    .offset(x: offset.x, y: offset.y)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3), value: isShowing)
    }
    
    /// Dismisses the keyboard when tapping outside of text input fields
    func dismissKeyboardOnTap() -> some View {
        return self.modifier(DismissKeyboardOnTap())
    }
}

// MARK: - Dismiss Keyboard Modifier
struct DismissKeyboardOnTap: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
    }
} 