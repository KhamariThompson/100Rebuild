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
                VStack(spacing: AppSpacing.l) {
                    // Header card
                    VStack(spacing: AppSpacing.m) {
                        headerView
                        progressView
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                    .padding(.top, AppSpacing.s)
                    
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
                        .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                        .padding(.bottom, AppSpacing.l)
                }
                .padding(.top, AppSpacing.m)
            }
            .safeAreaInset(edge: .top) {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: AppSpacing.iconSizeSmall, weight: .medium))
                            .foregroundColor(.theme.text)
                            .padding(AppSpacing.xs)
                            .background(
                                Circle()
                                    .fill(Color.theme.surface)
                                    .shadow(color: Color.theme.shadow, radius: 4, x: 0, y: 2)
                            )
                    }
                    .accessibilityLabel("Close check-in view")
                    
                    Spacer()
                    
                    Text("Check In")
                        .font(.system(size: AppSpacing.iconSizeMedium, weight: .semibold))
                        .foregroundColor(.theme.text)
                    
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Individual Content Sections
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Day \(challenge.daysCompleted + 1)")
                .font(AppTypography.title2)
                .fontWeight(.bold)
                .foregroundColor(.theme.accent)
            
            Text(challenge.title)
                .font(AppTypography.headline)
                .foregroundColor(.theme.text)
            
            Text(formattedDate)
                .font(AppTypography.subheadline)
                .foregroundColor(.theme.subtext)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppSpacing.screenHorizontalPadding)
        .padding(.top, AppSpacing.xs)
    }
    
    private var progressView: some View {
        // Progress view of the challenge
        VStack(spacing: AppSpacing.m) {
            // Progress bar
            AppComponents.ProgressBar(value: Double(challenge.daysCompleted) / 100.0)
                .frame(height: AppSpacing.xs)
            
            // Stats row
            HStack {
                // Days completed
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text("Days Completed")
                        .font(AppTypography.caption)
                        .foregroundColor(.theme.subtext)
                    
                    Text("\(challenge.daysCompleted)/100")
                        .font(AppTypography.headline)
                        .foregroundColor(.theme.accent)
                }
                
                Spacer()
                
                // Current streak
                VStack(alignment: .trailing, spacing: AppSpacing.xxs) {
                    Text("Current Streak")
                        .font(AppTypography.caption)
                        .foregroundColor(.theme.subtext)
                    
                    HStack(spacing: AppSpacing.xxs) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: AppSpacing.iconSizeSmall))
                        
                        Text("\(challenge.streakCount)")
                            .font(AppTypography.headline)
                            .foregroundColor(.theme.accent)
                    }
                }
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(
            AppComponents.Card {
                EmptyView()
            }
        )
    }
    
    private var journalCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            // Title with pen icon
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "pencil.line")
                    .font(.system(size: AppSpacing.iconSizeSmall))
                    .foregroundColor(.theme.accent)
                
                Text("Journal Entry")
                    .font(AppTypography.headline)
                    .foregroundColor(.theme.text)
            }
            
            // Journal text editor
            ZStack(alignment: .topLeading) {
                if journalText.isEmpty {
                    Text("Add your thoughts about today's progress...")
                        .font(AppTypography.body)
                        .foregroundColor(.theme.subtext.opacity(0.7))
                        .padding(.top, AppSpacing.xxs)
                }
                
                TextEditor(text: $journalText)
                    .font(AppTypography.body)
                    .foregroundColor(.theme.text)
                    .frame(minHeight: 120)
                    .focused($isJournalFocused)
                    .opacity(journalText.isEmpty ? 0.25 : 1)
            }
            .padding(AppSpacing.xs)
            .background(
                RoundedRectangle(cornerRadius: AppSpacing.s)
                    .stroke(Color.theme.border, lineWidth: 1)
            )
        }
        .padding(.horizontal, AppSpacing.screenHorizontalPadding)
        .padding(.vertical, AppSpacing.m)
        .background(
            AppComponents.Card {
                EmptyView()
            }
            .padding(.horizontal, AppSpacing.screenHorizontalPadding)
        )
    }
    
    private var photoUploadCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            // Title with camera icon
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "camera")
                    .font(.system(size: AppSpacing.iconSizeSmall))
                    .foregroundColor(.theme.accent)
                
                Text("Add Photo")
                    .font(AppTypography.headline)
                    .foregroundColor(.theme.text)
            }
            
            // Photo preview or selector
            if let selectedImage = selectedImage {
                // Photo preview with delete option
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .cornerRadius(AppSpacing.cardCornerRadius)
                    
                    Button(action: {
                        self.selectedImage = nil
                        self.photoItem = nil
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: AppSpacing.iconSizeMedium))
                            .foregroundColor(.theme.accent)
                            .background(Circle().fill(Color.white))
                    }
                    .padding(AppSpacing.xs)
                }
            } else {
                // Photo selector
                PhotosPicker(
                    selection: $photoItem,
                    matching: .images
                ) {
                    VStack(spacing: AppSpacing.s) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 28)) // Keep this a bit larger
                            .foregroundColor(.theme.accent.opacity(0.8))
                        
                        Text("Select Photo")
                            .font(AppTypography.subheadline)
                            .foregroundColor(.theme.accent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.buttonVerticalPadding)
                    .background(
                        RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                            .stroke(Color.theme.accent.opacity(0.4), lineWidth: 1.5)
                            .background(Color.theme.accent.opacity(0.05).cornerRadius(AppSpacing.cardCornerRadius))
                    )
                }
                .onChange(of: photoItem) { oldValue, newValue in
                    Task {
                        if let data = try? await newValue?.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            selectedImage = image
                        }
                    }
                }
            }
        }
        .padding(.horizontal, AppSpacing.screenHorizontalPadding)
        .padding(.vertical, AppSpacing.m)
        .background(
            AppComponents.Card {
                EmptyView()
            }
            .padding(.horizontal, AppSpacing.screenHorizontalPadding)
        )
    }
    
    private var timerCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            // Title with timer icon
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "timer")
                    .font(.system(size: AppSpacing.iconSizeSmall))
                    .foregroundColor(.theme.accent)
                
                Text("Timer Session")
                    .font(AppTypography.headline)
                    .foregroundColor(.theme.text)
            }
            
            // Timer display and controls
            VStack(spacing: AppSpacing.m) {
                HStack {
                    Text(formattedElapsedTime)
                        .font(.system(size: 42, weight: .bold, design: .monospaced))
                        .foregroundColor(.theme.text)
                        .frame(minWidth: 120)
                    
                    Spacer()
                    
                    // Timer controls
                    HStack(spacing: AppSpacing.m) {
                        Button(action: {
                            if timerRunning {
                                stopTimer()
                            } else {
                                startTimer()
                            }
                            
                            // Give haptic feedback
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            
                        }) {
                            Image(systemName: timerRunning ? "pause.fill" : "play.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .frame(width: 48, height: 48)
                                .background(
                                    Circle()
                                        .fill(Color.theme.accent)
                                )
                        }
                        
                        Button(action: {
                            resetTimer()
                            
                            // Give haptic feedback
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            
                        }) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 20))
                                .foregroundColor(.theme.accent)
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle()
                                        .stroke(Color.theme.accent, lineWidth: 1.5)
                                )
                        }
                    }
                }
                
                // Progress indicator
                if timerRunning || elapsedTime > 0 {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "hourglass")
                            .font(.system(size: AppSpacing.iconSizeSmall))
                            .foregroundColor(.theme.accent)
                            .opacity(timerRunning ? 1.0 : 0.5)
                        
                        Text(timerRunning ? "Timer running..." : "Timer paused")
                            .font(AppTypography.caption)
                            .foregroundColor(.theme.subtext)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "info.circle")
                            .font(.system(size: AppSpacing.iconSizeSmall))
                            .foregroundColor(.theme.accent)
                        
                        Text("This challenge requires a timed session")
                            .font(AppTypography.caption)
                            .foregroundColor(.theme.subtext)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.horizontal, AppSpacing.screenHorizontalPadding)
        .padding(.vertical, AppSpacing.m)
        .background(
            AppComponents.Card {
                EmptyView()
            }
            .padding(.horizontal, AppSpacing.screenHorizontalPadding)
        )
    }
    
    private var checkInButton: some View {
        Button(action: {
            performCheckIn()
        }) {
            Text("Complete Check-In")
                .font(AppTypography.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.buttonVerticalPadding)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.theme.accent, Color.theme.accent.opacity(0.8)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .cornerRadius(AppSpacing.cardCornerRadius)
                    .shadow(color: Color.theme.shadow, radius: 8, x: 0, y: 4)
                )
        }
        .disabled(viewModel.isLoading)
        .opacity(isValidCheckIn ? 1.0 : 0.6)
        .buttonStyle(AppScaleButtonStyle())
    }
    
    // MARK: - Helper Methods
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: Date())
    }
    
    private var formattedElapsedTime: String {
        let hours = Int(elapsedTime) / 3600
        let minutes = (Int(elapsedTime) % 3600) / 60
        let seconds = Int(elapsedTime) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    private var isValidCheckIn: Bool {
        if challenge.isTimed {
            // For timed challenge, require at least some timer activity
            return elapsedTime > 0
        } else {
            // For normal challenge, any valid check-in is okay
            return !viewModel.isLoading
        }
    }
    
    private func startTimer() {
        timerRunning = true
        
        if elapsedTime == 0 {
            timerStartTime = Date()
        } else {
            // Resume from current elapsed time
            timerStartTime = Date().addingTimeInterval(-elapsedTime)
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            guard let startTime = timerStartTime else { return }
            elapsedTime = Date().timeIntervalSince(startTime)
        }
    }
    
    private func stopTimer() {
        timerRunning = false
        timer?.invalidate()
        timer = nil
    }
    
    private func resetTimer() {
        stopTimer()
        elapsedTime = 0
        timerStartTime = nil
    }
    
    private func performCheckIn() {
        // Stop timer if running
        if timerRunning {
            stopTimer()
        }
        
        // Process check-in
        Task {
            await viewModel.checkIn(
                for: challenge,
                timedDuration: elapsedTime > 0 ? Int(elapsedTime) : nil
            )
            
            // Show success view after check-in
            if !viewModel.showError {
                showSuccessView = true
            }
        }
    }
    
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// Helper extension for previews
struct EnhancedCheckInView_Previews: PreviewProvider {
    static var previews: some View {
        // Preview implementation
        Text("Preview")
    }
} 