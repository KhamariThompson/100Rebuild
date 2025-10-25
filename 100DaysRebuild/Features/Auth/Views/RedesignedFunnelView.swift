import SwiftUI

// MARK: - Redesigned Funnel View
//
// Component-first funnel using DS design system
// - Clean visual hierarchy with FunnelHeroHeader, BenefitsGrid, Progress
// - Proper spacing and motion from design system
// - Accessibility-first with proper labels and hints
// - Responsive grid (2-col mobile, 3-col tablet)
// - Dark mode support through DS.Colors

/// Modern funnel view using design system components
struct RedesignedFunnelView: View {
    @StateObject private var funnelModel = FunnelModel()
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var analyticsService: AnalyticsService
    @EnvironmentObject var cohortManager: CohortManager

    @State private var currentStep = 1
    @State private var hasAppeared = false

    private let totalSteps = 8

    // Benefits to display
    private let benefits = [
        Benefit(icon: "infinity", title: "Unlimited challenges", caption: "Create as many as you want."),
        Benefit(icon: "chart.bar.xaxis", title: "Advanced stats", caption: "Deep insights & streak trends."),
        Benefit(icon: "sparkles", title: "Themes & widgets", caption: "Personalize your routine."),
        Benefit(icon: "lock.shield", title: "Privacy-first", caption: "Your data stays yours."),
    ]

    // Routing callback when funnel completes
    var onComplete: () -> Void

    init(onComplete: @escaping () -> Void = {}) {
        self.onComplete = onComplete
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                // Hero header with gradient title
                FunnelHeroHeader(
                    title: currentStep == totalSteps ? "You're all set" : "Level up your streaks",
                    subtitle: currentStep == totalSteps
                        ? "All Pro features are included — focus on momentum."
                        : "Answer a few quick questions to personalize your experience."
                )
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : -12)
                .animation(.easeOut(duration: 0.35), value: hasAppeared)

                // Progress bar
                FunnelProgressBar(current: currentStep, total: totalSteps)
                    .padding(.top, DS.Spacing.md)
                    .opacity(hasAppeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.35).delay(0.1), value: hasAppeared)

                // Current question
                if let question = funnelModel.currentQuestion {
                    questionView(question)
                        .padding(.top, DS.Spacing.lg)
                }

                // Benefits grid (show on first and last step)
                if currentStep == 1 || currentStep == totalSteps {
                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        Text("What you get")
                            .font(DS.Typo.title3)
                            .foregroundStyle(DS.Colors.onSurface)
                            .padding(.horizontal, DS.Spacing.xl)

                        BenefitsGrid(benefits: benefits)
                    }
                    .padding(.top, DS.Spacing.xl)
                }

                // Trust badges
                TrustSection()
                    .padding(.top, DS.Spacing.lg)

                // CTA buttons
                CTAStack(
                    primaryTitle: currentStep < totalSteps ? "Continue" : "Finish",
                    primaryAction: handlePrimaryAction,
                    secondaryTitle: currentStep > 1 ? "Back" : nil,
                    secondaryAction: currentStep > 1 ? handleBackAction : nil
                )
                .padding(.top, DS.Spacing.xl)

                // Legal footnote
                MetaFootnote("By continuing, you agree to our Terms & Privacy Policy.")
            }
            .padding(.bottom, DS.Spacing.xxl)
        }
        .background(DS.Colors.background.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .onAppear {
            analyticsService.trackEvent("funnel_started", properties: ["redesigned": true])
            withAnimation(.easeOut(duration: 0.35)) {
                hasAppeared = true
            }
        }
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
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

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
        .accessibilityLabel(option)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    @ViewBuilder
    private func textInputOption(_ question: FunnelQuestion) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            TextField("Enter your answer", text: $funnelModel.answers.freeTextAnswer)
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
                .accessibilityLabel(question.question)
                .accessibilityHint("Enter your text answer")

            if let subtitle = question.subtitle {
                Text(subtitle)
                    .font(DS.Typo.caption1)
                    .foregroundStyle(DS.Colors.onSurfaceSecondary)
                    .padding(.horizontal, DS.Spacing.xl)
            }
        }
    }

    // MARK: - Helper Methods

    private func isOptionSelected(_ option: String, for question: FunnelQuestion) -> Bool {
        return funnelModel.answers.answers[funnelModel.currentStep] == option
    }

    private func selectOption(_ option: String) {
        funnelModel.selectAnswer(option)

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        // Track analytics
        analyticsService.trackEvent("funnel_answer_selected", properties: [
            "step": funnelModel.currentStep,
            "question": funnelModel.currentQuestion?.question ?? "",
            "answer": option
        ])
    }

    private func handlePrimaryAction() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        if currentStep < totalSteps {
            // Advance to next step
            withAnimation(.easeOut(duration: 0.35)) {
                currentStep += 1
                funnelModel.nextStep()
            }

            analyticsService.trackEvent("funnel_next", properties: ["step": currentStep])
        } else {
            // Complete funnel
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

        analyticsService.trackEvent("funnel_back", properties: ["step": currentStep])
    }

    private func completeFunnel() {
        // Save funnel completion
        userSession.completeFunnel()

        analyticsService.trackEvent("funnel_completed", properties: [
            "total_steps": totalSteps,
            "commitment": funnelModel.answers.answers[8] ?? ""
        ])

        // Call completion handler
        onComplete()
    }
}

// MARK: - Preview

struct RedesignedFunnelView_Previews: PreviewProvider {
    static var previews: some View {
        RedesignedFunnelView()
            .environmentObject(UserSession.shared)
            .environmentObject(AnalyticsService.shared)
            .environmentObject(CohortManager.shared)
    }
}
