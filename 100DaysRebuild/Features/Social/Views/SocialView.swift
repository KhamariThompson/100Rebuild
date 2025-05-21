import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct SocialView: View {
    @StateObject private var viewModel = SocialViewModel()
    @Environment(\.colorScheme) private var colorScheme
    @State private var scrollOffset: CGFloat = 0
    
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
                VStack(spacing: AppSpacing.m) {
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
            }
            .animation(.easeInOut(duration: 0.3), value: viewModel.isLoading)
            .animation(.easeInOut(duration: 0.3), value: viewModel.error)
            .animation(.easeInOut(duration: 0.3), value: viewModel.socialFeed.isEmpty)
        }
        .background(Color.theme.background.ignoresSafeArea())
        .overlay {
            if viewModel.isLoading {
                LoadingOverlay()
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
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.theme.text)
                .multilineTextAlignment(.center)
            
            Text("Friends, groups, and leaderboards are almost here.")
                .font(AppTypography.title3)
                .foregroundColor(.theme.subtext)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.m)
                .padding(.bottom, AppSpacing.s)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.l)
    }
    
    // 2. Username Claim Section
    private var usernameClaimSection: some View {
        VStack(spacing: 0) {
            if case .claimed(let username) = viewModel.usernameStatus {
                // User has already claimed a username
                VStack(alignment: .center, spacing: AppSpacing.m) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.theme.success)
                    
                    VStack(spacing: AppSpacing.xs) {
                        Text("Your username is")
                            .font(AppTypography.body)
                            .foregroundColor(.theme.text)
                        
                        Text("@\(username)")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.theme.accent)
                    }
                    
                    Text("You're all set for the social features launch!")
                        .font(AppTypography.subheadline)
                        .foregroundColor(.theme.subtext)
                        .multilineTextAlignment(.center)
                        .padding(.top, AppSpacing.xs)
                }
                .padding(AppSpacing.l)
            } else {
                // User has not claimed a username yet
                VStack(alignment: .center, spacing: AppSpacing.m) {
                    Text("Claim Your Username")
                        .font(AppTypography.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.theme.text)
                    
                    Text("Reserve your username now to secure your identity before others claim it.")
                        .font(AppTypography.subheadline)
                        .foregroundColor(.theme.subtext)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, AppSpacing.xs)
                    
                    // Username text field
                    VStack(alignment: .leading, spacing: AppSpacing.s) {
                        HStack {
                            Text("@")
                                .foregroundColor(.theme.accent)
                                .font(.headline)
                            
                            TextField("Choose a username", text: Binding(
                                get: { viewModel.username },
                                set: { newValue in
                                    let filtered = viewModel.filterUsername(newValue)
                                    viewModel.validateUsername(username: filtered)
                                }
                            ))
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .textInputAutocapitalization(.never)
                            .textContentType(.username)
                            .submitLabel(.done)
                            .padding(.vertical, AppSpacing.s)
                        }
                        .padding(.horizontal, AppSpacing.m)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(validationBorderColor, lineWidth: 1)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.theme.surface)
                                )
                        )
                        
                        // Validation message
                        if !viewModel.validationMessage.isEmpty {
                            HStack {
                                if viewModel.isCheckingUsername {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .frame(width: 16, height: 16)
                                        .padding(.trailing, 4)
                                } else if isInvalidStatus {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.theme.error)
                                        .font(.system(size: 12))
                                } else if viewModel.validationMessage == "Username available!" {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.theme.success)
                                        .font(.system(size: 12))
                                }
                                
                                Text(viewModel.validationMessage)
                                    .font(AppTypography.caption)
                                    .foregroundColor(validationMessageColor)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                    
                    // Claim button
                    Button {
                        Task {
                            // Trigger haptic feedback
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.prepare()
                            
                            await viewModel.claimUsername()
                        }
                    } label: {
                        Text("Claim Username")
                            .font(AppTypography.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.m)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(canClaimUsername ? Color.theme.accent : Color.gray.opacity(0.5))
                            )
                    }
                    .disabled(!canClaimUsername)
                    .buttonStyle(AppScaleButtonStyle())
                    .padding(.top, AppSpacing.s)
                }
                .padding(AppSpacing.l)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.theme.surface)
                .shadow(color: Color.theme.shadow.opacity(colorScheme == .dark ? 0.3 : 0.1), 
                       radius: 12, x: 0, y: 8)
        )
    }
    
    // 3. Feature Teaser Section
    private var featureTeaseSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            Text("Coming Soon")
                .font(AppTypography.title3)
                .fontWeight(.bold)
                .foregroundColor(.theme.text)
                .padding(.horizontal, AppSpacing.xs)
            
            // Horizontal scroll of feature cards
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
                .padding(.horizontal, AppSpacing.xs)
                .padding(.bottom, AppSpacing.s)
            }
        }
    }
    
    // 4. Social Media Follow Section
    private var socialFollowSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            Text("Follow Us for Updates")
                .font(AppTypography.title3)
                .fontWeight(.bold)
                .foregroundColor(.theme.text)
                .padding(.horizontal, AppSpacing.xs)
            
            // Social media buttons
            HStack(spacing: AppSpacing.l) {
                // TikTok Button
                SocialButton(
                    platform: "TikTok",
                    username: "@100days.site",
                    icon: "tiktok-icon",
                    url: URL(string: "https://www.tiktok.com/@100days.site")!
                )
                
                // X/Twitter Button
                SocialButton(
                    platform: "X",
                    username: "@100DaysHQ",
                    icon: "x-icon",
                    url: URL(string: "https://twitter.com/100DaysHQ")!
                )
                
                // Instagram Button
                SocialButton(
                    platform: "Instagram",
                    username: "@100days.site",
                    icon: "instagram-icon",
                    url: URL(string: "https://instagram.com/100days.site")!
                )
            }
            .padding(.horizontal, AppSpacing.s)
            .padding(.vertical, AppSpacing.m)
        }
        .padding(AppSpacing.m)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.theme.surface)
                .shadow(color: Color.theme.shadow.opacity(colorScheme == .dark ? 0.3 : 0.1), 
                       radius: 8, x: 0, y: 4)
        )
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
                .font(.headline)
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
            usernameClaimSection
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
            Text("Coming Summer 2025")
                .font(AppTypography.caption)
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
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.theme.text)
                
                Text("We're working hard to bring you a full social experience. For now, you can claim your username and prepare for the launch.")
                    .font(.subheadline)
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

// Feature Card Model
struct FeatureCard: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let iconName: String
}

// Feature Teaser Card
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
                    .blur(radius: animateGlow ? 8 : 5)
                    .opacity(animateGlow ? 0.8 : 0.5)
                
                Image(systemName: iconName)
                    .font(.system(size: 28))
                    .foregroundColor(.theme.accent.opacity(0.6))
                
                // Lock overlay
                Image(systemName: "lock.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(6)
                    .background(
                        Circle()
                            .fill(Color.theme.accent)
                    )
                    .offset(x: 20, y: 20)
            }
            .padding(.top, AppSpacing.s)
            
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(title)
                    .font(AppTypography.headline)
                    .foregroundColor(.theme.text)
                
                Text(description)
                    .font(AppTypography.caption)
                    .foregroundColor(.theme.subtext)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, AppSpacing.s)
            
            Spacer()
        }
        .padding(AppSpacing.m)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.theme.surface)
                .shadow(color: Color.theme.shadow.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.theme.accent.opacity(0.2), lineWidth: 1)
        )
        .onAppear {
            withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                animateGlow = true
            }
        }
    }
}

// Social Media Button
struct SocialButton: View {
    let platform: String
    let username: String
    let icon: String
    let url: URL
    
    @State private var isPressed = false
    
    var body: some View {
        Button {
            // Open URL
            UIApplication.shared.open(url)
            
            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        } label: {
            VStack(spacing: AppSpacing.s) {
                // Icon
                if ["tiktok-icon", "x-icon", "instagram-icon"].contains(icon) {
                    // Use custom icon if available
                    Image(systemName: getSFSymbolFallback(for: icon))
                        .font(.system(size: 28))
                        .foregroundColor(getIconColor(for: platform))
                } else {
                    // Use SF Symbol as fallback
                    Image(systemName: getSFSymbolFallback(for: icon))
                        .font(.system(size: 28))
                        .foregroundColor(getIconColor(for: platform))
                }
                
                // Platform name and username
                VStack(spacing: 2) {
                    Text(platform)
                        .font(AppTypography.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.theme.text)
                    
                    Text(username)
                        .font(AppTypography.caption)
                        .foregroundColor(.theme.subtext)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(AppSpacing.m)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.theme.surface)
                    .shadow(color: Color.theme.shadow.opacity(0.1), radius: isPressed ? 2 : 5, x: 0, y: isPressed ? 1 : 3)
            )
        }
        .buttonStyle(AppScaleButtonStyle())
    }
    
    // Helper to get color for different platforms
    private func getIconColor(for platform: String) -> Color {
        switch platform {
        case "TikTok":
            return Color.black.opacity(colorScheme == .dark ? 0.9 : 0.8)
        case "X":
            return Color.black.opacity(colorScheme == .dark ? 0.9 : 0.8)
        case "Instagram":
            return Color.purple
        default:
            return Color.theme.accent
        }
    }
    
    // Helper to get SF Symbol fallbacks if needed
    private func getSFSymbolFallback(for icon: String) -> String {
        switch icon {
        case "tiktok-icon":
            return "play.rectangle.fill"
        case "x-icon":
            return "message.fill"
        case "instagram-icon":
            return "camera.fill"
        default:
            return icon
        }
    }
    
    @Environment(\.colorScheme) private var colorScheme
}

/// Loading overlay view
struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                
                Text("Loading...")
                    .font(.headline)
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
                .font(.headline)
            
            Text("Username reserved for future social features!")
                .font(.subheadline)
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