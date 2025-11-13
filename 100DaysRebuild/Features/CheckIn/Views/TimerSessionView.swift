import SwiftUI
import Combine
import AVFoundation

/// A view that displays a timer for timed challenges.
/// The user must complete the timer session to check in for the challenge.
struct TimerSessionView: View {
    // MARK: - Properties
    
    let challenge: Challenge
    @StateObject private var viewModel = TimerViewModel()
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.theme.background
                    .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    // Timer header
                    VStack(spacing: 12) {
                        Text(challenge.title)
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.theme.text)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                            .padding(.horizontal)

                        Text("Complete this timer to check in")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.theme.subtext)
                    }
                    .padding(.top)
                    
                    // Timer circle
                    ZStack {
                        // Background circle
                        Circle()
                            .stroke(lineWidth: 20)
                            .opacity(0.3)
                            .foregroundColor(Color.theme.accent.opacity(0.2))
                        
                        // Progress circle
                        Circle()
                            .trim(from: 0.0, to: viewModel.progress)
                            .stroke(style: StrokeStyle(lineWidth: 20, lineCap: .round, lineJoin: .round))
                            .foregroundColor(Color.theme.accent)
                            .rotationEffect(Angle(degrees: 270.0))
                            .animation(.linear, value: viewModel.progress)
                        
                        // Time display
                        VStack(spacing: 8) {
                            Text(viewModel.timeString)
                                .font(.system(size: 60, weight: .bold, design: .rounded))
                                .foregroundColor(.theme.text)
                                .monospacedDigit()

                            if viewModel.isRunning {
                                Text("remaining")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(.theme.subtext)
                            }
                        }
                    }
                    .frame(width: 280, height: 280)
                    .padding()
                    
                    // Controls
                    if viewModel.isCompleted {
                        completedControls
                    } else {
                        timerControls
                    }
                    
                    Spacer()
                    
                    // Duration picker (only when not running)
                    if !viewModel.isRunning && !viewModel.isCompleted {
                        durationPicker
                    }
                }
                .padding()
            }
            .navigationTitle("Timer Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        if viewModel.isRunning {
                            viewModel.showExitConfirmation = true
                        } else {
                            dismiss()
                        }
                    }
                }
            }
            .onAppear {
                viewModel.prepareSession()
            }
            .onDisappear {
                viewModel.cleanUp()
            }
            .alert("Cancel Timer?", isPresented: $viewModel.showExitConfirmation) {
                Button("Stay", role: .cancel) { }
                Button("Exit", role: .destructive) {
                    viewModel.cancelTimer()
                    dismiss()
                }
            } message: {
                Text("If you exit now, your progress won't be saved.")
            }
            .alert("Success!", isPresented: $viewModel.showSuccessAlert) {
                Button("Done") {
                    viewModel.completeCheckIn(for: challenge)
                    dismiss()
                }
            } message: {
                Text("You've successfully completed today's challenge.")
            }
            .alert("Error", isPresented: $viewModel.showErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }
    
    // MARK: - View Components
    
    private var completedControls: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 70, weight: .bold))
                .foregroundColor(.green)

            Text("Great job!")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(.theme.text)

            Text("You've completed your timer session")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.theme.subtext)
                .multilineTextAlignment(.center)

            Button {
                viewModel.completeCheckIn(for: challenge)
                dismiss()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .bold))

                    Text("Check In & Complete")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(
                        colors: [Color.theme.accent, Color.theme.accent.opacity(0.85)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: Color.theme.accent.opacity(0.4), radius: 12, x: 0, y: 6)
            }
            .padding(.top, 10)
        }
    }
    
    private var timerControls: some View {
        HStack(spacing: 40) {
            // Reset button (only when paused)
            if !viewModel.isRunning && viewModel.elapsedTime > 0 {
                Button {
                    viewModel.resetTimer()
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundColor(.theme.subtext)

                        Text("Reset")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.theme.subtext)
                    }
                }
            }

            // Start/Pause button
            Button {
                viewModel.isRunning ? viewModel.pauseTimer() : viewModel.startTimer()
            } label: {
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.theme.accent, Color.theme.accent.opacity(0.9)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                            .shadow(color: Color.theme.accent.opacity(0.4), radius: 12, x: 0, y: 6)

                        Image(systemName: viewModel.isRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                    }

                    Text(viewModel.isRunning ? "Pause" : "Start")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.theme.text)
                }
            }

            // Skip button (only when timer is running, for demo purposes)
            if viewModel.isRunning && viewModel.enableDebugSkip {
                Button {
                    viewModel.completeTimer()
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundColor(.theme.subtext)

                        Text("Skip")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.theme.subtext)
                    }
                }
            }
        }
    }
    
    private var durationPicker: some View {
        VStack(spacing: 16) {
            Text("Timer Duration")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(.theme.text)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach([5, 10, 15, 25, 30, 45, 60], id: \.self) { minutes in
                        Button {
                            viewModel.timerDuration = TimeInterval(minutes * 60)
                        } label: {
                            Text("\(minutes)m")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(viewModel.timerDuration == TimeInterval(minutes * 60) ? .white : .theme.text)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(viewModel.timerDuration == TimeInterval(minutes * 60) ?
                                             Color.theme.accent : Color.theme.surface)
                                        .shadow(
                                            color: viewModel.timerDuration == TimeInterval(minutes * 60) ?
                                                Color.theme.accent.opacity(0.3) : Color.clear,
                                            radius: 6,
                                            x: 0,
                                            y: 3
                                        )
                                )
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.theme.surface.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.theme.border.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - ViewModel

@MainActor
class TimerViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var isRunning: Bool = false
    @Published var isCompleted: Bool = false
    @Published var elapsedTime: TimeInterval = 0
    @Published var timerDuration: TimeInterval = 10 * 60 // Default 10 minutes
    @Published var progress: CGFloat = 0.0
    @Published var showExitConfirmation: Bool = false
    @Published var showSuccessAlert: Bool = false
    @Published var showErrorAlert: Bool = false
    @Published var errorMessage: String = ""
    
    // MARK: - Debug Options
    
    #if DEBUG
    @Published var enableDebugSkip: Bool = true
    #else
    @Published var enableDebugSkip: Bool = false
    #endif
    
    // MARK: - Private Properties
    
    private var timer: Timer?
    private var startDate: Date?
    private var backgroundDate: Date?
    private var audioPlayer: AVAudioPlayer?
    private let checkInService = CheckInService.shared
    @MainActor private let impact = UIImpactFeedbackGenerator(style: .medium)
    @MainActor private let notification = UINotificationFeedbackGenerator()
    
    // MARK: - Computed Properties
    
    var timeString: String {
        let remainingTime = max(0, timerDuration - elapsedTime)
        let minutes = Int(remainingTime) / 60
        let seconds = Int(remainingTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var durationInMinutes: Int {
        return Int(timerDuration / 60)
    }
    
    // MARK: - Initialization
    
    init() {
        setupNotifications()
    }
    
    deinit {
        // removeObservers synchronously from deinit; removeNotifications is nonisolated so this call is allowed
        removeNotifications()
        // Note: Cannot access main actor-isolated 'timer' from deinit
        // Timer will be invalidated when the object is deallocated
    }
    
    // MARK: - Public Methods
    
    func prepareSession() {
        loadSound()
    }
    
    func startTimer() {
        if timer != nil {
            timer?.invalidate()
        }

        startDate = Date()
        Task { @MainActor in
            impact.impactOccurred()
        }
        isRunning = true

        // Use a Timer but dispatch main-actor updates inside the Sendable closure.
        timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { [weak self] _ in
            let now = Date()

            // Update MainActor-isolated state inside a MainActor Task to satisfy Swift concurrency rules
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.elapsedTime = now.timeIntervalSince(self.startDate ?? now)
                self.updateProgress()

                if self.elapsedTime >= self.timerDuration {
                    self.completeTimer()
                }
            }
        }
    }

    func pauseTimer() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        Task { @MainActor in
            impact.impactOccurred(intensity: 0.5)
        }
    }

    func resetTimer() {
        timer?.invalidate()
        timer = nil
        elapsedTime = 0
        progress = 0
        isRunning = false
        Task { @MainActor in
            impact.impactOccurred(intensity: 0.7)
        }
    }
    
    func cancelTimer() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }
    
    func completeTimer() {
        timer?.invalidate()
        timer = nil
        elapsedTime = timerDuration
        progress = 1.0
        isRunning = false
        isCompleted = true
        playCompletionSound()
        Task { @MainActor in
            notification.notificationOccurred(.success)
        }
    }
    
    func completeCheckIn(for challenge: Challenge) {
        Task {
            do {
                _ = try await checkInService.checkIn(
                    for: challenge.id.uuidString,
                    durationInMinutes: durationInMinutes
                )
                await MainActor.run {
                    showSuccessAlert = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showErrorAlert = true
                }
            }
        }
    }
    
    func cleanUp() {
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - Private Methods
    
    private func updateProgress() {
        progress = min(1.0, elapsedTime / timerDuration)
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appMovedToBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appMovedToForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    nonisolated private func removeNotifications() {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func appMovedToBackground() {
        if isRunning {
            backgroundDate = Date()
            pauseTimer()
        }
    }
    
    @objc private func appMovedToForeground() {
        if let backgroundDate = backgroundDate, startDate != nil {
            let timeInBackground = Date().timeIntervalSince(backgroundDate)
            elapsedTime += timeInBackground
            updateProgress()
            
            if elapsedTime >= timerDuration {
                completeTimer()
            } else {
                startTimer()
            }
            
            self.backgroundDate = nil
        }
    }
    
    private func loadSound() {
        guard let soundURL = Bundle.main.url(forResource: "timer_complete", withExtension: "mp3") else {
            print("Sound file not found")
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.prepareToPlay()
        } catch {
            print("Could not load sound file: \(error)")
        }
    }
    
    private func playCompletionSound() {
        audioPlayer?.play()
    }
}

// MARK: - Preview

struct TimerSessionView_Previews: PreviewProvider {
    static var previews: some View {
        TimerSessionView(
            challenge: Challenge(
                title: "Read 30 minutes",
                ownerId: "preview",
                isTimed: true
            )
        )
    }
} 