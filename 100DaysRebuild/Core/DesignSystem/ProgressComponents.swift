import SwiftUI

/// Specialized components for displaying progress information
public enum ProgressComponents {
    
    /// A circular progress indicator with customizable appearance
    public struct CircularProgress: View {
        let progress: Double
        let size: CGFloat
        let lineWidth: CGFloat
        let backgroundColor: Color
        let foregroundColor: Color
        let showLabel: Bool
        
        public init(
            progress: Double,
            size: CGFloat = 60,
            lineWidth: CGFloat = 8,
            backgroundColor: Color = Color.theme.border.opacity(0.3),
            foregroundColor: Color = Color.theme.accent,
            showLabel: Bool = false
        ) {
            self.progress = max(0, min(1, progress))
            self.size = size
            self.lineWidth = lineWidth
            self.backgroundColor = backgroundColor
            self.foregroundColor = foregroundColor
            self.showLabel = showLabel
        }
        
        public var body: some View {
            ZStack {
                // Background circle
                Circle()
                    .stroke(backgroundColor, lineWidth: lineWidth)
                
                // Progress circle
                Circle()
                    .trim(from: 0, to: CGFloat(progress))
                    .stroke(
                        foregroundColor,
                        style: StrokeStyle(
                            lineWidth: lineWidth,
                            lineCap: .round
                        )
                    )
                    .rotationEffect(.degrees(-90))
                
                // Optional percentage label
                if showLabel {
                    Text("\(Int(progress * 100))%")
                        .font(AppTypography.caption1())
                        .bold()
                        .foregroundColor(foregroundColor)
                }
            }
            .frame(width: size, height: size)
        }
    }
    
    /// A detailed progress view showing a stat with title and subtitles
    public struct DetailedProgress: View {
        let title: String
        let value: String
        let subtitle: String?
        let progress: Double
        let color: Color
        
        public init(
            title: String,
            value: String,
            subtitle: String? = nil,
            progress: Double,
            color: Color = Color.theme.accent
        ) {
            self.title = title
            self.value = value
            self.subtitle = subtitle
            self.progress = progress
            self.color = color
        }
        
        public var body: some View {
            HStack(spacing: AppSpacing.m) {
                // Circular progress indicator
                CircularProgress(
                    progress: progress,
                    size: 50,
                    lineWidth: 6,
                    foregroundColor: color
                )
                
                // Text content
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(title)
                        .font(AppTypography.caption1())
                        .foregroundColor(.theme.subtext)
                    
                    Text(value)
                        .font(AppTypography.title3())
                        .foregroundColor(.theme.text)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(AppTypography.caption1())
                            .foregroundColor(.theme.subtext)
                    }
                }
                
                Spacer()
            }
            .padding(AppSpacing.m)
            .background(
                RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                    .fill(Color.theme.surface)
                    .shadow(color: Color.theme.shadow.opacity(0.1), radius: 5, x: 0, y: 2)
            )
        }
    }
    
    /// A day streak display with flame icon
    public struct StreakDisplay: View {
        let count: Int
        let subtitle: String?
        let showIcon: Bool
        
        public init(
            count: Int,
            subtitle: String? = nil,
            showIcon: Bool = true
        ) {
            self.count = count
            self.subtitle = subtitle
            self.showIcon = showIcon
        }
        
        public var body: some View {
            HStack(spacing: AppSpacing.s) {
                if showIcon {
                    Image(systemName: "flame.fill")
                        .font(.system(size: AppSpacing.iconSizeMedium))
                        .foregroundColor(.orange)
                }
                
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(count)")
                        .font(AppTypography.title1())
                        .foregroundColor(count > 0 ? .theme.text : .theme.subtext)
                        .fontWeight(.bold)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(AppTypography.caption1())
                            .foregroundColor(.theme.subtext)
                    } else {
                        Text(count == 1 ? "day" : "days")
                            .font(AppTypography.caption1())
                            .foregroundColor(.theme.subtext)
                    }
                }
            }
        }
    }
    
    /// Progress list item with customizable appearance
    public struct ProgressListItem: View {
        let title: String
        let progress: Double
        let subtitle: String?
        let iconName: String?
        let color: Color
        
        public init(
            title: String,
            progress: Double,
            subtitle: String? = nil,
            iconName: String? = nil,
            color: Color = Color.theme.accent
        ) {
            self.title = title
            self.progress = progress
            self.subtitle = subtitle
            self.iconName = iconName
            self.color = color
        }
        
        public var body: some View {
            HStack(spacing: AppSpacing.m) {
                // Optional icon
                if let iconName = iconName {
                    Image(systemName: iconName)
                        .font(.system(size: AppSpacing.iconSizeSmall))
                        .foregroundColor(color)
                        .frame(width: AppSpacing.iconSizeMedium)
                }
                
                // Title and subtitle
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(title)
                        .font(AppTypography.subhead())
                        .foregroundColor(.theme.text)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(AppTypography.caption1())
                            .foregroundColor(.theme.subtext)
                    }
                }
                
                Spacer()
                
                // Progress percentage
                Text("\(Int(progress * 100))%")
                    .font(AppTypography.callout())
                    .fontWeight(.medium)
                    .foregroundColor(color)
            }
            .padding(AppSpacing.m)
            .background(
                RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                    .fill(Color.theme.surface)
            )
        }
    }
    
    /// A visual calendar day indicator
    public struct CalendarDayIndicator: View {
        let day: Int
        let isCompleted: Bool
        let isToday: Bool
        let isFuture: Bool
        
        public init(
            day: Int,
            isCompleted: Bool = false,
            isToday: Bool = false,
            isFuture: Bool = false
        ) {
            self.day = day
            self.isCompleted = isCompleted
            self.isToday = isToday
            self.isFuture = isFuture
        }
        
        public var body: some View {
            ZStack {
                // Background - changes based on completed/today/future state
                Circle()
                    .fill(backgroundColor)
                    .frame(width: 36, height: 36)
                
                // Today indicator
                if isToday {
                    Circle()
                        .stroke(Color.theme.accent, lineWidth: 2)
                        .frame(width: 36, height: 36)
                }
                
                // Day number
                Text("\(day)")
                    .font(AppTypography.callout())
                    .fontWeight(isToday ? .bold : .regular)
                    .foregroundColor(textColor)
            }
        }
        
        private var backgroundColor: Color {
            if isCompleted {
                return Color.theme.accent
            } else if isToday {
                return Color.theme.surface
            } else if isFuture {
                return Color.theme.surface.opacity(0.5)
            } else {
                return Color.theme.surface
            }
        }
        
        private var textColor: Color {
            if isCompleted {
                return .white
            } else if isFuture {
                return Color.theme.subtext.opacity(0.5)
            } else {
                return Color.theme.text
            }
        }
    }
}

// MARK: - Previews
struct ProgressComponents_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: AppSpacing.m) {
            // Circular progress
            HStack(spacing: AppSpacing.l) {
                ProgressComponents.CircularProgress(progress: 0.75)
                ProgressComponents.CircularProgress(progress: 0.35, showLabel: true)
                ProgressComponents.CircularProgress(progress: 0.9, foregroundColor: .green)
            }
            
            // Detailed progress
            ProgressComponents.DetailedProgress(
                title: "Overall Progress",
                value: "75%",
                subtitle: "75 days completed",
                progress: 0.75
            )
            
            // Streak display
            ProgressComponents.StreakDisplay(count: 7)
            
            // Progress list item
            ProgressComponents.ProgressListItem(
                title: "Meditation",
                progress: 0.68,
                subtitle: "68 days completed",
                iconName: "brain.head.profile"
            )
            
            // Calendar day indicators
            HStack(spacing: AppSpacing.s) {
                ProgressComponents.CalendarDayIndicator(day: 15, isCompleted: true)
                ProgressComponents.CalendarDayIndicator(day: 16, isToday: true)
                ProgressComponents.CalendarDayIndicator(day: 17, isFuture: true)
            }
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
} 