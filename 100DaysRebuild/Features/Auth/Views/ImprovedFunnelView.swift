import SwiftUI

// MARK: - Improved Funnel View with Smart Conversion
//
// High-conversion funnel with:
// - Exit intent detection & prevention
// - Social proof at critical moments
// - Loss aversion & commitment devices
// - Progress investment reminders
// - Smart re-engagement tactics
// - Emotional momentum building

struct ImprovedFunnelView: View {
    @StateObject private var funnelModel = FunnelModel()
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var analyticsService: AnalyticsService
    @EnvironmentObject var cohortManager: CohortManager
    @EnvironmentObject var subscriptionStore: SubscriptionStore

    @State private var currentStep = 1
    @State private var hasAppeared = false
    @State private var showExitDialog = false
    @State private var exitAttempts = 0
    @State private var timeSpentOnFunnel: TimeInterval = 0
    @State private var startTime: Date = Date()
    @State private var showMicroWin = false
    @Environment(\.dismiss) var dismiss

    private let totalSteps = 8

    // Social proof numbers (rotate these from real data)
    private let socialProofStats = [
        "2,847 people started today",
        "89% complete their first 7 days",
        "Users avg 41-day streaks"
    ]

    var onComplete: () -> Void

    init(onComplete: @escaping () -> Void = {}) {
        self.onComplete = onComplete
    }

    var body: some View {
        ZStack {
            mainContent

            // Exit intent dialog
            if showExitDialog {
                exitIntentOverlay
            }

            // Micro win celebration
            if showMicroWin {
                microWinCelebration
            }
        }
        .onAppear {
            startTime = Date()
            analyticsService.trackEvent("funnel_started_v2", properties: ["redesigned": true])

            withAnimation(.easeOut(duration: 0.35)) {
                hasAppeared = true
            }
        }
        .onDisappear {
            timeSpentOnFunnel = Date().timeIntervalSince(startTime)
            analyticsService.trackEvent("funnel_exit", properties: [
                "step": currentStep,
                "time_spent": timeSpentOnFunnel,
                "exit_attempts": exitAttempts
            ])
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                // Dynamic header based on progress
                dynamicHeader
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : -12)
                    .animation(.easeOut(duration: 0.35), value: hasAppeared)

                // Progress with milestone markers
                enhancedProgressBar
                    .padding(.top, DS.Spacing.md)

                // Current question
                if let question = funnelModel.currentQuestion {
                    questionView(question)
                        .padding(.top, DS.Spacing.lg)
                }

                // Strategic social proof insertion
                if shouldShowSocialProof {
                    socialProofCard
                        .padding(.top, DS.Spacing.lg)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Benefits (shown strategically)
                if shouldShowBenefits {
                    benefitsSection
                        .padding(.top, DS.Spacing.xl)
                }

                // Smart CTA
                smartCTAStack
                    .padding(.top, DS.Spacing.xl)

                // Trust signals
                if currentStep == 1 || currentStep == totalSteps {
                    TrustSection()
                        .padding(.top, DS.Spacing.lg)
                }

                MetaFootnote("By continuing, you agree to our Terms & Privacy Policy.")
            }
            .padding(.bottom, DS.Spacing.xxl)
        }
        .background(DS.Colors.background.ignoresSafeArea())
    }

    // MARK: - Dynamic Header

    private var dynamicHeader: some View {
        VStack(spacing: DS.Spacing.sm) {
            // Step-specific messaging
            Text(headerTitle)
                .font(DS.Typo.titleXL)
                .foregroundStyle(DS.Colors.onSurface)
                .multilineTextAlignment(.center)

            Text(headerSubtitle)
                .font(DS.Typo.body)
                .foregroundStyle(DS.Colors.onSurfaceSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, DS.Spacing.xl)
    }

    private var headerTitle: String {
        switch currentStep {
        case 1:
            return "You're 3 minutes from your best streak yet"
        case 2, 3:
            return "Building your personalized plan"
        case 4, 5:
            return "Almost there — your routine is taking shape"
        case 6, 7:
            return "Final touches — this is yours"
        case totalSteps:
            return "🎉 You're ready"
        default:
            return "Creating your momentum system"
        }
    }

    private var headerSubtitle: String {
        switch currentStep {
        case 1:
            return "2,847 people started today. Join them."
        case totalSteps:
            return "Your personalized 100-day plan is ready"
        default:
            return "Just a few more questions..."
        }
    }

    // MARK: - Enhanced Progress Bar

    private var enhancedProgressBar: some View {
        VStack(spacing: DS.Spacing.xs) {
            // Progress bar with milestones
            ZStack(alignment: .leading) {
                // Background
                Rectangle()
                    .fill(DS.Colors.surface.opacity(0.5))
                    .frame(height: 6)

                // Progress
                Rectangle()
                    .fill(DS.Colors.accent)
                    .frame(width: progressWidth, height: 6)
                    .animation(.easeOut(duration: 0.3), value: currentStep)

                // Milestone markers
                HStack(spacing: 0) {
                    ForEach(1...totalSteps, id: \.self) { step in
                        Circle()
                            .fill(step <= currentStep ? DS.Colors.accent : DS.Colors.surface.opacity(0.5))
                            .frame(width: 10, height: 10)
                            .overlay(
                                Circle()
                                    .stroke(DS.Colors.background, lineWidth: 2)
                            )

                        if step < totalSteps {
                            Spacer()
                        }
                    }
                }
            }
            .frame(height: 10)
            .clipShape(Capsule())

            // Progress text with emotional language
            HStack {
                Text(progressText)
                    .font(DS.Typo.caption1)
                    .foregroundStyle(DS.Colors.onSurfaceSecondary)

                Spacer()

                Text("\(currentStep) of \(totalSteps)")
                    .font(DS.Typo.caption1.bold())
                    .foregroundStyle(DS.Colors.accent)
            }
        }
        .padding(.horizontal, DS.Spacing.xl)
    }

    private var progressWidth: CGFloat {
        let screenWidth = UIScreen.main.bounds.width - (DS.Spacing.xl * 2)
        return (CGFloat(currentStep) / CGFloat(totalSteps)) * screenWidth
    }

    private var progressText: String {
        let percentage = Int((Double(currentStep) / Double(totalSteps)) * 100)

        switch currentStep {
        case 1, 2:
            return "Getting started..."
        case 3, 4, 5:
            return "\(percentage)% done — you're invested now"
        case 6, 7:
            return "Almost done! Don't lose this progress"
        case totalSteps:
            return "Complete! 🎉"
        default:
            return "\(percentage)% complete"
        }
    }

    // MARK: - Social Proof Card

    private var socialProofCard: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "person.3.fill")
                .foregroundStyle(DS.Colors.accent)
                .font(.system(size: 20))

            VStack(alignment: .leading, spacing: 2) {
                Text(socialProofStats[currentStep % socialProofStats.count])
                    .font(DS.Typo.subhead.bold())
                    .foregroundStyle(DS.Colors.onSurface)

                Text("You're not alone in this")
                    .font(DS.Typo.caption1)
                    .foregroundStyle(DS.Colors.onSurfaceSecondary)
            }

            Spacer()
        }
        .padding(DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Spacing.cardCornerRadius)
                .fill(DS.Colors.accent.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Spacing.cardCornerRadius)
                        .stroke(DS.Colors.accent.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, DS.Spacing.xl)
    }

    private var shouldShowSocialProof: Bool {
        // Show at key decision points
        currentStep == 3 || currentStep == 5 || currentStep == 7
    }

    // MARK: - Benefits Section

    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(benefitsTitle)
                .font(DS.Typo.title3)
                .foregroundStyle(DS.Colors.onSurface)
                .padding(.horizontal, DS.Spacing.xl)

            BenefitsGrid(benefits: currentBenefits)
        }
    }

    private var shouldShowBenefits: Bool {
        currentStep == 1 || currentStep == totalSteps
    }

    private var benefitsTitle: String {
        currentStep == 1 ? "What you're building" : "What you unlocked"
    }

    private var currentBenefits: [Benefit] {
        [
            Benefit(icon: "flame.fill", title: "Your streak system", caption: "Visual momentum that builds discipline."),
            Benefit(icon: "chart.line.uptrend.xyaxis", title: "Progress insights", caption: "See patterns & optimize your routine."),
            Benefit(icon: "bell.badge.fill", title: "Smart reminders", caption: "Personalized to your schedule."),
            Benefit(icon: "heart.fill", title: "Built for you", caption: "Based on your answers, not one-size-fits-all."),
        ]
    }

    // MARK: - Question View

    @ViewBuilder
    private func questionView(_ question: FunnelQuestion) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // Question text
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(question.question)
                    .font(DS.Typo.titleL)
                    .foregroundStyle(DS.Colors.onSurface)

                if let subtitle = question.subtitle {
                    Text(subtitle)
                        .font(DS.Typo.subhead)
                        .foregroundStyle(DS.Colors.onSurfaceSecondary)
                }
            }
            .padding(.horizontal, DS.Spacing.xl)

            // Answer options
            answerOptions(for: question)
                .padding(.top, DS.Spacing.sm)
        }
    }

    @ViewBuilder
    private func answerOptions(for question: FunnelQuestion) -> some View {
        switch question.type {
        case .multipleChoice:
            multipleChoiceOptions(question)
        case .freeText:
            textInputOption(question)
        }
    }

    @ViewBuilder
    private func multipleChoiceOptions(_ question: FunnelQuestion) -> some View {
        VStack(spacing: DS.Spacing.sm) {
            ForEach(question.options, id: \.self) { option in
                optionButton(option, isSelected: isOptionSelected(option, for: question))
            }
        }
        .padding(.horizontal, DS.Spacing.xl)
    }

    @ViewBuilder
    private func optionButton(_ option: String, isSelected: Bool) -> some View {
        Button(action: {
            selectOption(option)
        }) {
            HStack {
                Text(option)
                    .font(DS.Typo.body)
                    .foregroundStyle(isSelected ? DS.Colors.accent : DS.Colors.onSurface)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(DS.Colors.accent)
                }
            }
            .padding(DS.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DS.Spacing.cardCornerRadius)
                    .fill(isSelected ? DS.Colors.accent.opacity(0.1) : DS.Colors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Spacing.cardCornerRadius)
                            .stroke(isSelected ? DS.Colors.accent : DS.Colors.border, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(AppScaleButtonStyle())
    }

    @ViewBuilder
    private func textInputOption(_ question: FunnelQuestion) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            TextField("Enter your commitment...", text: $funnelModel.answers.freeTextAnswer)
                .font(DS.Typo.body)
                .padding(DS.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DS.Spacing.cardCornerRadius)
                        .fill(DS.Colors.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Spacing.cardCornerRadius)
                                .stroke(DS.Colors.border, lineWidth: 1)
                        )
                )
                .padding(.horizontal, DS.Spacing.xl)

            if let subtitle = question.subtitle {
                Text(subtitle)
                    .font(DS.Typo.caption1)
                    .foregroundStyle(DS.Colors.onSurfaceSecondary)
                    .padding(.horizontal, DS.Spacing.xl)
            }
        }
    }

    // MARK: - Smart CTA Stack

    private var smartCTAStack: some View {
        VStack(spacing: DS.Spacing.md) {
            // Primary CTA with dynamic copy
            Button(action: handlePrimaryAction) {
                HStack {
                    Text(primaryCTAText)
                        .font(DS.Typo.body.bold())

                    if currentStep < totalSteps {
                        Image(systemName: "arrow.right")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(DS.Spacing.md)
                .background(DS.Colors.accent)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: DS.Spacing.cardCornerRadius))
            }
            .buttonStyle(AppScaleButtonStyle())
            .disabled(!funnelModel.canProceed)
            .opacity(funnelModel.canProceed ? 1 : 0.5)

            // Back button
            if currentStep > 1 {
                Button(action: handleBackAction) {
                    Text("Back")
                        .font(DS.Typo.body)
                        .foregroundStyle(DS.Colors.onSurfaceSecondary)
                }
            }

            // Exit with consequence warning
            if currentStep > 2 {
                Button(action: handleExitIntent) {
                    Text("Exit (lose progress)")
                        .font(DS.Typo.caption1)
                        .foregroundStyle(DS.Colors.onSurfaceSecondary.opacity(0.6))
                }
            }
        }
        .padding(.horizontal, DS.Spacing.xl)
    }

    private var primaryCTAText: String {
        switch currentStep {
        case 1:
            return "Start building my plan"
        case totalSteps:
            return "Start my 100 days"
        default:
            return funnelModel.canProceed ? "Continue" : "Choose an option"
        }
    }

    // MARK: - Exit Intent Overlay

    private var exitIntentOverlay: some View {
        ZStack {
            exitBackdrop
            exitDialogContent
        }
        .transition(.opacity)
    }

    private var exitBackdrop: some View {
        Color.black.opacity(0.5)
            .ignoresSafeArea()
            .onTapGesture {
                withAnimation {
                    showExitDialog = false
                }
            }
    }

    private var exitDialogContent: some View {
        VStack(spacing: DS.Spacing.lg) {
            exitDialogIcon
            exitDialogHeadline
            exitProgressReminder
            exitDialogActions
        }
        .padding(DS.Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: DS.Spacing.cardCornerRadius * 1.5)
                .fill(DS.Colors.surface)
        )
        .padding(.horizontal, DS.Spacing.xl)
    }

    private var exitDialogIcon: some View {
        ZStack {
            Circle()
                .fill(DS.Colors.accent.opacity(0.1))
                .frame(width: 60, height: 60)

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28))
                .foregroundStyle(DS.Colors.accent)
        }
    }

    private var exitDialogHeadline: some View {
        VStack(spacing: DS.Spacing.xs) {
            Text(exitDialogTitle)
                .font(DS.Typo.titleL)
                .foregroundStyle(DS.Colors.onSurface)
                .multilineTextAlignment(.center)

            Text(exitDialogSubtitle)
                .font(DS.Typo.body)
                .foregroundStyle(DS.Colors.onSurfaceSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var exitProgressReminder: some View {
        HStack(spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Your progress:")
                    .font(DS.Typo.caption1)
                    .foregroundStyle(DS.Colors.onSurfaceSecondary)

                Text("\(currentStep) of \(totalSteps) answered")
                    .font(DS.Typo.subhead.bold())
                    .foregroundStyle(DS.Colors.onSurface)
            }

            Spacer()

            Text("\(Int((Double(currentStep) / Double(totalSteps)) * 100))%")
                .font(DS.Typo.title2.bold())
                .foregroundStyle(DS.Colors.accent)
        }
        .padding(DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Spacing.cardCornerRadius)
                .fill(DS.Colors.surface.opacity(0.5))
        )
    }

    private var exitDialogActions: some View {
        VStack(spacing: DS.Spacing.sm) {
            Button(action: {
                withAnimation {
                    showExitDialog = false
                }
            }) {
                Text("Finish what I started")
                    .font(DS.Typo.body.bold())
                    .frame(maxWidth: .infinity)
                    .padding(DS.Spacing.md)
                    .background(DS.Colors.accent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Spacing.cardCornerRadius))
            }

            Button(action: {
                analyticsService.trackEvent("funnel_abandoned", properties: [
                    "step": currentStep,
                    "time_spent": Date().timeIntervalSince(startTime)
                ])
                dismiss()
            }) {
                Text("Exit anyway")
                    .font(DS.Typo.body)
                    .foregroundStyle(DS.Colors.onSurfaceSecondary)
            }
        }
    }

    private var exitDialogTitle: String {
        switch exitAttempts {
        case 0:
            return "You're \(totalSteps - currentStep) questions away"
        case 1:
            return "Wait — don't lose your progress"
        default:
            return "Last chance to finish"
        }
    }

    private var exitDialogSubtitle: String {
        switch exitAttempts {
        case 0:
            return "Your personalized plan is almost ready. Just \(totalSteps - currentStep) more questions."
        case 1:
            return "You've already invested \(Int(Date().timeIntervalSince(startTime) / 60)) minutes. Finish strong."
        default:
            return "Thousands finish this daily. Don't be the one who quits."
        }
    }

    // MARK: - Micro Win Celebration

    private var microWinCelebration: some View {
        VStack(spacing: DS.Spacing.md) {
            Text("🎉")
                .font(.system(size: 40))

            Text("Halfway there!")
                .font(DS.Typo.title3.bold())
                .foregroundStyle(DS.Colors.onSurface)

            Text("You're building something real")
                .font(DS.Typo.body)
                .foregroundStyle(DS.Colors.onSurfaceSecondary)
        }
        .padding(DS.Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: DS.Spacing.cardCornerRadius * 1.5)
                .fill(DS.Colors.surface)
                .shadow(color: .black.opacity(0.1), radius: 20, y: 10)
        )
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Helper Methods

    private func isOptionSelected(_ option: String, for question: FunnelQuestion) -> Bool {
        return funnelModel.answers.answers[funnelModel.currentStep] == option
    }

    private func selectOption(_ option: String) {
        funnelModel.selectAnswer(option)

        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        analyticsService.trackEvent("funnel_answer_selected", properties: [
            "step": funnelModel.currentStep,
            "answer": option
        ])

        // Auto-advance after selection
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if funnelModel.canProceed {
                handlePrimaryAction()
            }
        }
    }

    private func handlePrimaryAction() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        if currentStep < totalSteps {
            withAnimation(.easeOut(duration: 0.35)) {
                currentStep += 1
                funnelModel.nextStep()
            }

            // Show micro-win at halfway point
            if currentStep == totalSteps / 2 {
                withAnimation {
                    showMicroWin = true
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        showMicroWin = false
                    }
                }
            }

            analyticsService.trackEvent("funnel_next", properties: ["step": currentStep])
        } else {
            completeFunnel()
        }
    }

    private func handleBackAction() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        withAnimation(.easeOut(duration: 0.25)) {
            currentStep = max(1, currentStep - 1)
            funnelModel.previousStep()
        }
    }

    private func handleExitIntent() {
        exitAttempts += 1

        withAnimation {
            showExitDialog = true
        }

        analyticsService.trackEvent("funnel_exit_intent", properties: [
            "step": currentStep,
            "attempt": exitAttempts
        ])
    }

    private func completeFunnel() {
        userSession.completeFunnel()

        analyticsService.trackEvent("funnel_completed", properties: [
            "total_steps": totalSteps,
            "time_spent": Date().timeIntervalSince(startTime)
        ])

        // Start the 5-minute welcome offer window
        subscriptionStore.startFiveMinuteWindow()

        print("⏱️  ImprovedFunnelView: Started 5-minute window, routing to paywall")

        onComplete()
    }
}

// MARK: - Preview

struct ImprovedFunnelView_Previews: PreviewProvider {
    static var previews: some View {
        ImprovedFunnelView()
            .environmentObject(UserSession.shared)
            .environmentObject(AnalyticsService.shared)
            .environmentObject(CohortManager.shared)
    }
}
