import SwiftUI
import PhotosUI
import Firebase
import FirebaseAuth

struct ProfileView: View {
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var subscriptionService: SubscriptionService
    @EnvironmentObject var notificationService: NotificationService
    @StateObject private var viewModel = ProfileViewModel()
    
    @State private var isShowingSettings = false
    @FocusState private var isUsernameFocused: Bool
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header
                    VStack(spacing: 16) {
                        profileImageSection
                        
                        if viewModel.isEditingUsername {
                            usernameEditSection
                        } else {
                            userInfoSection
                        }
                    }
                    .padding(.vertical, 20)
                    
                    // Identity-Focused Stats (not duplicating Progress stats)
                    identityStatsSection
                    
                    // Social Section (Pro-gated)
                    socialSection
                    
                    // Last Active Challenge
                    if let lastActiveChallenge = viewModel.lastActiveChallenge {
                        lastActiveChallengeSection(challenge: lastActiveChallenge)
                    }
                    
                    // Sign Out Button at the bottom
                    Button(action: {
                        Task {
                            await viewModel.signOutWithoutThrowing()
                        }
                    }) {
                        Text("Sign Out")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.red)
                            )
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                    .padding(.bottom, 30)
                }
            }
            .background(Color.theme.background.ignoresSafeArea())
            .navigationTitle("Profile")
            .navigationBarItems(trailing: 
                Button(action: { isShowingSettings = true }) {
                    Image(systemName: "gear")
                        .font(.headline)
                }
            )
            .sheet(isPresented: $isShowingSettings) {
                SettingsView()
                    .environmentObject(userSession)
                    .environmentObject(subscriptionService)
                    .environmentObject(notificationService)
            }
            .onAppear {
                viewModel.loadUserProfile()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // MARK: - UI Components
    
    private var profileImageSection: some View {
        ZStack {
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
                // Use AsyncImage with the profile picture if available in UserSession
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
            
            // Edit photo button overlay
            PhotosPicker(
                selection: $viewModel.selectedPhoto,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Circle()
                    .fill(Color.black.opacity(0.4))
                    .frame(width: 100, height: 100)
                    .overlay(
                        Image(systemName: "camera.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                    )
                    .opacity(0.7)
            }
            .onChange(of: viewModel.selectedPhoto) { oldValue, newValue in
                if newValue != nil {
                    viewModel.updateProfilePhoto()
                }
            }
        }
    }
    
    private var userInfoSection: some View {
        VStack(spacing: 4) {
            Text(viewModel.username.isEmpty ? (userSession.username ?? "No username") : viewModel.username)
                .font(.title)
                .bold()
            
            Text(userSession.currentUser?.email ?? "")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Button(action: { 
                viewModel.isEditingUsername = true
                viewModel.newUsername = viewModel.username
                
                // Delay focus to wait for the text field to appear
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isUsernameFocused = true
                }
            }) {
                Label("Edit Profile", systemImage: "pencil")
                    .font(.headline)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.theme.accent, lineWidth: 1.5)
                    )
                    .foregroundColor(.theme.accent)
            }
            .padding(.top, 10)
        }
    }
    
    private var usernameEditSection: some View {
        VStack(spacing: 12) {
            TextField("Username", text: $viewModel.newUsername)
                .font(.title2)
                .multilineTextAlignment(.center)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .focused($isUsernameFocused)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .padding(.horizontal, 50)
                .onSubmit {
                    viewModel.checkUsernameAvailability()
                }
                .onChange(of: viewModel.newUsername) { oldValue, newValue in
                    if !newValue.isEmpty && newValue != viewModel.username {
                        viewModel.checkUsernameAvailability()
                    }
                }
            
            if viewModel.showUsernameError {
                Text(viewModel.usernameError)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, -8)
            }
            
            HStack(spacing: 20) {
                Button(action: {
                    viewModel.cancelUsernameEdit()
                }) {
                    Text("Cancel")
                        .font(.headline)
                        .foregroundColor(.theme.subtext)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.theme.subtext, lineWidth: 1.5)
                        )
                }
                
                Button(action: {
                    Task {
                        await viewModel.saveUsername()
                    }
                }) {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .padding(.horizontal, 15)
                            .padding(.vertical, 8)
                    } else {
                        Text("Save")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(viewModel.showUsernameError ? Color.gray : Color.theme.accent)
                            )
                    }
                }
                .disabled(viewModel.newUsername.isEmpty || viewModel.showUsernameError || viewModel.isLoading)
            }
        }
    }
    
    // MARK: - New Identity-Focused Sections
    
    private var identityStatsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About You")
                .font(.headline)
                .padding(.horizontal)
            
            HStack(spacing: 12) {
                // Member Since Card
                IdentityStatCard(
                    title: "Member Since", 
                    value: getMemberSinceDate(), 
                    icon: "calendar"
                )
                
                // Total Challenges
                IdentityStatCard(
                    title: "Challenges", 
                    value: "\(viewModel.totalChallenges)", 
                    icon: "flag.fill"
                )
            }
            .padding(.horizontal)
        }
    }
    
    // New function to get formatted member since date directly from Auth
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
    
    private var socialSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Social")
                .font(.title3)
                .bold()
                .padding(.horizontal)
                
            // Replace the hardcoded social stats with a simple "Coming Soon" message
            VStack(spacing: 12) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.gray.opacity(0.7))
                    .padding(.top, 8)
                
                Text("Social features coming in future update")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Text("Connect with friends, share progress, and join community challenges")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.theme.surface)
            )
            .padding(.horizontal)
        }
    }
    
    private func lastActiveChallengeSection(challenge: Challenge) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current Challenge")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(challenge.title)
                        .font(.title3)
                        .bold()
                    
                    Spacer()
                    
                    if challenge.isCompleted {
                        Text("Completed")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.green.opacity(0.2))
                            )
                            .foregroundColor(.green)
                    } else {
                        Text("\(challenge.daysCompleted)/100")
                            .font(.callout)
                            .foregroundColor(.theme.subtext)
                    }
                }
                
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.theme.subtext.opacity(0.2))
                            .frame(height: 8)
                            .cornerRadius(4)
                        
                        Rectangle()
                            .fill(Color.theme.accent)
                            .frame(width: max(0, min(CGFloat(challenge.progressPercentage) * geometry.size.width, geometry.size.width)), height: 8)
                            .cornerRadius(4)
                    }
                }
                .frame(height: 8)
                
                HStack {
                    Label("Started \(dateFormatter.string(from: challenge.startDate))", systemImage: "calendar")
                        .font(.caption)
                        .foregroundColor(.theme.subtext)
                    
                    Spacer()
                    
                    if let lastCheckIn = challenge.lastCheckInDate {
                        Label("Last check-in \(relativeTimeFormatter.localizedString(for: lastCheckIn, relativeTo: Date()))", systemImage: "clock")
                            .font(.caption)
                            .foregroundColor(.theme.subtext)
                    }
                }
            }
            .padding()
            .background(Color.theme.surface)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            .padding(.horizontal)
        }
    }
    
    // MARK: - New UI Components
    
    struct IdentityStatCard: View {
        let title: String
        let value: String
        let icon: String
        
        var body: some View {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(.theme.accent)
                
                if title == "Member Since" {
                    Text(value)
                        .font(.system(size: 16))
                        .bold()
                        .multilineTextAlignment(.center)
                } else {
                    Text(value)
                        .font(.title2)
                        .bold()
                }
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(Color.theme.surface)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
    }
    
    // MARK: - Helper Properties
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }
    
    private var relativeTimeFormatter: RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }
}

struct ProfileProLockedView<Content: View>: View {
    let content: Content
    @EnvironmentObject var subscriptionService: SubscriptionService
    @State private var isShowingPaywall = false
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            content
                .blur(radius: subscriptionService.isProUser ? 0 : 3)
                .opacity(subscriptionService.isProUser ? 1 : 0.5)
            
            if !subscriptionService.isProUser {
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    isShowingPaywall = true
                }) {
                    VStack(spacing: 12) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.theme.accent)
                        
                        Text("Pro Feature")
                            .font(.headline)
                            .foregroundColor(.theme.text)
                        
                        Text("Upgrade to unlock")
                            .font(.subheadline)
                            .foregroundColor(.theme.subtext)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.theme.surface)
                            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                    )
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .sheet(isPresented: $isShowingPaywall) {
            PaywallView()
        }
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
            .environmentObject(UserSession.shared)
            .environmentObject(SubscriptionService.shared)
            .environmentObject(NotificationService.shared)
    }
} 