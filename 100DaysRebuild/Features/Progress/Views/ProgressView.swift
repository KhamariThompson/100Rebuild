import SwiftUI
import Charts

struct ProgressView: View {
    @StateObject private var progressService = ProgressService.shared
    @EnvironmentObject var subscriptionService: SubscriptionService
    @State private var completionPercentage: Double = 0
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    if progressService.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let metrics = progressService.metrics {
                        // Motivational Section
                        VStack(spacing: 8) {
                            Text(metrics.streakEmoji)
                                .font(.system(size: 40))
                            
                            Text(metrics.motivationalText)
                                .font(.title2)
                                .foregroundColor(.theme.text)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.theme.surface)
                        )
                        .padding(.horizontal)
                        
                        // Completion Ring
                        VStack(spacing: 16) {
                            Text("Overall Progress")
                                .font(.headline)
                                .foregroundColor(.theme.text)
                            
                            ZStack {
                                Circle()
                                    .stroke(Color.theme.surface, lineWidth: 20)
                                    .frame(width: 200, height: 200)
                                
                                Circle()
                                    .trim(from: 0, to: completionPercentage)
                                    .stroke(
                                        AngularGradient(
                                            colors: [.theme.accent, .theme.accent.opacity(0.5)],
                                            center: .center
                                        ),
                                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                                    )
                                    .frame(width: 200, height: 200)
                                    .rotationEffect(.degrees(-90))
                                
                                VStack {
                                    Text("\(Int(completionPercentage * 100))%")
                                        .font(.title)
                                        .foregroundColor(.theme.text)
                                    Text("Complete")
                                        .font(.subheadline)
                                        .foregroundColor(.theme.subtext)
                                }
                            }
                            .onAppear {
                                withAnimation(.easeInOut(duration: 1.0)) {
                                    completionPercentage = metrics.completionRate
                                }
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.theme.surface)
                        )
                        .padding(.horizontal)
                        
                        // Core Metrics
                        VStack(spacing: 16) {
                            MetricCard(
                                title: "Total Challenges",
                                value: "\(metrics.totalChallenges)",
                                icon: "trophy.fill"
                            )
                            
                            MetricCard(
                                title: "Current Streak",
                                value: "\(metrics.currentStreak) days",
                                icon: "flame.fill"
                            )
                            
                            MetricCard(
                                title: "Longest Streak",
                                value: "\(metrics.longestStreak) days",
                                icon: "star.fill"
                            )
                            
                            MetricCard(
                                title: "Completion Rate",
                                value: "\(metrics.completionRatePercentage)%",
                                icon: "chart.bar.fill"
                            )
                        }
                        .padding(.horizontal)
                        
                        // Pro Features
                        if subscriptionService.isSubscribed {
                            // Streak Calendar
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Streak Calendar")
                                    .font(.headline)
                                    .foregroundColor(.theme.text)
                                
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                                    ForEach(0..<100) { day in
                                        Circle()
                                            .fill(day < metrics.totalDaysCompleted ? Color.theme.accent : Color.theme.surface)
                                            .frame(height: 8)
                                    }
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.theme.surface)
                            )
                            .padding(.horizontal)
                            
                            // Challenge Breakdown
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Challenge Breakdown")
                                    .font(.headline)
                                    .foregroundColor(.theme.text)
                                
                                Chart {
                                    ForEach(metrics.challengeBreakdown, id: \.title) { challenge in
                                        BarMark(
                                            x: .value("Progress", challenge.progress),
                                            y: .value("Challenge", challenge.title)
                                        )
                                        .foregroundStyle(Color.theme.accent)
                                    }
                                }
                                .frame(height: 200)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.theme.surface)
                            )
                            .padding(.horizontal)
                            
                            // Check-in History
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Check-in History")
                                    .font(.headline)
                                    .foregroundColor(.theme.text)
                                
                                Chart {
                                    ForEach(metrics.checkInHistory, id: \.date) { data in
                                        LineMark(
                                            x: .value("Date", data.date),
                                            y: .value("Check-ins", data.count)
                                        )
                                        .foregroundStyle(Color.theme.accent)
                                    }
                                }
                                .frame(height: 200)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.theme.surface)
                            )
                            .padding(.horizontal)
                        } else {
                            ProLockedView {
                                VStack(spacing: 16) {
                                    Text("Advanced Analytics")
                                        .font(.title3)
                                        .foregroundColor(.theme.text)
                                    
                                    Text("Track your progress with detailed charts and insights")
                                        .font(.subheadline)
                                        .foregroundColor(.theme.subtext)
                                        .multilineTextAlignment(.center)
                                    
                                    // Placeholder for charts
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.theme.surface)
                                        .frame(height: 200)
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.theme.surface)
                                )
                            }
                            .padding(.horizontal)
                        }
                    } else {
                        // No Data State
                        VStack(spacing: 16) {
                            Image(systemName: "chart.bar.xaxis")
                                .font(.system(size: 50))
                                .foregroundColor(.theme.subtext)
                            
                            Text("Start a challenge to see your progress!")
                                .font(.title3)
                                .foregroundColor(.theme.text)
                                .multilineTextAlignment(.center)
                            
                            Text("Create your first challenge and begin tracking your journey")
                                .font(.subheadline)
                                .foregroundColor(.theme.subtext)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.theme.surface)
                        )
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .background(Color.theme.background.ignoresSafeArea())
            .navigationTitle("Progress")
        }
        .task {
            await progressService.loadProgressMetrics()
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.theme.accent)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.theme.subtext)
                
                Text(value)
                    .font(.title3)
                    .foregroundColor(.theme.text)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.theme.surface)
        )
    }
}

// MARK: - Data Models
struct ChallengeBreakdown: Identifiable {
    let id = UUID()
    let title: String
    let progress: Double
}

struct CheckInData: Identifiable {
    let id = UUID()
    let date: Date
    let count: Int
} 