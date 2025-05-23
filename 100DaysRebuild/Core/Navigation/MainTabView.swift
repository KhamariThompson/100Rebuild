import SwiftUI

struct MainTabView: View {
    @StateObject private var router = NavigationRouter()
    @State private var showNewChallengeSheet = false
    @State private var socialNotificationCount: Int? = 0
    @State private var isMenuExpanded = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $router.selectedTab) {
                // Home Tab
                NavigationView {
                    Text("Home Tab")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.theme.background)
                        .navigationTitle("Home")
                        .contentPaddingForTabBar()
                }
                .tag(0)
                
                // Progress Tab
                NavigationView {
                    Text("Progress Tab")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.theme.background)
                        .navigationTitle("Progress")
                        .contentPaddingForTabBar()
                }
                .tag(1)
                
                // Social Tab
                NavigationView {
                    Text("Social Tab")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.theme.background)
                        .navigationTitle("Social")
                        .contentPaddingForTabBar()
                }
                .tag(2)
                
                // Profile Tab
                NavigationView {
                    Text("Profile Tab")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.theme.background)
                        .navigationTitle("Profile")
                        .contentPaddingForTabBar()
                }
                .tag(3)
            }
            .disabled(isMenuExpanded) // Disable tab view interaction when menu is expanded
            .edgesIgnoringSafeArea(.bottom)
            .onChange(of: router.selectedTab) { oldValue, newValue in
                // Make sure the tab change is intentional and not a bug
                // This prevents auto-switching back to home tab
                print("Tab changed from \(oldValue) to \(newValue)")
            }
            
            ZStack(alignment: .bottom) {
                // Custom tab bar (visible when menu is not expanded)
                if !isMenuExpanded {
                    MainTabBarView(
                        selectedTab: $router.selectedTab,
                        onNewChallengeButtonTapped: {
                            withAnimation {
                                isMenuExpanded = true
                            }
                        },
                        socialBadgeCount: socialNotificationCount
                    )
                    .offset(y: router.tabIsChanging ? 100 : 0) // Hide during tab transitions
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: router.tabIsChanging)
                    .shadow(color: Color.theme.shadow.opacity(0.25), radius: 10, x: 0, y: -3)
                    .background(
                        Rectangle()
                            .fill(Color.theme.surface)
                            .edgesIgnoringSafeArea(.bottom)
                            .frame(height: 2)
                            .offset(y: 100)
                    )
                }
                
                // Floating action menu (replaces the + button with a menu)
                if isMenuExpanded {
                    VStack {
                        Spacer()
                        
                        // Menu content
                        FloatingActionMenu(content: {
                            VStack(spacing: 12) {
                                FloatingActionMenuItem(
                                    icon: "flag.fill",
                                    title: "New Challenge",
                                    color: Color.blue
                                ) {
                                    isMenuExpanded = false
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        showNewChallengeSheet = true
                                    }
                                }
                                
                                FloatingActionMenuItem(
                                    icon: "pencil",
                                    title: "Custom Challenge",
                                    color: Color.green
                                ) {
                                    isMenuExpanded = false
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        // Show custom challenge sheet
                                    }
                                }
                                
                                FloatingActionMenuItem(
                                    icon: "doc.text.fill",
                                    title: "Challenge Template",
                                    color: Color.purple
                                ) {
                                    isMenuExpanded = false
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        // Show template selection
                                    }
                                }
                            }
                        }, isExpanded: $isMenuExpanded)
                    }
                    .padding(.bottom, 20) // Adjusted for better alignment
                }
            }
        }
        .sheet(isPresented: $showNewChallengeSheet) {
            // New Challenge Sheet view would go here
            NavigationView {
                Text("Create New Challenge")
                    .navigationTitle("New Challenge")
                    .navigationBarItems(
                        trailing: Button("Close") {
                            showNewChallengeSheet = false
                        }
                    )
            }
        }
        // Listen for notifications that might update the badge count
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SocialUpdateReceived"))) { notification in
            if let count = notification.object as? Int {
                socialNotificationCount = count > 0 ? count : nil
            }
        }
        // Handle taps outside the FAB menu
        .contentShape(Rectangle())
        .gesture(
            TapGesture()
                .onEnded { _ in
                    if isMenuExpanded {
                        withAnimation {
                            isMenuExpanded = false
                        }
                    }
                }
        )
    }
}

/// Router to manage tab state and transitions
class NavigationRouter: ObservableObject {
    @Published var selectedTab: Int = 0
    @Published var tabIsChanging: Bool = false
    
    /// Change tab with animation
    func changeTab(to tab: Int) {
        guard selectedTab != tab else { return }
        
        // Prevent changing tabs if already in transition
        if tabIsChanging {
            return
        }
        
        // Immediately set changing state
        tabIsChanging = true
        
        // Use direct tab change with minimal animation
        withAnimation(.easeOut(duration: 0.1)) {
            self.selectedTab = tab
        }
        
        // Reset changing state after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.tabIsChanging = false
        }
    }
    
    deinit {
        print("✅ NavigationRouter released")
    }
}

// Dynamic Tab Bar Notch Size Modifier
struct DynamicTabBarNotchModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.bottom, getSafeAreaInsets().bottom + 80) // Increased from 60 to 80 for more space
    }
    
    private func getSafeAreaInsets() -> UIEdgeInsets {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        }
        return window.safeAreaInsets
    }
}

extension View {
    func dynamicTabBarPadding() -> some View {
        self.modifier(DynamicTabBarNotchModifier())
    }
    
    // New modifier for content above tab bar
    func contentPaddingForTabBar() -> some View {
        self.padding(.bottom, 90) // Fixed extra padding to ensure content isn't hidden by tab bar
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
} 