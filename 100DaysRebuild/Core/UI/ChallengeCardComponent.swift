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
    @State private var isCheckedIn = false
    @State private var showConfetti = false
    
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
        self._isCheckedIn = State(initialValue: challenge.isCompletedToday)
    }
    
    private func handleCheckIn() {
        // Prevent multiple tap handling
        if isPerformingCheckIn {
            return
        }
        
        isPerformingCheckIn = true
        
        // Animate the button
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            isPressed = true
            scale = 0.95
        }
        
        // Haptic feedback for better physical response
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Optimistically update UI immediately
        isCheckedIn = true
        showConfetti = true
        
        // Call the check-in action (which will show the check-in sheet)
        onCheckIn()
        
        // Animate checkmark completion
        confettiCounter += 1
        
        // Reset animation after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = false
                scale = 1.0
            }
            isPerformingCheckIn = false
            
            // Stop confetti after the animation duration
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                showConfetti = false
            }
        }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Challenge header section
            HStack(spacing: AppSpacing.s) {
                // Icon based on challenge title or default
                Image(systemName: getChallengeIcon(title: challenge.title))
                    .font(.system(size: AppSpacing.iconSizeMedium))
                    .foregroundColor(.theme.accent)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(Color.theme.accent.opacity(0.12))
                    )
                
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(challenge.title)
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundColor(.theme.text)
                        .lineLimit(1)
                    
                    // Countdown text
                    Text(getCountdownText())
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(.theme.subtext)
                }
                
                Spacer()
                
                // Tag showing challenge type with custom tint
                Text(getChallengeTag())
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(backgroundTint)
                    )
                    .padding(.trailing, 2)
            }
            .padding(.horizontal, AppSpacing.m)
            .padding(.top, AppSpacing.m)
            .padding(.bottom, AppSpacing.s)
            
            // Progress bar
            ChallengeProgressBar(progress: Double(challenge.daysCompleted) / 100.0)
                .padding(.horizontal, AppSpacing.m)
            
            // Check-in button or completed status
            checkInButton
                .padding(.horizontal, AppSpacing.m)
                .padding(.top, AppSpacing.s)
                .padding(.bottom, AppSpacing.m)
        }
        .background(
            RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                .fill(Color.theme.surface)
                .shadow(color: Color.theme.shadow.opacity(0.1), radius: 6, x: 0, y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                        .stroke(backgroundTint, lineWidth: 1)
                        .opacity(0.5)
                )
        )
        .overlay(
            ZStack {
                if showConfetti {
                    ConfettiView(intensity: 1.0, duration: 3.0)
                        .allowsHitTesting(false)
                        .id(confettiCounter) // Force view refresh on each check-in
                }
            }
        )
        .scaleEffect(scale)
        .onAppear {
            // Start subtle pulse animation for active challenges
            withAnimation(Animation.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                isAnimating = true
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
                // Challenge fully completed (100 days)
                HStack {
                    Image(systemName: "trophy")
                        .foregroundColor(.yellow)
                    
                    Text("Challenge Completed!")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.theme.text)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.yellow.opacity(0.1))
                )
                
            } else if challenge.isCompletedToday || isCheckedIn {
                // Today's check-in completed
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    
                    Text("Completed Today")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.green.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.green.opacity(0.1))
                )
                
            } else {
                // Needs check-in today
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
        } else if challenge.isCompletedToday || isCheckedIn {
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