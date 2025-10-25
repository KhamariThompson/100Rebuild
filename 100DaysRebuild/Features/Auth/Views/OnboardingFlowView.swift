import SwiftUI

// MARK: - Onboarding Flow View
//
// CHANGED: Complete overhaul for emotion-forward funnel + hard paywall
// - 8-question funnel with progress tracking
// - Personalized streak setup based on answers
// - Commitment prompt leading to hard paywall
// - Analytics tracking throughout flow
// - Idempotent design (safe to re-run)

/// Main onboarding flow view that hosts the 8-question funnel and progress
struct OnboardingFlowView: View {
    @StateObject private var funnelModel = FunnelModel()
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var analyticsService: AnalyticsService
    
    @State private var showStreakSetup = false
    @State private var showCommitmentPrompt = false
    @State private var showPaywall = false
    @State private var animateContent = false
    
    var body: some View {
        ZStack {
            // Background
            Color.theme.background
                .ignoresSafeArea()
            
            if showStreakSetup {
                streakSetupFlow
            } else {
                funnelFlow
            }
        }
        .onAppear {
            analyticsService.trackEvent("quiz_started")
            
            withAnimation(.easeInOut(duration: 0.5)) {
                animateContent = true
            }
        }
    }
    
    // MARK: - Funnel Flow
    
    private var funnelFlow: some View {
        VStack(spacing: 0) {
            // Header with progress
            headerView
            
            // Main content
            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    // Current question
                    if let question = funnelModel.currentQuestion {
                        QuizQuestionView(
                            question: question,
                            selectedAnswer: .constant(funnelModel.answers.answers[funnelModel.currentStep]),
                            freeTextAnswer: $funnelModel.answers.freeTextAnswer
                        )
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : 30)
                        .animation(.easeInOut(duration: 0.6), value: animateContent)
                        .onChange(of: funnelModel.currentStep) { _ in
                            // Re-trigger animation for new questions
                            withAnimation(.easeInOut(duration: 0.4)) {
                                animateContent = false
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation(.easeInOut(duration: 0.6)) {
                                    animateContent = true
                                }
                            }
                        }
                        .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidChangeNotification)) { _ in
                            // Update model when text changes
                            funnelModel.setFreeTextAnswer(funnelModel.answers.freeTextAnswer)
                        }
                    }
                }
                .padding(.bottom, 120) // Space for buttons
            }
            
            // Action buttons
            bottomButtons
        }
        .onChange(of: funnelModel.answers.answers) { _ in
            // Track progress
            analyticsService.trackEvent("quiz_next", properties: ["step": funnelModel.currentStep])
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        VStack(spacing: AppSpacing.m) {
            // Progress indicator
            HStack {
                Text("Step \(funnelModel.currentStep) of \(funnelModel.totalSteps)")
                    .font(AppTypography.subhead(.medium))
                    .foregroundColor(.theme.subtext)
                    .accessibilityLabel("Progress: Step \(funnelModel.currentStep) of \(funnelModel.totalSteps)")
                
                Spacer()
                
                // Close button (for testing - remove in production)
                #if DEBUG
                Button("Skip") {
                    completeOnboarding()
                }
                .font(AppTypography.subhead(.medium))
                .foregroundColor(.theme.accent)
                #endif
            }
            
            // Custom progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    Rectangle()
                        .foregroundColor(Color.theme.accent.opacity(0.2))
                        .frame(width: geometry.size.width, height: 8)
                        .cornerRadius(4)
                    
                    // Progress
                    Rectangle()
                        .foregroundColor(Color.theme.accent)
                        .frame(width: geometry.size.width * CGFloat(funnelModel.progress), height: 8)
                        .cornerRadius(4)
                        .animation(.easeInOut(duration: 0.3), value: funnelModel.progress)
                }
            }
            .frame(height: 8)
            .accessibilityLabel("Setup progress")
            .accessibilityValue("\(Int(funnelModel.progress * 100)) percent complete")
        }
        .padding(.horizontal, AppSpacing.screenHorizontalPadding)
        .padding(.top, AppSpacing.m)
        .padding(.bottom, AppSpacing.l)
        .background(
            Color.theme.background
                .shadow(color: Color.theme.shadow.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
    
    // MARK: - Bottom Buttons
    
    private var bottomButtons: some View {
        VStack(spacing: AppSpacing.s) {
            // Continue button
            Button(action: handleContinue) {
                Text(funnelModel.isLastStep ? "Complete Setup" : "Continue")
                    .font(AppTypography.body(.medium))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(AppPrimaryButtonStyle())
            .disabled(!funnelModel.canProceed)
            .opacity(funnelModel.canProceed ? 1.0 : 0.6)
            
            // Back button (if not first step)
            if funnelModel.currentStep > 1 {
                Button(action: funnelModel.previousStep) {
                    Text("Back")
                        .font(AppTypography.body(.medium))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AppSecondaryButtonStyle())
            }
        }
        .padding(.horizontal, AppSpacing.screenHorizontalPadding)
        .padding(.bottom, AppSpacing.m)
        .background(
            Color.theme.background
                .shadow(color: Color.theme.shadow.opacity(0.1), radius: 8, x: 0, y: -4)
        )
    }
    
    // MARK: - Streak Setup Flow
    
    private var streakSetupFlow: some View {
        StreakSetupView(
            configuration: StreakConfiguration.from(answers: funnelModel.answers),
            onContinue: {
                analyticsService.trackEvent("setup_confirmed", properties: ["edited": "false"])
                showCommitmentPrompt = true
            },
            onEdit: {
                analyticsService.trackEvent("setup_confirmed", properties: ["edited": "true"])
                // Allow editing - go back to funnel
                showStreakSetup = false
            }
        )
        .onAppear {
            analyticsService.trackEvent("setup_shown")
        }
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
        .fullScreenCover(isPresented: $showCommitmentPrompt) {
            CommitmentPromptView(
                onContinue: {
                    analyticsService.trackEvent("transform_cta_tap")
                    showPaywall = true
                }
            )
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView()
                .onDisappear {
                    completeOnboarding()
                }
                .environmentObject(analyticsService)
        }
    }
    
    // MARK: - Actions
    
    private func handleContinue() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        if funnelModel.isLastStep {
            // Complete funnel, move to streak setup
            analyticsService.trackEvent("quiz_completed")
            
            withAnimation(.easeInOut(duration: 0.5)) {
                showStreakSetup = true
            }
        } else {
            // Move to next question
            funnelModel.nextStep()
        }
    }
    
    private func completeOnboarding() {
        // Mark funnel as completed and store timestamp
        userSession.completeFunnel()

        // Track completion analytics
        analyticsService.trackEvent("funnel_completed", properties: [
            "time_spent": "\(Date().timeIntervalSince(funnelStartTime))"
        ])

        // Note: We do NOT call userSession.completeOnboarding() here
        // That only happens after successful Pro purchase
        // The funnel completion just marks that they've finished the questionnaire
    }
    
    // Track when the funnel started
    private var funnelStartTime = Date()
}

// MARK: - Streak Setup View

/// Personalized streak configuration screen
struct StreakSetupView: View {
    let configuration: StreakConfiguration
    let onContinue: () -> Void
    let onEdit: () -> Void
    
    @State private var animateContent = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection
            
            // Configuration preview
            ScrollView {
                VStack(spacing: AppSpacing.l) {
                    configurationCards
                    
                    // Continue button
                    VStack(spacing: AppSpacing.s) {
                        Button(action: {
                            // Add haptic feedback
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            
                            onContinue()
                        }) {
                            Text("Looks good!")
                                .font(AppTypography.body(.medium))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(AppPrimaryButtonStyle())
                        
                        Button(action: {
                            // Add haptic feedback
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            
                            onEdit()
                        }) {
                            Text("Edit settings")
                                .font(AppTypography.body(.medium))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(AppSecondaryButtonStyle())
                    }
                }
                .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                .padding(.bottom, AppSpacing.xl)
            }
        }
        .background(Color.theme.background)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).delay(0.2)) {
                animateContent = true
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: AppSpacing.m) {
            Text("Your 100-Day Setup")
                .font(AppTypography.title1(.bold))
                .foregroundColor(.theme.text)
                .multilineTextAlignment(.center)
            
            Text("Here's your personalized streak configuration")
                .font(AppTypography.subhead(.regular))
                .foregroundColor(.theme.subtext)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, AppSpacing.screenHorizontalPadding)
        .padding(.vertical, AppSpacing.l)
    }
    
    private var configurationCards: some View {
        VStack(spacing: AppSpacing.m) {
            configCard(
                icon: "clock",
                title: "Daily Check-In Window",
                value: configuration.dailyTimeWindow
            )
            
            configCard(
                icon: "bell",
                title: "Reminder Style", 
                value: configuration.reminderStyle
            )
            
            configCard(
                icon: "arrow.clockwise",
                title: "Backup Plan",
                value: configuration.backupPlan
            )
            
            configCard(
                icon: "heart",
                title: "Motivation Tone",
                value: configuration.motivationTone
            )
            
            configCard(
                icon: "target",
                title: "Your 100-Day Goal",
                value: configuration.commitmentName,
                isHighlighted: true
            )
        }
    }
    
    private func configCard(icon: String, title: String, value: String, isHighlighted: Bool = false) -> some View {
        HStack(spacing: AppSpacing.m) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(isHighlighted ? Color.theme.accent : Color.theme.text)
                .frame(width: 30)
                .accessibility(hidden: true)
            
            // Content
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(title)
                    .font(AppTypography.subhead(.medium))
                    .foregroundColor(.theme.subtext)
                
                Text(value)
                    .font(AppTypography.body(isHighlighted ? .semibold : .regular))
                    .foregroundColor(isHighlighted ? Color.theme.accent : Color.theme.text)
                    .lineLimit(nil)
            }
            
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
        .padding(AppSpacing.m)
        .background(
            RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                .fill(isHighlighted ? Color.theme.accent.opacity(0.05) : Color.theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                        .stroke(
                            isHighlighted ? Color.theme.accent.opacity(0.3) : Color.theme.border,
                            lineWidth: isHighlighted ? 2 : 1
                        )
                )
        )
        .opacity(animateContent ? 1 : 0)
        .offset(y: animateContent ? 0 : 20)
        .animation(.easeInOut(duration: 0.5).delay(Double([0, 1, 2, 3, 4].firstIndex(where: { _ in true }) ?? 0) * 0.1), value: animateContent)
    }
}

// MARK: - Commitment Prompt View

/// Final commitment prompt before paywall
struct CommitmentPromptView: View {
    let onContinue: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.theme.background.ignoresSafeArea()
            
            VStack(spacing: AppSpacing.xl) {
                Spacer()
                
                // Content
                VStack(spacing: AppSpacing.l) {
                    Text("Ready to transform your life through consistency?")
                        .font(AppTypography.title1(.bold))
                        .foregroundColor(.theme.text)
                        .multilineTextAlignment(.center)
                        .dynamicTypeSize(.large ... .accessibility3)
                    
                    Text("Unlock daily check-ins, streaks, reminders, and progress — no ads.")
                        .font(AppTypography.body(.regular))
                        .foregroundColor(.theme.subtext)
                        .multilineTextAlignment(.center)
                        .dynamicTypeSize(.large ... .accessibility3)
                }
                
                Spacer()
                
                // Action button
                Button(action: onContinue) {
                    Text("Continue")
                        .font(AppTypography.body(.medium))
                        .frame(maxWidth: .infinity, minHeight: 44) // Minimum height for accessibility
                }
                .buttonStyle(AppPrimaryButtonStyle())
                .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                .padding(.bottom, AppSpacing.xl)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingFlowView()
        .environmentObject(UserSession.shared)
        .environmentObject(AnalyticsService.shared)
}
