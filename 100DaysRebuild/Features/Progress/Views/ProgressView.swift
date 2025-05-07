import SwiftUI
import Charts
import FirebaseFirestore
import FirebaseAuth

// MARK: - Main View
struct ProgressView: View {
    @StateObject private var viewModel = UserProgressViewModel()
    @EnvironmentObject var subscriptionService: SubscriptionService
    @EnvironmentObject var notificationService: NotificationService
    
    var body: some View {
        NavigationView {
            ProgressContentView(viewModel: viewModel)
                .background(Color.theme.background.ignoresSafeArea())
                .navigationTitle("Progress")
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .task {
            await viewModel.loadData()
        }
    }
}

// MARK: - Content View
struct ProgressContentView: View {
    @ObservedObject var viewModel: UserProgressViewModel
    @EnvironmentObject var subscriptionService: SubscriptionService
    @EnvironmentObject var notificationService: NotificationService
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if viewModel.isLoading {
                    ProgressLoadingView()
                } else if viewModel.hasData {
                    // Free Tier Features
                    MotivationalHeaderView(streak: viewModel.currentStreak)
                    CompletionRingView(
                        completionPercentage: viewModel.completionPercentage,
                        animateOnAppear: true
                    )
                    MetricsSection(viewModel: viewModel)
                    
                    // Pro Tier Features
                    if subscriptionService.isProUser {
                        ProFeaturesSectionView(viewModel: viewModel)
                    } else {
                        ProgressProLockedView()
                    }
                } else {
                    EmptyStateView()
                }
            }
            .padding(.vertical, 16)
        }
    }
}

// MARK: - Free Features Components
struct ProgressLoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .frame(width: 60, height: 60)
            
            Text("Loading your progress data...")
                .font(.headline)
                .foregroundColor(.theme.subtext)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 100)
    }
}

struct MotivationalHeaderView: View {
    let streak: Int
    
    private var streakEmoji: String {
        switch streak {
        case 0...2: return "🔥"
        case 3...6: return "🔥🔥"
        case 7...13: return "🔥🔥🔥"
        case 14...20: return "🔥🔥🔥🔥"
        default: return "🔥🔥🔥🔥🔥"
        }
    }
    
    private var motivationalText: String {
        switch streak {
        case 0:
            return "Start your journey today!"
        case 1...3:
            return "Great start! Keep the momentum going."
        case 4...7:
            return "You're building a solid habit! Keep it up!"
        case 8...14:
            return "Impressive streak! You're making real progress."
        case 15...30:
            return "Incredible dedication! You're transforming your life!"
        default:
            return "You're unstoppable! This is life-changing commitment!"
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Text(streakEmoji)
                .font(.system(size: 48))
                .padding(.bottom, 4)
            
            Text(motivationalText)
                .font(.headline)
                .foregroundColor(.theme.text)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.theme.surface)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal, 16)
    }
}

struct CompletionRingView: View {
    let completionPercentage: Double
    var animateOnAppear: Bool = false
    @State private var animatedPercentage: Double = 0
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Overall Completion")
                .font(.headline)
                .foregroundColor(.theme.text)
            
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.theme.surface, lineWidth: 24)
                    .frame(width: 200, height: 200)
                
                // Foreground ring
                Circle()
                    .trim(from: 0, to: animateOnAppear ? animatedPercentage : completionPercentage)
                    .stroke(
                        AngularGradient(
                            colors: [.theme.accent, .theme.accent.opacity(0.7)],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 24, lineCap: .round)
                    )
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                
                // Percentage text
                VStack(spacing: 4) {
                    Text("\(Int(animateOnAppear ? (animatedPercentage * 100) : (completionPercentage * 100)))%")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.theme.text)
                    
                    Text("Complete")
                        .font(.subheadline)
                        .foregroundColor(.theme.subtext)
                }
            }
            .padding(.vertical, 16)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.theme.surface)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal, 16)
        .onAppear {
            if animateOnAppear {
                withAnimation(.easeInOut(duration: 1.5)) {
                    animatedPercentage = completionPercentage
                }
            }
        }
    }
}

struct MetricsSection: View {
    @ObservedObject var viewModel: UserProgressViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            MetricCard(
                title: "Total Challenges",
                value: "\(viewModel.totalChallenges)",
                icon: "trophy.fill"
            )
            
            MetricCard(
                title: "Current Streak",
                value: "\(viewModel.currentStreak) days",
                icon: "flame.fill"
            )
            
            MetricCard(
                title: "Longest Streak",
                value: "\(viewModel.longestStreak) days",
                icon: "star.fill"
            )
            
            MetricCard(
                title: "Completion Rate",
                value: "\(Int(viewModel.completionPercentage * 100))%",
                icon: "chart.bar.fill"
            )
            
            MetricCard(
                title: "Last Check-in",
                value: viewModel.lastCheckInDateFormatted,
                icon: "calendar.badge.clock"
            )
        }
        .padding(.horizontal, 16)
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.theme.accent)
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.theme.subtext)
                
                Text(value)
                    .font(.headline)
                    .foregroundColor(.theme.text)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.theme.surface)
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
}

// MARK: - Pro Features Components
struct ProFeaturesSectionView: View {
    @ObservedObject var viewModel: UserProgressViewModel
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Pro Analytics")
                .font(.title3.bold())
                .foregroundColor(.theme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 8)
            
            StreakCalendarView(
                checkInDays: viewModel.activityData
            )
            
            ChallengeProgressChart(
                challengeData: viewModel.challengeProgressData
            )
            
            CheckInHistoryChart(
                historyData: viewModel.dailyCheckInsData
            )
            
            CompletionForecastView(
                completionDate: viewModel.projectedCompletionDate,
                currentPace: viewModel.currentPace
            )
            
            BadgesView(badges: viewModel.earnedBadges)
        }
    }
}

struct StreakCalendarView: View {
    let checkInDays: [Date]
    @State private var monthsToShow = 3
    
    private var calendarStart: Date {
        let calendar = Calendar.current
        let today = Date()
        let startComponents = calendar.dateComponents([.year, .month], from: today)
        return calendar.date(from: startComponents)!
            .addingTimeInterval(-TimeInterval(86400 * 30 * (monthsToShow - 1)))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Activity Calendar")
                .font(.headline)
                .foregroundColor(.theme.text)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(0..<30*monthsToShow, id: \.self) { day in
                    let date = calendarStart.addingTimeInterval(TimeInterval(day * 86400))
                    let isCheckInDay = checkInDays.contains { Calendar.current.isDate($0, inSameDayAs: date) }
                    
                    Circle()
                        .fill(isCheckInDay ? Color.theme.accent : Color.theme.surface)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(Color.theme.surface.opacity(0.3), lineWidth: 1)
                        )
                }
            }
            .padding(8)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.theme.surface)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal, 16)
    }
}

struct ChallengeProgressChart: View {
    let challengeData: [ChallengeProgress]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Challenge Progress")
                .font(.headline)
                .foregroundColor(.theme.text)
            
            Chart {
                ForEach(challengeData) { challenge in
                    BarMark(
                        x: .value("Progress", challenge.completionPercentage),
                        y: .value("Challenge", challenge.title)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.theme.accent, .theme.accent.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                }
            }
            .frame(height: 180)
            .chartYAxis {
                AxisMarks(preset: .aligned) { value in
                    AxisValueLabel {
                        if let title = value.as(String.self) {
                            Text(title)
                                .font(.caption)
                                .foregroundColor(.theme.subtext)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                    AxisValueLabel {
                        if let percent = value.as(Int.self) {
                            Text("\(percent)%")
                                .font(.caption)
                                .foregroundColor(.theme.subtext)
                        }
                    }
                    AxisGridLine()
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.theme.surface)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal, 16)
    }
}

struct CheckInHistoryChart: View {
    let historyData: [DailyCheckIn]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Check-in Trend")
                .font(.headline)
                .foregroundColor(.theme.text)
            
            Chart {
                ForEach(historyData) { data in
                    LineMark(
                        x: .value("Date", data.date),
                        y: .value("Check-ins", data.count)
                    )
                    .foregroundStyle(Color.theme.accent)
                    .symbol {
                        Circle()
                            .fill(Color.theme.accent)
                            .frame(width: 8, height: 8)
                    }
                    .interpolationMethod(.catmullRom)
                    
                    AreaMark(
                        x: .value("Date", data.date),
                        y: .value("Check-ins", data.count)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.theme.accent.opacity(0.3), .theme.accent.opacity(0.01)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
            }
            .frame(height: 180)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 5)) { value in
                    AxisValueLabel(format: .dateTime.day().month())
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.theme.surface)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal, 16)
    }
}

struct CompletionForecastView: View {
    let completionDate: Date?
    let currentPace: String
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Completion Forecast")
                .font(.headline)
                .foregroundColor(.theme.text)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 16) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.title2)
                        .foregroundColor(.theme.accent)
                        .frame(width: 32, height: 32)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Projected Completion")
                            .font(.subheadline)
                            .foregroundColor(.theme.subtext)
                        
                        Text(completionDate != nil ? dateFormatter.string(from: completionDate!) : "Not enough data")
                            .font(.headline)
                            .foregroundColor(.theme.text)
                    }
                }
                
                HStack(alignment: .top, spacing: 16) {
                    Image(systemName: "speedometer")
                        .font(.title2)
                        .foregroundColor(.theme.accent)
                        .frame(width: 32, height: 32)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current Pace")
                            .font(.subheadline)
                            .foregroundColor(.theme.subtext)
                        
                        Text(currentPace)
                            .font(.headline)
                            .foregroundColor(.theme.text)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.theme.surface)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal, 16)
    }
}

struct BadgesView: View {
    let badges: [Badge]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Earned Badges")
                .font(.headline)
                .foregroundColor(.theme.text)
            
            if badges.isEmpty {
                Text("Complete challenges to earn badges!")
                    .font(.subheadline)
                    .foregroundColor(.theme.subtext)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(badges) { badge in
                        BadgeItemView(badge: badge)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.theme.surface)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal, 16)
    }
}

struct BadgeItemView: View {
    let badge: Badge
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: badge.iconName)
                .font(.system(size: 32))
                .foregroundColor(.theme.accent)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(Color.theme.accent.opacity(0.1))
                )
            
            Text(badge.title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.theme.text)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(height: 100)
        .padding(8)
    }
}

struct ProgressProLockedView: View {
    @EnvironmentObject var subscriptionService: SubscriptionService
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.theme.accent.opacity(0.7))
                
                Text("Unlock Advanced Analytics")
                    .font(.title3.bold())
                    .foregroundColor(.theme.text)
                
                Text("Get detailed insights, challenge breakdowns, and predictive analysis with 100Days Pro.")
                    .font(.subheadline)
                    .foregroundColor(.theme.subtext)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 8)
            
            Button(action: {
                subscriptionService.showPaywall = true
            }) {
                Text("Upgrade to Pro")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.theme.accent)
                            .shadow(color: Color.theme.accent.opacity(0.4), radius: 8, x: 0, y: 4)
                    )
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.theme.surface)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal, 16)
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 64))
                .foregroundColor(.theme.accent.opacity(0.7))
                .padding(.bottom, 8)
            
            Text("No Progress Data Yet")
                .font(.title3.bold())
                .foregroundColor(.theme.text)
            
            Text("Start a challenge and check in regularly to see your progress analytics here.")
                .font(.body)
                .foregroundColor(.theme.subtext)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
            
            NavigationLink(destination: ChallengesView()) {
                Text("Start a Challenge")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.theme.accent)
                    )
                    .padding(.horizontal, 32)
            }
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.theme.surface)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal, 16)
    }
}

// MARK: - Data Models
@MainActor
class UserProgressViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var hasData = false
    
    // Free tier metrics
    @Published var totalChallenges = 0
    @Published var currentStreak = 0
    @Published var longestStreak = 0
    @Published var completionPercentage: Double = 0.0
    @Published var lastCheckInDate: Date? = nil
    
    // Pro tier data
    @Published var activityData: [Date] = []
    @Published var challengeProgressData: [ChallengeProgress] = []
    @Published var dailyCheckInsData: [DailyCheckIn] = []
    @Published var projectedCompletionDate: Date? = nil
    @Published var currentPace = "0 days/week"
    @Published var earnedBadges: [Badge] = []
    
    // Firestore reference
    private let firestore = Firestore.firestore()
    
    var lastCheckInDateFormatted: String {
        guard let date = lastCheckInDate else { return "No check-ins yet" }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    func loadData() async {
        isLoading = true
        hasData = false
        
        // Check for authenticated user
        guard let userId = Auth.auth().currentUser?.uid else {
            isLoading = false
            return
        }
        
        do {
            // Fetch user challenges from Firestore
            let challenges = try await loadChallenges(for: userId)
            
            if challenges.isEmpty {
                // No data yet
                isLoading = false
                hasData = false
                return
            }
            
            // Calculate metrics
            totalChallenges = challenges.count
            currentStreak = calculateCurrentStreak(challenges)
            longestStreak = calculateLongestStreak(challenges)
            completionPercentage = calculateCompletionRate(challenges)
            lastCheckInDate = findLastCheckInDate(challenges)
            
            // Pro features data
            await loadProFeaturesData(from: challenges)
            
            isLoading = false
            hasData = true
        } catch {
            print("Error loading progress data: \(error.localizedDescription)")
            isLoading = false
            hasData = false
        }
    }
    
    private func loadChallenges(for userId: String) async throws -> [Challenge] {
        let snapshot = try await firestore
            .collection("users")
            .document(userId)
            .collection("challenges")
            .getDocuments()
        
        return try snapshot.documents.compactMap { document in
            try document.data(as: Challenge.self)
        }
    }
    
    private func calculateCurrentStreak(_ challenges: [Challenge]) -> Int {
        // Find the highest active streak
        return challenges
            .filter { !$0.hasStreakExpired }
            .map { $0.streakCount }
            .max() ?? 0
    }
    
    private func calculateLongestStreak(_ challenges: [Challenge]) -> Int {
        // Get the highest streak count across all challenges
        return challenges.map { $0.streakCount }.max() ?? 0
    }
    
    private func calculateCompletionRate(_ challenges: [Challenge]) -> Double {
        guard !challenges.isEmpty else { return 0.0 }
        
        let totalDaysCompleted = challenges.reduce(0) { $0 + $1.daysCompleted }
        let totalPossibleDays = challenges.count * 100 // Each challenge is 100 days
        
        return Double(totalDaysCompleted) / Double(totalPossibleDays)
    }
    
    private func findLastCheckInDate(_ challenges: [Challenge]) -> Date? {
        // Find the most recent check-in date
        return challenges.compactMap { $0.lastCheckInDate }.max()
    }
    
    private func loadProFeaturesData(from challenges: [Challenge]) async {
        // Activity data - collect all dates where any check-ins occurred
        let allCheckInDates = challenges.compactMap { challenge in
            // For each challenge, reconstruct all check-in dates
            // In a real app, we'd store this as a subcollection in Firestore
            var dates: [Date] = []
            if let lastDate = challenge.lastCheckInDate {
                dates.append(lastDate)
            }
            return dates
        }.flatMap { $0 }
        
        activityData = allCheckInDates
        
        // Challenge progress data
        challengeProgressData = challenges.map { challenge in
            ChallengeProgress(
                title: challenge.title,
                completionPercentage: Int(challenge.progressPercentage * 100)
            )
        }
        
        // Daily check-ins (last 30 days)
        let calendar = Calendar.current
        let today = Date()
        
        // Create a dictionary to count check-ins by date
        var checkInsByDate: [Date: Int] = [:]
        
        for date in allCheckInDates {
            // Only include last 30 days
            if let daysAgo = calendar.dateComponents([.day], from: date, to: today).day, daysAgo <= 30 {
                // Normalize date to remove time component
                let normalizedDate = calendar.startOfDay(for: date)
                checkInsByDate[normalizedDate, default: 0] += 1
            }
        }
        
        // Convert to array sorted by date
        dailyCheckInsData = checkInsByDate.map { 
            DailyCheckIn(date: $0.key, count: $0.value) 
        }.sorted { $0.date < $1.date }
        
        // Projected completion date calculation
        calculateProjectedCompletionDate(challenges)
        
        // Badges calculation
        calculateEarnedBadges(challenges)
    }
    
    private func calculateProjectedCompletionDate(_ challenges: [Challenge]) {
        guard !challenges.isEmpty else {
            projectedCompletionDate = nil
            currentPace = "0 days/week"
            return
        }
        
        // Get incomplete challenges
        let incompleteChallenges = challenges.filter { !$0.isCompleted }
        if incompleteChallenges.isEmpty {
            projectedCompletionDate = nil
            currentPace = "All completed"
            return
        }
        
        // Calculate average check-ins per week over the last month
        let checkInsLast30Days = dailyCheckInsData.reduce(0) { $0 + $1.count }
        let weeklyRate = Double(checkInsLast30Days) / 4.0 // 30 days ≈ 4 weeks
        
        if weeklyRate <= 0 {
            projectedCompletionDate = nil
            currentPace = "0 days/week"
            return
        }
        
        // Calculate days remaining
        let totalDaysRemaining = incompleteChallenges.reduce(0) { $0 + $1.daysRemaining }
        
        // Estimate days to completion
        let weeksToCompletion = Double(totalDaysRemaining) / weeklyRate
        let daysToCompletion = weeksToCompletion * 7
        
        // Calculate projected date
        projectedCompletionDate = Calendar.current.date(byAdding: .day, value: Int(daysToCompletion), to: Date())
        
        // Format current pace
        let formattedPace = String(format: "%.1f", weeklyRate)
        currentPace = "\(formattedPace) days/week"
    }
    
    private func calculateEarnedBadges(_ challenges: [Challenge]) {
        var badges: [Badge] = []
        
        // Streak badges
        if longestStreak >= 7 {
            badges.append(Badge(id: 1, title: "7-Day Streak", iconName: "flame.fill"))
        }
        if longestStreak >= 30 {
            badges.append(Badge(id: 2, title: "30-Day Streak", iconName: "flame.fill"))
        }
        
        // Completion badges
        let completedChallenges = challenges.filter { $0.isCompleted }.count
        if completedChallenges > 0 {
            badges.append(Badge(id: 3, title: "First Completion", iconName: "checkmark.circle.fill"))
        }
        if completedChallenges >= 3 {
            badges.append(Badge(id: 4, title: "Triple Completion", iconName: "checkmark.circle.fill"))
        }
        
        // Progress badges
        if completionPercentage >= 0.25 {
            badges.append(Badge(id: 5, title: "25% Complete", iconName: "chart.bar.fill"))
        }
        if completionPercentage >= 0.50 {
            badges.append(Badge(id: 6, title: "50% Complete", iconName: "chart.bar.fill"))
        }
        if completionPercentage >= 0.75 {
            badges.append(Badge(id: 7, title: "75% Complete", iconName: "chart.bar.fill"))
        }
        
        // Consistency badge
        if totalChallenges > 0 && !challenges.contains(where: { $0.hasStreakExpired }) {
            badges.append(Badge(id: 8, title: "Perfect Consistency", iconName: "star.fill"))
        }
        
        earnedBadges = badges
    }
}

// MARK: - Model Structs
struct ChallengeProgress: Identifiable {
    let id = UUID()
    let title: String
    let completionPercentage: Int
}

struct DailyCheckIn: Identifiable {
    let id = UUID()
    let date: Date
    let count: Int
}

struct Badge: Identifiable {
    let id: Int
    let title: String
    let iconName: String
}

// MARK: - Preview
struct ProgressView_Previews: PreviewProvider {
    static var previews: some View {
        ProgressView()
            .environmentObject(SubscriptionService.shared)
    }
} 