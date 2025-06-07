import Foundation
import SwiftUI
import FirebaseStorage
import PhotosUI
import FirebaseFirestore
import FirebaseAuth
import Combine

// Using canonical Challenge model
// (No import needed as it will be accessed directly)

@MainActor
class ProfileViewModel: ObservableObject {
    // User state
    @Published var username: String = ""
    @Published var isEditingUsername: Bool = false
    @Published var newUsername: String = ""
    @Published var userBio: String = "Building my best habits 1 day at a time 💪"
    @Published var isEditingBio: Bool = false
    
    // Photo selection and upload
    @Published var selectedPhoto: PhotosPickerItem?
    @Published var profileImage: UIImage?
    @Published var isLoadingImage: Bool = false
    @Published var imageURL: URL?
    
    // For new challenge creation
    @Published var challengeTitle: String = ""
    
    // Camera picker support
    @Published var showCameraPicker: Bool = false
    @Published var showPhotoSourceOptions: Bool = false
    
    // UI states
    @Published var isLoading: Bool = false
    @Published var isInitialLoad: Bool = true
    @Published var error: String?
    @Published var showUsernameError: Bool = false
    @Published var usernameError: String = ""
    @Published var showSuccessAnimation: Bool = false
    
    // Dependencies
    private let firebaseService = FirebaseService.shared
    private let userSession = UserSession.shared
    private let subscriptionService = SubscriptionService.shared
    private let challengeStore = ChallengeStore.shared
    
    // User stats
    @Published var totalChallenges: Int = 0
    @Published var currentStreak: Int = 0
    @Published var longestStreak: Int = 0
    @Published var completedChallenges: Int = 0
    @Published var completionRate: Double = 0.0
    @Published var streakMilestone: Int? = nil
    
    // New identity-focused properties
    @Published var memberSinceDate: Date?
    @Published var friendsCount: Int = 0
    @Published var lastActiveChallenge: Challenge?
    @Published var isSocialFeatureEnabled: Bool = false // For controlling social coming soon features
    
    // Challenge that is closest to completion
    @Published var mostCompletedChallenge: Challenge?
    
    // Challenge store observer
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Setup observers for challenge store
        setupChallengeStoreObservers()
        
        // Load initial profile data
        loadUserProfile()
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    private func setupChallengeStoreObservers() {
        // Observe challenge updates from the store
        NotificationCenter.default.publisher(for: ChallengeStore.challengesDidUpdateNotification)
            .sink { [weak self] _ in
                self?.syncWithChallengeStore()
            }
            .store(in: &cancellables)
        
        // Also observe relevant properties directly
        challengeStore.$totalChallenges
            .combineLatest(challengeStore.$completedChallenges, challengeStore.$currentStreak)
            .sink { [weak self] (total, completed, streak) in
                guard let self = self else { return }
                self.totalChallenges = total
                self.completedChallenges = completed
                self.currentStreak = streak
            }
            .store(in: &cancellables)
        
        // Observe active challenge
        challengeStore.$activeChallenge
            .sink { [weak self] challenge in
                self?.lastActiveChallenge = challenge
            }
            .store(in: &cancellables)
    }
    
    private func syncWithChallengeStore() {
        // Update stats from the challenge store
        self.totalChallenges = challengeStore.getActiveChallenges().count
        self.completedChallenges = challengeStore.completedChallenges
        self.currentStreak = challengeStore.currentStreak
        
        // Update active challenge
        self.lastActiveChallenge = challengeStore.activeChallenge
        
        // Find the challenge closest to completion
        let activeChallenges = challengeStore.getActiveChallenges()
        self.mostCompletedChallenge = activeChallenges
            .filter { !$0.isCompleted } // Only consider incomplete challenges
            .sorted { $0.progressPercentage > $1.progressPercentage } // Sort by highest percentage first
            .first // Take the most completed one
        
        // If there are no incomplete challenges but there are completed ones, show the most recently completed
        if self.mostCompletedChallenge == nil && !activeChallenges.isEmpty {
            self.mostCompletedChallenge = activeChallenges
                .filter { $0.isCompleted }
                .sorted { $0.lastCheckInDate ?? Date.distantPast > $1.lastCheckInDate ?? Date.distantPast }
                .first
        }
    }
    
    // MARK: - Public methods
    
    func loadUserProfile() {
        isLoading = true
        
        Task {
            guard let userId = userSession.currentUser?.uid else {
                isInitialLoad = false
                isLoading = false
                return
            }
            
            // First, check if photoURL is already available in UserSession
            if let photoURL = userSession.photoURL {
                self.imageURL = photoURL
                await loadImageFromURL(photoURL)
            }
            
            // Load basic profile data
            do {
                let profile = try await getUserProfileFromFirestore(userId: userId)
                
                await MainActor.run {
                    self.username = profile.username ?? ""
                    self.userBio = profile.bio ?? "Building my best habits 1 day at a time 💪"
                    
                    if let photoURLString = profile.photoURL?.absoluteString,
                       let photoURL = URL(string: photoURLString) {
                        self.imageURL = photoURL
                        
                        // If this URL is different from what we already loaded, load it
                        if self.userSession.photoURL?.absoluteString != photoURLString {
                            Task {
                                await self.loadImageFromURL(photoURL)
                            }
                        }
                    }
                    
                    // Set member since date
                    self.memberSinceDate = profile.joinedDate
                }
            } catch {
                print("Error loading user profile: \(error.localizedDescription)")
            }
            
            // Ensure challenges are refreshed in the store
            await challengeStore.refreshChallenges()
            
            // Sync with challenge store for stats
            syncWithChallengeStore()
            
            // Calculate longest streak and completion rate
            calculateAdvancedStats()
            
            // Check for streak milestones
            checkForStreakMilestone()
            
            // Load user identity info
            await loadUserIdentityInfo()
            
            // Make sure we have the latest image loaded
            if let imageURL = self.imageURL, self.profileImage == nil {
                await loadImageFromURL(imageURL)
            }
            
            // As a fallback, check Auth.auth().currentUser.photoURL which might be different
            if let authPhotoURL = Auth.auth().currentUser?.photoURL, self.profileImage == nil {
                await loadImageFromURL(authPhotoURL)
                self.imageURL = authPhotoURL
            }
            
            // Finish loading
            isInitialLoad = false
            isLoading = false
        }
    }
    
    private func getUserProfileFromFirestore(userId: String) async throws -> UserProfile {
        return try await firebaseService.fetchUserProfile(userId: userId) ?? UserProfile()
    }
    
    /// Process and upload an image from PhotosPicker
    func updateProfilePhoto() {
        guard let selectedPhoto = selectedPhoto else { return }
        
        isLoadingImage = true
        
        Task {
            do {
                // Process selected image
                if let data = try await selectedPhoto.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await processAndUploadImage(image)
                } else {
                    print("Failed to load image data from PhotosPickerItem")
                    await MainActor.run {
                        self.error = "Failed to load the selected image"
                        self.isLoadingImage = false
                    }
                }
            } catch {
                print("Error uploading profile image: \(error.localizedDescription)")
                await MainActor.run {
                    self.error = "Failed to upload image: \(error.localizedDescription)"
                    self.isLoadingImage = false
                }
            }
        }
    }
    
    /// Process and upload an image from camera
    func uploadProfilePhotoFromCamera(_ image: UIImage) {
        isLoadingImage = true
        
        Task {
            await processAndUploadImage(image)
        }
    }
    
    /// Common processing and upload logic for all image sources
    func processAndUploadImage(_ image: UIImage) async {
        do {
            // Update UI state immediately
            await MainActor.run {
                isLoadingImage = true
                // Set image immediately to show the user
                self.profileImage = image
            }
            
            print("Starting profile image processing. Image size: \(image.size.width)x\(image.size.height)")
            
            // Ensure we have a user ID before proceeding
            guard let userId = userSession.currentUser?.uid else { 
                print("No user ID available for upload")
                await MainActor.run {
                    self.error = "User not logged in"
                    self.isLoadingImage = false
                }
                return
            }
            
            // Automatically crop the image to a circle since the cropping UI was removed
            guard let circularImage = image.circleCropped() else {
                print("Failed to create circular cropped image")
                await MainActor.run {
                    self.error = "Failed to process the image"
                    self.isLoadingImage = false
                }
                return
            }
            
            // Update the profile image to use the circular version
            await MainActor.run {
                self.profileImage = circularImage
            }
            
            // Resize if needed for storage efficiency
            let resizedImage = circularImage.size.width > 500 ? 
                circularImage.resized(to: CGSize(width: 500, height: 500)) : 
                circularImage
            
            print("Processed image to: \(resizedImage.size.width)x\(resizedImage.size.height)")
            
            // Ensure we're getting valid data back for the processed image
            guard let processedImageData = resizedImage.compressedJPEG(quality: 0.9) else {
                print("Failed to convert processed image to JPEG data")
                await MainActor.run {
                    self.error = "Failed to process the image"
                    self.isLoadingImage = false
                }
                return
            }
            
            print("Processed image data size: \(processedImageData.count) bytes")
            print("Starting upload to Firebase Storage for user: \(userId)")
            
            // Upload the image to Firebase Storage
            let storageRef = Storage.storage().reference().child("profile/\(userId)/profile.jpg")
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            
            // Upload the image
            let _ = try await storageRef.putDataAsync(processedImageData, metadata: metadata)
            print("Image uploaded successfully to Firebase Storage")
            
            // Get the download URL
            let downloadURL = try await storageRef.downloadURL()
            print("Download URL obtained: \(downloadURL.absoluteString)")
            
            // Update profile in Firebase Auth
            let changeRequest = Auth.auth().currentUser?.createProfileChangeRequest()
            changeRequest?.photoURL = downloadURL
            try await changeRequest?.commitChanges()
            print("Firebase Auth profile updated with new photo URL")
            
            // Update Firestore user document with the photo URL directly
            try await Firestore.firestore()
                .collection("users")
                .document(userId)
                .updateData(["photoURL": downloadURL.absoluteString])
            print("Firestore user document updated with new photo URL")
            
            // Update local state
            await MainActor.run {
                self.imageURL = downloadURL
                
                // Create a separate Task for the async operation
                Task {
                    do {
                        try await userSession.updateProfilePhoto(downloadURL)
                        print("UserSession updated with new photo URL")
                    } catch {
                        print("Error updating user session photo: \(error)")
                    }
                }
                
                isLoadingImage = false
                
                // Show success indicator
                self.showSuccessAnimation = true
                
                // Post notification that the profile photo was updated
                NotificationCenter.default.post(
                    name: Notification.Name("UserProfilePhotoUpdated"),
                    object: downloadURL
                )
                print("Profile photo update notification posted")
            }
        } catch {
            print("Error processing and uploading image: \(error.localizedDescription)")
            await MainActor.run {
                self.error = "Failed to upload image: \(error.localizedDescription)"
                self.isLoadingImage = false
            }
        }
    }
    
    func checkUsernameAvailability() {
        guard !newUsername.isEmpty, newUsername != username else {
            showUsernameError = false
            return
        }
        
        isLoading = true
        showUsernameError = false
        
        Task {
            do {
                let isAvailable = try await isUsernameAvailable(newUsername)
                
                await MainActor.run {
                    if !isAvailable {
                        usernameError = "Username already taken"
                        showUsernameError = true
                    } else if !isValidUsername(newUsername) {
                        usernameError = "Username must be 3-20 characters, letters and numbers only"
                        showUsernameError = true
                    } else {
                        showUsernameError = false
                    }
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.usernameError = "Error checking username"
                    self.showUsernameError = true
                    self.isLoading = false
                }
            }
        }
    }
    
    func saveUsername() async {
        guard !newUsername.isEmpty, newUsername != username, !showUsernameError else { return }
        
        isLoading = true
        
        do {
            let isAvailable = try await isUsernameAvailable(newUsername)
            
            if isAvailable && isValidUsername(newUsername) {
                // Update username in Firestore and UserSession
                try await firebaseService.updateUsername(newUsername, userId: userSession.currentUser?.uid ?? "")
                try await userSession.updateUsername(newUsername)
                
                await MainActor.run {
                    self.username = newUsername
                    self.isLoading = false
                    self.isEditingUsername = false
                    
                    // Trigger haptic feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                }
            } else {
                await MainActor.run {
                    self.usernameError = "Username is not available or invalid"
                    self.showUsernameError = true
                    self.isLoading = false
                }
            }
        } catch {
            await MainActor.run {
                self.usernameError = "Error updating username"
                self.showUsernameError = true
                self.isLoading = false
            }
        }
    }
    
    func cancelUsernameEdit() {
        isEditingUsername = false
        newUsername = username
        showUsernameError = false
    }
    
    // MARK: - Private methods
    
    private func loadProfilePhoto() async {
        // First check if photoURL is already available in UserSession
        if let photoURL = userSession.photoURL {
            await loadImageFromURL(photoURL)
            self.imageURL = photoURL
            return
        }
        
        // If not in UserSession, try to fetch from Firestore
        guard let userId = userSession.currentUser?.uid else { return }
        
        do {
            if let profile = try await firebaseService.fetchUserProfile(userId: userId) {
                if let photoURL = profile.photoURL {
                    await loadImageFromURL(photoURL)
                    self.imageURL = photoURL
                }
            }
        } catch {
            print("Error loading profile photo: \(error.localizedDescription)")
        }
    }
    
    private func loadUserIdentityInfo() async {
        guard let userId = userSession.currentUser?.uid else { return }
        
        // Load friends count (placeholder for now)
        friendsCount = 0
        
        // Social features flag - placeholder for now
        isSocialFeatureEnabled = false
    }
    
    public func loadImageFromURL(_ url: URL) async {
        // Check cache first
        if let cachedImage = ImageCacheManager.shared.image(forKey: url.absoluteString) {
            profileImage = cachedImage
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                profileImage = image
                ImageCacheManager.shared.setImage(image, forKey: url.absoluteString)
            }
        } catch {
            print("Error loading profile image: \(error.localizedDescription)")
        }
    }
    
    private func isUsernameAvailable(_ username: String) async throws -> Bool {
        let snapshot = try await Firestore.firestore()
            .collection("usernames")
            .document(username)
            .getDocument()
        
        // If the document exists, the username is taken
        return !snapshot.exists
    }
    
    private func isValidUsername(_ username: String) -> Bool {
        let usernameRegex = "^[a-zA-Z0-9]{3,20}$"
        let usernamePredicate = NSPredicate(format: "SELF MATCHES %@", usernameRegex)
        return usernamePredicate.evaluate(with: username)
    }
    
    // Helper method to format member since date
    func formattedMemberSinceDate() -> String {
        guard let date = memberSinceDate else { return "Unknown" }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return "Joined \(formatter.string(from: date))"
    }
    
    // Non-throwing signOut method
    func signOutWithoutThrowing() async {
        await userSession.signOutWithoutThrowing()
    }
    
    // Calculate advanced stats like longest streak and completion rate
    private func calculateAdvancedStats() {
        // Get all challenges
        let allChallenges = challengeStore.challenges
        
        // Calculate longest streak from all challenges
        longestStreak = allChallenges.map { $0.streakCount }.max() ?? currentStreak
        
        // Calculate completion rate (completed days / total possible days)
        let totalCompletedDays = allChallenges.reduce(0) { sum, challenge in
            sum + challenge.daysCompleted
        }
        let totalPossibleDays = allChallenges.count * 100 // 100 days per challenge
        
        completionRate = totalPossibleDays > 0 ? Double(totalCompletedDays) / Double(totalPossibleDays) * 100.0 : 0.0
    }
    
    // Check for streak milestones (7, 30, 100 days)
    private func checkForStreakMilestone() {
        let milestones = [7, 30, 100]
        
        // Find the highest milestone the user has reached
        if currentStreak >= 7 {
            if currentStreak >= 100 {
                streakMilestone = 100
            } else if currentStreak >= 30 {
                streakMilestone = 30
            } else {
                streakMilestone = 7
            }
        } else {
            streakMilestone = nil
        }
    }
    
    // Save user bio to Firestore
    func saveBio(_ bio: String) async {
        guard let userId = userSession.currentUser?.uid else { return }
        
        isLoading = true
        
        do {
            try await Firestore.firestore()
                .collection("users")
                .document(userId)
                .updateData(["bio": bio])
            
            await MainActor.run {
                self.userBio = bio
                self.isLoading = false
                self.isEditingBio = false
                self.showSuccessAnimation = true
                
                // Hide success animation after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.showSuccessAnimation = false
                }
            }
        } catch {
            print("Error saving bio: \(error.localizedDescription)")
            await MainActor.run {
                self.error = "Failed to save bio"
                self.isLoading = false
            }
        }
    }
} 