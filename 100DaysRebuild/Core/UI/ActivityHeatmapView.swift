import SwiftUI

struct ActivityHeatmapView: View {
    private let dateIntensityMap: [Date: Int]
    private let monthsToDisplay: Int
    private let cellSize: CGFloat
    private let cellSpacing: CGFloat
    
    @Environment(\.colorScheme) private var colorScheme
    
    /// Creates a GitHub-style activity heatmap
    /// - Parameters:
    ///   - dateIntensityMap: Dictionary mapping dates to intensity values (0-4)
    ///   - monthsToDisplay: Number of months to display (default: 6)
    ///   - cellSize: Size of each day cell (default: 12)
    ///   - cellSpacing: Spacing between cells (default: 3)
    init(
        dateIntensityMap: [Date: Int],
        monthsToDisplay: Int = 6,
        cellSize: CGFloat = 12,
        cellSpacing: CGFloat = 3
    ) {
        self.dateIntensityMap = dateIntensityMap
        self.monthsToDisplay = monthsToDisplay
        self.cellSize = cellSize
        self.cellSpacing = cellSpacing
    }
    
    private var calendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Start week on Monday (2), Sunday is 1
        return calendar
    }
    
    private var startDate: Date {
        let now = Date()
        var dateComponents = DateComponents()
        dateComponents.month = -monthsToDisplay + 1
        return calendar.date(byAdding: dateComponents, to: now) ?? now
    }
    
    private var endDate: Date {
        Date()
    }
    
    // Generate 2D grid of dates: [week][day]
    private var dateGrid: [[Date?]] {
        // Find the first Monday before or on the start date
        let startDateWeekday = calendar.component(.weekday, from: startDate)
        let daysToSubtract = (startDateWeekday == 1) ? 6 : startDateWeekday - 2 // Adjust for Monday start
        
        // Create day component explicitly for clarity with Swift 6
        var dayComponent = DateComponents()
        dayComponent.day = -daysToSubtract
        let gridStartDate = calendar.date(byAdding: dayComponent, to: startDate) ?? startDate
        
        // Calculate total days in grid
        let totalDays = calendar.dateComponents([.day], from: gridStartDate, to: endDate).day ?? 0
        
        // Calculate total weeks needed (+1 to include partial weeks)
        let weeksNeeded = (totalDays / 7) + 1
        
        // Create empty grid
        var grid: [[Date?]] = Array(repeating: Array(repeating: nil as Date?, count: 7), count: weeksNeeded)
        
        // Fill grid with dates
        var currentDate = gridStartDate
        var currentWeek = 0
        var currentDay = 0
        
        while currentDate <= endDate {
            // Skip dates before startDate
            if currentDate >= startDate {
                grid[currentWeek][currentDay] = calendar.startOfDay(for: currentDate)
            }
            
            // Move to next day
            currentDay += 1
            if currentDay >= 7 {
                currentDay = 0
                currentWeek += 1
            }
            
            // Create day component explicitly for clarity with Swift 6
            dayComponent.day = 1
            currentDate = calendar.date(byAdding: dayComponent, to: currentDate) ?? currentDate
        }
        
        return grid
    }
    
    // Get color based on intensity (0-4)
    private func colorForIntensity(_ intensity: Int) -> Color {
        let baseColor = Color.theme.accent
        
        switch intensity {
        case 0:
            return colorScheme == .dark ? 
                Color(.sRGB, red: 0.1, green: 0.1, blue: 0.1, opacity: 1) : 
                Color(.sRGB, red: 0.9, green: 0.9, blue: 0.9, opacity: 1)
        case 1:
            return baseColor.opacity(0.25)
        case 2:
            return baseColor.opacity(0.5)
        case 3:
            return baseColor.opacity(0.75)
        default:
            return baseColor
        }
    }
    
    // Get intensity for date (0-4)
    private func intensityForDate(_ date: Date?) -> Int {
        guard let date = date else { return 0 }
        
        let normalized = calendar.startOfDay(for: date)
        return min(4, dateIntensityMap[normalized] ?? 0)
    }
    
    // Generate month labels
    private func monthLabels() -> [MonthLabel] {
        var labels: [MonthLabel] = []
        var currentMonth = -1
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM"
        
        for weekIndex in 0..<dateGrid.count {
            for dayIndex in 0..<7 {
                if let date = dateGrid[weekIndex][dayIndex] {
                    let month = calendar.component(.month, from: date)
                    if month != currentMonth {
                        labels.append(MonthLabel(
                            text: dateFormatter.string(from: date),
                            weekIndex: weekIndex
                        ))
                        currentMonth = month
                    }
                }
            }
        }
        
        return labels
    }
    
    private struct MonthLabel: Identifiable {
        let text: String
        let weekIndex: Int
        var id: String { "\(text)_\(weekIndex)" }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 4) {
                // Day of week labels
                VStack(spacing: cellSpacing * 2 + cellSize) {
                    Text("M")
                        .font(.system(size: 9))
                        .foregroundColor(.theme.subtext)
                    
                    Text("W")
                        .font(.system(size: 9))
                        .foregroundColor(.theme.subtext)
                    
                    Text("F")
                        .font(.system(size: 9))
                        .foregroundColor(.theme.subtext)
                }
                .padding(.top, cellSize / 2)
                .frame(width: 8)
                
                // Scrollable contribution grid
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 8) {
                        // Days grid
                        HStack(alignment: .top, spacing: cellSpacing) {
                            ForEach(Array(dateGrid.enumerated()), id: \.offset) { weekIndex, week in
                                VStack(spacing: cellSpacing) {
                                    ForEach(0..<7, id: \.self) { dayIndex in
                                        let date = week[dayIndex]
                                        let intensity = intensityForDate(date)
                                        
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(colorForIntensity(intensity))
                                            .frame(width: cellSize, height: cellSize)
                                    }
                                }
                            }
                        }
                        
                        // Month labels
                        HStack(alignment: .top, spacing: 0) {
                            ForEach(monthLabels()) { label in
                                Text(label.text)
                                    .font(.system(size: 9))
                                    .foregroundColor(.theme.subtext)
                                    .frame(width: 30, alignment: .leading)
                                    .offset(x: CGFloat(label.weekIndex) * (cellSize + cellSpacing))
                            }
                        }
                        .frame(height: 12)
                        .padding(.top, 4)
                    }
                }
            }
            
            // Intensity legend
            HStack(spacing: 4) {
                Text("Less")
                    .font(.caption2)
                    .foregroundColor(.theme.subtext)
                
                ForEach(0..<5) { intensity in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(colorForIntensity(intensity))
                        .frame(width: 8, height: 8)
                }
                
                Text("More")
                    .font(.caption2)
                    .foregroundColor(.theme.subtext)
            }
        }
    }
}

// Preview provider
struct ActivityHeatmapView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            ActivityHeatmapView(dateIntensityMap: sampleData())
                .padding()
                .previewLayout(.sizeThatFits)
                .preferredColorScheme(.light)
            
            ActivityHeatmapView(dateIntensityMap: sampleData())
                .padding()
                .previewLayout(.sizeThatFits)
                .preferredColorScheme(.dark)
        }
    }
    
    static func sampleData() -> [Date: Int] {
        var data: [Date: Int] = [:]
        let calendar = Calendar.current
        
        // Add some random data points
        for day in 0..<180 {
            if Bool.random() && day % 3 == 0 {
                // Create day component explicitly for Swift 6
                var dayComponent = DateComponents()
                dayComponent.day = -day
                let date = calendar.date(byAdding: dayComponent, to: Date()) ?? Date()
                data[date] = Int.random(in: 1...4)
            }
        }
        
        return data
    }
} 