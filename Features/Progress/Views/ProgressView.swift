import SwiftUI
import Firebase
import FirebaseFirestoreSwift

struct ProgressView: View {
    @StateObject private var viewModel = UserProgressViewModel()
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        ZStack {
            // Background
            Color.theme.background
                .ignoresSafeArea()
            
            // Content based on state
            if viewModel.isLoading {
                loadingView
            } else if let errorMessage = viewModel.errorMessage {
                errorView(message: errorMessage)
            } else if viewModel.hasData {
                progressContentView
            } else {
                emptyStateView
            }
        }
        .onAppear {
            // When the view appears, ensure Firebase is properly initialized
            FirebaseService.shared.configureIfNeeded()
            
            // Start loading data
            Task {
                await viewModel.loadData()
            }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                // Refresh when app becomes active
                Task { await viewModel.loadData() }
            }
        }
        // Listen for network changes
        .onReceive(NotificationCenter.default.publisher(for: .networkStatusChanged)) { notification in
            if let isConnected = notification.userInfo?["isConnected"] as? Bool, isConnected {
                // Reload data when network becomes available
                Task { await viewModel.loadData() }
            }
        }
    }
    
    // Loading view with progress indicator
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading your progress...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }
    
    // Error view with retry button
    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.yellow)
            
            Text(message)
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if NetworkMonitor.shared.isConnected {
                Button("Try Again") {
                    Task { await viewModel.loadData() }
                }
                .buttonStyle(.borderedProminent)
            } else {
                HStack {
                    Image(systemName: "wifi.slash")
                    Text("You're offline")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top)
            }
        }
        .padding()
    }
    
    // Empty state when no data is available
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.bar")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text("No progress data yet")
                .font(.headline)
            
            Text("Complete challenges to see your progress.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    // Main content view
    private var progressContentView: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Progress Dashboard")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.top)
                
                // Progress metrics
                progressMetricsView
                
                // Badges section
                badgesView
                
                Spacer()
            }
            .padding()
        }
    }
    
    // Progress metrics section
    private var progressMetricsView: some View {
        VStack(spacing: 16) {
            // Top metrics cards
            HStack(spacing: 12) {
                MetricCard(
                    title: "Total Challenges",
                    value: "\(viewModel.totalChallenges)",
                    icon: "list.bullet"
                )
                
                MetricCard(
                    title: "Current Streak",
                    value: "\(viewModel.currentStreak) days",
                    icon: "flame.fill"
                )
            }
            
            // Bottom metrics cards
            HStack(spacing: 12) {
                MetricCard(
                    title: "Longest Streak",
                    value: "\(viewModel.longestStreak) days",
                    icon: "star.fill"
                )
                
                MetricCard(
                    title: "Completion",
                    value: "\(Int(viewModel.completionPercentage * 100))%",
                    icon: "chart.bar.fill"
                )
            }
        }
    }
    
    // Badges section
    private var badgesView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Achievements")
                .font(.headline)
                .padding(.top, 8)
            
            if viewModel.earnedBadges.isEmpty {
                Text("Complete challenges to earn badges")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(viewModel.earnedBadges) { badge in
                        ProgressBadgeCard(badge: badge)
                    }
                }
            }
        }
        .padding()
        .background(Color.theme.surface)
        .cornerRadius(12)
    }
}

// MARK: - Supporting Views

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.theme.accent)
                
                Text(title)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.theme.surface)
        .cornerRadius(12)
    }
}

// MARK: - Badge Card

struct ProgressBadgeCard: View {
    let badge: ProgressBadge
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: badge.iconName)
                .font(.system(size: 30))
                .foregroundColor(.theme.accent)
            
            Text(badge.title)
                .font(.caption)
                .foregroundColor(.theme.text)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.theme.surface)
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
}

// MARK: - View Model

@MainActor
class UserProgressViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var hasData = false
    @Published var errorMessage: String?
    
    // Free tier metrics
    @Published var totalChallenges = 0
    @Published var currentStreak = 0
    @Published var longestStreak = 0
    @Published var completionPercentage: Double = 0.0
    @Published var lastCheckInDate: Date? = nil
    
    // Pro tier data
    @Published var activityData: [Date] = []
    @Published var challengeProgressData: [ProgressChallengeItem] = []
    @Published var dailyCheckInsData: [ProgressDailyCheckIn] = []
    @Published var projectedCompletionDate: Date? = nil
    @Published var currentPace = "0 days/week"
    @Published var earnedBadges: [ProgressBadge] = []
    @Published var dateIntensityMap: [Date: Int] = [:]
    
    // Firestore reference
    private let firestore = Firestore.firestore()
    private var loadDataTask: Task<Void, Never>?
    private var retryCount = 0
    private let maxRetries = 3
    
    // Cancel any running tasks when the view model is deinitialized
    deinit {
        loadDataTask?.cancel()
    }
    
    // Load data from Firestore with proper async handling and timeouts
    func loadData() async {
        // Cancel any previous task
        loadDataTask?.cancel()
        errorMessage = nil
        
        // Check Firebase availability first
        let firebaseReady = await FirebaseAvailabilityService.shared.waitForFirebase()
        if !firebaseReady {
            await MainActor.run {
                self.errorMessage = "Firebase services unavailable. Please try again later."
                self.isLoading = false
            }
            return
        }
        
        // Check authentication
        guard let userId = Auth.auth().currentUser?.uid else {
            print("DEBUG: Progress - no user ID, aborting load")
            await MainActor.run {
                self.errorMessage = "You need to be signed in to view progress."
                self.isLoading = false
            }
            return
        }
        
        print("DEBUG: Progress - starting data load (attempt \(retryCount + 1))")
        await MainActor.run { self.isLoading = true }
        
        loadDataTask = Task {
            do {
                // Create timeout task
                let timeoutTask = Task {
                    do {
                        try await Task.sleep(nanoseconds: 8_000_000_000) // 8 second timeout
                        if !Task.isCancelled {
                            print("DEBUG: Progress - load operation timed out")
                            if retryCount < maxRetries {
                                retryCount += 1
                                print("DEBUG: Progress - retrying (\(retryCount)/\(maxRetries))")
                                await loadData() // Retry
                            } else {
                                loadDataTask?.cancel()
                                await MainActor.run {
                                    self.loadFallbackData()
                                    self.errorMessage = "Unable to load data after several attempts."
                                    self.isLoading = false
                                }
                            }
                        }
                    } catch {
                        // Handle potential task cancellation
                        print("DEBUG: Progress - timeout task cancelled")
                    }
                }
                
                // Try to load actual data from Firestore
                print("DEBUG: Progress - querying Firestore")
                let challengesRef = firestore
                    .collection("users")
                    .document(userId)
                    .collection("challenges")
                    .whereField("isArchived", isEqualTo: false)
                
                // Add network condition check
                if !NetworkMonitor.shared.isConnected {
                    print("DEBUG: Progress - network offline, trying cached data")
                }
                
                // Perform the actual Firestore query
                let snapshot = try await challengesRef.getDocuments()
                
                // Cancel the timeout task since we got a response
                timeoutTask.cancel()
                
                if Task.isCancelled { return }
                
                // Process the challenge data
                let challenges = snapshot.documents.compactMap { doc -> Challenge? in
                    try? doc.data(as: Challenge.self)
                }
                
                print("DEBUG: Progress - loaded \(challenges.count) challenges")
                
                if Task.isCancelled { return }
                
                // Calculate stats
                let totalChallenges = challenges.count
                let currentStreak = calculateCurrentStreak(challenges)
                let longestStreak = calculateLongestStreak(challenges)
                let completionPercentage = calculateCompletionRate(challenges)
                let badges = calculateBadges(challenges)
                
                if Task.isCancelled { return }
                
                // Update the UI on the main thread
                await MainActor.run {
                    self.totalChallenges = totalChallenges
                    self.currentStreak = currentStreak
                    self.longestStreak = longestStreak
                    self.completionPercentage = completionPercentage
                    self.earnedBadges = badges
                    
                    self.hasData = true
                    self.isLoading = false
                }
                
                // Reset retry count on success
                retryCount = 0
                
                print("DEBUG: Progress - data processed successfully")
            } catch let error as NSError {
                if !Task.isCancelled {
                    print("ERROR: Progress - Firestore query failed: \(error.localizedDescription)")
                    
                    // Handle different error types
                    if error.domain == FirestoreErrorDomain {
                        switch error.code {
                        case 7: // Unavailable 
                            if retryCount < maxRetries {
                                retryCount += 1
                                // Exponential backoff
                                try? await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(retryCount))) * 1_000_000_000)
                                await loadData() // Retry with backoff
                                return
                            }
                        default:
                            break
                        }
                    }
                    
                    // Fall back to sample data for any error after retries
                    await MainActor.run {
                        self.loadFallbackData()
                        self.errorMessage = "Could not load your progress data: \(error.localizedDescription)"
                        self.isLoading = false
                    }
                }
            }
        }
    }
    
    // Helper to load fallback data when Firestore fails
    private func loadFallbackData() {
        print("DEBUG: Progress - loading fallback data")
        
        // Set minimal sample data
        totalChallenges = 0
        currentStreak = 0
        longestStreak = 0
        completionPercentage = 0.0
        
        // Empty badges array
        earnedBadges = []
        
        // Set hasData to true to avoid loading spinner
        hasData = true
    }
    
    // Calculate current streak from challenge data
    private func calculateCurrentStreak(_ challenges: [Challenge]) -> Int {
        // Get max streak from active challenges
        let activeStreaks = challenges.filter { !$0.hasStreakExpired }
        return activeStreaks.map { $0.streakCount }.max() ?? 0
    }
    
    // Calculate longest streak from challenge data
    private func calculateLongestStreak(_ challenges: [Challenge]) -> Int {
        return challenges.map { $0.streakCount }.max() ?? 0
    }
    
    // Calculate completion rate
    private func calculateCompletionRate(_ challenges: [Challenge]) -> Double {
        guard challenges.count > 0 else { return 0.0 }
        
        let totalCompletedDays = challenges.reduce(0) { $0 + $1.daysCompleted }
        let totalPossibleDays = challenges.count * 100
        
        return Double(totalCompletedDays) / Double(totalPossibleDays)
    }
    
    // Calculate badges from Challenge objects
    private func calculateBadges(_ challenges: [Challenge]) -> [ProgressBadge] {
        var badges: [ProgressBadge] = []
        
        // Streak badges
        if longestStreak >= 7 {
            badges.append(ProgressBadge(id: 1, title: "7-Day Streak", iconName: "flame.fill"))
        }
        if longestStreak >= 30 {
            badges.append(ProgressBadge(id: 2, title: "30-Day Streak", iconName: "flame.fill"))
        }
        
        // Completion badges
        let completedChallenges = challenges.filter { $0.isCompleted }.count
        if completedChallenges > 0 {
            badges.append(ProgressBadge(id: 3, title: "First Completion", iconName: "checkmark.circle.fill"))
        }
        if completedChallenges >= 3 {
            badges.append(ProgressBadge(id: 4, title: "Triple Completion", iconName: "checkmark.circle.fill"))
        }
        
        // Progress badges
        if completionPercentage >= 0.25 {
            badges.append(ProgressBadge(id: 5, title: "25% Complete", iconName: "chart.bar.fill"))
        }
        if completionPercentage >= 0.50 {
            badges.append(ProgressBadge(id: 6, title: "50% Complete", iconName: "chart.bar.fill"))
        }
        if completionPercentage >= 0.75 {
            badges.append(ProgressBadge(id: 7, title: "75% Complete", iconName: "chart.bar.fill"))
        }
        
        // Consistency badge
        if totalChallenges > 0 && !challenges.contains(where: { $0.hasStreakExpired }) {
            badges.append(ProgressBadge(id: 8, title: "Perfect Consistency", iconName: "star.fill"))
        }
        
        return badges
    }
}

// MARK: - Model Types

struct ProgressBadge: Identifiable {
    let id: Int
    let title: String
    let iconName: String
}

struct ProgressChallengeItem: Identifiable {
    let id: String
    let title: String
    let daysCompleted: Int
    let totalDays: Int
    let isActive: Bool
}

struct ProgressDailyCheckIn: Identifiable {
    let id: String
    let date: Date
    let challengeCount: Int
}

// Preview
struct ProgressView_Previews: PreviewProvider {
    static var previews: some View {
        ProgressView()
    }
}

// MARK: - Color Theme Extension

extension Color {
    static let theme = ColorTheme()
}

struct ColorTheme {
    let accent = Color("AccentColor")
    let background = Color("Background")
    let surface = Color("Surface")
    let text = Color("Text")
} 