import SwiftUI

// Using canonical Challenge model
// (No import needed as it will be accessed directly)

struct ChallengeCardView: View {
    @State var challenge: Challenge
    let onCheckIn: () -> Void
    let subscriptionService: SubscriptionService
    @State private var isCheckedIn = false
    @State private var isPerformingCheckIn = false
    
    @State private var isAnimating = false
    @State private var scale: CGFloat = 1.0
    
    init(challenge: Challenge, subscriptionService: SubscriptionService, onCheckIn: @escaping () -> Void) {
        _challenge = State(initialValue: challenge)
        self.subscriptionService = subscriptionService
        self.onCheckIn = onCheckIn
        _isCheckedIn = State(initialValue: challenge.isCompletedToday)
    }
    
    private func handleCheckIn() {
        // Prevent multiple tap handling
        if isPerformingCheckIn {
            return
        }
        
        isPerformingCheckIn = true
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            isAnimating = true
            scale = 0.95
        }
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Optimistically update UI immediately
        isCheckedIn = true
        
        // Update challenge locally immediately for better UX
        let updatedChallenge = challenge.afterCheckIn()
        self.challenge = updatedChallenge
        
        // Call the check-in action
        onCheckIn()
        
        // Reset animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                scale = 1.0
            }
            isPerformingCheckIn = false
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title and Streak
            HStack {
                Text(challenge.title)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.theme.text)
                
                Spacer()
                
                HStack(spacing: 6) {
                    Text(challenge.streakEmoji)
                        .font(.title3)
                    
                    Text("\(challenge.streakCount)")
                        .font(.system(size: 15, weight: .semibold))
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
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("days")
                            .font(.system(size: 10, weight: .medium))
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
                            .font(.caption)
                            .foregroundColor(.theme.subtext)
                        
                        Spacer()
                        
                        Text("\(Int(challenge.progressPercentage * 100))%")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.theme.accent)
                    }
                }
            }
            .padding(.top, 4)
            
            // Check-in Button
            if (!challenge.isCompletedToday && !isCheckedIn) && !challenge.isCompleted {
                Button(action: handleCheckIn) {
                    HStack {
                        Text("Check In")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
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
            } else if challenge.isCompleted {
                HStack {
                    Image(systemName: "trophy.fill")
                        .foregroundColor(.yellow)
                    
                    Text("Challenge Completed!")
                        .font(.system(size: 16, weight: .semibold))
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
                        .font(.system(size: 16, weight: .medium))
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
            
            // Streak warning if expired
            if challenge.hasStreakExpired && challenge.streakCount > 0 && !challenge.isCompleted {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 12))
                    
                    Text("Streak expired! Check in today to start a new streak.")
                        .font(.system(size: 12))
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
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.theme.surface)
                .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
        )
        .padding(.horizontal)
        .padding(.vertical, 8)
        .onAppear {
            // Ensure isCheckedIn matches challenge state on appear
            isCheckedIn = challenge.isCompletedToday
        }
        .onChange(of: challenge) { oldChallenge, newChallenge in
            // Update the isCheckedIn state when challenge changes
            isCheckedIn = newChallenge.isCompletedToday
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
                subscriptionService: SubscriptionService.shared,
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
                subscriptionService: SubscriptionService.shared,
                onCheckIn: {}
            )
            
            ChallengeCardView(
                challenge: Challenge(
                    title: "Completed Challenge", 
                    daysCompleted: 100,
                    ownerId: "test"
                ),
                subscriptionService: SubscriptionService.shared,
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
                subscriptionService: SubscriptionService.shared,
                onCheckIn: {}
            )
        }
    }
} 