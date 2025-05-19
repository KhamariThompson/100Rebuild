import SwiftUI

// MARK: - App Dependencies ViewModifier

/// ViewModifier that applies all common app dependencies to a view
struct AppDependenciesModifier: ViewModifier {
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var subscriptionService: SubscriptionService
    @EnvironmentObject var notificationService: NotificationService
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var userStatsService: UserStatsService
    
    func body(content: Content) -> some View {
        content
            .environmentObject(userSession)
            .environmentObject(subscriptionService)
            .environmentObject(notificationService)
            .environmentObject(themeManager)
            .environmentObject(userStatsService)
    }
}

// MARK: - Circular Avatar ViewModifier

/// ViewModifier for creating a circular avatar image
struct CircularAvatarModifier: ViewModifier {
    var size: CGFloat
    
    func body(content: Content) -> some View {
        content
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.theme.surface, lineWidth: 3)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Success Checkmark ViewModifier

/// ViewModifier for showing a success checkmark animation
struct SuccessCheckmarkModifier: ViewModifier {
    var isShowing: Bool
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            if isShowing {
                ZStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 30, height: 30)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
                .transition(.scale.combined(with: .opacity))
                .animation(.spring(), value: isShowing)
                .position(x: UIScreen.main.bounds.width / 2 + 30, y: UIScreen.main.bounds.height / 2 + 30)
            }
        }
    }
}

// MARK: - Shadow Card ViewModifier

/// ViewModifier for creating a card with consistent shadow and background
struct ShadowCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 12
    
    func body(content: Content) -> some View {
        content
            .padding()
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.theme.surface)
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
            )
            .padding(.horizontal)
    }
}

// MARK: - ScrollOffset ViewModifier

/// ViewModifier to track scroll offset in a ScrollView
struct ScrollOffsetModifier: ViewModifier {
    @Binding var offset: CGFloat
    
    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geo -> Color in
                    let offsetY = geo.frame(in: .global).minY
                    
                    DispatchQueue.main.async {
                        self.offset = offsetY
                    }
                    
                    return Color.clear
                }
            )
    }
}

// MARK: - SafeArea Key
struct SafeAreaKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Fix Navigation Layout Conflicts
struct FixNavigationLayoutModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .navigationViewStyle(StackNavigationViewStyle())
            .navigationBarTitleDisplayMode(.inline)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .preference(key: SafeAreaKey.self, value: geo.safeAreaInsets.top)
                        .onPreferenceChange(SafeAreaKey.self) { _ in }
                }
            )
    }
}

// MARK: - View Extensions

extension View {
    /// Apply all common app dependencies as environment objects to this view
    func withAppDependencies() -> some View {
        modifier(AppDependenciesModifier())
    }
    
    /// Add a success checkmark animation to this view
    func successCheckmark(isShowing: Bool) -> some View {
        modifier(SuccessCheckmarkModifier(isShowing: isShowing))
    }
    
    /// Apply a shadow card style to this view
    func shadowCard(cornerRadius: CGFloat = 12) -> some View {
        modifier(ShadowCardModifier(cornerRadius: cornerRadius))
    }
    
    func fixNavigationLayout() -> some View {
        modifier(FixNavigationLayoutModifier())
    }
    
    /// Present sheet with proper navigation layout fixes
    func fixedSheet<Content: View>(
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        self.sheet(isPresented: isPresented, onDismiss: onDismiss) {
            content()
                .withAppDependencies()
                .withAppTheme()
                .fixNavigationLayout()
        }
    }
} 