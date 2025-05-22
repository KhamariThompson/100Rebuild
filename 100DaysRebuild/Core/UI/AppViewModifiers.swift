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
            .background(Color.theme.background.ignoresSafeArea()) // Ensure background color during transitions is consistent
    }
}

// MARK: - Tab Transition Modifier
struct TabTransitionModifier: ViewModifier {
    @ObservedObject var router: NavigationRouter
    
    func body(content: Content) -> some View {
        content
            .opacity(router.tabIsChanging ? 0 : 1)
            .blur(radius: router.tabIsChanging ? 5 : 0)
            .animation(.easeInOut(duration: 0.2), value: router.tabIsChanging)
            .overlay(
                // Add loading indicator during transition for better UX
                ZStack {
                    if router.tabIsChanging {
                        Color.theme.background
                            .opacity(0.5)
                        
                        ProgressView()
                            .scaleEffect(1.2)
                            .progressViewStyle(CircularProgressViewStyle(tint: Color.theme.accent))
                    }
                }
            )
    }
}

// MARK: - Card Shadow Modifier
struct CardShadowModifier: ViewModifier {
    let shadowRadius: CGFloat
    let shadowOpacity: Double
    
    func body(content: Content) -> some View {
        content
            .shadow(
                color: Color.theme.shadow.opacity(shadowOpacity),
                radius: shadowRadius,
                x: 0,
                y: 4
            )
    }
}

// MARK: - Tooltip Modifier
struct TooltipModifier: ViewModifier {
    @State private var showTooltip = false
    let message: String
    let position: TooltipPosition
    let backgroundColor: Color
    let textColor: Color
    let arrowSize: CGFloat
    let cornerRadius: CGFloat
    
    enum TooltipPosition {
        case top, bottom, leading, trailing
    }
    
    func body(content: Content) -> some View {
        content
            .overlay(
                ZStack {
                    if showTooltip {
                        GeometryReader { geometry in
                            VStack {
                                switch position {
                                case .top:
                                    tooltipContent
                                        .offset(y: -geometry.size.height - arrowSize)
                                        .frame(width: min(geometry.size.width * 1.5, 250))
                                case .bottom:
                                    Spacer()
                                    tooltipContent
                                        .offset(y: geometry.size.height/2 + arrowSize)
                                        .frame(width: min(geometry.size.width * 1.5, 250))
                                case .leading:
                                    HStack(alignment: .center) {
                                        tooltipContent
                                            .offset(x: -arrowSize)
                                            .frame(width: min(geometry.size.width * 1.2, 200))
                                        Spacer()
                                    }
                                case .trailing:
                                    HStack(alignment: .center) {
                                        Spacer()
                                        tooltipContent
                                            .offset(x: arrowSize)
                                            .frame(width: min(geometry.size.width * 1.2, 200))
                                    }
                                }
                            }
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showTooltip)
                        }
                    }
                }
            )
            .onTapGesture {
                withAnimation {
                    showTooltip.toggle()
                    
                    // Auto-hide tooltip after 3 seconds
                    if showTooltip {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation {
                                showTooltip = false
                            }
                        }
                    }
                }
            }
    }
    
    private var tooltipContent: some View {
        VStack(alignment: .center) {
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(textColor)
                .multilineTextAlignment(.center)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(backgroundColor)
                .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
        )
    }
}

// MARK: - Round Corners Modifier
struct RoundedCornerModifier: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
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
    
    /// Applies a transition effect during tab changes
    func withTabTransition(router: NavigationRouter) -> some View {
        self.modifier(TabTransitionModifier(router: router))
    }
    
    /// Applies a standard card shadow
    func cardShadow(radius: CGFloat = 10, opacity: Double = 0.1) -> some View {
        self.modifier(CardShadowModifier(shadowRadius: radius, shadowOpacity: opacity))
    }
    
    /// Add a tooltip to any view
    func tooltip(_ message: String, position: TooltipModifier.TooltipPosition = .bottom, 
                backgroundColor: Color = Color.theme.accent,
                textColor: Color = .white,
                arrowSize: CGFloat = 8,
                cornerRadius: CGFloat = 8) -> some View {
        self.modifier(
            TooltipModifier(
                message: message,
                position: position,
                backgroundColor: backgroundColor,
                textColor: textColor,
                arrowSize: arrowSize,
                cornerRadius: cornerRadius
            )
        )
    }
    
    /// Rounds specific corners of a view
    func roundedCorners(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCornerModifier(radius: radius, corners: corners))
    }
}

// MARK: - Navigation Debug Modifier
/// A modifier that helps debug navigation issues by printing path changes
struct NavigationDebounceModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear {
                #if DEBUG
                print("View appeared: \(String(describing: self))")
                #endif
            }
            .onDisappear {
                #if DEBUG
                print("View disappeared: \(String(describing: self))")
                #endif
            }
    }
} 