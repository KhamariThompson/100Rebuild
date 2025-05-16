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
                    VStack(spacing: 8) {
                        Text(challenge.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.theme.text)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Text("Complete this timer to check in")
                            .font(.subheadline)
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
                        VStack(spacing: 5) {
                            Text(viewModel.timeString)
                                .font(.system(size: 60, weight: .bold, design: .rounded))
                                .foregroundColor(.theme.text)
                                .monospacedDigit()
                            
                            if viewModel.isRunning {
                                Text("remaining")
                                    .font(.caption)
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
                .font(.system(size: 70))
                .foregroundColor(.green)
            
            Text("Great job!")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.theme.text)
            
            Text("You've completed your timer session")
                .font(.subheadline)
                .foregroundColor(.theme.subtext)
                .multilineTextAlignment(.center)
            
            Button {
                viewModel.completeCheckIn(for: challenge)
                dismiss()
            } label: {
                Text("Check In & Complete")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.theme.accent)
                    )
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
                    VStack {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 30))
                            .foregroundColor(.theme.subtext)
                        
                        Text("Reset")
                            .font(.caption)
                            .foregroundColor(.theme.subtext)
                    }
                }
            }
            
            // Start/Pause button
            Button {
                viewModel.isRunning ? viewModel.pauseTimer() : viewModel.startTimer()
            } label: {
                VStack {
                    ZStack {
                        Circle()
                            .fill(Color.theme.accent)
                            .frame(width: 70, height: 70)
                        
                        Image(systemName: viewModel.isRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                    }
                    
                    Text(viewModel.isRunning ? "Pause" : "Start")
                        .font(.caption)
                        .foregroundColor(.theme.text)
                }
            }
            
            // Skip button (only when timer is running, for demo purposes)
            if viewModel.isRunning && viewModel.enableDebugSkip {
                Button {
                    viewModel.completeTimer()
                } label: {
                    VStack {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.theme.subtext)
                        
                        Text("Skip")
                            .font(.caption)
                            .foregroundColor(.theme.subtext)
                    }
                }
            }
        }
    }
    
    private var durationPicker: some View {
        VStack(spacing: 15) {
            Text("Timer Duration")
                .font(.headline)
                .foregroundColor(.theme.text)
            
            HStack {
                ForEach([5, 10, 15, 25, 30, 45, 60], id: \.self) { minutes in
                    Button {
                        viewModel.timerDuration = TimeInterval(minutes * 60)
                    } label: {
                        Text("\(minutes)m")
                            .font(.system(.body, design: .rounded))
                            .fontWeight(viewModel.timerDuration == TimeInterval(minutes * 60) ? .bold : .regular)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(viewModel.timerDuration == TimeInterval(minutes * 60) ? 
                                         Color.theme.accent : Color.theme.surface)
                            )
                            .foregroundColor(viewModel.timerDuration == TimeInterval(minutes * 60) ? 
                                            .white : .theme.text)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.theme.surface.opacity(0.7))
        )
    }
}

// MARK: - ViewModel

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
    private let impact = UIImpactFeedbackGenerator(style: .medium)
    private let notification = UINotificationFeedbackGenerator()
    
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
        removeNotifications()
        timer?.invalidate()
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
        impact.impactOccurred()
        isRunning = true
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            let now = Date()
            self.elapsedTime = now.timeIntervalSince(self.startDate ?? now)
            self.updateProgress()
            
            if self.elapsedTime >= self.timerDuration {
                self.completeTimer()
            }
        }
    }
    
    func pauseTimer() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        impact.impactOccurred(intensity: 0.5)
    }
    
    func resetTimer() {
        timer?.invalidate()
        timer = nil
        elapsedTime = 0
        progress = 0
        isRunning = false
        impact.impactOccurred(intensity: 0.7)
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
        notification.notificationOccurred(.success)
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
    
    private func removeNotifications() {
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