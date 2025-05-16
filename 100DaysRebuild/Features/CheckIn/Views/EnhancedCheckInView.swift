import SwiftUI
import PhotosUI

// Import the common ShareSheet
import Foundation

struct EnhancedCheckInView: View {
    // Dependencies
    @ObservedObject var challengesViewModel: ChallengesViewModel
    @StateObject private var viewModel = CheckInViewModel()
    @StateObject private var milestoneViewModel = MilestoneCelebrationViewModel()
    
    // Challenge data
    let challenge: Challenge
    
    // Navigation and state
    @Environment(\.dismiss) private var dismiss
    @State private var showSuccessView = false
    @State private var showMilestoneView = false
    @State private var showNotePrompt = false
    
    // Timer state for timed challenges
    @State private var timerRunning = false
    @State private var elapsedTime: TimeInterval = 0
    @State private var timerStartTime: Date?
    @State private var timer: Timer?
    
    // Journal state
    @State private var journalText: String = ""
    @FocusState private var isJournalFocused: Bool
    
    // Photo upload state
    @State private var photoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    
    var body: some View {
        Group {
            if showMilestoneView {
                // Display milestone celebration
                MilestoneCelebrationModal(
                    dayNumber: challenge.daysCompleted + 1,
                    challengeId: challenge.id.uuidString,
                    challengeTitle: challenge.title,
                    isPresented: $showMilestoneView
                )
                .onDisappear {
                    // When milestone view is dismissed, decide what to show next
                    if showNotePrompt {
                        showNotePrompt = true
                    } else {
                        // Update timer before dismissing
                        Task {
                            await challengesViewModel.loadChallenges()
                        }
                        dismiss()
                    }
                }
            } else if showSuccessView {
                // Display success view with quote
                CheckInSuccessView(
                    challenge: challenge,
                    quote: viewModel.currentQuote,
                    dayNumber: challenge.daysCompleted + 1,
                    showMilestone: false, // We're handling milestones differently now
                    milestoneMessage: "",
                    milestoneEmoji: "",
                    showNotePrompt: $showNotePrompt,
                    isPresented: $showSuccessView,
                    viewModel: viewModel
                )
                .onDisappear {
                    // When success view is dismissed, check if we should show milestone
                    if viewModel.isMilestoneDay && milestoneViewModel.shouldShowMilestone(
                        challengeId: challenge.id.uuidString,
                        day: challenge.daysCompleted + 1
                    ) {
                        showMilestoneView = true
                    } else if showNotePrompt {
                        showNotePrompt = true
                    } else {
                        // Update timer before dismissing
                        Task {
                            await challengesViewModel.loadChallenges()
                        }
                        dismiss()
                    }
                }
            } else if showNotePrompt {
                // Display reflection prompt
                CheckInNotePromptView(
                    challenge: challenge,
                    dayNumber: challenge.daysCompleted + 1,
                    prompt: viewModel.currentPrompt,
                    viewModel: viewModel,
                    isPresented: $showNotePrompt
                )
                .onDisappear {
                    // Update timer before dismissing
                    Task {
                        await challengesViewModel.loadChallenges()
                    }
                    dismiss()
                }
            } else {
                // Initial check-in confirmation screen
                initialCheckInView
            }
        }
        .navigationBarHidden(showSuccessView || showNotePrompt || showMilestoneView)
        .onAppear {
            // Set up the check-in
            Task {
                await viewModel.prepareForCheckIn(
                    challengeId: challenge.id.uuidString,
                    currentDay: challenge.daysCompleted + 1,
                    challengeTitle: challenge.title
                )
            }
            
            // Sync seen milestones from cloud
            Task {
                await milestoneViewModel.syncSeenMilestones(challengeId: challenge.id.uuidString)
            }
            
            // Start haptic feedback
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }
    }
    
    private var initialCheckInView: some View {
        ZStack {
            // Background with gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.theme.background, Color.theme.background.opacity(0.9)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .onTapGesture {
                // Dismiss keyboard if tapped outside of any input field
                isJournalFocused = false
                dismissKeyboard()
            }
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header card
                    VStack(spacing: 16) {
                        headerView
                        progressView
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    
                    // Journal card
                    journalCard
                    
                    // Photo upload card
                    photoUploadCard
                    
                    // Timer card (if challenge requires timer)
                    if challenge.isTimed {
                        timerCard
                    }
                    
                    // Check-in button
                    checkInButton
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                }
                .padding(.top, 20)
            }
            .safeAreaInset(edge: .top) {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.theme.text)
                            .padding(10)
                            .background(
                                Circle()
                                    .fill(Color.theme.surface)
                                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                            )
                    }
                    .accessibilityLabel("Close check-in view")
                    
                    Spacer()
                    
                    Text("Check In")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.theme.text)
                    
                    Spacer()
                    
                    // Empty view to balance the layout
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 36, height: 36)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .background(
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea()
                )
            }
            .background(Color.theme.background)
        }
    }
    
    // MARK: - Component Views
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(challenge.title)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.theme.text)
                .accessibilityLabel("Challenge title: \(challenge.title)")
            
            HStack {
                Text("Day \(challenge.daysCompleted + 1) of 100")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.theme.accent)
                    .accessibilityLabel("Day \(challenge.daysCompleted + 1) of 100")
                
                Spacer()
                
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.orange)
                    
                    Text("Streak: \(challenge.streakCount) days")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.theme.subtext)
                }
                .accessibilityLabel("Current streak: \(challenge.streakCount) days")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
        )
    }
    
    private var progressView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Progress")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.theme.text)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.theme.surface)
                        .frame(width: geometry.size.width, height: 12)
                    
                    // Progress fill
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.theme.accent, Color.theme.accent.opacity(0.8)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * CGFloat(challenge.progressPercentage), height: 12)
                }
                .accessibilityValue("\(Int(challenge.progressPercentage * 100))% complete")
            }
            .frame(height: 12)
            
            HStack {
                Text("\(challenge.daysCompleted)%")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.theme.accent)
                
                Spacer()
                
                Text("\(challenge.daysRemaining) days left")
                    .font(.system(size: 14))
                    .foregroundColor(.theme.subtext)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
        )
    }
    
    private var journalCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Journal Entry")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.theme.text)
            
            Text(viewModel.currentPrompt)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.theme.accent)
                .padding(.bottom, 4)
                .accessibilityLabel("Journal prompt: \(viewModel.currentPrompt)")
            
            TextEditor(text: $journalText)
                .focused($isJournalFocused)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .frame(minHeight: 120)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.theme.surface.opacity(0.8))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.theme.accent.opacity(0.2), lineWidth: 1)
                )
                .overlay(
                    Group {
                        if journalText.isEmpty && !isJournalFocused {
                            Text("Reflect on your progress...")
                                .foregroundColor(.theme.subtext.opacity(0.6))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 20)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                .allowsHitTesting(false)
                        }
                    }
                )
                .accessibilityHint("Journal entry. Double tap to edit.")
                .onChange(of: journalText) { oldValue, newValue in
                    if newValue.count % 20 == 0 && newValue.count > 0 {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    }
                }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
        )
        .padding(.horizontal, 20)
    }
    
    private var photoUploadCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Photo")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.theme.text)
            
            if let selectedImage = selectedImage {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 200)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 3)
                        .accessibilityLabel("Selected photo")
                    
                    Button(action: {
                        self.selectedImage = nil
                        self.photoItem = nil
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.7))
                                .frame(width: 30, height: 30)
                            
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(8)
                    .accessibilityLabel("Remove photo")
                }
            } else {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    VStack {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.theme.accent.opacity(0.8))
                            .padding(.bottom, 8)
                        
                        Text("Add a photo to your check-in")
                            .font(.system(size: 14))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.theme.subtext)
                    }
                    .frame(height: 120)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.theme.surface.opacity(0.8))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.theme.accent.opacity(0.2), lineWidth: 1)
                    )
                }
                .accessibilityLabel("Select a photo")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
        )
        .padding(.horizontal, 20)
        .onChange(of: photoItem) {
            if let newValue = photoItem {
                loadTransferable(from: newValue)
            }
        }
    }
    
    private var timerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Track Time")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.theme.text)
            
            VStack(spacing: 24) {
                // Timer display
                Text(timeString(from: elapsedTime))
                    .font(.system(size: 48, weight: .medium, design: .monospaced))
                    .foregroundColor(.theme.text)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Timer: \(timeString(from: elapsedTime))")
                
                // Timer controls
                HStack(spacing: 20) {
                    Button(action: {
                        if timerRunning {
                            stopTimer()
                        } else {
                            startTimer()
                        }
                    }) {
                        HStack {
                            Image(systemName: timerRunning ? "pause.fill" : "play.fill")
                                .font(.system(size: 16, weight: .semibold))
                            
                            Text(timerRunning ? "Pause" : "Start")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(height: 50)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.theme.accent)
                        )
                    }
                    .accessibilityLabel(timerRunning ? "Pause timer" : "Start timer")
                    
                    Button(action: {
                        resetTimer()
                    }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 16, weight: .semibold))
                            
                            Text("Reset")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.theme.text)
                        .frame(height: 50)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.theme.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.theme.subtext.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                    .disabled(elapsedTime == 0)
                    .opacity(elapsedTime == 0 ? 0.5 : 1)
                    .accessibilityLabel("Reset timer")
                    .accessibilityHint(elapsedTime == 0 ? "Timer is already at zero" : "Reset timer to zero")
                }
            }
            .padding(.vertical, 16)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
        )
        .padding(.horizontal, 20)
        .onAppear {
            // Handle app going to background
            NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { _ in
                if timerRunning {
                    // We're pausing but saving the elapsed time
                    stopTimer()
                }
            }
            
            // Handle app coming back to foreground
            NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
                // Give opportunity to resume timer
                // We don't auto-resume for UX reasons - user should explicitly resume
            }
        }
        .onDisappear {
            // Clean up timer resources
            stopTimer()
            
            // Remove notification observers
            NotificationCenter.default.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)
            NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
        }
    }
    
    private var checkInButton: some View {
        Button(action: {
            // Save journal text to view model first
            viewModel.note = journalText
            
            // Check if timer is required
            if challenge.isTimed && elapsedTime == 0 {
                // Show error message
                viewModel.errorMessage = "Please complete the timer before checking in"
                viewModel.showError = true
                return
            }
            
            performCheckIn()
        }) {
            HStack {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .padding(.trailing, 8)
                    
                    Text("Processing...")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                } else {
                    Spacer()
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .padding(.trailing, 6)
                    
                    Text("Complete Check-In")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                }
            }
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.theme.accent, Color.theme.accent.opacity(0.8)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: Color.theme.accent.opacity(0.3), radius: 10, x: 0, y: 5)
            )
        }
        .disabled(viewModel.isLoading || (challenge.isTimed && elapsedTime == 0))
        .opacity(challenge.isTimed && elapsedTime == 0 ? 0.7 : 1)
        .accessibilityLabel("Complete check-in")
        .accessibilityHint(challenge.isTimed && elapsedTime == 0 ? "Complete the timer first" : "")
    }
    
    // MARK: - Helper Functions
    
    private func loadTransferable(from imageSelection: PhotosPickerItem) {
        imageSelection.loadTransferable(type: PhotoTransferable.self) { result in
            Task { @MainActor in
                guard imageSelection == photoItem else { return }
                
                switch result {
                case .success(let photoTransferable?):
                    self.selectedImage = photoTransferable.image
                    viewModel.selectedImage = photoTransferable.image
                    
                    // Provide haptic feedback on successful image selection
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    
                case .success(nil):
                    print("No photo transferable data available")
                case .failure(let error):
                    print("Error loading image: \(error)")
                }
            }
        }
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) / 60 % 60
        let seconds = Int(timeInterval) % 60
        
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    private func startTimer() {
        // If timer isn't already running
        if !timerRunning {
            timerRunning = true
            
            // Set start time if this is a new timer session
            if timerStartTime == nil {
                timerStartTime = Date()
                
                // Haptic feedback when starting a new timer session
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
            } else {
                // Adjust for paused time
                timerStartTime = Date().addingTimeInterval(-elapsedTime)
                
                // Light haptic when resuming
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            }
            
            // Create a timer that fires once per second
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                if let startTime = timerStartTime {
                    elapsedTime = Date().timeIntervalSince(startTime)
                }
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        timerRunning = false
        
        // Light haptic when pausing
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    private func resetTimer() {
        stopTimer()
        elapsedTime = 0
        timerStartTime = nil
        
        // Medium haptic when resetting
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    private func performCheckIn() {
        Task {
            // First, upload image if we have one
            if let image = selectedImage {
                _ = await viewModel.uploadImage(image)
            }
            
            // Save time if this is a timed challenge
            if challenge.isTimed && elapsedTime > 0 {
                // Set the duration in the view model
                viewModel.timerDuration = elapsedTime
            }
            
            // Perform the check-in
            await viewModel.performCheckIn()
            
            // If successful, show the success view
            if !viewModel.showError {
                // Provide haptic feedback
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                
                // Update the last check-in time immediately for better UX
                challengesViewModel.lastCheckInDate = Date()
                
                showSuccessView = true
                
                // Refresh the challenges list
                await challengesViewModel.loadChallenges()
            } else {
                // Error haptic feedback
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)
            }
        }
    }
    
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), 
                                      to: nil, from: nil, for: nil)
    }
}

// Preview removed to avoid sample data usage in production code 