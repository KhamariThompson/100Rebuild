import SwiftUI

/// A personalized greeting component showing time of day and username
public struct MorningGreetingComponent: View {
    // User data
    let userName: String?
    let streakCount: Int
    let timeOfDay: TimeOfDay
    
    // Defines time of day for appropriate greeting and icon
    public enum TimeOfDay {
        case morning
        case afternoon
        case evening
        
        public var greeting: String {
            switch self {
            case .morning: return "Good morning"
            case .afternoon: return "Good afternoon"
            case .evening: return "Good evening"
            }
        }
        
        public var emoji: String {
            switch self {
            case .morning: return "☀️"
            case .afternoon: return "🌤️"
            case .evening: return "🌙"
            }
        }
        
        public var gradient: LinearGradient {
            switch self {
            case .morning:
                return LinearGradient(
                    gradient: Gradient(colors: [Color.orange.opacity(0.7), Color.yellow.opacity(0.5)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .afternoon:
                return LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.cyan.opacity(0.4)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .evening:
                return LinearGradient(
                    gradient: Gradient(colors: [Color.indigo.opacity(0.6), Color.purple.opacity(0.4)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }
    
    public init(userName: String?, streakCount: Int, timeOfDay: TimeOfDay) {
        self.userName = userName
        self.streakCount = streakCount
        self.timeOfDay = timeOfDay
    }
    
    public var body: some View {
        VStack(spacing: AppSpacing.s) {
            // Personalized greeting
            HStack {
                // Main greeting with name if available
                Text(getPersonalizedGreeting())
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.theme.text)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                
                Spacer()
                
                // Time of day icon
                ZStack {
                    Circle()
                        .fill(timeOfDay.gradient)
                        .frame(width: 50, height: 50)
                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 3)
                    
                    Text(timeOfDay.emoji)
                        .font(.system(size: 24))
                }
            }
        }
        .padding(AppSpacing.m)
        .background(
            RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                .fill(
                    LinearGradient(
                        colors: [Color.theme.surface, Color.theme.surface.opacity(0.95)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.theme.shadow.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
    
    // Helper to create a personalized greeting with the user's name
    private func getPersonalizedGreeting() -> String {
        if let name = userName, !name.isEmpty {
            return "\(timeOfDay.greeting), \(name)"
        } else {
            return "\(timeOfDay.greeting)"
        }
    }
}

// Preview for the component
struct MorningGreetingComponent_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Morning greeting with name and streak
            MorningGreetingComponent(
                userName: "Khamari",
                streakCount: 7,
                timeOfDay: .morning
            )
            
            // Afternoon greeting with no name
            MorningGreetingComponent(
                userName: nil,
                streakCount: 1,
                timeOfDay: .afternoon
            )
            
            // Evening greeting with no streak
            MorningGreetingComponent(
                userName: "Alex",
                streakCount: 0,
                timeOfDay: .evening
            )
        }
        .padding()
        .background(Color.theme.background)
        .previewLayout(.sizeThatFits)
    }
} 