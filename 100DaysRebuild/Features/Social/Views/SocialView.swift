import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct SocialView: View {
    @StateObject private var viewModel = SocialViewModel()
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Social coming soon header
                socialComingSoonHeader
                
                // Username claim card
                usernameClaimCard
                
                // Social links section
                socialLinksSection
                    .padding(.top)
            }
            .padding(.horizontal)
            .padding(.vertical, 16)
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
    }
    
    // MARK: - View Components
    
    private var socialComingSoonHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Social is Coming to 100Days!")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(Color.theme.text)
            
            Text("Connect with others on their 100-day journey – friends, group challenges, and leaderboards are on the way.")
                .font(.body)
                .foregroundColor(Color.theme.subtext)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top)
    }
    
    private var usernameClaimCard: some View {
        VStack(spacing: 0) {
            if case .claimed(let username) = viewModel.usernameStatus {
                // User has already claimed a username
                ClaimedUsernameView(username: username)
            } else {
                // User has not claimed a username yet
                UsernameClaimFormView(viewModel: viewModel)
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
                    username: "@100Days.site",
                    sfSymbol: "play.rectangle.fill",
                    color: .black
                )
                
                SocialLinkButton(
                    platform: "X", 
                    username: "@100DaysHQ",
                    sfSymbol: "message.fill",
                    color: .black
                )
                
                SocialLinkButton(
                    platform: "Instagram", 
                    username: "@100Days.site",
                    sfSymbol: "camera.fill",
                    color: .purple
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

/// View for displaying when username has been claimed
struct ClaimedUsernameView: View {
    let username: String
    @State private var animateCheckmark = false
    @State private var animateUsername = false
    
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
                    .scaleEffect(animateCheckmark ? 1.0 : 0.8)
                    .opacity(animateCheckmark ? 1.0 : 0.7)
            }
            
            Text("You'll use this to join groups, appear on leaderboards, and tag friends in the future.")
                .font(.subheadline)
                .foregroundColor(Color.theme.subtext)
                .lineSpacing(4)
                .opacity(animateUsername ? 1.0 : 0.8)
        }
        .onAppear {
            // Small subtle animation when the view appears
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                animateCheckmark = true
            }
            
            withAnimation(.easeInOut(duration: 0.6)) {
                animateUsername = true
            }
        }
    }
}

/// View for username claim form
struct UsernameClaimFormView: View {
    @ObservedObject var viewModel: SocialViewModel
    @FocusState private var isUsernameFocused: Bool
    @State private var animateCheckmark = false
    @State private var animateUsername = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Claim Your Username")
                .font(.headline)
                .foregroundColor(Color.theme.text)
            
            Text("Reserve your username now to secure your identity before others claim it.")
                .font(.subheadline)
                .foregroundColor(Color.theme.subtext)
                .padding(.bottom, 4)
            
            // Username text field
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("@")
                        .foregroundColor(Color.theme.accent)
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
                    .focused($isUsernameFocused)
                    .textInputAutocapitalization(.never)
                    .textContentType(.username)
                    .submitLabel(.done)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(validationBorderColor, lineWidth: 1)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.theme.background)
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
                                .foregroundColor(.red)
                                .font(.system(size: 12))
                        } else if viewModel.validationMessage == "Username available!" {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 12))
                        }
                        
                        Text(viewModel.validationMessage)
                            .font(.caption)
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
                HStack {
                    Spacer()
                    Text("Claim Username")
                        .fontWeight(.semibold)
                    Spacer()
                }
                .padding(.vertical, 12)
                .foregroundColor(.white)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(canClaimUsername ? Color.theme.accent : Color.gray.opacity(0.5))
                )
            }
            .disabled(!canClaimUsername)
            .padding(.top, 8)
            
            // Success animation overlay
            if animateCheckmark {
                SuccessAnimationView(username: viewModel.username, animateCheckmark: $animateCheckmark, animateUsername: $animateUsername)
                    .padding(.top, 16)
            }
        }
        // Observe the usernameJustClaimed property to trigger animations
        .onChange(of: viewModel.usernameJustClaimed) { justClaimed in
            if justClaimed {
                // Trigger haptic feedback
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                
                // Trigger animations
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    animateUsername = true
                }
                
                withAnimation(.easeInOut(duration: 0.4)) {
                    animateCheckmark = true
                }
                
                // Reset animations after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation {
                        animateCheckmark = false
                        animateUsername = false
                    }
                }
            }
        }
    }
    
    // Helper computed properties
    private var canClaimUsername: Bool {
        if viewModel.isCheckingUsername { return false }
        if isInvalidStatus { return false }
        if viewModel.username.isEmpty { return false }
        return viewModel.validationMessage == "Username available!"
    }
    
    // Helper property to check for invalid or error status
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
            return Color.red.opacity(0.7)
        } else if viewModel.validationMessage == "Username available!" {
            return Color.green.opacity(0.7)
        } else {
            return Color.gray.opacity(0.3)
        }
    }
    
    private var validationMessageColor: Color {
        if isInvalidStatus {
            return .red
        } else if viewModel.validationMessage == "Username available!" {
            return .green
        } else {
            return Color.theme.subtext
        }
    }
}

/// Success Animation View
struct SuccessAnimationView: View {
    let username: String
    @Binding var animateCheckmark: Bool
    @Binding var animateUsername: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Text("@\(username)")
                .foregroundColor(Color.theme.accent)
                .fontWeight(.semibold)
                .scaleEffect(animateUsername ? 1.1 : 1.0)
                .modifier(ShimmerEffect(isActive: animateUsername))
            
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(Color.theme.success)
                .font(.title3)
                .scaleEffect(animateCheckmark ? 1.0 : 0.01)
                .opacity(animateCheckmark ? 1 : 0)
                .rotationEffect(animateCheckmark ? .degrees(0) : .degrees(-90))
                .animation(.spring(response: 0.35, dampingFraction: 0.7, blendDuration: 0.5), value: animateCheckmark)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .overlay(
            SocialConfettiView()
                .opacity(animateUsername ? 1 : 0)
        )
    }
}

/// A shimmer effect modifier for text
struct ShimmerEffect: ViewModifier {
    let isActive: Bool
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        if isActive {
            content
                .overlay(
                    GeometryReader { geometry in
                        LinearGradient(
                            gradient: Gradient(colors: [
                                .clear,
                                Color.white.opacity(0.5),
                                .clear
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geometry.size.width * 3)
                        .offset(x: -geometry.size.width + (phase * geometry.size.width * 3))
                        .blendMode(.screen)
                        .animation(
                            Animation.linear(duration: 1.5)
                                .repeatForever(autoreverses: false),
                            value: phase
                        )
                        .onAppear {
                            phase = 1.0
                        }
                    }
                )
                .clipShape(Rectangle())
        } else {
            content
        }
    }
}

/// Improved Confetti View using SwiftUI
struct SocialConfettiView: View {
    @State private var isAnimating = false
    
    private let confettiCount = 30
    private let symbols = ["star.fill", "sparkle", "circle.fill", "largecircle.fill.circle"]
    
    var body: some View {
        ZStack {
            // Particle confetti
            ForEach(0..<confettiCount, id: \.self) { index in
                confettiParticle(for: index)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) {
                isAnimating = true
            }
        }
    }
    
    @ViewBuilder
    private func confettiParticle(for index: Int) -> some View {
        let size = CGFloat.random(in: 5...12)
        let useSymbol = Bool.random()
        let position = CGPoint(
            x: CGFloat.random(in: 50...300),
            y: CGFloat.random(in: -50...10)
        )
        let finalYPosition = CGFloat.random(in: 100...400)
        let duration = Double.random(in: 0.8...1.5)
        let rotation = Double.random(in: 0...360)
        let finalRotation = Double.random(in: 0...360)
        
        Group {
            if useSymbol {
                Image(systemName: symbols.randomElement()!)
                    .foregroundColor(confettiColor(index: index))
                    .font(.system(size: size))
            } else {
                Circle()
                    .fill(confettiColor(index: index))
                    .frame(width: size, height: size)
            }
        }
        .position(position)
        .offset(y: isAnimating ? finalYPosition : 0)
        .rotationEffect(.degrees(isAnimating ? finalRotation : rotation))
        .opacity(isAnimating ? 0 : 1)
        .animation(
            .easeOut(duration: duration)
                .delay(Double.random(in: 0...0.3)),
            value: isAnimating
        )
    }
    
    private func confettiColor(index: Int) -> Color {
        let colors: [Color] = [
            .blue, .green, .yellow, .pink, .purple, 
            .orange, .red, .theme.accent, .theme.success
        ]
        return colors[index % colors.count]
    }
}

// Helper extension for random colors
extension Color {
    static var random: Color {
        let colors: [Color] = [.blue, .green, .yellow, .pink, .purple, .orange, .red]
        return colors.randomElement()!
    }
}

/// Social media link button
struct SocialLinkButton: View {
    let platform: String
    let username: String
    let sfSymbol: String
    let color: Color
    
    var body: some View {
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