import SwiftUI

struct UsernameDisplayView: View {
    let username: String
    @State private var animateCheckmark = false
    @State private var showConfetti = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Your username is ")
                    .foregroundColor(Color.theme.text) +
                Text("@\(username)")
                    .foregroundColor(Color.theme.accent)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Color.theme.success)
                    .font(.title2)
                    .scaleEffect(animateCheckmark ? 1.2 : 1.0)
                    .opacity(animateCheckmark ? 1.0 : 0.7)
            }
            
            Text("You'll use this to connect with friends, join challenges, and appear on future leaderboards. Your display name is used separately for personalized greetings.")
                .font(.subheadline)
                .foregroundColor(Color.theme.subtext)
                .lineSpacing(4)
        }
        .onAppear {
            // Animate the checkmark when view appears
            withAnimation(Animation.spring(response: 0.3, dampingFraction: 0.6).delay(0.2)) {
                animateCheckmark = true
            }
            
            // Reset the animation after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation {
                    animateCheckmark = false
                }
            }
        }
    }
}

#Preview {
    UsernameDisplayView(username: "johndoe")
        .padding()
        .previewLayout(.sizeThatFits)
} 