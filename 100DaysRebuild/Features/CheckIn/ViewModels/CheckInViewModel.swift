import Foundation
import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage
import Combine

@MainActor
class CheckInViewModel: ObservableObject {
    // MARK: - Properties
    
    // Dependencies
    private let checkInService = CheckInService.shared
    private let firestore = Firestore.firestore()
    
    // State
    @Published var isLoading = false
    @Published var error: Error?
    @Published var showError = false
    @Published var errorMessage = ""
    
    // Check-in flow state
    @Published var currentQuote: Quote?
    @Published var lastQuote: Quote?
    @Published var motivationalMessage: String = ""
    @Published var note: String = ""
    @Published var showSuccessView = false
    @Published var showMilestoneView = false
    @Published var showNotePrompt = false
    @Published var photoURL: URL?
    @Published var selectedImage: UIImage?
    @Published var timerDuration: TimeInterval = 0
    
    // Milestone tracking
    @Published var isMilestoneDay = false
    @Published var milestoneMessage = ""
    @Published var milestoneEmoji = ""
    @Published var milestoneDay: Int = 0
    
    // Share card options
    @Published var selectedCardLayout: MilestoneShareCardGenerator.CardLayout = .modern
    @Published var selectedBackground: MilestoneShareCardGenerator.BackgroundStyle = .gradient([Color.theme.accent, Color.theme.accent.opacity(0.7)])
    
    // Reflection prompts
    private let reflectionPrompts = [
        "Why does today matter?",
        "What did you overcome today?",
        "What did you learn today?",
        "What are you grateful for today?",
        "What's one thing you're proud of today?",
        "How did you grow today?",
        "What made you smile today?",
        "What challenge did you face today?",
        "What's one thing you'll do differently tomorrow?"
    ]
    
    @Published var currentPrompt: String = ""
    
    private var challengeId: String = ""
    private var currentDay: Int = 0
    private var challengeTitle: String = ""
    
    init() {
        // Load previous quote from UserDefaults to avoid repeating
        if let savedQuoteData = UserDefaults.standard.data(forKey: "lastQuoteShown"),
           let savedQuote = try? JSONDecoder().decode(Quote.self, from: savedQuoteData) {
            self.lastQuote = savedQuote
        }
    }
    
    // MARK: - Public Methods
    
    func prepareForCheckIn(challengeId: String, currentDay: Int, challengeTitle: String) async {
        self.challengeId = challengeId
        self.currentDay = currentDay
        self.challengeTitle = challengeTitle
        
        // Set a random prompt for reflection
        self.currentPrompt = reflectionPrompts.randomElement() ?? "Why does today matter?"
        
        // Get a random quote different from last one
        if let lastQuoteData = UserDefaults.standard.data(forKey: "lastQuoteShown"),
           let lastQuote = try? JSONDecoder().decode(Quote.self, from: lastQuoteData) {
            self.lastQuote = lastQuote
            self.currentQuote = Quote.getRandomQuote(different: lastQuote)
        } else {
            self.currentQuote = Quote.getRandomQuote()
        }
        
        // Get a random motivational message
        self.motivationalMessage = MotivationalMessages.getRandomMessage()
        
        // Check if this is a milestone day
        self.isMilestoneDay = [3, 7, 30, 50, 100].contains(currentDay)
        if isMilestoneDay {
            switch currentDay {
            case 100:
                // Special layout for completion
                selectedCardLayout = .modern
                selectedBackground = .gradient([Color.theme.accent, Color.theme.gradientEnd])
            case 50:
                selectedCardLayout = .modern
                selectedBackground = .gradient([Color.theme.accent, Color.theme.accent.opacity(0.7)])
            case 30:
                selectedCardLayout = .classic
                selectedBackground = .gradient([Color.theme.accent, Color.theme.gradientEnd.opacity(0.8)])
            default:
                selectedCardLayout = .minimal
                selectedBackground = .solid(Color.theme.surface)
            }
        }
    }
    
    /// Perform the check-in for the current day
    func performCheckIn() async {
        guard !isLoading, !challengeId.isEmpty else { return }
        
        isLoading = true
        
        do {
            // Use the CheckInService to perform the check-in
            _ = try await checkInService.checkIn(for: challengeId)
            
            // Save the check-in details including note and photo
            await saveCheckInDetails()
            
            // Save current quote as last shown
            if let quote = currentQuote {
                do {
                    let encoded = try JSONEncoder().encode(quote)
                    UserDefaults.standard.set(encoded, forKey: "lastQuoteShown")
                } catch {
                    print("Failed to encode quote: \(error.localizedDescription)")
                }
            }
            
            // Show success view
            showSuccessView = true
            
            // Reset state
            isLoading = false
            
        } catch {
            await handleError(error)
        }
    }
    
    func uploadImage(_ image: UIImage) async -> URL? {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "You must be signed in to upload an image"
            showError = true
            return nil
        }
        
        do {
            let storage = Storage.storage()
            let storageRef = storage.reference()
            
            // Create a unique filename
            let fileName = "\(UUID().uuidString).jpg"
            let imageRef = storageRef.child("users/\(userId)/check-ins/\(fileName)")
            
            // Use PhotoTransferable for compression
            let photoTransferable = PhotoTransferable(image: image)
            
            // Get compressed data
            guard let imageData = photoTransferable.compressedData(quality: 0.7) else {
                throw NSError(domain: "app", code: 0, userInfo: [NSLocalizedDescriptionKey: "Could not compress image"])
            }
            
            // Upload the image
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            
            let _ = try await imageRef.putDataAsync(imageData, metadata: metadata)
            let downloadURL = try await imageRef.downloadURL()
            
            return downloadURL
        } catch {
            errorMessage = "Failed to upload image: \(error.localizedDescription)"
            showError = true
            return nil
        }
    }
    
    /// Creates a social share card using the selected style
    func createShareCard() -> UIImage? {
        // Get effective challenge title (use a default if not provided)
        let title = challengeTitle.isEmpty ? "My 100 Days Challenge" : challengeTitle
        
        // Generate the card with our new generator
        return MilestoneShareCardGenerator.generateMilestoneCard(
            currentDay: currentDay,
            challengeTitle: title,
            quote: currentQuote,
            backgroundStyle: selectedBackground,
            layout: selectedCardLayout
        )
    }
    
    /// Changes the layout style for the share card
    func setCardLayout(_ layout: MilestoneShareCardGenerator.CardLayout) {
        selectedCardLayout = layout
    }
    
    /// Changes the background style for the share card
    func setCardBackground(_ background: MilestoneShareCardGenerator.BackgroundStyle) {
        selectedBackground = background
    }
    
    /// Save check-in details including notes and photos without performing a new check-in
    public func saveCheckInDetails() async {
        guard !isLoading, !challengeId.isEmpty else { return }
        
        isLoading = true
        
        do {
            // Fix the recursive call by using a helper method
            try await performSaveCheckInDetails()
            isLoading = false
        } catch {
            await handleError(error)
        }
    }
    
    // Helper method to avoid recursive call
    private func performSaveCheckInDetails() async throws {
        // Early return if challenge ID is not set
        guard !challengeId.isEmpty else { return }
        
        // Get the current user ID
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "CheckInViewModel", code: 401, userInfo: [
                NSLocalizedDescriptionKey: "You must be signed in to save check-in details"
            ])
        }
        
        // Reference to the check-ins collection for this challenge
        let checkInsRef = firestore
            .collection("users")
            .document(userId)
            .collection("challenges")
            .document(challengeId)
            .collection("checkIns")
        
        // Create a document for today's check-in
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Check if there's already a check-in for today
        let todayQuery = checkInsRef
            .whereField("date", isEqualTo: Timestamp(date: today))
        
        let snapshot = try await todayQuery.getDocuments()
        
        let checkInDocRef: DocumentReference
        
        if let existingDoc = snapshot.documents.first {
            // Update existing check-in document
            checkInDocRef = existingDoc.reference
        } else {
            // Create a new document
            checkInDocRef = checkInsRef.document()
        }
        
        // Prepare the check-in data
        var checkInData: [String: Any] = [
            "date": Timestamp(date: today),
            "dayNumber": currentDay,
            "userId": userId,
            "createdAt": FieldValue.serverTimestamp(),
            "promptShown": currentPrompt
        ]
        
        // Add note if provided
        if !note.isEmpty {
            checkInData["note"] = note
        }
        
        // Add quote if available
        if let quote = currentQuote {
            checkInData["quote"] = [
                "text": quote.text,
                "author": quote.author
            ]
        }
        
        // Add motivational message
        checkInData["motivationalMessage"] = motivationalMessage
        
        // Add timer duration if this is a timed challenge
        if timerDuration > 0 {
            checkInData["duration"] = timerDuration
        }
        
        // Upload photo if selected
        if let image = selectedImage {
            // Create a storage reference
            let storageRef = Storage.storage().reference()
            let photoId = UUID().uuidString
            let photoRef = storageRef.child("checkInPhotos/\(userId)/\(challengeId)/\(photoId).jpg")
            
            // Use PhotoTransferable for better compression
            let photoTransferable = PhotoTransferable(image: image)
            
            // Get compressed data
            guard let imageData = photoTransferable.compressedData(quality: 0.6) else {
                throw NSError(domain: "CheckInViewModel", code: 400, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to process image"
                ])
            }
            
            // Upload the image
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            
            let _ = try await photoRef.putDataAsync(imageData, metadata: metadata)
            
            // Get download URL
            let downloadURL = try await photoRef.downloadURL()
            
            // Add to check-in data
            checkInData["photoURL"] = downloadURL.absoluteString
            self.photoURL = downloadURL
        }
        
        // Save check-in data
        try await checkInDocRef.setData(checkInData, merge: true)
    }
    
    // MARK: - Private Methods
    
    private func handleError(_ error: Error) async {
        isLoading = false
        
        if let checkInError = error as? CheckInError {
            switch checkInError {
            case .alreadyCheckedInToday:
                // Special case for already checked in - show success view anyway
                // This improves UX for users who might not remember they already checked in
                showSuccessView = true
                return
                
            case .networkUnavailable:
                // Special case for offline check-in
                errorMessage = "Your check-in will be processed when you're back online"
                
            default:
                errorMessage = checkInError.errorDescription ?? "An error occurred during check-in"
            }
        } else {
            errorMessage = error.localizedDescription
        }
        
        // Show error UI
        self.error = error
        showError = true
    }
    
    func checkIn(for challenge: Challenge, timedDuration: Int? = nil) async -> Bool {
        isLoading = true
        error = nil
        
        do {
            // Use the CheckInService to perform the check-in
            let success = try await checkInService.checkIn(
                for: challenge.id.uuidString,
                durationInMinutes: timedDuration
            )
            
            if success {
                // Check if this is a day that should trigger a milestone
                await checkForMilestone(challenge: challenge)
                
                // Load a motivational quote for the success view
                await loadRandomQuote()
                
                // Show appropriate success view based on milestone
                if isMilestoneDay {
                    showMilestoneView = true
                } else {
                    showSuccessView = true
                }
            }
            
            isLoading = false
            return success
        } catch let checkInError as CheckInError {
            isLoading = false
            error = checkInError
            errorMessage = checkInError.localizedDescription
            showError = true
            
            // Special handling for already checked in
            if case .alreadyCheckedInToday = checkInError {
                // Nothing special to do, just show the message
            }
            
            // Special handling for offline mode
            if case .networkUnavailable = checkInError {
                showSuccessView = true
                motivationalMessage = "Your check-in has been saved locally and will sync when you're back online."
            }
            
            return false
        } catch {
            isLoading = false
            self.error = error
            errorMessage = error.localizedDescription
            showError = true
            return false
        }
    }
    
    // MARK: - Helper Methods
    
    /// Check if the current day is a milestone day
    private func checkForMilestone(challenge: Challenge) async {
        // Get the current day number from the challenge
        let currentDayValue = (challenge.daysCompleted ?? 0) + 1 // +1 because we just checked in
        self.currentDay = currentDayValue
        
        // Check if this is a milestone day (7, 10, 21, 30, 50, 75, 90, 100)
        let milestoneDays = [7, 10, 21, 30, 50, 75, 90, 100]
        
        if milestoneDays.contains(self.currentDay) {
            self.isMilestoneDay = true
            self.milestoneDay = self.currentDay
            
            // Choose a special message for this milestone
            self.motivationalMessage = getMilestoneMessage(forDay: self.currentDay)
        } else {
            self.isMilestoneDay = false
            
            // Choose a regular motivational message
            self.motivationalMessage = getRandomMotivationalMessage()
        }
    }
    
    /// Load a random inspirational quote for the success view
    private func loadRandomQuote() async {
        do {
            // Try to fetch a quote from the API
            if let quote = try? await QuoteService.shared.fetchRandomQuote() {
                self.currentQuote = quote
                return
            }
        }
        
        // Fallback to local quotes if the API request fails
        let fallbackQuotes = [
            Quote(text: "The secret of getting ahead is getting started.", author: "Mark Twain"),
            Quote(text: "Small daily improvements over time lead to stunning results.", author: "Robin Sharma"),
            Quote(text: "Consistency is the key to achieving and maintaining momentum.", author: "Brian Tracy"),
            Quote(text: "Success is the sum of small efforts, repeated day in and day out.", author: "Robert Collier"),
            Quote(text: "The only way to do great work is to love what you do.", author: "Steve Jobs"),
            Quote(text: "Don't count the days, make the days count.", author: "Muhammad Ali"),
            Quote(text: "Habits are the compound interest of self-improvement.", author: "James Clear"),
            Quote(text: "Every day may not be good, but there's something good in every day.", author: "Alice Morse Earle")
        ]
        
        // Make sure we don't repeat the last quote if possible
        if let lastQuote = self.lastQuote, let index = fallbackQuotes.firstIndex(where: { $0.text == lastQuote.text }) {
            var availableQuotes = fallbackQuotes
            availableQuotes.remove(at: index)
            self.currentQuote = availableQuotes.randomElement() ?? fallbackQuotes.randomElement()
        } else {
            self.currentQuote = fallbackQuotes.randomElement()
        }
    }
    
    /// Get a motivational message for a specific milestone
    private func getMilestoneMessage(forDay day: Int) -> String {
        switch day {
        case 7:
            return "Incredible! You've completed your first week. This is where real progress begins!"
        case 10:
            return "Double digits! 10 days shows serious commitment. Keep this momentum going!"
        case 21:
            return "21 days - you're building a lasting habit! Research shows this is when habits start to stick."
        case 30:
            return "A full month complete! You've shown incredible discipline to make it this far."
        case 50:
            return "Halfway to 100! What an achievement. You're proving your dedication every day."
        case 75:
            return "75 days - you're in elite territory now! Most people never make it this far."
        case 90:
            return "90 days! Research shows it takes about 90 days to establish lasting behavior change. You did it!"
        case 100:
            return "100 DAYS COMPLETE! 🎉 You've achieved something truly remarkable. Be proud of yourself!"
        default:
            return "Another successful day! Keep it up!"
        }
    }
    
    /// Get a random motivational message for non-milestone check-ins
    private func getRandomMotivationalMessage() -> String {
        let messages = [
            "Great job! Another day complete.",
            "You're building momentum! Keep going!",
            "Consistency is key, and you're crushing it!",
            "Progress happens one day at a time. Well done!",
            "Every check-in brings you closer to your goal!",
            "You showed up today. That's what matters most!",
            "Small steps lead to big results. Nice work!",
            "Your future self will thank you for today's effort."
        ]
        
        return messages.randomElement() ?? "Great job today!"
    }
} 