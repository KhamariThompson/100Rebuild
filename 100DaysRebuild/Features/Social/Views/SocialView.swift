import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct SocialView: View {
    @StateObject private var viewModel = SocialViewModel()
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var router: NavigationRouter
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @State private var scrollOffset: CGFloat = 0
    @State private var showUsernameSetup = false
    
    // Animation states
    @State private var heroAppeared = false
    @State private var cardsAppeared = false
    @State private var socialsAppeared = false
    
    // Social gradient for header
    private let socialGradient = LinearGradient(
        colors: [Color.theme.accent, Color.theme.accent.opacity(0.8)],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    // Feature cards data
    private let featureCards = [
        FeatureCard(title: "Group Challenges", description: "Complete challenges with friends", iconName: "person.3.fill"),
        FeatureCard(title: "Friends Feed", description: "See what your friends are working on", iconName: "bubble.left.and.bubble.right.fill"),
        FeatureCard(title: "Global Leaderboards", description: "Compete with others around the world", iconName: "crown.fill")
    ]
    
    var body: some View {
        ZStack {
            // Background
            Color.theme.background
                .ignoresSafeArea()
            
            // ScrollView with integrated title
            ScrollView {
                VStack(spacing: AppSpacing.l) {
                    // Title with gradient inside ScrollView
                    Text("Social")
                        .font(.largeTitle)
                        .bold()
                        .foregroundStyle(socialGradient)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                        .padding(.top, AppSpacing.m)
                    
                    // Content based on state
                    if viewModel.isLoading {
                        loadingView
                            .transition(.opacity)
                    } else if let error = viewModel.error {
                        errorView(message: error)
                            .transition(.opacity)
                    } else if viewModel.socialFeed.isEmpty && !viewModel.isOffline {
                        emptyStateView
                            .transition(.opacity)
                    } else {
                        if viewModel.isOffline {
                            offlineBanner
                        }
                        
                        socialFeedView
                            .transition(.opacity)
                    }
                }
                .padding(.bottom, 20) // Add bottom padding to prevent content from being cut off
            }
            .animation(.easeInOut(duration: 0.3), value: viewModel.isLoading)
            .animation(.easeInOut(duration: 0.3), value: viewModel.error)
            .animation(.easeInOut(duration: 0.3), value: viewModel.socialFeed.isEmpty)
        }
        .background(Color.theme.background.ignoresSafeArea())
        .overlay {
            if viewModel.isLoading {
                SocialLoadingOverlay()
            }
        }
        .alert(isPresented: Binding<Bool>(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Alert(
                title: Text("Error"),
                message: Text(viewModel.errorMessage ?? "Unknown error"),
                dismissButton: .default(Text("OK"))
            )
        }
        .overlay {
            if viewModel.showSuccessToast {
                VStack {
                    Spacer()
                    SuccessToast()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .animation(.spring(), value: viewModel.showSuccessToast)
                .zIndex(100)
            }
        }
        .sheet(isPresented: $showUsernameSetup) {
            UsernameSetupView()
                .environmentObject(userSession)
        }
        .onAppear {
            // Staggered animations
            withAnimation(.easeOut(duration: 0.6)) {
                heroAppeared = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeOut(duration: 0.7)) {
                    cardsAppeared = true
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.easeOut(duration: 0.8)) {
                    socialsAppeared = true
                }
            }
            
            // Only fetch the username when the view appears
            Task {
                await viewModel.loadUserUsername()
            }
        }
    }
    
    // MARK: - View Components
    
    // 1. Hero Section
    private var heroSection: some View {
        VStack(spacing: AppSpacing.m) {
            // Emoji header
            Text("🔗")
                .font(.system(size: 48))
                .padding(.bottom, AppSpacing.xs)
            
            // Title and subtitle
            Text("The Social Side of 100Days")
                .font(AppTypography.display())
                .foregroundColor(.theme.text)
                .multilineTextAlignment(.center)
            
            Text("Friends, groups, and leaderboards are almost here.")
                .font(AppTypography.title3())
                .foregroundColor(.theme.subtext)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.m)
                .padding(.bottom, AppSpacing.s)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.l)
    }
    
    // 2. Username Claim Section
    private var usernameCard: some View {
        VStack(spacing: 0) {
            if case .claimed(let username) = viewModel.usernameStatus {
                // User has already claimed a username
                UsernameDisplayView(username: username)
            } else if case .unclaimed = viewModel.usernameStatus {
                // User needs to set up a username
                UsernameInputView(viewModel: viewModel)
            } else {
                // Error state
                VStack(alignment: .leading, spacing: 12) {
                    Text("Username Setup Required")
                        .font(.headline)
                        .foregroundColor(Color.theme.text)
                    
                    Text("We couldn't find your username. Please reload the app or contact support if this issue persists.")
                        .font(.subheadline)
                        .foregroundColor(Color.theme.subtext)
                }
                .padding()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.theme.surface)
                .shadow(color: Color.theme.shadow.opacity(colorScheme == .dark ? 0.3 : 0.1), 
                       radius: 8, x: 0, y: 4)
        )
    }
    
    // 3. Feature Teaser Section
    private var featureTeaseSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            Text("Coming Soon")
                .font(AppTypography.title3())
                .fontWeight(.bold)
                .foregroundColor(.theme.text)
                .padding(.horizontal, AppSpacing.xs)
            
            // Horizontal scroll of feature cards with improved layout
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.m) {
                    ForEach(featureCards) { card in
                        FeatureTeaseCard(
                            title: card.title,
                            description: card.description,
                            iconName: card.iconName
                        )
                        .frame(width: 180, height: 200)
                    }
                }
                .padding(.horizontal, AppSpacing.m)
                .padding(.bottom, AppSpacing.m)
                .padding(.top, AppSpacing.xs)
            }
        }
    }
    
    // 4. Social Media Follow Section
    private var socialFollowSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            // Header with icon
            HStack(spacing: 8) {
                Image(systemName: "globe")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.theme.accent)
                
                Text("Connect With Us")
                    .font(AppTypography.title3())
                    .fontWeight(.bold)
                    .foregroundColor(.theme.text)
            }
            .padding(.horizontal, AppSpacing.m)
            
            // Social media cards with improved 3-card layout
            VStack(spacing: 20) {
                // Top row - 2 cards side by side
                HStack(spacing: 20) {
                    // TikTok Card
                    socialMediaCard(
                        platform: "TikTok",
                        username: "@100days.site",
                        systemIcon: "play.square.fill",
                        url: URL(string: "https://www.tiktok.com/@100days.site") ?? URL(string: "https://100days.site")!,
                        gradient: [Color.black, Color(red: 0.1, green: 0.1, blue: 0.2)]
                    )
                    .frame(maxWidth: .infinity)
                    
                    // X Card (formerly Twitter)
                    socialMediaCard(
                        platform: "X",
                        username: "@100DaysHQ",
                        systemIcon: "bubble.left.and.bubble.right.fill",
                        url: URL(string: "https://twitter.com/100DaysHQ") ?? URL(string: "https://100days.site")!,
                        gradient: [Color(red: 0.05, green: 0.05, blue: 0.05), Color(red: 0.2, green: 0.2, blue: 0.2)]
                    )
                    .frame(maxWidth: .infinity)
                }
                
                // Bottom row - centered Instagram card
                socialMediaCard(
                    platform: "Instagram",
                    username: "@100days.site",
                    systemIcon: "camera.circle.fill",
                    url: URL(string: "https://instagram.com/100days.site") ?? URL(string: "https://100days.site")!,
                    gradient: [Color.purple, Color.pink.opacity(0.8)]
                )
                .frame(maxWidth: .infinity)
                .frame(height: 160) // Make the bottom card taller for better visual balance
            }
            .padding(.horizontal, AppSpacing.m)
            .padding(.vertical, AppSpacing.m)
        }
        .padding(.vertical, AppSpacing.m)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.theme.surface)
                .shadow(color: Color.theme.shadow.opacity(0.05), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal, AppSpacing.xs)
    }
    
    // Redesigned social media card with gradient background
    private func socialMediaCard(platform: String, username: String, systemIcon: String, url: URL, gradient: [Color]) -> some View {
        Button {
            // Open URL
            UIApplication.shared.open(url)
            
            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                // Platform icon
                HStack(spacing: 8) {
                    Image(systemName: systemIcon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 14, weight: .medium))
                        .padding(6)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Circle())
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                // Platform name and username
                VStack(alignment: .leading, spacing: 6) {
                    Text(platform)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(username)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(1)
                }
            }
            .frame(height: 130)
            .padding(18)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: gradient),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(16)
            .shadow(color: Color.theme.shadow.opacity(0.2), radius: 8, x: 0, y: 4)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .overlay(
                // Add subtle pulsating effect on hover
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                    .scaleEffect(1.02)
                    .opacity(0.0)
                    .animation(
                        Animation.easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: true),
                        value: UUID()
                    )
            )
        }
        .buttonStyle(AppScaleButtonStyle())
    }
    
    // MARK: - Helper Properties
    
    private var canClaimUsername: Bool {
        if viewModel.isCheckingUsername { return false }
        if isInvalidStatus { return false }
        if viewModel.username.isEmpty { return false }
        return viewModel.validationMessage == "Username available!"
    }
    
    private var isInvalidStatus: Bool {
        switch viewModel.usernameStatus {
        case .invalid, .error:
            return true
        default:
            return false
        }
    }
    
    private var validationBorderColor: Color {
        if viewModel.isCheckingUsername {
            return Color.gray.opacity(0.5)
        } else if isInvalidStatus {
            return Color.theme.error.opacity(0.7)
        } else if viewModel.validationMessage == "Username available!" {
            return Color.theme.success.opacity(0.7)
        } else {
            return Color.gray.opacity(0.3)
        }
    }
    
    private var validationMessageColor: Color {
        if isInvalidStatus {
            return .theme.error
        } else if viewModel.validationMessage == "Username available!" {
            return .theme.success
        } else {
            return Color.theme.subtext
        }
    }
    
    // MARK: - Missing View Components
    
    // Loading state view
    private var loadingView: some View {
        VStack(spacing: AppSpacing.m) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.theme.accent)
            
            Text("Loading social features...")
                .font(AppTypography.headline())
                .foregroundColor(.theme.text)
                .multilineTextAlignment(.center)
                .padding(.top, AppSpacing.s)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 100)
    }
    
    // Error state view
    private func errorView(message: String) -> some View {
        VStack(spacing: AppSpacing.m) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.yellow)
                .padding(.bottom, AppSpacing.s)
            
            Text("Oops! Something went wrong")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.theme.text)
                .multilineTextAlignment(.center)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.theme.subtext)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.l)
            
            Button {
                Task {
                    // Implement refresh action here
                    await viewModel.refreshData()
                }
            } label: {
                Text("Try Again")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.vertical, AppSpacing.m)
                    .background(Color.theme.accent)
                    .cornerRadius(10)
            }
            .padding(.top, AppSpacing.s)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 100)
    }
    
    // Empty state view
    private var emptyStateView: some View {
        VStack(spacing: AppSpacing.l) {
            // Hero section with staggered animation
            heroSection
                .opacity(heroAppeared ? 1 : 0)
                .offset(y: heroAppeared ? 0 : 20)
            
            // Username claim section
            usernameCard
                .opacity(heroAppeared ? 1 : 0)
                .offset(y: heroAppeared ? 0 : 30)
            
            // Feature teasers section
            featureTeaseSection
                .opacity(cardsAppeared ? 1 : 0)
                .offset(y: cardsAppeared ? 0 : 40)
            
            // Social media follow section
            socialFollowSection
                .opacity(socialsAppeared ? 1 : 0)
                .offset(y: socialsAppeared ? 0 : 40)
            
            // Coming Soon Footer
            Text("Coming Soon")
                .font(AppTypography.caption1())
                .foregroundColor(.theme.subtext)
                .padding(.bottom, AppSpacing.xl)
                .opacity(socialsAppeared ? 1 : 0)
            
            Spacer(minLength: AppSpacing.xl)
        }
        .padding(.horizontal, AppSpacing.screenHorizontalPadding)
    }
    
    // Offline banner view
    private var offlineBanner: some View {
        HStack {
            Image(systemName: "wifi.slash")
                .foregroundColor(.yellow)
            Text("You're offline. Some features may be limited.")
                .font(.footnote)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, AppSpacing.screenHorizontalPadding)
        .padding(.vertical, AppSpacing.xs)
        .background(Color(.systemGray6))
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    // Social feed view (placeholder for future implementation)
    private var socialFeedView: some View {
        VStack(spacing: AppSpacing.l) {
            // Hero section with staggered animation
            heroSection
                .opacity(heroAppeared ? 1 : 0)
                .offset(y: heroAppeared ? 0 : 20)
            
            // Coming soon message
            VStack(spacing: AppSpacing.m) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.theme.accent)
                
                Text("Social Feed Coming Soon")
                    .font(AppTypography.title3())
                    .fontWeight(.bold)
                    .foregroundColor(.theme.text)
                
                Text("We're working hard to bring you a full social experience. For now, you can claim your username and prepare for the launch.")
                    .font(AppTypography.subhead())
                    .foregroundColor(.theme.subtext)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.m)
            }
            .padding(AppSpacing.l)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.theme.surface)
                    .shadow(color: Color.theme.shadow.opacity(0.1), radius: 8, x: 0, y: 4)
            )
            .padding(.horizontal, AppSpacing.screenHorizontalPadding)
            .opacity(cardsAppeared ? 1 : 0)
            .offset(y: cardsAppeared ? 0 : 30)
        }
    }
}

// MARK: - Supporting Views and Models

// Username Input View for username setup
struct UsernameInputView: View {
    @ObservedObject var viewModel: SocialViewModel
    @FocusState private var isUsernameFocused: Bool
    @State private var localUsername: String = ""
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose Your Username")
                .font(.headline)
                .foregroundColor(Color.theme.text)
            
            Text("This username will be used for social features. It must be unique and contain only letters and numbers.")
                .font(.subheadline)
                .foregroundColor(Color.theme.subtext)
            
            // Username input field with local state
            TextField("Username", text: $localUsername)
                .padding()
                .background(Color.theme.surface)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(viewModel.validationBorderColor, lineWidth: 1)
                )
                .focused($isUsernameFocused)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .onChange(of: localUsername) { _ in 
                    // Only update viewModel when needed (debounce in ViewModel)
                    viewModel.validateUsername(username: localUsername)
                }
            
            // Validation message
            if !viewModel.validationMessage.isEmpty {
                Text(viewModel.validationMessage)
                    .font(.caption)
                    .foregroundColor(viewModel.validationMessageColor)
            }
            
            // Claim button
            Button {
                Task {
                    await viewModel.claimUsername()
                }
            } label: {
                Text("Claim Username")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? .black : .white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(viewModel.canClaimUsername ? Color.theme.accent : Color.gray.opacity(0.3))
                    .cornerRadius(10)
            }
            .disabled(!viewModel.canClaimUsername)
            .padding(.top, 8)
        }
        .padding()
        .onAppear {
            // Initialize local username from view model
            localUsername = viewModel.username
            
            // Auto-focus the username field with a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                isUsernameFocused = true
            }
        }
    }
}

// Feature Card Model
struct FeatureCard: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let iconName: String
}

// Feature Teaser Card with improved layout
struct FeatureTeaseCard: View {
    let title: String
    let description: String
    let iconName: String
    @State private var animateGlow = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            // Locked icon
            ZStack {
                Circle()
                    .fill(Color.theme.accent.opacity(0.15))
                    .frame(width: 60, height: 60)
                
                Image(systemName: iconName)
                    .font(.system(size: 28))
                    .foregroundColor(.theme.accent.opacity(0.6))
                
                // Lock overlay
                Image(systemName: "lock.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(6)
                    .background(
                        Circle()
                            .fill(Color.theme.accent)
                    )
                    .offset(x: 18, y: 18)
            }
            .padding(.top, AppSpacing.m)
            .padding(.leading, AppSpacing.s)
            
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(title)
                    .font(AppTypography.headline())
                    .foregroundColor(.theme.text)
                    .padding(.top, AppSpacing.s)
                
                Text(description)
                    .font(AppTypography.caption1())
                    .foregroundColor(.theme.subtext)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, AppSpacing.s)
            .padding(.bottom, AppSpacing.m)
            
            Spacer()
        }
        .frame(height: 190)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.theme.surface)
                .shadow(color: Color.theme.shadow.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                animateGlow = true
            }
        }
    }
}

/// Loading overlay view
struct SocialLoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                
                Text("Loading...")
                    .font(AppTypography.headline())
                    .foregroundColor(.white)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.theme.surface.opacity(0.9))
            )
        }
    }
}

/// Success toast view
struct SuccessToast: View {
    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.white)
                .font(AppTypography.headline())
            
            Text("Username reserved for future social features!")
                .font(AppTypography.subhead())
                .fontWeight(.medium)
                .foregroundColor(.white)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.theme.accent)
                .shadow(radius: 5)
        )
        .padding(.horizontal)
        .padding(.bottom, 30)
    }
}

struct SocialView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SocialView()
                .navigationTitle("Social")
        }
    }
} 