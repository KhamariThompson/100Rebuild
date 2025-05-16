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
    
    // Photo selection and upload
    @Published var selectedPhoto: PhotosPickerItem?
    @Published var profileImage: UIImage?
    @Published var isLoadingImage: Bool = false
    @Published var imageURL: URL?
    
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
    @Published var completedChallenges: Int = 0
    
    // New identity-focused properties
    @Published var memberSinceDate: Date?
    @Published var friendsCount: Int = 0
    @Published var lastActiveChallenge: Challenge?
    @Published var isSocialFeatureEnabled: Bool = false // For controlling social coming soon features
    
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
        self.totalChallenges = challengeStore.totalChallenges
        self.completedChallenges = challengeStore.completedChallenges
        self.currentStreak = challengeStore.currentStreak
        
        // Update active challenge
        self.lastActiveChallenge = challengeStore.activeChallenge
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
            
            // Load basic profile data
            do {
                let profile = try await getUserProfileFromFirestore(userId: userId)
                
                await MainActor.run {
                    self.username = profile.username ?? ""
                    
                    if let photoURLString = profile.photoURL?.absoluteString {
                        self.imageURL = URL(string: photoURLString)
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
            
            // Load user identity info
            await loadUserIdentityInfo()
            
            // Update profile image if URL is available
            if let imageURL = self.imageURL {
                await loadImageFromURL(imageURL)
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
    private func processAndUploadImage(_ image: UIImage) async {
        do {
            // Process image using extensions
            let processedImage = image.resized(to: CGSize(width: 500, height: 500)).circleCropped()
            
            // Ensure we're getting valid data back for the processed image
            guard let processedImageData = processedImage.compressedJPEG(quality: 0.7) else {
                print("Failed to convert processed image to JPEG data")
                await MainActor.run {
                    self.error = "Failed to process the image"
                    self.isLoadingImage = false
                }
                return
            }
            
            // Upload to Firebase Storage
            guard let userId = userSession.currentUser?.uid else { 
                print("No user ID available for upload")
                await MainActor.run {
                    self.error = "User not logged in"
                    self.isLoadingImage = false
                }
                return
            }
            
            print("Starting upload to Firebase Storage for user: \(userId)")
            print("Image data size: \(processedImageData.count) bytes")
            
            // Upload the image to Firebase Storage
            let url = try await firebaseService.uploadProfileImage(data: processedImageData, userId: userId)
            print("Image uploaded successfully to: \(url.absoluteString)")
            
            // Update Firestore with photoURL
            try await updatePhotoURL(url)
            print("Firestore photoURL updated")
            
            // Update UserSession to ensure photoURL is accessible app-wide
            try await userSession.updateProfilePhoto(url)
            print("UserSession photoURL updated")
            
            // Cache the image for immediate display
            ImageCacheManager.shared.setImage(processedImage, forKey: url.absoluteString)
            
            // Update UI
            await MainActor.run {
                self.profileImage = processedImage
                self.imageURL = url
                self.isLoadingImage = false
                self.showSuccessAnimation = true
                
                // Trigger haptic feedback
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                
                // Hide success animation after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.showSuccessAnimation = false
                }
            }
        } catch let firebaseError as FirebaseError {
            print("Firebase error uploading profile image: \(firebaseError)")
            await MainActor.run {
                switch firebaseError {
                case .storageError(let error):
                    self.error = "Storage error: \(error.localizedDescription)"
                case .networkOffline:
                    self.error = "Network is offline. Please check your connection."
                default:
                    self.error = "Error uploading image: \(firebaseError)"
                }
                self.isLoadingImage = false
            }
        } catch {
            print("Error uploading profile image: \(error.localizedDescription)")
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
                    self.showSuccessAnimation = true
                    
                    // Trigger haptic feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    
                    // Hide success animation after a delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self.showSuccessAnimation = false
                    }
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
    
    private func loadImageFromURL(_ url: URL) async {
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
    
    private func updatePhotoURL(_ url: URL) async throws {
        guard let userId = userSession.currentUser?.uid else {
            throw NSError(domain: "ProfileViewModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        try await Firestore.firestore()
            .collection("users")
            .document(userId)
            .setData(["photoURL": url.absoluteString], merge: true)
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
} 