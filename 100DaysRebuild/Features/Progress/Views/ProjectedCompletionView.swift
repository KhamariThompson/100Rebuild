import SwiftUI

struct ProjectedCompletionView: View {
    let projectedDate: Date
    let currentPace: String
    let completionPercentage: Double
    
    private var daysUntilCompletion: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: projectedDate)
        return components.day ?? 0
    }
    
    private var isSoon: Bool {
        daysUntilCompletion <= 30
    }
    
    private var isDistant: Bool {
        daysUntilCompletion >= 90
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Completion date forecast
            HStack(alignment: .center, spacing: 16) {
                // Calendar icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [.theme.accent, .theme.accent.opacity(0.7)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 50, height: 50)
                        .shadow(color: .theme.accent.opacity(0.3), radius: 4, x: 0, y: 2)
                    
                    VStack(spacing: 0) {
                        Text(formattedMonth(projectedDate))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text(formattedDay(projectedDate))
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Estimated completion")
                        .font(.subheadline)
                        .foregroundColor(.theme.subtext)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(formattedFullDate(projectedDate))
                            .font(.headline)
                            .foregroundColor(.theme.text)
                        
                        Text("(\(daysUntilCompletion) days)")
                            .font(.subheadline)
                            .foregroundColor(.theme.subtext)
                    }
                }
                
                Spacer()
            }
            
            // Current pace information
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your current pace")
                        .font(.subheadline)
                        .foregroundColor(.theme.subtext)
                    
                    Text(currentPace)
                        .font(.headline)
                        .foregroundColor(.theme.text)
                }
                
                Spacer()
                
                // Pace indicator (faster, slower, or on track)
                paceIndicator
            }
            
            // Motivational message based on completion timeline
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Insight")
                        .font(.caption)
                        .bold()
                        .foregroundColor(.theme.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color.theme.accent.opacity(0.1))
                        )
                    
                    Spacer()
                }
                
                Text(motivationalMessage)
                    .font(.subheadline)
                    .foregroundColor(.theme.text)
                    .padding(.top, 8)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 10)
        }
    }
    
    private var paceIndicator: some View {
        HStack(spacing: 4) {
            // Icon based on pace (example logic)
            Image(systemName: paceIcon)
                .foregroundColor(paceColor)
            
            Text(paceText)
                .font(.caption)
                .bold()
                .foregroundColor(paceColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(paceColor.opacity(0.1))
        )
    }
    
    // Helper properties for pace indicator
    private var paceIcon: String {
        if isSoon {
            return "speedometer"
        } else if isDistant {
            return "tortoise.fill"
        } else {
            return "figure.walk"
        }
    }
    
    private var paceColor: Color {
        if isSoon {
            return .green
        } else if isDistant {
            return .orange
        } else {
            return .blue
        }
    }
    
    private var paceText: String {
        if isSoon {
            return "Fast pace"
        } else if isDistant {
            return "Slower pace"
        } else {
            return "Steady pace"
        }
    }
    
    private var motivationalMessage: String {
        if isSoon {
            return "At your current pace, you'll complete your 100-day challenge ahead of schedule. Keep up the great work!"
        } else if isDistant {
            return "Your completion date is a way off. Consider increasing your check-in frequency to reach your goal sooner."
        } else {
            return "You're making steady progress toward your goal. Maintain your current pace for timely completion."
        }
    }
    
    // Date formatting helpers
    private func formattedMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: date).uppercased()
    }
    
    private func formattedDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    private func formattedFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// Preview
struct ProjectedCompletionView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            ProjectedCompletionView(
                projectedDate: Date().addingTimeInterval(20 * 24 * 60 * 60), // 20 days from now
                currentPace: "5.3 days/week",
                completionPercentage: 0.65
            )
            .padding()
            .background(Color.theme.surface)
            .cornerRadius(16)
            
            ProjectedCompletionView(
                projectedDate: Date().addingTimeInterval(120 * 24 * 60 * 60), // 120 days from now
                currentPace: "2.1 days/week",
                completionPercentage: 0.25
            )
            .padding()
            .background(Color.theme.surface)
            .cornerRadius(16)
            
            ProjectedCompletionView(
                projectedDate: Date().addingTimeInterval(60 * 24 * 60 * 60), // 60 days from now
                currentPace: "3.5 days/week",
                completionPercentage: 0.45
            )
            .padding()
            .background(Color.theme.surface)
            .cornerRadius(16)
        }
        .padding()
        .background(Color.theme.background)
    }
} 