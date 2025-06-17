import SwiftUI

struct DailySparkView: View {
    let currentStreak: Int
    let completionPercentage: Double
    @State private var rotationIndex = 0
    
    // Collection of motivational quotes
    private let quotes = [
        "Every day is a chance to be better than yesterday.",
        "Small steps lead to big changes over time.",
        "Consistency is the foundation of mastery.",
        "What you do every day matters more than what you do occasionally.",
        "Don't break the chain. Keep showing up.",
        "Progress is progress, no matter how small.",
        "The only bad workout is the one that didn't happen.",
        "Discipline is choosing between what you want now and what you want most.",
        "Success is the sum of small efforts repeated day-in and day-out.",
        "The expert in anything was once a beginner."
    ]
    
    // Messages based on progress state
    private var progressMessages: [String] {
        [
            "You're at \(Int(completionPercentage * 100))% completion - keep it up!",
            currentStreak > 0 ? "You've been consistent for \(currentStreak) days!" : "Start your streak today!",
            progressTip
        ]
    }
    
    private var progressTip: String {
        if completionPercentage < 0.25 {
            return "Focus on building a daily habit - even 5 minutes counts!"
        } else if completionPercentage < 0.5 {
            return "You're finding your rhythm - stay committed to your goal!"
        } else if completionPercentage < 0.75 {
            return "You're past halfway! Keep the momentum going."
        } else if completionPercentage < 1.0 {
            return "The finish line is in sight! Strong finish!"
        } else {
            return "Congrats on completing your challenge! What's next?"
        }
    }
    
    // Combined content for variety
    private var sparkContent: [String] {
        quotes + progressMessages
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 24))
                    .foregroundColor(.yellow)
                
                Spacer()
                
                // Refresh button
                Button {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        rotateContent()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 20))
                        .foregroundColor(.theme.accent.opacity(0.8))
                }
            }
            
            Text(sparkContent[rotationIndex])
                .font(.headline)
                .foregroundColor(.theme.text)
                .multilineTextAlignment(.center)
                .padding()
                .frame(maxWidth: .infinity)
                .id(rotationIndex) // Force view refresh on content change
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.theme.accent.opacity(0.1),
                            Color.theme.surface
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
        .onAppear {
            // Start with a random message
            rotationIndex = Int.random(in: 0..<sparkContent.count)
        }
    }
    
    private func rotateContent() {
        var newIndex: Int
        repeat {
            newIndex = Int.random(in: 0..<sparkContent.count)
        } while newIndex == rotationIndex && sparkContent.count > 1
        
        rotationIndex = newIndex
    }
}

// Replace #Preview with traditional PreviewProvider
struct DailySparkView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            DailySparkView(currentStreak: 7, completionPercentage: 0.35)
                .padding()
            
            DailySparkView(currentStreak: 0, completionPercentage: 0.0)
                .padding()
            
            DailySparkView(currentStreak: 21, completionPercentage: 0.75)
                .padding()
        }
        .background(Color.gray.opacity(0.1))
    }
} 