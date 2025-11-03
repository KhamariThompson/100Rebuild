import SwiftUI

// Using canonical Challenge model
// (No import needed as it will be accessed directly)

struct ChallengeCardView: View {
    @State var challenge: Challenge
    let onCheckIn: () -> Void
    // Removed: let subscriptionService: SubscriptionService (no longer needed in this view)
    @State private var isCheckedIn = false
    @State private var isPerformingCheckIn = false

    @State private var isAnimating = false
    @State private var scale: CGFloat = 1.0

    init(challenge: Challenge, onCheckIn: @escaping () -> Void) {
        _challenge = State(initialValue: challenge)
        self.onCheckIn = onCheckIn
        _isCheckedIn = State(initialValue: challenge.isCompletedToday)
    }
    
    private func handleCheckIn() {
        // Prevent multiple tap handling
        if isPerformingCheckIn {
            return
        }
        
        isPerformingCheckIn = true
        
        // Haptic feedback - lightweight and immediate
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Optimistically update UI immediately
        isCheckedIn = true
        
        // Update challenge locally immediately for better UX
        let updatedChallenge = challenge.afterCheckIn()
        self.challenge = updatedChallenge
        
        // Call the check-in action immediately - this will trigger the sheet
        onCheckIn()
        
        // Reset state after a very short delay
        DispatchQueue.main.async {
            self.isPerformingCheckIn = false
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Define common conditional variables at the top
            let isNewChallenge = challenge.lastCheckInDate == nil && challenge.streakCount == 0
            let isExpiredWithHistory = challenge.hasStreakExpired && challenge.lastCheckInDate != nil
            let hasStreak = challenge.streakCount > 0
            
            // Title and Streak
            HStack {
                Text(challenge.title)
                    .font(AppTypography.font(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.theme.text)
                
                Spacer()
                
                HStack(spacing: 6) {
                    Text(challenge.streakEmoji)
                        .font(AppTypography.title3())
                    
                    Text("\(challenge.streakCount)")
                        .font(AppTypography.subhead(.semibold))
                        .foregroundColor(.theme.subtext)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.theme.surface)
                        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                )
                .opacity(challenge.hasStreakExpired ? 0.6 : 1.0)
            }
            
            // Day Counter and Progress
            HStack(alignment: .center, spacing: 12) {
                // Day counter in circle
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.theme.accent, Color.theme.accent.opacity(0.8)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                        .shadow(color: Color.theme.accent.opacity(0.3), radius: 4, x: 0, y: 2)
                    
                    VStack(spacing: 0) {
                        Text("\(challenge.daysCompleted)")
                            .font(AppTypography.title3(.bold))
                            .foregroundColor(.white)
                        
                        Text("days")
                            .font(AppTypography.caption2(.medium))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    // Progress Bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .foregroundColor(Color.theme.surface)
                                .frame(height: 8)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .foregroundColor(Color.theme.accent)
                                .frame(width: max(0, min(geometry.size.width, geometry.size.width * CGFloat(challenge.progressPercentage))), height: 8)
                        }
                    }
                    .frame(height: 8)
                    
                    // Days Remaining and Percentage
                    HStack {
                        Text("\(challenge.daysRemaining) days remaining")
                            .font(AppTypography.caption1())
                            .foregroundColor(.theme.subtext)
                        
                        Spacer()
                        
                        Text("\(Int(challenge.progressPercentage * 100))%")
                            .font(AppTypography.caption1(.semibold))
                            .foregroundColor(.theme.accent)
                    }
                }
            }
            .padding(.top, 4)
            
            // Check-in button or status
            if (!challenge.isCompletedToday && !isCheckedIn) && !challenge.isCompleted {
                // Special cases:
                // 1. New or restarted challenges: lastCheckInDate is nil AND streakCount is 0
                // 2. Expired streaks with previous check-ins: hasStreakExpired is true AND lastCheckInDate is not nil
                if isExpiredWithHistory && !isNewChallenge {
                    // Show warning for expired streak (only for non-new challenges with history)
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        
                        Text("Streak Expired")
                            .font(AppTypography.body(.medium))
                            .foregroundColor(.theme.text)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.orange.opacity(0.2), Color.orange.opacity(0.1)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    )
                } else {
                    // Show check-in button for new challenges, restarted challenges, or active streaks
                    Button(action: handleCheckIn) {
                        HStack {
                            Text("Check In")
                                .font(AppTypography.headline(.semibold))
                                .foregroundColor(.white)
                            
                            Image(systemName: "checkmark.circle.fill")
                                .font(AppTypography.subhead())
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.theme.accent, Color.theme.accent.opacity(0.8)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .shadow(color: Color.theme.accent.opacity(0.3), radius: 8, x: 0, y: 4)
                        )
                    }
                    .buttonStyle(AppScaleButtonStyle())
                    .disabled(isPerformingCheckIn)
                }
            } else if challenge.isCompleted {
                HStack {
                    Image(systemName: "trophy.fill")
                        .foregroundColor(.yellow)
                    
                    Text("Challenge Completed!")
                        .font(AppTypography.headline(.semibold))
                        .foregroundColor(.theme.text)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.yellow.opacity(0.2), Color.yellow.opacity(0.1)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                )
            } else {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    
                    Text("Completed Today")
                        .font(AppTypography.body(.medium))
                        .foregroundColor(.theme.text)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.green.opacity(0.15), Color.green.opacity(0.05)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                )
            }
            
            // Streak warning if expired - only show for challenges with actual history
            if isExpiredWithHistory && hasStreak && !challenge.isCompleted {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(AppTypography.caption1())
                    
                    Text("Streak expired! Check in today to start a new streak.")
                        .font(AppTypography.caption1())
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.orange.opacity(0.1))
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.theme.surface)
                .shadow(color: Color.theme.shadow.opacity(0.1), radius: 2, x: 0, y: 1)
                .shadow(color: Color.theme.shadow.opacity(0.05), radius: 10, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.theme.accent.opacity(0.3),
                            Color.theme.accent.opacity(0.05)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .scaleEffect(scale)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: scale)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .onAppear {
            // Ensure isCheckedIn matches challenge state on appear
            isCheckedIn = challenge.isCompletedToday
        }
        .onChange(of: challenge) { newChallenge in
            // Update the isCheckedIn state when challenge changes
            isCheckedIn = newChallenge.isCompletedToday
        }
        // Use onReceive to listen for notifications in a SwiftUI-friendly way
        .onReceive(NotificationCenter.default.publisher(for: ChallengeStore.challengesDidUpdateNotification)) { notification in
            // Check if this is a restart notification for this specific challenge
            if let restartedId = notification.userInfo?["restartedChallengeId"] as? UUID,
               restartedId == challenge.id {
                // Force refresh this view with the latest challenge data
                print("🔔 ChallengeCardView received restart notification for challenge: \(restartedId)")
                
                // Get the latest version of the challenge from the store
                if let updatedChallenge = ChallengeStore.shared.getChallenge(id: restartedId) {
                    // Update the local state with the latest challenge data
                    updateChallenge(updatedChallenge)
                }
            }
        }
    }
    
    // Helper method to update challenge with new data
    func updateChallenge(_ newChallenge: Challenge) {
        self.challenge = newChallenge
        self.isCheckedIn = newChallenge.isCompletedToday
    }
}

struct ChallengeCardView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            ChallengeCardView(
                challenge: Challenge(title: "Test Challenge", ownerId: "test"),
                onCheckIn: {}
            )

            ChallengeCardView(
                challenge: Challenge(
                    title: "Completed Today",
                    lastCheckInDate: Date(),
                    daysCompleted: 50,
                    isCompletedToday: true,
                    ownerId: "test"
                ),
                onCheckIn: {}
            )

            ChallengeCardView(
                challenge: Challenge(
                    title: "Completed Challenge",
                    daysCompleted: 100,
                    ownerId: "test"
                ),
                onCheckIn: {}
            )

            ChallengeCardView(
                challenge: Challenge(
                    title: "Expired Streak",
                    lastCheckInDate: Calendar.current.date(byAdding: .day, value: -3, to: Date())!,
                    streakCount: 5,
                    daysCompleted: 25,
                    ownerId: "test"
                ),
                onCheckIn: {}
            )
        }
    }
} 