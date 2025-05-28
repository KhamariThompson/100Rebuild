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
    @State private var isShowingImagePicker = false
    
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
                    // Challenge title card
                    challengeTitleCard
                        .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                        .padding(.top, AppSpacing.l)
                    
                    // Progress card
                    progressView
                        .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                    
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
                .padding(.top, AppSpacing.xl)
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
                    
                    Text("Day \(challenge.daysCompleted + 1) Check-In")
                        .font(.system(size: AppSpacing.iconSizeMedium, weight: .semibold))
                        .foregroundColor(.theme.text)
                    
                    Spacer()
                    
                    // Balance the layout with an invisible element
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 24, height: 24)
                }
                .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                .padding(.vertical, AppSpacing.s)
                .background(
                    Color.theme.background
                        .opacity(0.95)
                        .shadow(color: Color.theme.shadow.opacity(0.1), radius: 3, x: 0, y: 2)
                        .blur(radius: 0.2)
                )
            }
        }
    }
    
    // MARK: - UI Components
    
    // Challenge title card with icon
    private var challengeTitleCard: some View {
        VStack(alignment: .center, spacing: AppSpacing.s) {
            // Challenge icon
            Image(systemName: getChallengeIcon(title: challenge.title))
                .font(.system(size: 36))
                .foregroundColor(.theme.accent)
                .frame(width: 72, height: 72)
                .background(
                    Circle()
                        .fill(Color.theme.accent.opacity(0.12))
                )
                .padding(.bottom, AppSpacing.xs)
            
            // Challenge title
            Text(challenge.title)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.theme.text)
                .multilineTextAlignment(.center)
            
            // Day counter
            Text("Day \(challenge.daysCompleted + 1) of 100")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.theme.subtext)
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.m)
        .background(
            RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                .fill(Color.theme.surface)
                .shadow(color: Color.theme.shadow.opacity(0.08), radius: 8, x: 0, y: 4)
        )
    }
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
                // Date of check-in
                Text(formattedDate)
                    .font(AppTypography.caption1())
                    .foregroundColor(.theme.subtext)
                
                Spacer()
                
                // Streak indicator
                HStack(spacing: AppSpacing.xxs) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: AppSpacing.iconSizeSmall))
                    
                    Text("\(challenge.streakCount)")
                        .font(AppTypography.caption1())
                        .foregroundColor(.theme.subtext)
                }
            }
            
            // Day indicator
            Text("Day \(challenge.daysCompleted + 1) of 100")
                .font(AppTypography.headline())
                .foregroundColor(.theme.text)
        }
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
                        .font(AppTypography.caption1())
                        .foregroundColor(.theme.subtext)
                    
                    Text("\(challenge.daysCompleted)/100")
                        .font(AppTypography.headline())
                        .foregroundColor(.theme.accent)
                }
                
                Spacer()
                
                // Current streak
                VStack(alignment: .trailing, spacing: AppSpacing.xxs) {
                    Text("Current Streak")
                        .font(AppTypography.caption1())
                        .foregroundColor(.theme.subtext)
                    
                    HStack(spacing: AppSpacing.xxs) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: AppSpacing.iconSizeSmall))
                        
                        Text("\(challenge.streakCount)")
                            .font(AppTypography.headline())
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
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            // Section title
            HStack {
                Image(systemName: "text.book.closed")
                    .foregroundColor(.theme.accent)
                    .font(.system(size: AppSpacing.iconSizeSmall))
                
                Text("Journal Entry")
                    .font(AppTypography.headline())
                    .foregroundColor(.theme.text)
                
                Spacer()
                
                // Character count indicator
                Text("\(journalText.count)/500")
                    .font(AppTypography.caption2())
                    .foregroundColor(journalText.count > 450 ? (journalText.count >= 500 ? .red : .orange) : .theme.subtext)
            }
            
            // Text editor with placeholder
            ZStack(alignment: .topLeading) {
                if journalText.isEmpty {
                    Text("How did you feel about your progress today? (Optional)")
                        .font(AppTypography.body())
                        .foregroundColor(.theme.subtext.opacity(0.7))
                        .padding(.top, 8)
                        .padding(.leading, 4)
                }
                
                TextEditor(text: $journalText)
                    .focused($isJournalFocused)
                    .font(AppTypography.body())
                    .foregroundColor(.theme.text)
                    .frame(minHeight: 100)
                    .background(Color.clear)
                    .onChange(of: journalText) { oldValue, newValue in
                        // Limit text to 500 characters
                        if newValue.count > 500 {
                            journalText = String(newValue.prefix(500))
                        }
                    }
            }
            .padding(AppSpacing.xs)
            .background(
                RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius - 4)
                    .fill(Color.theme.surface.opacity(0.5))
            )
        }
        .padding(AppSpacing.cardPadding)
        .background(
            AppComponents.Card {
                VStack {
                    // Your content here
                }
            }
        )
        .padding(.horizontal, AppSpacing.screenHorizontalPadding)
    }
    
    private var photoUploadCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            // Section title
            HStack {
                Image(systemName: "photo")
                    .foregroundColor(.theme.accent)
                    .font(.system(size: AppSpacing.iconSizeSmall))
                
                Text("Add Photo")
                    .font(AppTypography.headline())
                    .foregroundColor(.theme.text)
                
                Spacer()
                
                if selectedImage != nil {
                    Button(action: { selectedImage = nil }) {
                        Text("Clear")
                            .font(AppTypography.footnote())
                            .foregroundColor(.red)
                    }
                }
            }
            
            // Photo selection area
            ZStack {
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .cornerRadius(AppSpacing.cardCornerRadius - 4)
                } else {
                    PhotosPicker(
                        selection: $photoItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        VStack(spacing: AppSpacing.s) {
                            Image(systemName: "camera")
                                .font(.system(size: 32))
                                .foregroundColor(.theme.accent.opacity(0.8))
                            
                            Text("Tap to add a photo (Optional)")
                                .font(AppTypography.caption1())
                                .foregroundColor(.theme.subtext)
                        }
                        .frame(maxWidth: .infinity, minHeight: 120)
                        .background(
                            RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius - 4)
                                .fill(Color.theme.surface.opacity(0.5))
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius - 4)
                                        .stroke(Color.theme.border.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                }
            }
            .onChange(of: photoItem) { oldValue, newValue in
                if let newValue = newValue {
                    loadTransferable(from: newValue)
                }
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(
            AppComponents.Card {
                EmptyView()
            }
        )
        .padding(.horizontal, AppSpacing.screenHorizontalPadding)
    }
    
    private var timerCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            // Section title
            HStack {
                Image(systemName: "timer")
                    .foregroundColor(.theme.accent)
                    .font(.system(size: AppSpacing.iconSizeSmall))
                
                Text("Time Your Activity")
                    .font(AppTypography.headline())
                    .foregroundColor(.theme.text)
                
                Spacer()
            }
            
            // Timer display and controls
            VStack(spacing: AppSpacing.m) {
                // Elapsed time display
                Text(formattedElapsedTime)
                    .font(.system(size: 48, weight: .medium, design: .monospaced))
                    .foregroundColor(timerRunning ? .theme.accent : .theme.text)
                    .frame(maxWidth: .infinity)
                
                // Start/Stop button
                Button(action: toggleTimer) {
                    Text(timerRunning ? "Stop Timer" : "Start Timer")
                        .font(AppTypography.headline())
                        .foregroundColor(.white)
                        .padding(.vertical, AppSpacing.s)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius - 4)
                                .fill(timerRunning ? Color.red : Color.theme.accent)
                        )
                }
            }
            .padding(AppSpacing.s)
            .background(
                RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius - 4)
                    .fill(Color.theme.surface.opacity(0.5))
            )
        }
        .padding(AppSpacing.cardPadding)
        .background(
            AppComponents.Card {
                EmptyView()
            }
        )
        .padding(.horizontal, AppSpacing.screenHorizontalPadding)
    }
    
    private var checkInButton: some View {
        Button(action: performCheckIn) {
            HStack {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                        .padding(.trailing, 10)
                }
                
                Text("Complete Day \(challenge.daysCompleted + 1)")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.black)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.m)
            .background(
                RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                    .fill(Color.theme.accent)
                    .shadow(color: Color.theme.shadow, radius: 8, x: 0, y: 4)
            )
            .overlay(
                // Loading indicator when in progress
                Group {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.2)
                    }
                }
            )
        }
        .disabled(viewModel.isLoading || !isValidCheckIn)
        .opacity(isValidCheckIn ? 1.0 : 0.6)
        .buttonStyle(AppScaleButtonStyle())
    }
    
    // MARK: - Helper Methods
    
    private func performCheckIn() {
        Task {
            await viewModel.checkIn(
                for: challenge,
                timedDuration: Int(elapsedTime / 60)
            )
            showSuccessView = true
        }
    }
    
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
    
    private func toggleTimer() {
        if timerRunning {
            // Stop the timer
            timer?.invalidate()
            timerRunning = false
        } else {
            // Start the timer
            timerStartTime = Date()
            timerRunning = true
            
            // Create a timer that fires every second
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                if let startTime = timerStartTime {
                    elapsedTime = Date().timeIntervalSince(startTime) + elapsedTime
                    timerStartTime = Date()
                }
            }
        }
    }
    
    private func loadTransferable(from imageSelection: PhotosPickerItem) {
        imageSelection.loadTransferable(type: Data.self) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    if let data = data, let image = UIImage(data: data) {
                        self.selectedImage = image
                    } else {
                        print("Failed to load image data")
                    }
                case .failure(let error):
                    print("Image transfer failed: \(error)")
                }
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
