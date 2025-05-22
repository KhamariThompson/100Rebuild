import SwiftUI
import PhotosUI
import Firebase
import FirebaseAuth

// Using canonical Challenge model
// (No import needed as it will be accessed directly)

struct ProfileView: View {
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var subscriptionService: SubscriptionService
    @EnvironmentObject var notificationService: NotificationService
    @EnvironmentObject var router: TabViewRouter
    @StateObject private var viewModel = ProfileViewModel()
    
    @State private var isShowingSettings = false
    @State private var isShowingAnalytics = false
    @State private var isShowingNewChallenge = false
    @State private var isShowingUsernamePrompt = false
    @FocusState private var isUsernameFocused: Bool
    @State private var scrollOffset: CGFloat = 0
    
    // Profile gradient for header title
    private let profileGradient = LinearGradient(
        gradient: Gradient(colors: [Color.theme.accent, Color.theme.accent.opacity(0.7)]),
        startPoint: .leading,
        endPoint: .trailing
    )
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.theme.background
                    .ignoresSafeArea()
                
                // Full screen loading view when initially loading
                if viewModel.isInitialLoad {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                            .padding()
                        
                        Text("Loading your profile...")
                            .foregroundColor(.theme.subtext)
                            .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity)
                } 
                // Main content with title inside ScrollView (scrolls with content)
                else {
                    ScrollView {
                        VStack(spacing: AppSpacing.m) {
                            // Title with gradient inside the ScrollView
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Profile")
                                    .font(.largeTitle)
                                    .bold()
                                    .foregroundStyle(profileGradient)
                                
                                // Subtitle if username is available
                                if !viewModel.username.isEmpty {
                                    Text("@\(viewModel.username)")
                                        .font(.system(size: 15, weight: .medium, design: .rounded))
                                        .foregroundColor(.theme.subtext)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                            .padding(.top, AppSpacing.m)
                            
                            // Hero Section
                            profileHeroSection
                                .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                                .padding(.bottom, AppSpacing.l)
                            
                            // Stats Section - Horizontal Scrolling
                            statsScrollSection
                                .padding(.bottom, AppSpacing.l)
                            
                            // Action Bar - Horizontal
                            horizontalActionBar
                                .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                                .padding(.bottom, AppSpacing.l)
                            
                            // Last Active Challenge - Condensed
                            if let lastActiveChallenge = viewModel.lastActiveChallenge {
                                condensedChallengePreview(challenge: lastActiveChallenge)
                                    .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                            } else {
                                noActiveChallenge
                                    .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                            }
                            
                            // Add some bottom padding for better scrolling
                            Color.clear.frame(height: 40)
                        }
                    }
                    .safeAreaInset(edge: .top) {
                        // Spacer to ensure content doesn't appear under the header
                        Color.clear.frame(height: 0)
                    }
                    .overlay {
                        if viewModel.isLoading && !viewModel.isInitialLoad {
                            VStack {
                                ProgressView()
                                    .scaleEffect(1.5)
                                    .padding()
                            }
                            .frame(width: 100, height: 100)
                            .background(
                                RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                                    .fill(Color.theme.surface.opacity(0.8))
                                    .shadow(color: Color.theme.shadow, radius: 8, x: 0, y: 2)
                            )
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
            }
            .navigationBarHidden(true) // Hide navigation bar since we have our own header
            .animation(.easeInOut(duration: 0.3), value: viewModel.isInitialLoad)
            .animation(.easeInOut(duration: 0.3), value: viewModel.isLoading)
            .alert(isPresented: Binding<Bool>(
                get: { viewModel.error != nil },
                set: { if !$0 { viewModel.error = nil } }
            )) {
                Alert(
                    title: Text("Error"),
                    message: Text(viewModel.error ?? "Unknown error"),
                    dismissButton: .default(Text("OK"))
                )
            }
            .fullScreenCover(isPresented: $isShowingUsernamePrompt) {
                UsernamePromptView(username: $viewModel.newUsername, onSave: {
                    Task {
                        await viewModel.saveUsername()
                    }
                })
            }
            .fixedSheet(isPresented: $isShowingSettings) {
                SettingsView()
            }
            .fixedSheet(isPresented: $isShowingAnalytics) {
                Text("Profile Analytics")
                    .font(.title)
                    .padding()
            }
            .fixedSheet(isPresented: $isShowingNewChallenge) {
                Text("New Challenge")
                    .font(.title)
                    .padding()
            }
            .onAppear {
                // Load user profile data
                viewModel.loadUserProfile()
                
                // Show username prompt if no username is set
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if !viewModel.isInitialLoad && viewModel.username.isEmpty {
                        isShowingUsernamePrompt = true
                    }
                }
                
                // Add observer for profile photo updates
                NotificationCenter.default.addObserver(
                    forName: Notification.Name("UserProfilePhotoUpdated"),
                    object: nil,
                    queue: .main
                ) { [weak viewModel] notification in
                    if let url = notification.object as? URL {
                        Task {
                            await viewModel?.loadImageFromURL(url)
                        }
                    }
                }
            }
            .onDisappear {
                // Remove notification observers
                NotificationCenter.default.removeObserver(self, name: Notification.Name("UserProfilePhotoUpdated"), object: nil)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // MARK: - UI Components
    
    // Hero Section with avatar, username, and join date
    private var profileHeroSection: some View {
        VStack(spacing: 12) { // Reduced spacing between elements
            ZStack {
                // Profile Image
                profileImageView
                
                // Edit photo button overlay
                Circle()
                    .fill(Color.black.opacity(0.4))
                    .frame(width: 100, height: 100)
                    .overlay(
                        Image(systemName: "camera.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                    )
                    .opacity(0.7)
                    .photoSourcePicker(
                        showSourceOptions: $viewModel.showPhotoSourceOptions,
                        showCameraPicker: $viewModel.showCameraPicker,
                        photosPickerSelection: $viewModel.selectedPhoto
                    )
                    .onChange(of: viewModel.selectedPhoto) { oldValue, newValue in
                        if newValue != nil {
                            viewModel.updateProfilePhoto()
                        }
                    }
            }
            
            // Username display with @ symbol
            Text("@\(viewModel.username.isEmpty ? (userSession.username ?? "username") : viewModel.username)")
                .font(AppTypography.title2)
                .bold()
                .foregroundColor(.theme.text)
                .padding(.top, 4) // Reduced padding
            
            // Join date only - streak info removed
            Text("Joined \(getMemberSinceDate())")
                .font(AppTypography.footnote)
                .foregroundColor(.theme.subtext)
            
            // Edit profile button
            Button(action: { 
                isShowingSettings = true
            }) {
                Label("Edit Profile", systemImage: "pencil")
                    .font(AppTypography.callout)
                    .fontWeight(.medium)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .stroke(Color.theme.accent, lineWidth: 1.5)
                    )
                    .foregroundColor(.theme.accent)
            }
            .padding(.top, 4) // Reduced padding
        }
        .padding(.vertical, AppSpacing.s) // Reduced vertical padding
        .padding(.horizontal, AppSpacing.m)
        .background(
            RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                .fill(Color.theme.surface)
                .shadow(color: Color.theme.shadow, radius: 4, x: 0, y: 2)
        )
    }
    
    // Stats horizontal scroll area
    private var statsScrollSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.s) {
                // Member Since Stat
                ProfileStatCard(
                    icon: "calendar",
                    value: viewModel.memberSinceDate?.formatAsMonthYear() ?? "N/A",
                    label: "Member Since",
                    iconColor: .blue
                )
                
                // Active Challenges Stat
                ProfileStatCard(
                    icon: "flag.fill",
                    value: "\(ChallengeStore.shared.getActiveChallenges().count)",
                    label: "Active Challenges",
                    iconColor: .green
                )
                
                // Current Streak Stat
                ProfileStatCard(
                    icon: "flame.fill",
                    value: "\(viewModel.currentStreak)",
                    label: "Current Streak",
                    iconColor: .orange
                )
            }
            .padding(.horizontal, AppSpacing.screenHorizontalPadding)
        }
    }
    
    // Action Bar - Horizontal layout with capsule buttons
    private var horizontalActionBar: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Text("Quick Actions")
                .font(AppTypography.headline)
            
            HStack(spacing: AppSpacing.m) {
                // Analytics button
                ActionButton(title: "View Analytics", icon: "chart.pie.fill", color: .blue) {
                    // Navigate to Progress tab and mark for showing analytics
                    router.changeTab(to: 1)
                    // Use notification to trigger the action in the target tab
                    NotificationCenter.default.post(
                        name: Notification.Name("ShowProgressAnalytics"),
                        object: nil
                    )
                }
                
                // Create challenge button
                ActionButton(title: "Create Challenge", icon: "plus", color: .green) {
                    // Navigate to Challenges tab and trigger new challenge
                    router.changeTab(to: 0)
                    // Allow time for the tab to switch
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isShowingNewChallenge = true
                    }
                }
                
                // Settings button
                ActionButton(title: "Settings", icon: "gear", color: .gray) {
                    isShowingSettings = true
                }
            }
        }
    }
    
    // Condensed Challenge Preview without circular progress
    private func condensedChallengePreview(challenge: Challenge) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Text("Current Challenge")
                .font(AppTypography.headline)
            
            Button(action: {
                // Navigate to the challenge detail
                router.changeTab(to: 0)
                // Post notification to show this specific challenge
                NotificationCenter.default.post(
                    name: Notification.Name("ShowChallenge"),
                    object: challenge.id
                )
            }) {
                VStack(alignment: .leading, spacing: AppSpacing.s) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(challenge.title)
                                .font(AppTypography.callout)
                                .fontWeight(.semibold)
                                .foregroundColor(.theme.text)
                            
                            Text("Day \(challenge.daysCompleted) of 100")
                                .font(AppTypography.footnote)
                                .foregroundColor(.theme.subtext)
                        }
                        
                        Spacer()
                        
                        // Day count or completed badge
                        if challenge.isCompleted {
                            Text("Completed")
                                .font(AppTypography.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.green.opacity(0.2))
                                )
                                .foregroundColor(.green)
                        } else {
                            Text("\(challenge.daysCompleted)%")
                                .font(AppTypography.callout)
                                .fontWeight(.semibold)
                                .foregroundColor(.theme.accent)
                        }
                    }
                    
                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.theme.subtext.opacity(0.2))
                                .frame(height: 6)
                                .cornerRadius(3)
                            
                            Rectangle()
                                .fill(Color.theme.accent)
                                .frame(width: max(0, min(CGFloat(challenge.progressPercentage) * geometry.size.width, geometry.size.width)), height: 6)
                                .cornerRadius(3)
                        }
                    }
                    .frame(height: 6)
                    
                    // Last check-in time
                    if let lastCheckIn = challenge.lastCheckInDate {
                        HStack {
                            Image(systemName: "clock")
                                .font(.system(size: 12))
                                .foregroundColor(.theme.subtext)
                            
                            Text("Last check-in \(timeAgoFormatter.localizedString(for: lastCheckIn, relativeTo: Date()))")
                                .font(AppTypography.caption)
                                .foregroundColor(.theme.subtext)
                        }
                    }
                }
                .padding(AppSpacing.m)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                        .fill(Color.theme.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                        .stroke(Color.theme.border, lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // No active challenge view
    private var noActiveChallenge: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Text("No Active Challenge")
                .font(AppTypography.headline)
            
            Button(action: {
                // Navigate to Challenges tab
                router.changeTab(to: 0)
                // Delay before showing new challenge sheet
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isShowingNewChallenge = true
                }
            }) {
                VStack(spacing: AppSpacing.m) {
                    Image(systemName: "flag.slash")
                        .font(.system(size: 32))
                        .foregroundColor(.theme.subtext)
                    
                    Text("Start your first 100-day challenge")
                        .font(AppTypography.callout)
                        .fontWeight(.medium)
                        .foregroundColor(.theme.text)
                        .multilineTextAlignment(.center)
                    
                    Text("Start Challenge")
                        .font(AppTypography.callout)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 24)
                        .background(
                            Capsule()
                                .fill(Color.theme.accent)
                        )
                }
                .padding(AppSpacing.m)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                        .fill(Color.theme.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                        .stroke(Color.theme.border, lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // Profile image view component
    private var profileImageView: some View {
        Group {
            if viewModel.isLoadingImage {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(width: 100, height: 100)
            } else if let profileImage = viewModel.profileImage {
                Image(uiImage: profileImage)
                    .resizable()
                    .scaledToFill()
                    .circularAvatarStyle(size: 100)
                    .successCheckmark(isShowing: viewModel.showSuccessAnimation)
            } else {
                // Use ProfilePictureView if available in UserSession
                if let photoURL = userSession.photoURL {
                    ProfilePictureView(url: photoURL, size: 100)
                        .successCheckmark(isShowing: viewModel.showSuccessAnimation)
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 100))
                        .foregroundColor(.theme.accent)
                        .successCheckmark(isShowing: viewModel.showSuccessAnimation)
                }
            }
        }
    }
    
    // MARK: - Helper Components
    
    // Stat badge for the horizontal scroll section
    struct ProfileStatCard: View {
        let icon: String
        let value: String
        let label: String
        let iconColor: Color
        
        var body: some View {
            VStack(alignment: .center, spacing: 4) {
                // Icon in a circle
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(iconColor)
                }
                .padding(.bottom, 4)
                
                // Value
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.theme.text)
                
                // Label
                Text(label)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.theme.subtext)
                    .multilineTextAlignment(.center)
            }
            .frame(minWidth: 100)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.theme.surface)
                    .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
            )
        }
    }
    
    // Action button for the horizontal action bar
    struct ActionButton: View {
        let title: String
        let icon: String
        let color: Color
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                    
                    Text(title)
                        .font(AppTypography.footnote)
                        .fontWeight(.medium)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .foregroundColor(color)
                .background(
                    Capsule()
                        .stroke(color, lineWidth: 1.5)
                )
            }
            .buttonStyle(AppScaleButtonStyle())
        }
    }
    
    // Username Prompt Full-Screen Modal
    struct UsernamePromptView: View {
        @Binding var username: String
        var onSave: () -> Void
        @Environment(\.dismiss) private var dismiss
        
        var body: some View {
            ZStack {
                Color.theme.background.ignoresSafeArea()
                
                VStack(spacing: AppSpacing.l) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 70))
                        .foregroundColor(.theme.accent)
                        .padding(.bottom, AppSpacing.m)
                    
                    Text("Choose Your Username")
                        .font(AppTypography.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("This will be your display name throughout the app.")
                        .font(AppTypography.body)
                        .foregroundColor(.theme.subtext)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.xl)
                    
                    VStack(spacing: AppSpacing.s) {
                        HStack {
                            Text("@")
                                .font(AppTypography.title3)
                                .foregroundColor(.theme.subtext)
                            
                            TextField("username", text: $username)
                                .font(AppTypography.title3)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                                .fill(Color.theme.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                                .stroke(Color.theme.border, lineWidth: 1)
                        )
                        
                        Button(action: {
                            onSave()
                            dismiss()
                        }) {
                            Text("Save Username")
                                .font(AppTypography.callout)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                                        .fill(username.isEmpty ? Color.gray : Color.theme.accent)
                                )
                        }
                        .disabled(username.isEmpty)
                    }
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.top, AppSpacing.m)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    // Format the member since date
    private func getMemberSinceDate() -> String {
        // First try to get date from ViewModel (Firestore data)
        if let memberSinceDate = viewModel.memberSinceDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: memberSinceDate)
        }
        
        // If not available in ViewModel, try to get directly from Firebase Auth
        if let creationDate = Auth.auth().currentUser?.metadata.creationDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: creationDate)
        }
        
        // If all else fails, show "Unavailable"
        return "Unavailable"
    }
    
    // Relative time formatter for "time ago" strings
    private var timeAgoFormatter: RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }
}

// MARK: - Preview Provider
struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
            .environmentObject(UserSession.shared)
            .environmentObject(SubscriptionService.shared)
            .environmentObject(NotificationService.shared)
            .environmentObject(TabViewRouter())
    }
}

// MARK: - Helper Extensions

// New helper extension for formatting date as month and year
extension Date {
    func formatAsMonthYear() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: self)
    }
}

// MARK: - Static Components

// StatCard view for showing stats with icon
struct ProfileStatCard: View {
    let icon: String
    let value: String
    let label: String
    let iconColor: Color
    
    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            // Icon in a circle
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            .padding(.bottom, 4)
            
            // Value
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.theme.text)
            
            // Label
            Text(label)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.theme.subtext)
                .multilineTextAlignment(.center)
        }
        .frame(minWidth: 100)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.theme.surface)
                .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
        )
    }
} 