import SwiftUI

struct ActivityHeatmapView: View {
    let dateIntensityMap: [Date: Int]
    private let columns = 16
    private let rows = 7
    private let cellSize: CGFloat = 14
    private let spacing: CGFloat = 4
    
    private var sortedDates: [Date] {
        Array(dateIntensityMap.keys).sorted()
    }
    
    private var maxIntensity: Int {
        dateIntensityMap.values.max() ?? 1
    }
    
    // Calculate grid data for the heatmap
    private var gridData: [[HeatmapCell]] {
        let calendar = Calendar.current
        var grid: [[HeatmapCell]] = Array(repeating: Array(repeating: HeatmapCell(date: Date(), intensity: 0), count: columns), count: rows)
        
        // Get starting date (about 16 weeks ago)
        let today = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -(columns * rows - 3), to: today) else {
            return grid
        }
        
        // Populate the grid with dates and their intensities
        for row in 0..<rows {
            for col in 0..<columns {
                let index = row + (col * rows)
                if let date = calendar.date(byAdding: .day, value: index, to: startDate) {
                    let normalizedDate = calendar.startOfDay(for: date)
                    let intensity = dateIntensityMap[normalizedDate] ?? 0
                    
                    // Skip future dates
                    if normalizedDate <= today {
                        grid[row][col] = HeatmapCell(date: normalizedDate, intensity: intensity)
                    }
                }
            }
        }
        
        return grid
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Month labels
            monthLabelsView
                .padding(.leading, 24) // Add space for day labels
            
            HStack(alignment: .top, spacing: 0) {
                // Day of week labels
                dayLabelsView
                
                // Activity grid
                activityGridView
            }
            
            // Color scale legend
            legendView
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var monthLabelsView: some View {
        HStack(alignment: .center, spacing: 0) {
            ForEach(getMonthLabels(), id: \.self) { month in
                Text(month)
                    .font(.caption2)
                    .foregroundColor(.theme.subtext)
                    .frame(width: 40, alignment: .leading)
            }
            Spacer()
        }
    }
    
    private var dayLabelsView: some View {
        VStack(alignment: .trailing, spacing: spacing) {
            ForEach(getDayLabels(), id: \.self) { day in
                Text(day)
                    .font(.caption2)
                    .foregroundColor(.theme.subtext)
                    .frame(height: cellSize)
            }
        }
        .padding(.trailing, 4)
    }
    
    private var activityGridView: some View {
        VStack(alignment: .leading, spacing: spacing) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: spacing) {
                    ForEach(0..<columns, id: \.self) { col in
                        let cell = gridData[row][col]
                        Rectangle()
                            .fill(colorForIntensity(cell.intensity))
                            .frame(width: cellSize, height: cellSize)
                            .cornerRadius(2)
                            .overlay(
                                RoundedRectangle(cornerRadius: 2)
                                    .stroke(Color.theme.background, lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
                    }
                }
            }
        }
    }
    
    private var legendView: some View {
        HStack(spacing: 4) {
            Text("Less")
                .font(.caption2)
                .foregroundColor(.theme.subtext)
            
            ForEach(0...4, id: \.self) { i in
                Rectangle()
                    .fill(colorForIntensity(i))
                    .frame(width: cellSize - 2, height: cellSize - 2)
                    .cornerRadius(2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(Color.theme.background, lineWidth: 1)
                    )
            }
            
            Text("More")
                .font(.caption2)
                .foregroundColor(.theme.subtext)
        }
        .padding(.top, 4)
    }
    
    // Helper functions
    private func colorForIntensity(_ intensity: Int) -> Color {
        let normalizedIntensity = min(4, max(0, intensity))
        
        switch normalizedIntensity {
        case 0:
            return Color.theme.surface
        case 1:
            return Color.theme.accent.opacity(0.25)
        case 2:
            return Color.theme.accent.opacity(0.5)
        case 3:
            return Color.theme.accent.opacity(0.75)
        case 4...:
            return Color.theme.accent
        default:
            return Color.theme.surface
        }
    }
    
    private func getMonthLabels() -> [String] {
        let calendar = Calendar.current
        var months: [String] = []
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        
        if let date = gridData[0][0].date {
            var currentMonth = calendar.component(.month, from: date)
            var currentDate = date
            
            for col in 0..<columns {
                if col % 4 == 0 || col == 0 {
                    let month = calendar.component(.month, from: currentDate)
                    if month != currentMonth {
                        currentMonth = month
                        months.append(formatter.string(from: currentDate))
                    } else if col == 0 {
                        months.append(formatter.string(from: currentDate))
                    } else {
                        months.append("")
                    }
                } else {
                    months.append("")
                }
                
                if let nextDate = calendar.date(byAdding: .day, value: rows, to: currentDate) {
                    currentDate = nextDate
                }
            }
        }
        
        return months
    }
    
    private func getDayLabels() -> [String] {
        let weekdays = ["S", "M", "T", "W", "T", "F", "S"]
        return Array(weekdays.prefix(rows))
    }
}

// Model for each cell in the heatmap
struct HeatmapCell {
    let date: Date?
    let intensity: Int
}

// MARK: - Preview Provider
struct ActivityHeatmapView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleData = generateSampleData()
        
        return VStack {
            ActivityHeatmapView(dateIntensityMap: sampleData)
                .padding()
                .background(Color.theme.surface)
                .cornerRadius(16)
                .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.theme.background)
    }
    
    static func generateSampleData() -> [Date: Int] {
        var data: [Date: Int] = [:]
        let calendar = Calendar.current
        
        for i in 0..<90 {
            if Bool.random() && i % 3 != 0 {
                let date = calendar.date(byAdding: .day, value: -i, to: Date()) ?? Date()
                let intensity = Int.random(in: 0...4)
                let normalizedDate = calendar.startOfDay(for: date)
                data[normalizedDate] = intensity
            }
        }
        
        return data
    }
} 