import SwiftUI

/// A reusable hero summary card that combines headline, metrics, and progress visualization
public struct HeroSummaryCard: View {
    // Main headline text
    let headline: String
    
    // Progress percentage (0.0 to 1.0)
    let progress: Double
    
    // Stats for the three metrics
    let streakCount: Int
    let completionPercentage: Double
    let challengeCount: Int
    
    // Optional accent color
    var accentColor: Color = .theme.accent
    
    public init(
        headline: String,
        progress: Double,
        streakCount: Int,
        completionPercentage: Double,
        challengeCount: Int,
        accentColor: Color = .theme.accent
    ) {
        self.headline = headline
        self.progress = min(max(0, progress), 1.0)
        self.streakCount = streakCount
        self.completionPercentage = min(max(0, completionPercentage), 1.0)
        self.challengeCount = challengeCount
        self.accentColor = accentColor
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            // Hero headline
            Text(headline)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundColor(.theme.text)
                .padding(.horizontal, AppSpacing.s)
                .multilineTextAlignment(.leading)
            
            // Stats in a horizontal layout
            HStack(spacing: AppSpacing.m) {
                // Streak with flame emoji
                VStack(alignment: .center, spacing: AppSpacing.xxs) {
                    HStack(spacing: 4) {
                        Text("🔥")
                            .font(.system(size: 18))
                        Text("\(streakCount)")
                            .font(.system(size: 22, weight: .medium, design: .rounded))
                            .foregroundColor(.theme.text)
                    }
                    Text("Current Streak")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.theme.subtext)
                }
                .frame(maxWidth: .infinity)
                
                // Percent complete
                VStack(alignment: .center, spacing: AppSpacing.xxs) {
                    Text("\(Int(completionPercentage * 100))%")
                        .font(.system(size: 22, weight: .medium, design: .rounded))
                        .foregroundColor(.theme.text)
                    Text("Complete")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.theme.subtext)
                }
                .frame(maxWidth: .infinity)
                
                // Active challenges
                VStack(alignment: .center, spacing: AppSpacing.xxs) {
                    Text("\(challengeCount)")
                        .font(.system(size: 22, weight: .medium, design: .rounded))
                        .foregroundColor(.theme.text)
                    Text("Challenges")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.theme.subtext)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, AppSpacing.s)
            
            // Radial ring progress chart - CalAI style
            ZStack {
                // Background ring
                Circle()
                    .stroke(lineWidth: AppSpacing.progressRingStrokeWidth)
                    .opacity(0.2)
                    .foregroundColor(accentColor)
                
                // Progress ring
                Circle()
                    .trim(from: 0.0, to: CGFloat(progress))
                    .stroke(style: StrokeStyle(lineWidth: AppSpacing.progressRingStrokeWidth, lineCap: .round, lineJoin: .round))
                    .foregroundColor(accentColor)
                    .rotationEffect(Angle(degrees: 270.0))
                    .animation(.easeInOut(duration: 1.0), value: progress)
                
                // Center content
                VStack(spacing: 0) {
                    Text("\(Int(completionPercentage * 100))%")
                        .font(.system(size: 24, weight: .medium, design: .rounded))
                        .foregroundColor(.theme.text)
                    
                    Text("complete")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.theme.subtext)
                }
            }
            .frame(width: 120, height: 120)
            .padding(.top, AppSpacing.s)
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                .fill(Color.theme.surface)
                .shadow(color: Color.theme.shadow.opacity(0.06), radius: 4, x: 0, y: 1)
        )
    }
}

// Preview for the HeroSummaryCard
struct HeroSummaryCard_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: AppSpacing.l) {
                HeroSummaryCard(
                    headline: "You've checked in 7 days in a row!",
                    progress: 0.42,
                    streakCount: 7,
                    completionPercentage: 0.42,
                    challengeCount: 3
                )
                
                HeroSummaryCard(
                    headline: "You're just getting started!",
                    progress: 0.05,
                    streakCount: 1,
                    completionPercentage: 0.05,
                    challengeCount: 1,
                    accentColor: .orange
                )
                
                HeroSummaryCard(
                    headline: "Impressive! Keep going!",
                    progress: 0.78,
                    streakCount: 35,
                    completionPercentage: 0.78,
                    challengeCount: 5,
                    accentColor: .green
                )
            }
            .padding()
        }
        .background(Color.theme.background)
        .preferredColorScheme(.dark)
    }
} 