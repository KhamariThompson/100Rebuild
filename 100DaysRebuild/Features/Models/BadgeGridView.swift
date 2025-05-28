import SwiftUI

/// A reusable grid view for displaying badges with adaptive layout
struct BadgeGridView: View {
    let badges: [Badge]
    let columns: Int
    let showLocked: Bool
    let onTap: (Badge) -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    init(
        badges: [Badge],
        columns: Int = 3,
        showLocked: Bool = true,
        onTap: @escaping (Badge) -> Void
    ) {
        self.badges = badges
        self.columns = columns
        self.showLocked = showLocked
        self.onTap = onTap
    }
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columns), spacing: 12) {
            ForEach(filteredBadges) { badge in
                BadgeItemView(badge: badge, onTap: onTap)
            }
        }
        .padding(.vertical, 8)
    }
    
    private var filteredBadges: [Badge] {
        if showLocked {
            return badges
        } else {
            return badges.filter { $0.isUnlocked }
        }
    }
}

/// Individual badge item with unlock status
struct BadgeItemView: View {
    let badge: Badge
    let onTap: (Badge) -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: { onTap(badge) }) {
            VStack(spacing: 8) {
                // Badge icon with conditional styling
                ZStack {
                    // Background circle
                    Circle()
                        .fill(badge.isUnlocked
                              ? badge.category.color.opacity(0.15)
                              : Color.gray.opacity(0.1))
                        .frame(width: 60, height: 60)
                    
                    // Border
                    Circle()
                        .strokeBorder(badge.isUnlocked
                                     ? badge.category.color.opacity(0.3)
                                     : Color.gray.opacity(0.2),
                                     lineWidth: 1.5)
                        .frame(width: 60, height: 60)
                    
                    // Icon
                    Image(systemName: badge.iconName)
                        .font(.system(size: 24))
                        .foregroundColor(badge.isUnlocked
                                        ? badge.category.color
                                        : Color.gray.opacity(0.5))
                    
                    // Locked overlay
                    if !badge.isUnlocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Color.gray.opacity(0.7))
                            .background(
                                Circle()
                                    .fill(Color.theme.surface)
                                    .frame(width: 20, height: 20)
                            )
                            .offset(x: 18, y: 18)
                    }
                    
                    // Progress ring
                    if !badge.isUnlocked && badge.progressPercentage > 0 {
                        Circle()
                            .trim(from: 0, to: badge.progressPercentage)
                            .stroke(badge.category.color.opacity(0.5), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 58, height: 58)
                    }
                    
                    // Glow effect for recently unlocked badges
                    if badge.isUnlocked, let timestamp = badge.unlockedAt,
                       Date().timeIntervalSince(timestamp.dateValue()) < 86400 { // 24 hours
                        Circle()
                            .fill(badge.category.color.opacity(0.3))
                            .frame(width: 70, height: 70)
                            .blur(radius: 10)
                            .opacity(0.7)
                            .zIndex(-1)
                    }
                }
                .shadow(color: badge.isUnlocked ? badge.category.color.opacity(0.3) : Color.clear, radius: 4, x: 0, y: 2)
                
                // Badge name
                Text(badge.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(badge.isUnlocked ? Color.theme.text : Color.theme.subtext.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(height: 28)
            }
            .frame(minWidth: 70, minHeight: 90)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .tooltip(getTooltipMessage(for: badge))
    }
    
    private func getTooltipMessage(for badge: Badge) -> String {
        if badge.isUnlocked {
            return "\(badge.description)\nUnlocked: \(formattedDate(badge.unlockedAt?.dateValue()))"
        } else {
            return "\(badge.description)\nProgress: \(badge.currentProgress)/\(badge.requiredValue)"
        }
    }
    
    private func formattedDate(_ date: Date?) -> String {
        guard let date = date else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

/// Badge detail view shown when a badge is tapped
struct BadgeDetailView: View {
    let badge: Badge
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            // Title
            Text(badge.name)
                .font(.title2)
                .bold()
                .foregroundColor(.theme.text)
            
            // Badge icon
            ZStack {
                // Background circle
                Circle()
                    .fill(badge.category.color.opacity(0.15))
                    .frame(width: 120, height: 120)
                
                // Border
                Circle()
                    .strokeBorder(badge.category.color.opacity(0.3), lineWidth: 2)
                    .frame(width: 120, height: 120)
                
                // Icon
                Image(systemName: badge.iconName)
                    .font(.system(size: 60))
                    .foregroundColor(badge.category.color)
                    .symbolEffect(.pulse, options: .repeating, isActive: badge.isUnlocked)
            }
            .shadow(color: badge.category.color.opacity(0.3), radius: 10, x: 0, y: 5)
            
            // Badge details
            VStack(spacing: 16) {
                // Description
                Text(badge.description)
                    .font(.body)
                    .foregroundColor(.theme.text)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Category
                HStack {
                    Image(systemName: badge.category.icon)
                        .foregroundColor(badge.category.color)
                    
                    Text(badge.category.rawValue)
                        .font(.subheadline)
                        .foregroundColor(.theme.subtext)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(
                    Capsule()
                        .fill(badge.category.color.opacity(0.1))
                )
                
                // Unlock status
                if badge.isUnlocked {
                    VStack(spacing: 6) {
                        Text("Unlocked")
                            .font(.headline)
                            .foregroundColor(.green)
                        
                        if let unlockDate = badge.unlockedAt?.dateValue() {
                            Text(formattedDate(unlockDate))
                                .font(.subheadline)
                                .foregroundColor(.theme.subtext)
                        }
                    }
                } else {
                    VStack(spacing: 6) {
                        Text("Progress")
                            .font(.headline)
                            .foregroundColor(.theme.accent)
                        
                        Text("\(badge.currentProgress) / \(badge.requiredValue)")
                            .font(.subheadline)
                            .foregroundColor(.theme.subtext)
                        
                        // Progress bar
                        BadgeProgressBar(value: badge.progressPercentage)
                            .frame(width: 200, height: 8)
                            .padding(.top, 4)
                    }
                }
                
                // Reward if any
                if badge.reward.type != .none {
                    VStack(spacing: 4) {
                        Text("Reward")
                            .font(.headline)
                            .foregroundColor(.yellow)
                        
                        Text(badge.reward.description)
                            .font(.subheadline)
                            .foregroundColor(.theme.subtext)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.yellow.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color.yellow.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
            }
            .padding()
            
            Spacer()
            
            // Share button
            if badge.isUnlocked {
                Button(action: {
                    // Share functionality would go here
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share this Achievement")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 24)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.theme.accent)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.bottom)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.theme.background.ignoresSafeArea())
        .navigationBarItems(leading: Button(action: { dismiss() }) {
            Image(systemName: "xmark.circle.fill")
                .font(.title3)
                .foregroundColor(.theme.subtext)
        })
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

/// Simple progress bar component
struct BadgeProgressBar: View {
    let value: Double
    let backgroundColor: Color
    let foregroundColor: Color
    
    init(
        value: Double,
        backgroundColor: Color = Color.gray.opacity(0.2),
        foregroundColor: Color = Color.theme.accent
    ) {
        self.value = min(max(value, 0.0), 1.0)
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 10)
                    .fill(backgroundColor)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                
                // Foreground
                RoundedRectangle(cornerRadius: 10)
                    .fill(foregroundColor)
                    .frame(width: geometry.size.width * value, height: geometry.size.height)
            }
        }
    }
}

// MARK: - Preview
struct BadgeGridView_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack {
                BadgeGridView(
                    badges: [
                        BadgeConfig.dayOneWarrior,
                        BadgeConfig.fiveDaySpark,
                        BadgeConfig.firestarter,
                        BadgeConfig.momentumMachine,
                        BadgeConfig.unstoppable,
                        BadgeConfig.hundredClub
                    ],
                    onTap: { _ in }
                )
            }
            .padding()
        }
        .background(Color.theme.background)
        .previewLayout(.sizeThatFits)
        .preferredColorScheme(.dark)
    }
} 