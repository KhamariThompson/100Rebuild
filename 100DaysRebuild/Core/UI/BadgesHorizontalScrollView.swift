import SwiftUI

/// A reusable component to display badges in a horizontal scrolling view
struct BadgesHorizontalScrollView: View {
    // Array of badge models to display
    let badges: [ProgressBadge]
    
    // Callback when a badge is tapped
    var onBadgeTapped: ((ProgressBadge) -> Void)?
    
    // Whether to show locked badges in grayscale
    var showLockedBadges: Bool = true
    
    init(
        badges: [ProgressBadge],
        showLockedBadges: Bool = true,
        onBadgeTapped: ((ProgressBadge) -> Void)? = nil
    ) {
        self.badges = badges
        self.showLockedBadges = showLockedBadges
        self.onBadgeTapped = onBadgeTapped
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            Text("Milestones & Badges")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.theme.text)
            
            if badges.isEmpty && !showLockedBadges {
                Text("Complete challenges to earn badges!")
                    .foregroundColor(.theme.subtext)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, AppSpacing.l)
            } else {
                // Horizontal scrolling badge cards
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.m) {
                        ForEach(badges) { badge in
                            BadgeCard(badge: badge, isLocked: false)
                                .frame(width: 120, height: 150)
                                .onTapGesture {
                                    let generator = UIImpactFeedbackGenerator(style: .medium)
                                    generator.impactOccurred()
                                    onBadgeTapped?(badge)
                                }
                        }
                        
                        // Add locked badges if enabled
                        if showLockedBadges {
                            // Sample locked badges (these would normally come from a model)
                            let lockedBadges: [LockedBadge] = [
                                LockedBadge(id: 100, title: "30 Day Streak", iconName: "flame.fill", requirement: "Maintain a 30-day streak"),
                                LockedBadge(id: 101, title: "50% Complete", iconName: "chart.bar.fill", requirement: "Reach 50% completion"),
                                LockedBadge(id: 102, title: "Consistent", iconName: "calendar", requirement: "Check in 5 days in a row")
                            ]
                            
                            ForEach(lockedBadges) { lockedBadge in
                                LockedBadgeCard(badge: lockedBadge)
                                    .frame(width: 120, height: 150)
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.xs)
                    .padding(.vertical, AppSpacing.s)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                .fill(Color.theme.surface)
                .shadow(color: Color.theme.shadow.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
}

/// Standard badge card for earned badges
struct BadgeCard: View {
    let badge: ProgressBadge
    let isLocked: Bool
    @State private var animate = false
    
    var body: some View {
        VStack(spacing: AppSpacing.s) {
            // Badge icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.theme.accent,
                                Color.theme.accent.opacity(0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 70, height: 70)
                    .scaleEffect(animate ? 1.05 : 1.0)
                    .shadow(color: Color.theme.accent.opacity(0.3), radius: 8, x: 0, y: 4)
                
                Image(systemName: badge.iconName)
                    .font(.system(size: 32))
                    .foregroundColor(.white)
            }
            .padding(.bottom, AppSpacing.xxs)
            
            // Badge title
            Text(badge.title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.theme.text)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(height: 40)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                .fill(Color.theme.surface)
        )
        .onAppear {
            withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}

/// Locked badge card variation with grayscale and blur effect
struct LockedBadgeCard: View {
    let badge: LockedBadge
    
    var body: some View {
        VStack(spacing: AppSpacing.s) {
            // Badge icon with lock overlay
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 70, height: 70)
                
                Image(systemName: badge.iconName)
                    .font(.system(size: 32))
                    .foregroundColor(.gray.opacity(0.7))
                    .blur(radius: 1)
                
                Image(systemName: "lock.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(6)
                    .background(
                        Circle()
                            .fill(Color.theme.accent.opacity(0.8))
                    )
                    .offset(x: 20, y: 20)
            }
            .padding(.bottom, AppSpacing.xxs)
            
            // Badge title
            Text(badge.title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.theme.subtext)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(height: 40)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                .fill(Color.theme.surface)
        )
        .opacity(0.7)
    }
}

/// Model for locked badges
struct LockedBadge: Identifiable {
    let id: Int
    let title: String
    let iconName: String
    let requirement: String
}

// Preview for the BadgesHorizontalScrollView
struct BadgesHorizontalScrollView_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: AppSpacing.l) {
                // Sample with earned badges
                BadgesHorizontalScrollView(
                    badges: [
                        ProgressBadge(id: 1, title: "First Completion", iconName: "checkmark.circle.fill"),
                        ProgressBadge(id: 2, title: "7-Day Streak", iconName: "flame.fill")
                    ],
                    onBadgeTapped: { badge in
                        print("Tapped badge: \(badge.title)")
                    }
                )
                
                // Sample with no badges
                BadgesHorizontalScrollView(
                    badges: []
                )
            }
            .padding()
        }
        .background(Color.theme.background)
        .preferredColorScheme(.dark)
    }
} 