import SwiftUI
import Charts

struct ConsistencyGraphView: View {
    let dailyCheckIns: [ProgressDailyCheckIn]
    @State private var selectedDay: ProgressDailyCheckIn?
    @State private var plotWidth: CGFloat = 0
    
    private var weeklyData: [WeeklyCheckIn] {
        let calendar = Calendar.current
        var weeklyData: [String: Int] = [:]
        
        // Group check-ins by week
        for checkIn in dailyCheckIns {
            let weekStartDate = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: checkIn.date))!
            let weekString = formatWeekDate(weekStartDate)
            
            weeklyData[weekString, default: 0] += checkIn.count
        }
        
        // Sort by date and convert to WeeklyCheckIn objects
        let sortedWeeks = weeklyData.sorted { 
            formatWeekToDate($0.key) < formatWeekToDate($1.key) 
        }
        
        return sortedWeeks.map { WeeklyCheckIn(week: $0.key, count: $0.value) }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            if #available(iOS 16.0, *) {
                // iOS 16+ Chart
                modernChart
            } else {
                // Fallback for older iOS
                legacyChart
            }
            
            HStack {
                Text("Tip: Higher bars mean more check-ins that week")
                    .font(.caption)
                    .foregroundColor(.theme.subtext)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.yellow)
                    
                    Text("Pro")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.theme.subtext)
                }
            }
            .padding(.horizontal, 4)
        }
    }
    
    @available(iOS 16.0, *)
    private var modernChart: some View {
        Chart {
            ForEach(weeklyData) { item in
                BarMark(
                    x: .value("Week", item.week),
                    y: .value("Check-ins", item.count)
                )
                .foregroundStyle(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.theme.accent, Color.theme.accent.opacity(0.5)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(6)
            }
            
            if let selected = selectedDay {
                RuleMark(
                    x: .value("Week", formatWeekDate(selected.date))
                )
                .foregroundStyle(.gray.opacity(0.3))
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                .annotation(position: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Week of \(formatWeekDate(selected.date))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(selected.count) check-ins")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.theme.surface)
                            .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                    )
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic) { value in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.narrow))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let intValue = value.as(Int.self) {
                        Text("\(intValue)")
                            .font(.caption)
                            .foregroundColor(.theme.subtext)
                    }
                }
            }
        }
        .frame(height: 180)
        .padding(.top, 8)
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let x = value.location.x - geo.frame(in: .local).minX
                                guard let index = weekLocationToIndex(x: x, proxy: proxy, geo: geo) else { return }
                                selectedDay = dailyCheckInForWeek(weeklyData[index].week)
                            }
                            .onEnded { _ in
                                selectedDay = nil
                            }
                    )
            }
        }
    }
    
    // Legacy chart view for older iOS versions
    private var legacyChart: some View {
        VStack(spacing: 8) {
            // Week labels
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(weeklyData) { item in
                    Text(item.week.prefix(3))
                        .font(.caption2)
                        .foregroundColor(.theme.subtext)
                        .frame(maxWidth: .infinity)
                        .rotationEffect(.degrees(-45))
                        .offset(y: 10)
                }
            }
            .padding(.horizontal, 8)
            
            // Bar chart
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(weeklyData) { item in
                    VStack {
                        ZStack(alignment: .bottom) {
                            Rectangle()
                                .fill(Color.theme.surface)
                                .frame(height: 150)
                            
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.theme.accent, Color.theme.accent.opacity(0.5)]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(height: normalizedHeight(for: item.count, maxHeight: 150))
                        }
                        .cornerRadius(6)
                        
                        Text("\(item.count)")
                            .font(.caption2)
                            .foregroundColor(.theme.subtext)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 8)
        }
    }
    
    // Helper functions
    private func formatWeekDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
    
    private func formatWeekToDate(_ weekString: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.date(from: weekString) ?? Date()
    }
    
    private func normalizedHeight(for value: Int, maxHeight: CGFloat) -> CGFloat {
        let maxValue = weeklyData.map { $0.count }.max() ?? 1
        return CGFloat(value) / CGFloat(maxValue) * maxHeight
    }
    
    private func weekLocationToIndex(x: CGFloat, proxy: ChartProxy, geo: GeometryProxy) -> Int? {
        let relativeX = max(0, min(x, geo.size.width))
        let dataCount = weeklyData.count
        let index = Int((relativeX / geo.size.width) * CGFloat(dataCount))
        return index < dataCount ? index : nil
    }
    
    private func dailyCheckInForWeek(_ week: String) -> ProgressDailyCheckIn? {
        let _ = formatWeekToDate(week)
        let calendar = Calendar.current
        
        // Find the first check-in that belongs to this week
        for checkIn in dailyCheckIns {
            let checkInWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: checkIn.date))!
            let weekStartString = formatWeekDate(checkInWeekStart)
            
            if weekStartString == week {
                return checkIn
            }
        }
        
        return nil
    }
}

// Weekly check-in model
struct WeeklyCheckIn: Identifiable {
    let id = UUID()
    let week: String
    let count: Int
}

// MARK: - Preview
#Preview {
    VStack {
        ConsistencyGraphView(dailyCheckIns: [
            ProgressDailyCheckIn(date: Date().addingTimeInterval(-6*24*60*60), count: 2),
            ProgressDailyCheckIn(date: Date().addingTimeInterval(-5*24*60*60), count: 1),
            ProgressDailyCheckIn(date: Date().addingTimeInterval(-4*24*60*60), count: 3),
            ProgressDailyCheckIn(date: Date().addingTimeInterval(-3*24*60*60), count: 0),
            ProgressDailyCheckIn(date: Date().addingTimeInterval(-2*24*60*60), count: 2),
            ProgressDailyCheckIn(date: Date().addingTimeInterval(-1*24*60*60), count: 1),
            ProgressDailyCheckIn(date: Date(), count: 3)
        ])
        .padding()
        .background(Color.theme.surface)
        .cornerRadius(12)
        .padding()
    }
    .background(Color.gray.opacity(0.1))
} 