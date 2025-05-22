import SwiftUI
import UIKit

/// A reusable consistency calendar view that displays user check-ins in a clean, elegant grid
/// Shows 3 weeks of activity with proper visual design and performance optimizations
struct ConsistencyCalendarView: View {
    // Dictionary mapping dates to intensity values (0 = missed, 1+ = checked in with intensity)
    let dateIntensityMap: [Date: Int]
    
    // Animation state
    @State private var animationProgress: CGFloat = 0
    
    // Settings
    private let cellSize: CGFloat = 22
    private let cellSpacing: CGFloat = 4
    private let cornerRadius: CGFloat = 4
    
    // Get dates for the last 3 weeks starting correctly aligned with weekdays
    private var calendarDays: [(date: Date, intensity: Int, isToday: Bool)] {
        let calendar = Calendar.current
        let today = Date()
        var result: [(date: Date, intensity: Int, isToday: Bool)] = []
        
        // Find the weekday index of today (0 = Sunday, 6 = Saturday)
        let weekdayIndex = calendar.component(.weekday, from: today) - 1
        
        // Calculate date for the start of the grid (3 weeks ago + remaining weekdays)
        let gridStartOffset = -((7 * 2) + weekdayIndex)
        guard let gridStartDate = calendar.date(byAdding: .day, value: gridStartOffset, to: today) else {
            return result
        }
        
        // Generate dates for the 3-week grid (3 rows × 7 columns)
        for dayOffset in 0..<21 {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: gridStartDate) else {
                continue
            }
            
            // Don't include future dates
            if date <= today {
                // Get the normalized date starting at midnight
                let normalizedDate = calendar.startOfDay(for: date)
                
                // Look up intensity from the map or default to 0 (missed)
                let intensity = dateIntensityMap[normalizedDate] ?? 0
                let isToday = calendar.isDate(date, inSameDayAs: today)
                
                // Add the date with its intensity and today flag
                result.append((date: normalizedDate, intensity: intensity, isToday: isToday))
            }
        }
        
        return result
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Weekday headers once at the top
            HStack(spacing: cellSpacing) {
                ForEach(Array(Calendar.current.veryShortWeekdaySymbols.enumerated()), id: \.offset) { index, day in
                    Text(day)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.theme.subtext)
                        .frame(width: cellSize)
                }
            }
            .padding(.horizontal, 2)
            
            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(cellSize), spacing: cellSpacing), count: 7), spacing: cellSpacing) {
                ForEach(calendarDays, id: \.date) { item in
                    calendarCell(for: item)
                        .id(item.date) // Important for animations
                }
            }
            
            // Legend at the bottom with smaller text and spacing
            HStack(spacing: 10) {
                legendItem(color: Color.gray.opacity(0.2), text: "Missed")
                legendItem(color: Color.theme.accent, text: "Checked in")
            }
            .padding(.top, 4)
            .padding(.horizontal, 2)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5)) {
                animationProgress = 1.0
            }
        }
    }
    
    // Calendar cell view with animations and proper styling
    private func calendarCell(for item: (date: Date, intensity: Int, isToday: Bool)) -> some View {
        // Determine cell color based on check-in status
        let color = item.intensity > 0 
            ? Color.theme.accent  // Checked in - filled blue
            : Color.gray.opacity(0.2)  // Missed - light gray
        
        return RoundedRectangle(cornerRadius: cornerRadius)
            .fill(color)
            .frame(width: cellSize, height: cellSize)
            .overlay(
                // Today indicator with border
                Group {
                    if item.isToday {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.theme.accent, lineWidth: 1.5)
                    }
                }
            )
            .scaleEffect(animationProgress)
            .opacity(animationProgress)
            // Add spring animation when cell appears
            .modifier(CheckInAnimationModifier(
                intensity: item.intensity,
                isToday: item.isToday
            ))
    }
    
    // Legend item helper with smaller styling
    private func legendItem(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 10, height: 10)
            
            Text(text)
                .font(.caption2)
                .foregroundColor(.theme.subtext)
        }
    }
}

// MARK: - Preview
struct ConsistencyCalendarView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            ConsistencyCalendarView(dateIntensityMap: mockCheckIns())
                .padding()
                .background(Color.theme.surface)
                .cornerRadius(16)
                .padding()
        }
        .background(Color.theme.background)
    }
    
    // Helper to create mock data for preview
    static func mockCheckIns() -> [Date: Int] {
        var result: [Date: Int] = [:]
        let calendar = Calendar.current
        let today = Date()
        
        for day in 0..<21 {
            if let date = calendar.date(byAdding: .day, value: -day, to: today) {
                // Random intensity for demonstration
                if day % 3 == 0 {
                    result[date] = 1
                } else if day % 7 == 0 {
                    result[date] = 2
                }
            }
        }
        
        return result
    }
}

// MARK: - Extensions
extension Calendar {
    /// Shorter weekday symbols (S, M, T, W, T, F, S)
    var veryShortWeekdaySymbols: [String] {
        self.shortWeekdaySymbols.map { String($0.prefix(1)) }
    }
}

// MARK: - Animation Modifiers

/// A modifier that adds spring animation when a cell is checked in
struct CheckInAnimationModifier: ViewModifier {
    let intensity: Int
    let isToday: Bool
    
    @State private var hasAnimated = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(hasAnimated ? 1.0 : (intensity > 0 ? 0.8 : 1.0))
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: intensity)
            .onAppear {
                // Small delay to ensure cells animate in sequence
                DispatchQueue.main.asyncAfter(deadline: .now() + (isToday ? 0.1 : 0.2)) {
                    hasAnimated = true
                }
            }
            // Reset animation state if intensity changes
            .onChange(of: intensity) { newValue in
                if newValue > 0 {
                    // Briefly scale down and then back up to create a "pop" effect
                    withAnimation(.easeInOut(duration: 0.1)) {
                        hasAnimated = false
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            hasAnimated = true
                        }
                    }
                }
            }
    }
} 