import Foundation
import SwiftUI
import FirebaseStorage
import PhotosUI
import FirebaseFirestore
import FirebaseAuth

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
    
    // UI states
    @Published var isLoading: Bool = false
    @Published var error: String?
    @Published var showUsernameError: Bool = false
    @Published var usernameError: String = ""
    @Published var showSuccessAnimation: Bool = false
    
    // Dependencies
    private let firebaseService = FirebaseService.shared
    private let userSession = UserSession.shared
    
    // User stats
    @Published var totalChallenges: Int = 0
    @Published var currentStreak: Int = 0
    @Published var completedChallenges: Int = 0
    
    // New identity-focused properties
    @Published var memberSinceDate: Date?
    @Published var friendsCount: Int = 0
    @Published var lastActiveChallenge: Challenge?
    @Published var isSocialFeatureEnabled: Bool = false // For controlling social coming soon features
    
    init() {
        loadUserProfile()
    }
    
    // MARK: - Public methods
    
    func loadUserProfile() {
        isLoading = true
        
        Task {
            // Load initial username
            if let username = userSession.username {
                self.username = username
                self.newUsername = username
            }
            
            // Load profile photo if exists
            await loadProfilePhoto()
            
            // Load user stats
            await loadUserStats()
            
            // Load identity-focused stats
            await loadUserIdentityInfo()
            
            isLoading = false
        }
    }
    
    func updateProfilePhoto() {
        guard let selectedPhoto = selectedPhoto else { return }
        
        isLoadingImage = true
        
        Task {
            do {
                // Process selected image
                if let data = try await selectedPhoto.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    
                    // Process image using extensions
                    let processedImage = image.resized(to: CGSize(width: 500, height: 500)).circleCropped()
                    if let processedImageData = processedImage.compressedJPEG(quality: 0.7) {
                        // Upload to Firebase Storage
                        if let userId = userSession.currentUser?.uid {
                            let url = try await firebaseService.uploadProfileImage(data: processedImageData, userId: userId)
                            
                            // Update Firestore with photoURL and UserSession
                            try await updatePhotoURL(url)
                            // Update UserSession to ensure photoURL is accessible app-wide
                            try await userSession.updateProfilePhoto(url)
                            
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
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.error = "Failed to upload image: \(error.localizedDescription)"
                    self.isLoadingImage = false
                }
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
    
    private func loadUserStats() async {
        guard let userId = userSession.currentUser?.uid else { return }
        
        do {
            let challenges = try await Firestore.firestore()
                .collection("users")
                .document(userId)
                .collection("challenges")
                .getDocuments()
                .documents
            
            // Process the data on the main actor to avoid data races
            await MainActor.run {
                // Calculate stats directly from the documents
                self.totalChallenges = challenges.count
                self.completedChallenges = challenges.filter { doc in
                    (doc.data()["isCompleted"] as? Bool) == true
                }.count
                self.currentStreak = challenges.compactMap { doc in
                    doc.data()["streakCount"] as? Int
                }.max() ?? 0
            }
        } catch {
            print("Error loading user stats: \(error.localizedDescription)")
        }
    }
    
    private func loadUserIdentityInfo() async {
        guard let userId = userSession.currentUser?.uid else { return }
        
        do {
            // Fetch user document for creation date
            let userDoc = try await Firestore.firestore()
                .collection("users")
                .document(userId)
                .getDocument()
            
            if let userData = userDoc.data() {
                // Copy needed values to local sendable variables
                let createdAtTimestamp = userData["createdAt"] as? Timestamp
                
                // Process the data on the main actor to avoid data races
                await MainActor.run {
                    // Get account creation date
                    if let timestamp = createdAtTimestamp {
                        self.memberSinceDate = timestamp.dateValue()
                    } else {
                        // Fallback to Firebase auth creation date
                        self.memberSinceDate = Auth.auth().currentUser?.metadata.creationDate
                    }
                }
            } else {
                // If no user document exists, use Firebase Auth creation date
                await MainActor.run {
                    self.memberSinceDate = Auth.auth().currentUser?.metadata.creationDate
                }
            }
            
            // Fetch the most recent/active challenge
            let challengesQuery = try await Firestore.firestore()
                .collection("users")
                .document(userId)
                .collection("challenges")
                .whereField("isArchived", isEqualTo: false)
                .order(by: "lastModified", descending: true)
                .limit(to: 1)
                .getDocuments()
            
            if let mostRecentDoc = challengesQuery.documents.first {
                // Process the challenge data on the main actor
                await MainActor.run {
                    if let challenge = try? mostRecentDoc.data(as: Challenge.self) {
                        self.lastActiveChallenge = challenge
                    }
                }
            }
            
        } catch {
            print("Error loading user identity info: \(error.localizedDescription)")
        }
    }
    
    private func loadImageFromURL(_ url: URL) async {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                await MainActor.run {
                    self.profileImage = image
                }
            }
        } catch {
            print("Error loading image from URL: \(error.localizedDescription)")
        }
    }
    
    private func updatePhotoURL(_ url: URL) async throws {
        guard let userId = userSession.currentUser?.uid else { throw NSError(domain: "ProfileViewModel", code: 1) }
        
        // Note: This will also be updated by userSession.updateProfilePhoto, but we keep it
        // to ensure data consistency in case the UserSession method fails.
        let urlString = url.absoluteString // Create a sendable copy of the URL string
        try await Firestore.firestore()
            .collection("users")
            .document(userId)
            .updateData(["photoURL": urlString])
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
} 