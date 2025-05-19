import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct SocialView: View {
    @StateObject private var viewModel = SocialViewModel()
    @Environment(\.colorScheme) private var colorScheme
    @State private var scrollOffset: CGFloat = 0
    
    // Social gradient for header title
    private let socialGradient = LinearGradient(
        gradient: Gradient(colors: [Color.theme.accent, Color.purple.opacity(0.7)]),
        startPoint: .leading,
        endPoint: .trailing
    )
    
    var body: some View {
        ZStack(alignment: .top) {
            // Background
            Color.theme.background
                .ignoresSafeArea()
            
            // Content with scroll tracking
            ScrollView {
                VStack(spacing: 0) {
                    // Spacer to push content below the header
                    Color.clear
                        .frame(height: 110)
                    
                    // Main content
                    VStack(spacing: 24) {
                        // Social coming soon header
                        socialComingSoonHeader
                        
                        // Username card
                        usernameCard
                        
                        // Social links section
                        socialLinksSection
                            .padding(.top)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 16)
                }
                .trackScrollOffset($scrollOffset)
            }
            
            // Overlay the dynamic header
            ScrollAwareHeaderView(
                title: "Social",
                scrollOffset: $scrollOffset,
                subtitle: "Connect with others",
                accentGradient: socialGradient
            )
        }
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
        .onAppear {
            // Only fetch the username when the view appears
            Task {
                await viewModel.loadUserUsername()
            }
        }
    }
    
    // MARK: - View Components
    
    private var socialComingSoonHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Social is Coming to 100Days!")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(Color.theme.text)
            
            Text("Connect with others on your 100-day journey — friends, group challenges, and leaderboards are on the way.")
                .font(.body)
                .foregroundColor(Color.theme.subtext)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var usernameCard: some View {
        VStack(spacing: 0) {
            if case .claimed(let username) = viewModel.usernameStatus {
                // User has already claimed a username
                UsernameDisplayView(username: username)
            } else {
                // Error or loading state
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
    
    private var socialLinksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Follow Us for Launch Updates")
                .font(.headline)
                .foregroundColor(Color.theme.text)
            
            // Social media buttons
            HStack(spacing: 20) {
                SocialLinkButton(
                    platform: "TikTok", 
                    username: "@100days.site",
                    sfSymbol: "play.rectangle.fill",
                    color: .black,
                    url: URL(string: "https://www.tiktok.com/@100days.site")
                )
                
                SocialLinkButton(
                    platform: "X", 
                    username: "@100DaysHQ",
                    sfSymbol: "message.fill",
                    color: .black,
                    url: URL(string: "https://twitter.com/100DaysHQ")
                )
                
                SocialLinkButton(
                    platform: "Instagram", 
                    username: "@100days.site",
                    sfSymbol: "camera.fill",
                    color: .purple,
                    url: URL(string: "https://www.instagram.com/100days.site")
                )
            }
            .padding(.top, 4)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.theme.surface)
                .shadow(color: Color.theme.shadow.opacity(colorScheme == .dark ? 0.3 : 0.1), 
                       radius: 8, x: 0, y: 4)
        )
    }
}

// MARK: - Supporting Views

/// View for displaying the user's username with animation
struct UsernameDisplayView: View {
    let username: String
    @State private var animateCheckmark = false
    @State private var showConfetti = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Your username is ")
                    .foregroundColor(Color.theme.text) +
                Text("@\(username)")
                    .foregroundColor(Color.theme.accent)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Color.theme.success)
                    .font(.title2)
                    .scaleEffect(animateCheckmark ? 1.2 : 1.0)
                    .opacity(animateCheckmark ? 1.0 : 0.7)
            }
            
            Text("You'll use this to connect with friends, join challenges, appear on future leaderboards, and be discoverable by others.")
                .font(.subheadline)
                .foregroundColor(Color.theme.subtext)
                .lineSpacing(4)
        }
        .overlay {
            if showConfetti {
                ConfettiView(intensity: 0.5, duration: 2.0)
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            // Animate checkmark with spring effect
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                animateCheckmark = true
            }
            
            // Show confetti with a slight delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showConfetti = true
                
                // Provide haptic feedback
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            }
            
            // Reset animation after a delay for next appearance
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                showConfetti = false
                animateCheckmark = false
            }
        }
    }
}

/// Social media link button with URL linking
struct SocialLinkButton: View {
    let platform: String
    let username: String
    let sfSymbol: String
    let color: Color
    let url: URL?
    
    var body: some View {
        Button {
            if let url = url {
                openURL(url)
            }
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.1))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: sfSymbol)
                        .font(.system(size: 20))
                        .foregroundColor(color)
                }
                
                VStack(spacing: 2) {
                    Text(platform)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(Color.theme.text)
                    
                    Text(username)
                        .font(.caption2)
                        .foregroundColor(Color.theme.subtext)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
    
    private func openURL(_ url: URL) {
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
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

struct SocialView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SocialView()
                .navigationTitle("Social")
        }
    }
} 