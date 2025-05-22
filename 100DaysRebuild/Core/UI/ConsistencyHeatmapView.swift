import SwiftUI

/// A reusable consistency heatmap view for displaying check-in patterns
public struct ConsistencyHeatmapView: View {
    // Map of dates to intensity values (0-5)
    let dateIntensityMap: [Date: Int]
    
    // Number of weeks to display
    var weeksToShow: Int = 12
    
    // Color for heatmap cells
    var accentColor: Color = .theme.accent
    
    // Daily grid cell size
    private let cellSize: CGFloat = 14
    
    // Day column and week row labels
    private let weekdayLabels = ["S", "M", "T", "W", "T", "F", "S"]
    
    public init(
        dateIntensityMap: [Date: Int],
        weeksToShow: Int = 12,
        accentColor: Color = .theme.accent
    ) {
        self.dateIntensityMap = dateIntensityMap
        self.weeksToShow = min(max(4, weeksToShow), 26) // Limit between 4-26 weeks for reasonable display
        self.accentColor = accentColor
    }
    
    // Generate grid data for the heatmap
    private var gridData: [[HeatmapCell]] {
        let calendar = Calendar.current
        let today = Date()
        
        // Get start date (going back weeksToShow weeks)
        let startDate = calendar.date(byAdding: .day, value: -weeksToShow * 7, to: today)!
        
        // Array to hold grid cells
        var grid: [[HeatmapCell]] = Array(repeating: Array(repeating: HeatmapCell(date: today, intensity: 0), count: 7), count: weeksToShow)
        
        // Fill the grid with actual dates and intensities
        for week in 0..<weeksToShow {
            for weekday in 0..<7 {
                let day = calendar.date(byAdding: .day, value: week * 7 + weekday, to: startDate)!
                let intensity = dateIntensityMap[calendar.startOfDay(for: day)] ?? 0
                grid[week][weekday] = HeatmapCell(date: day, intensity: intensity)
            }
        }
        
        return grid
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            Text("Consistency")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.theme.text)
            
            VStack(spacing: AppSpacing.xs) {
                // Day of week labels
                HStack(spacing: 4) {
                    ForEach(Array(weekdayLabels.enumerated()), id: \.offset) { index, label in
                        Text(label)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.theme.subtext)
                            .frame(width: cellSize)
                    }
                }
                .padding(.leading, 30) // Offset to align with grid
                
                // Week rows
                ForEach(0..<gridData.count, id: \.self) { weekIndex in
                    HStack(spacing: 4) {
                        // Week number/label
                        if weekIndex % 4 == 0 {
                            let date = gridData[weekIndex][0].date
                            let month = Calendar.current.component(.month, from: date)
                            Text(monthLabel(for: month))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.theme.subtext)
                                .frame(width: 24, alignment: .leading)
                        } else {
                            Spacer()
                                .frame(width: 24)
                        }
                        
                        // Days in the week
                        ForEach(0..<7, id: \.self) { dayIndex in
                            let cell = gridData[weekIndex][dayIndex]
                            heatmapCell(for: cell)
                        }
                    }
                }
            }
            
            // Legend
            HStack(spacing: AppSpacing.m) {
                // Empty/None
                HStack(spacing: AppSpacing.xxs) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 12, height: 12)
                    
                    Text("None")
                        .font(.caption2)
                        .foregroundColor(.theme.subtext)
                }
                
                // Medium activity
                HStack(spacing: AppSpacing.xxs) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(accentColor.opacity(0.5))
                        .frame(width: 12, height: 12)
                    
                    Text("Activity")
                        .font(.caption2)
                        .foregroundColor(.theme.subtext)
                }
                
                // High activity
                HStack(spacing: AppSpacing.xxs) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(accentColor)
                        .frame(width: 12, height: 12)
                    
                    Text("Streak")
                        .font(.caption2)
                        .foregroundColor(.theme.subtext)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, AppSpacing.xs)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                .fill(Color.theme.surface)
                .shadow(color: Color.theme.shadow.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
    
    // Helper to get abbreviated month name
    private func monthLabel(for month: Int) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM"
        let date = Calendar.current.date(from: DateComponents(year: 2023, month: month, day: 1))!
        return dateFormatter.string(from: date)
    }
    
    // Individual heatmap cell
    private func heatmapCell(for cell: HeatmapCell) -> some View {
        let intensity = cell.intensity
        let today = Calendar.current.isDateInToday(cell.date)
        
        let color: Color = if intensity == 0 {
            Color.gray.opacity(0.2)
        } else {
            accentColor.opacity(Double(intensity) / 5.0)
        }
        
        return RoundedRectangle(cornerRadius: 2)
            .fill(color)
            .frame(width: cellSize, height: cellSize)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(today ? Color.theme.accent : Color.clear, lineWidth: 1)
            )
            .cornerRadius(2)
    }
}

// Model for a heatmap cell
struct HeatmapCell {
    let date: Date
    let intensity: Int // 0-5, where 0 is no activity, 5 is highest
}

// Preview for the ConsistencyHeatmapView
struct ConsistencyHeatmapView_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: AppSpacing.l) {
                // Generate sample data
                ConsistencyHeatmapView(
                    dateIntensityMap: generateSampleData(),
                    weeksToShow: 12
                )
            }
            .padding()
        }
        .background(Color.theme.background)
        .preferredColorScheme(.dark)
    }
    
    // Helper to generate sample intensity data
    static func generateSampleData() -> [Date: Int] {
        var data: [Date: Int] = [:]
        let calendar = Calendar.current
        let today = Date()
        
        // Generate random intensities for the past 90 days
        for day in 0..<90 {
            let date = calendar.date(byAdding: .day, value: -day, to: today)!
            let startOfDay = calendar.startOfDay(for: date)
            
            // Generate with higher probability for recent dates
            let probability = Double(90 - day) / 90.0
            if Double.random(in: 0...1) < probability {
                let intensity = Int.random(in: 1...5)
                data[startOfDay] = intensity
            }
        }
        
        return data
    }
} 