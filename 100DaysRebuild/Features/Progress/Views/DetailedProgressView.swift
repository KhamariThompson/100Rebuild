import SwiftUI
import FirebaseFirestore

// Using a different name to avoid conflicts with ProgressContentView in ProgressView.swift
struct DetailedProgressView: View {
    @ObservedObject var viewModel: UPViewModel
    @EnvironmentObject var subscriptionService: SubscriptionService
    @EnvironmentObject var notificationService: NotificationService
    @EnvironmentObject var router: NavigationRouter
    @Binding var showAnalytics: Bool
    
    var body: some View {
        ZStack {
            // Background
            Color.theme.background.ignoresSafeArea()
            
            // Full screen loading view when initially loading
            if viewModel.isInitialLoad {
                fullScreenLoadingView
                    .transition(.opacity)
            } 
            // Main content
            else {
                ScrollView {
                    VStack(spacing: AppSpacing.sectionSpacing) {
                        if viewModel.hasData {
                            VStack(spacing: AppSpacing.sectionSpacing) {
                                // Stats Section
                                statsSection
                                
                                // Journey Carousel (Your Journey So Far)
                                JourneyCarouselView(viewModel: viewModel)

                                // Daily Spark
                                dailySparkSection
                                
                                // Projected Completion (Your Pace) - Pro Feature
                                projectedCompletionSection
                                
                                // Consistency Graph - Pro Feature
                                consistencyGraphSection
                                
                                // Activity Heatmap (Pro Feature)
                                heatmapSection
                                
                                // Badges Section
                                badgesSection
                                
                                // Add padding at the bottom for better scrolling
                                Spacer().frame(height: AppSpacing.m)
                            }
                            .transition(.opacity)
                        } else if let error = viewModel.errorMessage {
                            errorState(message: error)
                                .transition(.opacity)
                        } else {
                            emptyState
                                .transition(.opacity)
                        }
                    }
                    .padding(.vertical)
                }
                .refreshable {
                    await viewModel.loadData(forceRefresh: true)
                }
                .transition(.opacity)
            }
            
            // Overlay loading indicator when refreshing with existing data
            if viewModel.isLoading && viewModel.hasData && !viewModel.isInitialLoad {
                VStack {
                    SwiftUI.ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)
                        .padding()
                }
                .frame(width: 100, height: 100)
                .background(
                    RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                        .fill(Color.theme.surface.opacity(0.8))
                        .shadow(color: Color.theme.shadow, radius: 8, x: 0, y: 2)
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.isInitialLoad) 
        .animation(.easeInOut(duration: 0.3), value: viewModel.isLoading)
        .animation(.easeInOut(duration: 0.3), value: viewModel.hasData)
        .animation(.easeInOut(duration: 0.3), value: viewModel.errorMessage != nil)
    }
    
    // MARK: - Loading View
    private var fullScreenLoadingView: some View {
        VStack(spacing: 24) {
            // Loading animation container
            ZStack {
                // Pulsating background circle
                Circle()
                    .fill(Color.theme.accent.opacity(0.1))
                    .frame(width: 120, height: 120)
                    .scaleEffect(viewModel.isInitialLoad ? 1.1 : 0.9)
                    .animation(
                        Animation.easeInOut(duration: 1.2)
                            .repeatForever(autoreverses: true),
                        value: viewModel.isInitialLoad
                    )
                    .onAppear { viewModel.isInitialLoad = true }
                
                // Loading spinner
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color.theme.accent))
                    .scaleEffect(1.8)
                    .padding(30)
            }
            
            VStack(spacing: 12) {
                // Main loading text
                Text("Loading your progress...")
                    .font(.system(size: 22, weight: .medium, design: .rounded))
                    .foregroundColor(.theme.text)
                    .padding(.top, 8)
                
                // Informational text with friendlier wording
                Text("We're gathering your achievements and streaks.")
                    .font(.subheadline)
                    .foregroundColor(.theme.subtext)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .opacity(0.9)
                
                // Loading indicators row
                HStack(spacing: 24) {
                    LoadingStepIndicator(title: "Stats", isCompleted: true)
                    LoadingStepIndicator(title: "Streaks", isCompleted: true)
                    LoadingStepIndicator(title: "Charts", isCompleted: false, isAnimating: true)
                }
                .padding(.top, 12)
            }
            
            // Fallback or skip option with better styling
            // Only show after a 3 second delay
            FallbackButton(isShowing: viewModel.isInitialLoad) {
                // Provide fallback to sample data with animation
                withAnimation(.easeInOut(duration: 0.4)) {
                    viewModel.hasData = true
                    viewModel.isInitialLoad = false
                    viewModel.isLoading = false
                }
            }
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.theme.background)
    }
    
    // MARK: - Stats Section
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            // Enhanced section title with icon
            HStack(spacing: AppSpacing.s) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: AppSpacing.iconSizeMedium, weight: .semibold))
                    .foregroundColor(.theme.accent)
                
                Text("Your Progress")
                    .font(AppTypography.title3())
                    .foregroundColor(.theme.text)
            }
            .padding(.horizontal, AppSpacing.xxs)
            .padding(.bottom, AppSpacing.xxs)
            
            // Stats grid with responsive layout
            VStack(spacing: AppSpacing.m) {
                HStack(spacing: AppSpacing.m) {
                    StatCard(title: "Current Streak", value: "\(viewModel.currentStreak)", icon: "flame.fill", color: .orange)
                    StatCard(title: "Longest Streak", value: "\(viewModel.longestStreak)", icon: "trophy.fill", color: .yellow)
                }
                
                HStack(spacing: AppSpacing.m) {
                    StatCard(title: "Completion", value: "\(Int(viewModel.completionPercentage * 100))%", icon: "chart.pie.fill", color: .theme.accent)
                    StatCard(title: "Challenges", value: "\(viewModel.totalChallenges)", icon: "checklist", color: .green)
                }
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                .fill(Color.theme.surface)
                .shadow(color: Color.theme.shadow, radius: 8, x: 0, y: 2)
        )
        .padding(.horizontal, AppSpacing.screenHorizontalPadding)
    }
    
    // MARK: - Activity Heatmap Section
    private var heatmapSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            HStack(spacing: AppSpacing.s) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: AppSpacing.iconSizeMedium, weight: .semibold))
                    .foregroundColor(.theme.accent)
                
                Text("Activity")
                    .font(AppTypography.title3())
                    .foregroundColor(.theme.text)
            }
            
            if subscriptionService.isProUser {
                if viewModel.dateIntensityMap.isEmpty {
                    Text("No activity data available yet")
                        .foregroundColor(.theme.subtext)
                        .frame(height: 140, alignment: .center)
                        .frame(maxWidth: .infinity)
                } else {
                    // Show the heatmap directly for Pro users
                    ActivityHeatmapView(dateIntensityMap: viewModel.dateIntensityMap)
                        .frame(height: 140)
                }
            } else {
                // Show locked view for free users
                ProLockedView {
                    ActivityHeatmapView(dateIntensityMap: viewModel.dateIntensityMap)
                        .frame(height: 140)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.theme.surface)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal)
    }
    
    // MARK: - Badges Section
    private var badgesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Badges")
                .font(.title3)
                .foregroundColor(.theme.text)
            
            if viewModel.earnedBadges.isEmpty {
                Text("You haven't earned any badges yet")
                    .foregroundColor(.theme.subtext)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 16) {
                    ForEach(viewModel.earnedBadges) { badge in
                        ProgressBadgeCard(badge: badge)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.theme.surface)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal)
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 28) {
            // Empty state illustration
            ZStack {
                Circle()
                    .fill(Color.theme.accent.opacity(0.1))
                    .frame(width: 110, height: 110)
                
                Image(systemName: "chart.bar")
                    .font(.system(size: 40))
                    .foregroundColor(Color.theme.accent)
            }
            
            VStack(spacing: 16) {
                Text("No Progress Data Yet")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                
                Text("Start tracking your challenges to visualize your progress and journey.")
                    .font(.subheadline)
                    .foregroundColor(.theme.subtext)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
            }
            
            Button(action: {
                // Add haptic feedback
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                
                // Navigate to challenges tab with animation
                withAnimation {
                    router.changeTab(to: 0)
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Start a Challenge")
                        .font(.headline)
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.theme.accent, Color.theme.accent.opacity(0.8)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(16)
                .shadow(color: Color.theme.accent.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(AppScaleButtonStyle())
            .padding(.top, 8)
        }
        .padding(36)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.theme.surface)
                .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 6)
        )
        .padding(.horizontal, 20)
        .padding(.vertical, 40)
    }
    
    // MARK: - Error State
    private func errorState(message: String) -> some View {
        VStack(spacing: 28) {
            // Error icon
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.1))
                    .frame(width: 110, height: 110)
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundColor(.red.opacity(0.8))
            }
            
            VStack(spacing: 16) {
                Text("Unable to Load Progress")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.theme.subtext)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
            }
            
            VStack(spacing: 16) {
                // Primary action button
                Button(action: {
                    // Add haptic feedback
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    
                    // Try loading again
                    Task {
                        await viewModel.loadData(forceRefresh: true)
                    }
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Try Again")
                            .font(.headline)
                    }
                    .frame(height: 50)
                    .frame(minWidth: 180)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.theme.accent)
                            .shadow(color: Color.theme.accent.opacity(0.3), radius: 8, x: 0, y: 4)
                    )
                    .foregroundColor(.white)
                }
                .buttonStyle(AppScaleButtonStyle())
                
                // Secondary action button
                Button(action: {
                    // Add haptic feedback
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    
                    // Load sample data with animation
                    withAnimation(.easeInOut(duration: 0.4)) {
                        viewModel.hasData = true
                        viewModel.errorMessage = nil
                        viewModel.isInitialLoad = false
                        viewModel.isLoading = false
                    }
                }) {
                    Text("Continue with Sample Data")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.theme.accent)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.theme.accent.opacity(0.5), lineWidth: 1)
                        )
                }
                .buttonStyle(AppScaleButtonStyle())
            }
        }
        .padding(36)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.theme.surface)
                .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 6)
        )
        .padding(.horizontal, 20)
        .padding(.vertical, 40)
    }
    
    // MARK: - Daily Spark Section
    private var dailySparkSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Daily Spark")
                .font(.title3)
                .foregroundColor(.theme.text)
            
            DailySparkView(currentStreak: viewModel.currentStreak, completionPercentage: viewModel.completionPercentage)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.theme.surface)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal)
    }
    
    // MARK: - Projected Completion Section
    private var projectedCompletionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Pace")
                .font(.title3)
                .foregroundColor(.theme.text)
            
            if subscriptionService.isProUser {
                if let projectedDate = viewModel.projectedCompletionDate {
                    ProjectedCompletionView(
                        projectedDate: projectedDate,
                        currentPace: viewModel.currentPace,
                        completionPercentage: viewModel.completionPercentage
                    )
                } else {
                    Text("Not enough data to predict completion date yet")
                        .foregroundColor(.theme.subtext)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                }
            } else {
                // Show locked view for free users
                ProLockedView {
                    ProjectedCompletionView(
                        projectedDate: Date().addingTimeInterval(60*60*24*30), // Example date - 30 days from now
                        currentPace: "4.5 days/week",
                        completionPercentage: 0.35
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.theme.surface)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal)
    }
    
    // MARK: - Consistency Graph Section
    private var consistencyGraphSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Consistency Graph")
                .font(.title3)
                .foregroundColor(.theme.text)
            
            if subscriptionService.isProUser {
                if viewModel.dailyCheckInsData.isEmpty {
                    Text("Not enough data to show consistency graph yet")
                        .foregroundColor(.theme.subtext)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                } else {
                    ConsistencyGraphView(dailyCheckIns: viewModel.dailyCheckInsData)
                        .frame(height: 200)
                }
            } else {
                // Show locked view for free users
                ProLockedView {
                    ConsistencyGraphView(dailyCheckIns: generateSampleCheckInData())
                        .frame(height: 200)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.theme.surface)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal)
    }
    
    // Helper function to generate sample data for locked preview
    private func generateSampleCheckInData() -> [ProgressDailyCheckIn] {
        let calendar = Calendar.current
        var sampleData: [ProgressDailyCheckIn] = []
        
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: -i, to: Date()) {
                let count = Int.random(in: 0...3)
                sampleData.append(ProgressDailyCheckIn(date: date, count: count))
            }
        }
        
        return sampleData
    }
} 