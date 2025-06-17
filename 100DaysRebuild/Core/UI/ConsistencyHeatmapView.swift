import SwiftUI

/// A reusable consistency heatmap view for displaying check-in patterns
public struct ConsistencyHeatmapView: View {
    // Map of dates to intensity values (0-5)
    let dateIntensityMap: [Date: Int]
    
    // Default to showing 12 weeks
    var initialWeeksToShow: Int = 12
    
    // Color for heatmap cells
    var accentColor: Color = .theme.accent
    
    // Environment properties
    @Environment(\.colorScheme) private var colorScheme
    
    // State variables for interactive features
    @State private var selectedTimeRange: TimeRange = .oneMonth
    @State private var currentStartDate: Date
    @State private var showHistoryPicker = false
    @State private var animateCurrentDay = false
    @State private var availableMonths: [YearMonth] = []
    @State private var selectedYearMonth: YearMonth?
    
    // Day column and week row labels
    private let weekdayLabels = ["S", "M", "T", "W", "T", "F", "S"]
    
    // Time range options
    enum TimeRange: String, CaseIterable, Identifiable {
        case oneMonth = "1 Month"
        case threeMonths = "3 Months" // Default: 12 weeks
        case sixMonths = "6 Months"
        case oneYear = "1 Year"
        
        var id: String { self.rawValue }
        
        var weeksCount: Int {
            switch self {
            case .oneMonth: return 4
            case .threeMonths: return 12
            case .sixMonths: return 26
            case .oneYear: return 52
            }
        }
        
        var title: String {
            switch self {
            case .oneMonth: return "Month View"
            case .threeMonths: return "Quarter View"
            case .sixMonths: return "Half Year"
            case .oneYear: return "Year View"
            }
        }
    }
    
    // Structure to represent year/month combinations
    struct YearMonth: Identifiable, Hashable {
        let year: Int
        let month: Int
        var id: String { "\(year)-\(month)" }
        
        var date: Date {
            Calendar.current.date(from: DateComponents(year: year, month: month, day: 1)) ?? Date()
        }
        
        var displayString: String {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMMM yyyy"
            return dateFormatter.string(from: date)
        }
        
        static func from(date: Date) -> YearMonth {
            let components = Calendar.current.dateComponents([.year, .month], from: date)
            return YearMonth(year: components.year ?? 2023, month: components.month ?? 1)
        }
    }
    
    public init(
        dateIntensityMap: [Date: Int],
        weeksToShow: Int = 4,
        accentColor: Color = .theme.accent
    ) {
        self.dateIntensityMap = dateIntensityMap
        self.initialWeeksToShow = min(max(4, weeksToShow), 52) // Limit between 4-52 weeks
        self.accentColor = accentColor
        
        // Initialize with current date aligned to proper week
        let calendar = Calendar.current
        let today = Date()
        
        // Find the weekday of today (0-6, where 0 is Sunday)
        let todayWeekday = calendar.component(.weekday, from: today) - 1
        
        // Calculate a start date that will align today with its proper column
        // We need to go back to the start of the week containing today,
        // then go back the appropriate number of weeks for month view
        let daysToStartOfWeek = todayWeekday
        // For month view (4 weeks), we want today to be in the last week or second-to-last week
        let totalDaysBack = 3 * 7 + daysToStartOfWeek // This positions today in the 4th week
        
        // Set the start date
        let initialStartDate = calendar.date(byAdding: .day, value: -totalDaysBack, to: today) ?? today
        _currentStartDate = State(initialValue: initialStartDate)
        
        // Pre-calculate available months from data
        _availableMonths = State(initialValue: Self.generateAvailableMonths(from: dateIntensityMap))
    }
    
    // Generate list of available year/months from data
    private static func generateAvailableMonths(from data: [Date: Int]) -> [YearMonth] {
        let calendar = Calendar.current
        let uniqueMonths = Set(data.keys.map { date in
            let components = calendar.dateComponents([.year, .month], from: date)
            return YearMonth(year: components.year ?? 2023, month: components.month ?? 1)
        })
        
        return Array(uniqueMonths).sorted { first, second in
            if first.year != second.year {
                return first.year > second.year
            }
            return first.month > second.month
        }
    }
    
    // Navigate to previous time period
    private func navigateToPrevious() {
        let calendar = Calendar.current
        let weeksCount = selectedTimeRange.weeksCount
        
        withAnimation(.easeInOut(duration: 0.3)) {
            // Go back by the current display period
            currentStartDate = calendar.date(byAdding: .day, value: -weeksCount * 7, to: currentStartDate) ?? currentStartDate
        }
    }
    
    // Navigate to next time period
    private func navigateToNext() {
        let calendar = Calendar.current
        let weeksCount = selectedTimeRange.weeksCount
        let today = Date()
        
        // Calculate the endpoint of current view
        let currentEndDate = calendar.date(byAdding: .day, value: weeksCount * 7, to: currentStartDate) ?? currentStartDate
        
        // Only allow forward navigation if it won't exceed today
        if currentEndDate < today {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStartDate = calendar.date(byAdding: .day, value: weeksCount * 7, to: currentStartDate) ?? currentStartDate
            }
        }
    }
    
    // Navigate to current time period
    private func navigateToToday() {
        let calendar = Calendar.current
        let weeksCount = selectedTimeRange.weeksCount
        let today = Date()
        
        withAnimation(.easeInOut(duration: 0.3)) {
            // Find the weekday of today (0-6, where 0 is Sunday)
            let todayWeekday = calendar.component(.weekday, from: today) - 1
            
            // Calculate a start date that will align today with its proper column
            // We need to go back to the start of the week containing today,
            // then go back the appropriate number of weeks
            let daysToStartOfWeek = todayWeekday
            let totalDaysBack = (weeksCount - 1) * 7 + daysToStartOfWeek
            
            // Set the new start date
            currentStartDate = calendar.date(byAdding: .day, value: -totalDaysBack, to: today) ?? today
        }
    }
    
    // Navigate to specific month
    private func navigateToMonth(_ yearMonth: YearMonth) {
        withAnimation(.easeInOut(duration: 0.3)) {
            // Set the view to center around the selected month
            let monthStart = yearMonth.date
            let weeksCount = selectedTimeRange.weeksCount
            
            // Adjust the start date based on the weeks to show
            currentStartDate = Calendar.current.date(byAdding: .day, value: -(weeksCount * 7) / 2, to: monthStart) ?? monthStart
            
            showHistoryPicker = false
        }
    }
    
    // Format date range for display
    private func formattedDateRange() -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        
        let endDate = calendar.date(byAdding: .day, value: selectedTimeRange.weeksCount * 7, to: currentStartDate) ?? Date()
        
        return "\(formatter.string(from: currentStartDate)) - \(formatter.string(from: endDate))"
    }
    
    // Generate grid data for the heatmap
    private func gridData(startDate: Date, weeksToShow: Int) -> [[HeatmapCell]] {
        let calendar = Calendar.current
        let today = Date()
        
        // Array to hold grid cells
        var grid: [[HeatmapCell]] = Array(repeating: Array(repeating: HeatmapCell(date: today, intensity: 0), count: 7), count: weeksToShow)
        
        // Fill the grid with actual dates and intensities
        for week in 0..<weeksToShow {
            for weekday in 0..<7 {
                let day = calendar.date(byAdding: .day, value: week * 7 + weekday, to: startDate)!
                let intensity = dateIntensityMap[calendar.startOfDay(for: day)] ?? 0
                let isToday = calendar.isDateInToday(day)
                let isFuture = day > today
                
                grid[week][weekday] = HeatmapCell(
                    date: day, 
                    intensity: intensity, 
                    isToday: isToday,
                    isFuture: isFuture
                )
            }
        }
        
        return grid
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Enhanced header with navigation controls
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                // Title and view switcher row
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Consistency Heatmap")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.theme.text)
                        
                        Button(action: {
                            withAnimation {
                                showHistoryPicker.toggle()
                            }
                        }) {
                            HStack(spacing: 4) {
                                Text(formattedDateRange())
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.theme.accent)
                                
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.theme.accent)
                                    .rotationEffect(Angle(degrees: showHistoryPicker ? 180 : 0))
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Time range picker
                    Menu {
                        ForEach(TimeRange.allCases) { range in
                            Button(action: {
                                withAnimation {
                                    selectedTimeRange = range
                                    // Reset view to current period with new range
                                    navigateToToday()
                                }
                            }) {
                                HStack {
                                    Text(range.title)
                                    if selectedTimeRange == range {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(selectedTimeRange.title)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.theme.subtext)
                            
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10))
                                .foregroundColor(.theme.subtext)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.theme.background.opacity(0.5))
                        .cornerRadius(6)
                    }
                }
                
                // History dropdown (conditionally visible)
                if showHistoryPicker {
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(alignment: .leading, spacing: 4) {
                            // Group by year
                            let groupedMonths = Dictionary(grouping: availableMonths, by: { $0.year })
                            
                            ForEach(groupedMonths.keys.sorted(by: >), id: \.self) { year in
                                if let months = groupedMonths[year]?.sorted(by: { $0.month > $1.month }) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(year)")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.theme.text)
                                            .padding(.top, 4)
                                        
                                        ForEach(months) { yearMonth in
                                            Button(action: {
                                                navigateToMonth(yearMonth)
                                            }) {
                                                HStack {
                                                    Text(yearMonth.displayString)
                                                        .font(.system(size: 13))
                                                        .foregroundColor(.theme.text)
                                                    
                                                    Spacer()
                                                    
                                                    if YearMonth.from(date: currentStartDate) == yearMonth {
                                                        Image(systemName: "checkmark")
                                                            .font(.system(size: 12))
                                                            .foregroundColor(.theme.accent)
                                                    }
                                                }
                                                .padding(.vertical, 6)
                                                .padding(.horizontal, 8)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 6)
                                                        .fill(YearMonth.from(date: currentStartDate) == yearMonth ? 
                                                              Color.theme.accent.opacity(0.1) : Color.clear)
                                                )
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(8)
                        .background(Color.theme.surface)
                        .cornerRadius(8)
                    }
                    .frame(maxHeight: 200)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)
            
            // Navigation controls with weekday labels
            HStack(alignment: .center, spacing: 0) {
                // Navigation controls
                HStack(spacing: 8) {
                    // Previous period button
                    Button(action: navigateToPrevious) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.theme.accent)
                            .padding(6)
                            .background(
                                Circle()
                                    .fill(Color.theme.accent.opacity(0.1))
                            )
                    }
                    
                    // Today button
                    Button(action: {
                        // Enhanced Today navigation to ensure proper alignment
                        withAnimation(.easeInOut(duration: 0.3)) {
                            let calendar = Calendar.current
                            let today = Date()
                            
                            // Calculate weeks to go back to show today aligned properly
                            let weeksCount = selectedTimeRange.weeksCount
                            
                            // Find the weekday of today (0-6, where 0 is Sunday)
                            let todayWeekday = calendar.component(.weekday, from: today) - 1
                            
                            // Calculate a start date that will align today with its proper column
                            // We need to go back to the start of the week containing today,
                            // then go back the appropriate number of weeks
                            let daysToStartOfWeek = todayWeekday
                            let totalDaysBack = (weeksCount - 1) * 7 + daysToStartOfWeek
                            
                            // Set the new start date
                            currentStartDate = calendar.date(byAdding: .day, value: -totalDaysBack, to: today) ?? today
                        }
                    }) {
                        Text("Today")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.theme.accent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.theme.accent.opacity(0.1))
                            )
                    }
                    
                    // Next period button
                    Button(action: navigateToNext) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.theme.accent)
                            .padding(6)
                            .background(
                                Circle()
                                    .fill(Color.theme.accent.opacity(0.1))
                            )
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
            
            // Weekday labels aligned with grid - moved outside of the navigation controls
            HStack(spacing: 3) {
                // Add spacer to align with month labels
                Spacer()
                    .frame(width: 35)
                
                // Weekday labels
                HStack(spacing: 3) {
                    ForEach(0..<7, id: \.self) { index in
                        Text(weekdayLabels[index])
                            .font(.subheadline)
                            .foregroundColor(.theme.subtext)
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 4)
            
            // Heatmap grid
            let currentGridData = gridData(startDate: currentStartDate, weeksToShow: selectedTimeRange.weeksCount)
            
            // Grid of cells with full width layout
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    ForEach(0..<currentGridData.count, id: \.self) { weekIndex in
                        HStack(alignment: .center, spacing: 0) {
                            // Month labels
                            if weekIndex % 4 == 0 || weekIndex == 0 {
                                let date = currentGridData[weekIndex][0].date
                                let month = Calendar.current.component(.month, from: date)
                                Text(monthLabel(for: month))
                                    .font(.subheadline)
                                    .foregroundColor(.theme.subtext)
                                    .frame(width: 35, alignment: .leading)
                            } else {
                                Spacer()
                                    .frame(width: 35)
                            }
                            
                            // Days of the week as a grid
                            HStack(spacing: 3) {
                                ForEach(0..<7, id: \.self) { dayIndex in
                                    let cell = currentGridData[weekIndex][dayIndex]
                                    heatmapCell(for: cell, size: 16)
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
            .frame(minHeight: 200, maxHeight: 300)
            .padding(.bottom, 8)
            
            Divider()
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            
            // Legend row
            HStack(spacing: AppSpacing.xs) {
                // Simple check-in vs no check-in legend
                HStack(spacing: 8) {
                    // No check-in
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 24, height: 12)
                        
                        Text("No Check-in")
                            .font(.subheadline)
                            .foregroundColor(.theme.subtext)
                    }
                    
                    // Check-in
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(colorScheme == .light ? Color.black : Color.white)
                            .frame(width: 24, height: 12)
                        
                        Text("Check-in")
                            .font(.subheadline)
                            .foregroundColor(.theme.subtext)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                
                // Today indicator
                HStack(spacing: 4) {
                    Circle()
                        .stroke(Color.theme.accent, lineWidth: 1)
                        .frame(width: 8, height: 8)
                    
                    Text("Today")
                        .font(.subheadline)
                        .foregroundColor(.theme.subtext)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 300)
        .background(Color.theme.surface)
        .cornerRadius(20)
        .onAppear {
            // Start the animation for today's cell when the view appears
            withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                animateCurrentDay = true
            }
        }
    }
    
    private func monthLabel(for month: Int) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM"
        let date = Calendar.current.date(from: DateComponents(year: 2023, month: month, day: 1))!
        return dateFormatter.string(from: date)
    }
    
    // Individual heatmap cell
    private func heatmapCell(for cell: HeatmapCell, size: CGFloat) -> some View {
        let intensity = cell.intensity
        let isToday = cell.isToday
        let isFuture = cell.isFuture
        let hasCheckIn = intensity > 0
        
        // Simplified color scheme: Black/White for check-ins (depending on mode), gray for no check-ins
        let color: Color
        if hasCheckIn {
            color = colorScheme == .light ? .black : .white // Use black in light mode, white in dark mode
        } else {
            color = isFuture ? Color.gray.opacity(0.1) : Color.gray.opacity(0.2)
        }
        
        return ZStack {
            // Base cell
            RoundedRectangle(cornerRadius: 4)
                .fill(color)
                .frame(width: size, height: size)
            
            // Today indicator
            if isToday {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.theme.accent, lineWidth: 1)
                    .frame(width: size, height: size)
            }
            
            // Pulse animation for today's check-in
            if hasCheckIn && isToday {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.theme.accent.opacity(0.2))
                    .frame(width: size, height: size)
                    .scaleEffect(animateCurrentDay ? 1.2 : 1.0)
                    .opacity(animateCurrentDay ? 0.4 : 0.8)
            }
        }
        .cornerRadius(4)
        .frame(width: size, height: size) // Ensure consistent sizing
    }
}

// Model for a heatmap cell
struct HeatmapCell {
    let date: Date
    let intensity: Int // 0-5, where 0 is no activity, 5 is highest
    var isToday: Bool = false
    var isFuture: Bool = false
}

// Preview for the ConsistencyHeatmapView
struct ConsistencyHeatmapView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Dark mode preview
            ScrollView {
                VStack(spacing: AppSpacing.l) {
                    // Generate sample data
                    ConsistencyHeatmapView(
                        dateIntensityMap: generateSampleData(),
                        weeksToShow: 12
                    )
                    .padding(.horizontal)
                }
            }
            .background(Color.theme.background)
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")
            
            // Light mode preview
            ScrollView {
                VStack(spacing: AppSpacing.l) {
                    // Generate sample data
                    ConsistencyHeatmapView(
                        dateIntensityMap: generateSampleData(),
                        weeksToShow: 12
                    )
                    .padding(.horizontal)
                }
            }
            .background(Color.theme.background)
            .preferredColorScheme(.light)
            .previewDisplayName("Light Mode")
        }
    }
    
    // Helper to generate sample intensity data
    static func generateSampleData() -> [Date: Int] {
        var data: [Date: Int] = [:]
        let calendar = Calendar.current
        let today = Date()
        
        // Ensure today has data
        data[calendar.startOfDay(for: today)] = Int.random(in: 1...5)
        
        // Generate data for the past 2 years
        for day in 1..<730 {
            let date = calendar.date(byAdding: .day, value: -day, to: today)!
            let startOfDay = calendar.startOfDay(for: date)
            
            // Generate with higher probability for recent dates
            let probability = min(0.7, Double(180 - min(day, 180)) / 180.0)
            if Double.random(in: 0...1) < probability {
                let intensity = Int.random(in: 1...5)
                data[startOfDay] = intensity
            }
        }
        
        return data
    }
} 