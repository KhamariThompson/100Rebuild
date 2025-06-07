import SwiftUI

/// A reusable Challenge Card component with improved UI for the Challenges tab
public struct ChallengeCardComponent: View {
    // Challenge data
    let challenge: Challenge
    
    // Action to perform when "Check In" button is tapped
    let onCheckIn: () -> Void
    
    // State for animations and UI
    @State private var isAnimating = false
    @State private var scale: CGFloat = 1.0
    @State private var isPressed = false
    @State private var confettiCounter = 0
    @Environment(\.colorScheme) private var colorScheme
    
    // Display state
    @State private var isPerformingCheckIn = false
    @State private var showConfetti = false
    @State private var localHasStreakExpired: Bool = false
    
    // For cleanup
    @State private var notificationObserver: NSObjectProtocol?
    
    // Background tint based on challenge type
    private var backgroundTint: Color {
        // Generate a subtle background tint based on challenge title
        let hue = Double(abs(challenge.title.hashValue % 360)) / 360.0
        return Color(hue: hue, saturation: 0.1, brightness: 1.0)
    }
    
    // Changed from public to internal initializer since Challenge is an internal type
    init(challenge: Challenge, onCheckIn: @escaping () -> Void) {
        self.challenge = challenge
        self.onCheckIn = onCheckIn
        self._localHasStreakExpired = State(initialValue: challenge.hasStreakExpired)
    }
    
    private func handleCheckIn() {
        // Mark as performing check-in to prevent multiple taps
        isPerformingCheckIn = true
        
        // Show success animation immediately
        showConfetti = true
        confettiCounter += 1 // Force refresh
        
        // Call the provided check-in handler
        onCheckIn()
        
        // Reset the check-in state after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isPerformingCheckIn = false
            // Make sure we update our local state to reflect changes
            updateLocalExpiredStatus()
        }
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Challenge title with icon
            HStack(alignment: .center, spacing: 12) {
                // Challenge icon
                Image(systemName: getChallengeIcon(title: challenge.title))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.theme.accent)
                    .clipShape(Circle())
                
                // Challenge title
                Text(challenge.title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.theme.text)
                    .lineLimit(1)
                
                Spacer()
                
                // Streak counter - animated conditionally
                HStack(spacing: 4) {
                    Text(challenge.streakEmoji)
                        .font(.system(size: 15))
                        .opacity(1.0)
                        .scaleEffect(isAnimating ? 1.1 : 1.0)
                        .animation(Animation.spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0).repeatCount(3, autoreverses: true), value: isAnimating)
                    
                    Text("\(challenge.streakCount)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.theme.subtext)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.theme.surface)
                        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                )
                .opacity(localHasStreakExpired ? 0.8 : 1.0)
            }
            
            // Progress info
            VStack(spacing: 8) {
                // Progress bar
                ChallengeProgressBar(progress: challenge.progressPercentage)
                
                // Days and countdown info
                HStack {
                    // Show day counter
                    Text(getCountdownText())
                        .font(.system(size: 13))
                        .foregroundColor(.theme.subtext)
                    
                    Spacer()
                    
                    // Show streak expire warning
                    if localHasStreakExpired && challenge.streakCount > 0 && !challenge.isCompletedToday && !challenge.isCompleted && challenge.lastCheckInDate != nil {
                        HStack(spacing: 3) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.orange)
                            
                            Text("Streak expired")
                                .font(.system(size: 12))
                                .foregroundColor(.orange)
                        }
                    } else if challenge.streakCount > 0 && !challenge.isCompletedToday && !challenge.isCompleted {
                        // Show deadline info for active challenges with streaks
                        Text("Keep your streak alive")
                            .font(.system(size: 12))
                            .foregroundColor(.theme.subtext)
                    }
                }
            }
            
            // Action Button based on state
            checkInButton
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.theme.surface)
                .shadow(color: Color.theme.shadow.opacity(0.1), radius: 2, x: 0, y: 2)
        )
        .onAppear {
            updateLocalExpiredStatus()
            
            // Avoid capturing self strongly in notification handler by using a separate function
            setupNotificationObserver()
            
            // Force a refresh of local state when view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.updateLocalExpiredStatus()
            }
        }
        // Update local state when challenge changes
        .onChange(of: challenge) { newChallenge in
            updateLocalExpiredStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: ChallengeStore.challengesDidUpdateNotification)) { notification in
            // Check if this notification is specifically for this challenge
            if let restartedChallengeId = notification.userInfo?["restartedChallengeId"] as? UUID,
               restartedChallengeId == challenge.id {
                print("📱 Explicit onReceive handler triggered for restart of challenge: \(challenge.id)")
                // Force update on next run loop
                DispatchQueue.main.async {
                    self.updateLocalExpiredStatus()
                }
            }
        }
        .onDisappear {
            // Remove observer when view disappears
            if let observer = notificationObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
    
    // Setup the notification observer without capturing self strongly
    private func setupNotificationObserver() {
        // Store the challenge ID in a local variable to avoid capturing self
        let challengeId = challenge.id
        
        notificationObserver = NotificationCenter.default.addObserver(
            forName: ChallengeStore.challengesDidUpdateNotification,
            object: nil,
            queue: .main
        ) { notification in
            // Check if this notification is specifically for this challenge
            if let restartedChallengeId = notification.userInfo?["restartedChallengeId"] as? UUID,
               restartedChallengeId == challengeId {
                print("📱 ChallengeCardComponent received specific update for challenge: \(challengeId)")
                // Immediately force an update with a slight delay to ensure data is refreshed
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.updateLocalExpiredStatus()
                }
            } else if let refreshedChallengeId = notification.userInfo?["refreshedChallengeId"] as? UUID,
                      refreshedChallengeId == challengeId {
                print("📱 ChallengeCardComponent received refresh notification for challenge: \(challengeId)")
                // Immediately force an update
                self.updateLocalExpiredStatus()
            } else if notification.userInfo == nil || notification.userInfo?.isEmpty == true {
                // General update - still update
                self.updateLocalExpiredStatus()
            }
        }
    }
    
    // Get a tag for the challenge type
    private func getChallengeTag() -> String {
        if challenge.isTimed {
            return "Timed"
        } else {
            let lowercaseTitle = challenge.title.lowercased()
            if lowercaseTitle.contains("workout") || lowercaseTitle.contains("exercise") {
                return "Fitness"
            } else if lowercaseTitle.contains("read") || lowercaseTitle.contains("book") {
                return "Reading"
            } else if lowercaseTitle.contains("meditat") {
                return "Wellness"
            } else if lowercaseTitle.contains("code") || lowercaseTitle.contains("program") {
                return "Coding"
            } else {
                return "Daily"
            }
        }
    }
    
    // Dynamic check-in button
    private var checkInButton: some View {
        Group {
            if challenge.isCompleted {
                // Challenge is complete
                HStack {
                    Image(systemName: "trophy.fill")
                        .foregroundColor(.yellow)
                    
                    Text("Challenge Completed!")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.theme.text)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colorScheme == .dark ? Color.yellow.opacity(0.15) : Color.yellow.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                        )
                )
            } else if challenge.isCompletedToday {
                // Completed today
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    
                    Text("Completed Today")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.theme.text)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colorScheme == .dark ? Color.green.opacity(0.15) : Color.green.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.green.opacity(0.3), lineWidth: 1)
                        )
                )
            } else if localHasStreakExpired && challenge.lastCheckInDate != nil && challenge.streakCount > 0 {
                // Streak has expired - only show for challenges with history (non-new challenges)
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    
                    Text("Streak Expired")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.theme.text)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colorScheme == .dark ? Color.orange.opacity(0.15) : Color.orange.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                        )
                )
            } else {
                // Needs check-in today (includes new challenges or restarted challenges)
                Button(action: handleCheckIn) {
                    HStack {
                        Text("Mark Complete ✅")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(colorScheme == .dark ? .black : .white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.theme.accent)
                            .shadow(color: Color.theme.accent.opacity(0.15), radius: 3, x: 0, y: 1)
                    )
                }
                .buttonStyle(AppScaleButtonStyle())
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // Prevent tap from propagating to parent view
            if !challenge.isCompleted && !challenge.isCompletedToday && 
               !(localHasStreakExpired && challenge.lastCheckInDate != nil && challenge.streakCount > 0) {
                handleCheckIn()
            }
        }
    }
    
    private func updateLocalExpiredStatus() {
        // Update the local state to ensure the UI updates correctly
        let isExpired = challenge.hasStreakExpired
        
        // Force a UI update by reassigning the state property regardless of whether it changed
        // This ensures the UI refreshes when a challenge is restarted
        DispatchQueue.main.async {
            self.localHasStreakExpired = isExpired
        }
        
        print("📊 Updated localHasStreakExpired to \(isExpired) for challenge \(challenge.id)")
    }
}

/// A simple progress bar view to display challenge progress
struct ChallengeProgressBar: View {
    let progress: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background bar
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.theme.border.opacity(0.3))
                    .frame(height: 4)
                
                // Progress bar
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.theme.accent)
                    .frame(width: geometry.size.width * CGFloat(progress), height: 4)
            }
        }
        .frame(height: 4)
    }
}

// Helper to get an icon based on challenge title - public for testing
func getChallengeIcon(title: String) -> String {
    let lowercaseTitle = title.lowercased()
    
    if lowercaseTitle.contains("workout") || lowercaseTitle.contains("exercise") || lowercaseTitle.contains("gym") {
        return "figure.walk"
    } else if lowercaseTitle.contains("read") || lowercaseTitle.contains("book") {
        return "book"
    } else if lowercaseTitle.contains("meditat") {
        return "brain.head.profile"
    } else if lowercaseTitle.contains("journal") || lowercaseTitle.contains("writ") {
        return "pencil"
    } else if lowercaseTitle.contains("water") || lowercaseTitle.contains("drink") {
        return "drop"
    } else if lowercaseTitle.contains("diet") || lowercaseTitle.contains("eat") || lowercaseTitle.contains("food") {
        return "fork.knife"
    } else if lowercaseTitle.contains("sleep") {
        return "bed.double"
    } else if lowercaseTitle.contains("language") || lowercaseTitle.contains("speak") {
        return "text.bubble"
    } else if lowercaseTitle.contains("draw") || lowercaseTitle.contains("art") {
        return "paintbrush"
    } else if lowercaseTitle.contains("picture") || lowercaseTitle.contains("photo") {
        return "camera"
    } else if lowercaseTitle.contains("code") || lowercaseTitle.contains("program") {
        return "chevron.left.forwardslash.chevron.right"
    } else if lowercaseTitle.contains("clean") || lowercaseTitle.contains("tidy") {
        return "house"
    } else {
        return "flag"
    }
}

// Helper to get countdown text for challenge progress display
extension ChallengeCardComponent {
    func getCountdownText() -> String {
        if challenge.isCompleted {
            return "Completed all 100 days! 🎉"
        } else if challenge.isCompletedToday {
            return "Day \(challenge.daysCompleted) of 100 complete"
        } else {
            return "Day \(challenge.daysCompleted + 1) of 100"
        }
    }
}

// Preview for the component
struct ChallengeCardComponent_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Regular challenge
            ChallengeCardComponent(
                challenge: Challenge.mockActive(
                    title: "Read 10 pages",
                    daysCompleted: 25,
                    streakCount: 3
                ),
                onCheckIn: {}
            )
            
            // Completed today challenge
            ChallengeCardComponent(
                challenge: Challenge.mockCompletedToday(
                    title: "Code every day",
                    daysCompleted: 42,
                    streakCount: 7
                ),
                onCheckIn: {}
            )
            
            // Completed challenge
            ChallengeCardComponent(
                challenge: Challenge.mockCompleted(
                    title: "Meditate for 10 minutes",
                    daysCompleted: 100,
                    streakCount: 0
                ),
                onCheckIn: {}
            )
        }
        .padding()
        .background(Color.theme.background)
        .previewLayout(.sizeThatFits)
    }
}

// MARK: - Mock Extension for Preview
private extension Challenge {
    // Convenience initializer for active challenge
    static func mockActive(title: String, daysCompleted: Int, streakCount: Int) -> Challenge {
        Challenge(
            id: UUID(),
            title: title,
            startDate: Date().addingTimeInterval(-Double(daysCompleted) * 86400),
            lastCheckInDate: Date().addingTimeInterval(-86400), // Yesterday
            streakCount: streakCount,
            daysCompleted: daysCompleted,
            isCompletedToday: false,
            isArchived: false,
            ownerId: "preview-user", // Added ownerId parameter
            lastModified: Date(),
            isTimed: false
        )
    }
    
    // Convenience initializer for challenge completed today
    static func mockCompletedToday(title: String, daysCompleted: Int, streakCount: Int) -> Challenge {
        Challenge(
            id: UUID(),
            title: title,
            startDate: Date().addingTimeInterval(-Double(daysCompleted) * 86400),
            lastCheckInDate: Date(), // Today
            streakCount: streakCount,
            daysCompleted: daysCompleted,
            isCompletedToday: true,
            isArchived: false,
            ownerId: "preview-user", // Added ownerId parameter
            lastModified: Date(),
            isTimed: false
        )
    }
    
    // Convenience initializer for completed challenge
    static func mockCompleted(title: String, daysCompleted: Int, streakCount: Int) -> Challenge {
        Challenge(
            id: UUID(),
            title: title,
            startDate: Date().addingTimeInterval(-100 * 86400),
            lastCheckInDate: Date(),
            streakCount: streakCount,
            daysCompleted: 100, // Completed
            isCompletedToday: true,
            isArchived: false,
            ownerId: "preview-user", // Added ownerId parameter
            lastModified: Date(),
            isTimed: false
        )
    }
} 