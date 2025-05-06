import SwiftUI

struct ChallengeCardView: View {
    let challenge: Challenge
    let onCheckIn: () -> Void
    
    @State private var isAnimating = false
    @State private var scale: CGFloat = 1.0
    @EnvironmentObject var subscriptionService: SubscriptionService
    
    private func handleCheckIn() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            isAnimating = true
            scale = 0.95
        }
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        onCheckIn()
        
        // Reset animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                scale = 1.0
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title and Streak
            HStack {
                Text(challenge.title)
                    .font(.headline)
                    .foregroundColor(.theme.text)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text(challenge.streakEmoji)
                        .font(.title2)
                    
                    Text("\(challenge.streakCount)")
                        .font(.subheadline)
                        .foregroundColor(.theme.subtext)
                }
            }
            
            // Day Counter
            Text("Day \(challenge.daysCompleted) of 100")
                .font(.subheadline)
                .foregroundColor(.theme.subtext)
            
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .foregroundColor(Color.theme.surface)
                        .frame(height: 6)
                        .cornerRadius(3)
                    
                    Rectangle()
                        .foregroundColor(Color.theme.accent)
                        .frame(width: max(0, min(geometry.size.width, geometry.size.width * CGFloat(challenge.progressPercentage))), height: 6)
                        .cornerRadius(3)
                }
            }
            .frame(height: 6)
            .padding(.vertical, 8)
            
            // Days Remaining
            Text("\(challenge.daysRemaining) days remaining")
                .font(.caption)
                .foregroundColor(.theme.subtext)
            
            // Check-in Button
            if !challenge.isCompletedToday && !challenge.isCompleted {
                Button(action: handleCheckIn) {
                    Text("Check In")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.theme.accent)
                                .shadow(color: Color.theme.accent.opacity(0.3), radius: 8, x: 0, y: 4)
                        )
                }
                .scaleEffect(scale)
            } else if challenge.isCompleted {
                HStack {
                    Image(systemName: "trophy.fill")
                        .foregroundColor(.theme.accent)
                    
                    Text("Challenge Completed!")
                        .font(.subheadline)
                        .foregroundColor(.theme.text)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.theme.surface)
                )
            } else {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.theme.accent)
                    
                    Text("Completed Today")
                        .font(.subheadline)
                        .foregroundColor(.theme.subtext)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.theme.surface)
                )
            }
        }
        .padding()
        .background(Color.theme.surface)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

struct ChallengeCardView_Previews: PreviewProvider {
    static var previews: some View {
        ChallengeCardView(
            challenge: Challenge(title: "Test Challenge", ownerId: "test"),
            onCheckIn: {}
        )
        .environmentObject(SubscriptionService.shared)
    }
} 