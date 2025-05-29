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
    @EnvironmentObject var router: NavigationRouter
    @EnvironmentObject var badgeService: BadgeService
    @StateObject private var viewModel = ProfileViewModel()
    
    @State private var isShowingSettings = false
    @State private var isShowingAnalytics = false
    @State private var isShowingNewChallenge = false
    @State private var isShowingUsernamePrompt = false
    @State private var isShowingPhotoOptions = false
    @State private var isShowingCameraPicker = false
    @State private var isShowingPhotoLibrary = false
    @State private var isShowingImageCropper = false
    @State private var isShowingBadgeEditor = false
    @State private var selectedBadge: Badge? = nil
    @State private var selectedImage: UIImage?
    @State private var isImageReady = false
    @FocusState private var isUsernameFocused: Bool
    @State private var scrollOffset: CGFloat = 0
    
    // Profile gradient for header title
    private let profileGradient = LinearGradient(
        gradient: Gradient(colors: [Color.theme.accent, Color.theme.accent.opacity(0.7)]),
        startPoint: .leading,
        endPoint: .trailing
    )
    
    var body: some View {
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
            } else {
                // Main profile scrolling content
                ScrollView {
                    // Scrollable content that slides under the sticky header
                    VStack(spacing: AppSpacing.m) {
                        // Title header with username
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                // Profile title with gradient
                                Text("Profile")
                                    .font(.largeTitle)
                                    .bold()
                                    .foregroundStyle(profileGradient)
                            }
                            
                            Spacer()
                            
                            // Settings button
                            Button(action: { isShowingSettings = true }) {
                                Image(systemName: "gear")
                                    .font(.system(size: AppSpacing.iconSizeMedium, weight: .semibold))
                                    .foregroundColor(.theme.accent)
                            }
                            .buttonStyle(AppScaleButtonStyle())
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                        .padding(.top, AppSpacing.m)
                        
                        // Top hero section with profile image and username
                        profileHeroSection
                            .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                        
                        // Stats scrolling section
                        statsScrollSection
                        
                        // Badge showcase section
                        BadgeShowcaseView(
                            badges: badgeService.showcasedBadges,
                            onTap: { badge in
                                selectedBadge = badge
                            },
                            onEditTap: {
                                isShowingBadgeEditor = true
                            }
                        )
                        .padding(.top, 8)
                        
                        // Divider for visual separation
                        Divider()
                            .padding(.vertical, AppSpacing.m)
                            .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                        
                        // Horizontal action bar
                        horizontalActionBar
                            .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                        
                        // Divider for visual separation
                        Divider()
                            .padding(.vertical, AppSpacing.m)
                            .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                        
                        // Current Challenge - Show only the most completed one
                        if let challenge = viewModel.mostCompletedChallenge {
                            condensedChallengePreview(challenge: challenge)
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
        // Bio editing sheet
        .sheet(isPresented: $viewModel.isEditingBio) {
            bioEditSheet
        }
        // Error alert
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
        .confirmationDialog("Choose Photo Source", isPresented: $isShowingPhotoOptions) {
            Button("Camera") {
                // Present camera picker on the main thread with a slight delay to ensure proper presentation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isShowingCameraPicker = true
                }
            }
            Button("Photo Library") {
                // Present photo library picker on the main thread with a slight delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isShowingPhotoLibrary = true
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .photosPicker(
            isPresented: $isShowingPhotoLibrary,
            selection: $viewModel.selectedPhoto,
            matching: .images,
            photoLibrary: .shared()
        )
        .onChange(of: viewModel.selectedPhoto) { oldValue, newValue in
            if let newValue = newValue {
                Task {
                    do {
                        let data = try await newValue.loadTransferable(type: Data.self)
                        if let data = data, let image = UIImage(data: data) {
                            await MainActor.run {
                                selectedImage = image
                                isImageReady = true
                                isShowingPhotoLibrary = false
                                // Reset the selection immediately to allow future selections
                                viewModel.selectedPhoto = nil
                            }
                        }
                    } catch {
                        print("Error loading image: \(error)")
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingCameraPicker) {
            ImagePicker(selectedImage: $selectedImage, isPresented: $isShowingCameraPicker, source: .camera)
                .onDisappear {
                    if let image = selectedImage {
                        // Set isImageReady directly on the main thread
                        DispatchQueue.main.async {
                            isImageReady = true
                        }
                    }
                }
        }
        .sheet(isPresented: $isImageReady, onDismiss: {
            selectedImage = nil
            isImageReady = false
        }) {
            NavigationView {
                if let image = selectedImage {
                    ImageCropperView(
                        image: image,
                        onCrop: { croppedImage in
                            Task {
                                await MainActor.run {
                                    viewModel.profileImage = croppedImage
                                }
                                await viewModel.processAndUploadImage(croppedImage)
                                isImageReady = false
                                selectedImage = nil
                            }
                        },
                        onCancel: {
                            isImageReady = false
                            selectedImage = nil
                        }
                    )
                }
            }
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $isShowingAnalytics) {
            Text("Profile Analytics")
                .font(.title)
                .padding()
        }
        .sheet(isPresented: $isShowingNewChallenge) {
            Text("New Challenge")
                .font(.title)
                .padding()
        }
        .sheet(isPresented: $isShowingUsernamePrompt) {
            UsernamePromptView(username: $viewModel.newUsername, onSave: {
                Task {
                    await viewModel.saveUsername()
                }
            })
        }
        .sheet(isPresented: $isShowingBadgeEditor) {
            BadgeShowcaseEditorView()
                .environmentObject(badgeService)
        }
        .sheet(item: $selectedBadge) { badge in
            BadgeDetailView(badge: badge)
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
    
    // MARK: - UI Components
    
    // Hero Section with avatar, username, and bio
    private var profileHeroSection: some View {
        VStack(spacing: 12) {
            // Profile Image with tap gesture
            profileImageView
                .onTapGesture {
                    DispatchQueue.main.async {
                        isShowingPhotoOptions = true
                    }
                }
            
            // Username display with @ symbol
            Text("@\(viewModel.username.isEmpty ? (userSession.username ?? "username") : viewModel.username)")
                .font(AppTypography.title2())
                .bold()
                .foregroundColor(.theme.text)
                .padding(.top, 4)
            
            // Joined date - displayed under username
            Text("Joined \(formatJoinDate(viewModel.memberSinceDate))")
                .font(.system(size: 12))
                .foregroundColor(.theme.subtext.opacity(0.8))
                .padding(.top, -2)
            
            // Bio text (editable on tap)
            ZStack(alignment: .trailing) {
                Text(viewModel.userBio)
                    .font(AppTypography.subhead())
                    .foregroundColor(.theme.subtext)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 24)
            }
            .padding(.vertical, 4)
            
            // Edit profile button
            Button(action: { 
                isShowingSettings = true
            }) {
                Text("Edit Profile")
                    .font(AppTypography.subhead())
                    .foregroundColor(.theme.accent)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .strokeBorder(Color.theme.accent, lineWidth: 1.5)
                    )
            }
            .buttonStyle(PlainButtonStyle())
            
            // Milestone badge (if applicable)
            if let milestone = viewModel.streakMilestone {
                milestoneBadge(days: milestone)
                    .padding(.top, 4)
            }
            
            // Pro badge if user is subscribed
            if subscriptionService.isProUser {
                HStack {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.yellow)
                        .font(.system(size: 12))
                    
                    Text("PRO")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.yellow)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.yellow.opacity(0.15))
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.yellow.opacity(0.3), lineWidth: 1)
                        )
                )
                .padding(.top, 4)
            }
        }
    }
    
    // Milestone badge view
    private func milestoneBadge(days: Int) -> some View {
        HStack(spacing: 6) {
            Image(systemName: days >= 100 ? "flame.fill" : "flame")
                .foregroundColor(days >= 100 ? .orange : .theme.accent)
                .font(.system(size: 14))
            
            Text("\(days)-Day Streak Achieved!")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(days >= 100 ? .orange : .theme.accent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(days >= 100 ? Color.orange.opacity(0.15) : Color.theme.accent.opacity(0.1))
                .overlay(
                    Capsule()
                        .strokeBorder(days >= 100 ? Color.orange.opacity(0.3) : Color.theme.accent.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // Bio edit sheet - a better alternative with a text field
    private var bioEditSheet: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Tell us about yourself")
                    .font(AppTypography.title3())
                    .padding(.top, 20)
                
                Text("Your bio helps people understand who you are")
                    .font(AppTypography.subhead())
                    .foregroundColor(.theme.subtext)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                
                TextField("Bio", text: $viewModel.userBio)
                    .padding()
                    .background(Color.theme.surface)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.theme.border, lineWidth: 1)
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                
                Text("Keep it brief - it will be displayed as max 2 lines")
                    .font(AppTypography.caption1())
                    .foregroundColor(.theme.subtext)
                    .padding(.top, -5)
                
                Spacer()
            }
            .padding()
            .background(Color.theme.background.edgesIgnoringSafeArea(.all))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.isEditingBio = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await viewModel.saveBio(viewModel.userBio)
                        }
                    }
                }
            }
        }
    }
    
    // Stats horizontal scroll area
    private var statsScrollSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            // Section title
            Text("Your Momentum")
                .font(AppTypography.headline())
                .foregroundColor(.theme.text)
                .padding(.horizontal, AppSpacing.screenHorizontalPadding)
            
            // Static row of three cards
            HStack(spacing: AppSpacing.m) {
                // Current Streak Stat
                MomentumCard(
                    icon: "flame.fill",
                    value: "\(viewModel.currentStreak)",
                    label: "Current Streak",
                    description: "days in a row"
                )
                .frame(maxWidth: .infinity)
                
                // Longest Streak Stat
                MomentumCard(
                    icon: "trophy.fill",
                    value: "\(viewModel.longestStreak)",
                    label: "Longest Streak",
                    description: "days"
                )
                .frame(maxWidth: .infinity)
                
                // Completion Rate Stat
                MomentumCard(
                    icon: "chart.bar.fill",
                    value: String(format: "%.0f%%", viewModel.completionRate),
                    label: "Completion Rate",
                    description: "overall success"
                )
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, AppSpacing.screenHorizontalPadding)
        }
        .padding(.bottom, AppSpacing.s)
    }
    
    // Stat card for momentum section
    private struct MomentumCard: View {
        let icon: String
        let value: String
        let label: String
        let description: String
        @Environment(\.colorScheme) private var colorScheme
        
        var body: some View {
            VStack(alignment: .center, spacing: 6) {
                // Icon in a circle
                ZStack {
                    Circle()
                        .fill(getIconColor().opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(getIconColor())
                }
                
                // Value
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.theme.text)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
                
                // Label
                Text(label)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.theme.text)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                
                // Description
                Text(description)
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundColor(.theme.subtext.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.theme.surface)
                    .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
            )
        }
        
        // Get appropriate icon color based on icon type
        private func getIconColor() -> Color {
            switch icon {
            case "flame.fill":
                return .orange
            case "trophy.fill":
                return .yellow
            case "chart.bar.fill":
                return .blue
            default:
                return .theme.accent
            }
        }
    }
    
    // Action Bar - Horizontal layout with capsule buttons
    private var horizontalActionBar: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Text("Quick Actions")
                .font(AppTypography.headline())
            
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
                .frame(maxWidth: .infinity)
                
                // Create challenge button
                ActionButton(title: "Create Challenge", icon: "plus", color: .green) {
                    // Navigate to Challenges tab and trigger new challenge
                    router.changeTab(to: 0)
                    // Allow time for the tab to switch
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isShowingNewChallenge = true
                    }
                }
                .frame(maxWidth: .infinity)
                
                // Settings button (updated to match other action buttons)
                ActionButton(title: "Settings", icon: "gear", color: .gray) {
                    isShowingSettings = true
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
    
    // Condensed Challenge Preview without circular progress
    private func condensedChallengePreview(challenge: Challenge) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Text("Challenge In Progress")
                .font(AppTypography.headline())
            
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
                                .font(AppTypography.callout())
                                .fontWeight(.semibold)
                                .foregroundColor(.theme.text)
                            
                            Text("Day \(challenge.daysCompleted) of 100")
                                .font(AppTypography.footnote())
                                .foregroundColor(.theme.subtext)
                        }
                        
                        Spacer()
                        
                        // Day count or completed badge
                        if challenge.isCompleted {
                            Text("Completed")
                                .font(AppTypography.caption1())
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
                                .font(AppTypography.callout())
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
                                .font(AppTypography.caption1())
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
                .font(AppTypography.headline())
            
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
                        .font(AppTypography.callout())
                        .fontWeight(.medium)
                        .foregroundColor(.theme.text)
                        .multilineTextAlignment(.center)
                    
                    Text("Start Challenge")
                        .font(AppTypography.callout())
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
        ZStack {
            // Base consistent background
            Circle()
                .fill(Color.theme.surface)
                .frame(width: 100, height: 100)
            
            // Different states layered with transitions
            Group {
                if viewModel.isLoadingImage {
                    // Loading state
                    ProgressView()
                        .scaleEffect(1.0)
                        .progressViewStyle(CircularProgressViewStyle(tint: Color.theme.accent))
                    
                    // Show current image with reduced opacity while loading
                    if let profileImage = viewModel.profileImage {
                        Image(uiImage: profileImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                            .opacity(0.5)
                    }
                } else if let profileImage = viewModel.profileImage {
                    // Locally loaded image (e.g. after camera capture or upload)
                    Image(uiImage: profileImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                        .transition(.opacity)
                        .successCheckmark(isShowing: viewModel.showSuccessAnimation)
                } else if let photoURL = userSession.photoURL {
                    // Remote image from URL
                    ProfilePictureView(url: photoURL, size: 100)
                        .transition(.opacity)
                        .successCheckmark(isShowing: viewModel.showSuccessAnimation)
                } else {
                    // Fallback to initials
                    InitialAvatarView(
                        name: viewModel.username.isEmpty ? (userSession.username ?? "User") : viewModel.username,
                        size: 100,
                        backgroundColor: Color.theme.accent
                    )
                    .transition(.opacity)
                    .successCheckmark(isShowing: viewModel.showSuccessAnimation)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: viewModel.isLoadingImage)
            .animation(.easeInOut(duration: 0.3), value: viewModel.profileImage != nil)
            .animation(.easeInOut(duration: 0.3), value: userSession.photoURL != nil)
        }
        .frame(width: 100, height: 100)
    }
    
    // MARK: - Helper Components
    
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
                        .font(AppTypography.footnote())
                        .fontWeight(.medium)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .foregroundColor(color)
                .background(
                    Capsule()
                        .stroke(color, lineWidth: 1.5)
                )
                .frame(minWidth: 120) // Set a minimum width for consistent sizing
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
                        .font(AppTypography.title2())
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("This will be your display name throughout the app.")
                        .font(AppTypography.body())
                        .foregroundColor(.theme.subtext)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.xl)
                    
                    VStack(spacing: AppSpacing.s) {
                        HStack {
                            Text("@")
                                .font(AppTypography.title3())
                                .foregroundColor(.theme.subtext)
                            
                            TextField("username", text: $username)
                                .font(AppTypography.title3())
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
                                .font(AppTypography.callout())
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
    private func formatJoinDate(_ date: Date?) -> String {
        // First try to use the date from ViewModel (Firestore data)
        if let joinDate = date {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: joinDate)
        }
        
        // If not available in ViewModel, try to get directly from Firebase Auth
        if let creationDate = Auth.auth().currentUser?.metadata.creationDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: creationDate)
        }
        
        // If all else fails, return empty string
        return "Unknown"
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
            .environmentObject(NavigationRouter())
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

// Helper struct to configure UIScrollView properties
private struct ScrollViewConfigurator: UIViewRepresentable {
    let decelerationRate: UIScrollView.DecelerationRate
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            if let scrollView = uiView.superview?.superview?.superview as? UIScrollView {
                scrollView.decelerationRate = decelerationRate
                scrollView.showsHorizontalScrollIndicator = false
                scrollView.bounces = true
                scrollView.alwaysBounceHorizontal = true
            }
        }
    }
} 