import SwiftUI

// MARK: - Quiz Question View
// 
// CHANGED: Enhanced for 100Days funnel with emotion-forward design
// - Added haptic feedback for better accessibility
// - Improved focus management for text input
// - Added suggestion chips for free text questions
// - Enhanced animation and visual feedback

/// Reusable component for displaying multiple choice and text input questions
struct QuizQuestionView: View {
    let question: FunnelQuestion
    @Binding var selectedAnswer: String?
    @Binding var freeTextAnswer: String
    
    @State private var animateOptions = false
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: AppSpacing.l) {
            // Question Header
            questionHeader
            
            // Question Content
            if question.type == .multipleChoice {
                multipleChoiceOptions
            } else {
                freeTextInput
            }
        }
        .onAppear {
            // Animate options appearance with delay
            withAnimation(.easeInOut(duration: 0.6).delay(0.2)) {
                animateOptions = true
            }
        }
    }
    
    // MARK: - Question Header
    
    private var questionHeader: some View {
        VStack(spacing: 12) {
            Text(question.question)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.theme.text)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            if let subtitle = question.subtitle {
                Text(subtitle)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.theme.subtext)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Multiple Choice Options
    
    private var multipleChoiceOptions: some View {
        VStack(spacing: AppSpacing.s) {
            ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                optionButton(option: option, index: index)
                    .opacity(animateOptions ? 1 : 0)
                    .offset(y: animateOptions ? 0 : 20)
                    .animation(
                        .easeInOut(duration: 0.5).delay(Double(index) * 0.1),
                        value: animateOptions
                    )
            }
        }
        .padding(.horizontal, AppSpacing.m)
    }
    
    private func optionButton(option: String, index: Int) -> some View {
        Button(action: {
            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedAnswer = option
            }
        }) {
            HStack(spacing: 14) {
                Text(option)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(selectedAnswer == option ? .white : .theme.text)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                // Selection indicator
                if selectedAnswer == option {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(
                ZStack {
                    if selectedAnswer == option {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [Color.theme.accent, Color.theme.accent.opacity(0.9)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.theme.surface)
                    }

                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            selectedAnswer == option
                                ? Color.theme.accent.opacity(0.5)
                                : Color.theme.border.opacity(0.3),
                            lineWidth: selectedAnswer == option ? 2 : 1
                        )
                }
            )
            .shadow(
                color: selectedAnswer == option
                    ? Color.theme.accent.opacity(0.3)
                    : Color.theme.shadow.opacity(0.05),
                radius: selectedAnswer == option ? 12 : 4,
                x: 0,
                y: selectedAnswer == option ? 6 : 2
            )
        }
        .buttonStyle(PlainButtonStyle())
                .accessibilityLabel(option)
                .accessibilityAddTraits(selectedAnswer == option ? [.isSelected] : [])
                .accessibilityHint("Double tap to select this option")
                .accessibilityValue(selectedAnswer == option ? "Selected" : "Not selected")
    }
    
    // MARK: - Free Text Input
    
    private var freeTextInput: some View {
        VStack(spacing: 20) {
            // Input field with enhanced styling
            VStack(alignment: .leading, spacing: 10) {
                Text("Your commitment:")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.theme.text)

                TextField("e.g., Exercise for 30 minutes daily", text: $freeTextAnswer)
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundColor(.theme.text)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.theme.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        isTextFieldFocused
                                            ? Color.theme.accent.opacity(0.5)
                                            : Color.theme.border.opacity(0.3),
                                        lineWidth: isTextFieldFocused ? 2 : 1
                                    )
                            )
                            .shadow(
                                color: isTextFieldFocused
                                    ? Color.theme.accent.opacity(0.15)
                                    : Color.clear,
                                radius: 8,
                                x: 0,
                                y: 4
                            )
                    )
                    .focused($isTextFieldFocused)
                    .submitLabel(.done)
                    .onSubmit {
                        isTextFieldFocused = false
                    }

                // Character hint with better typography
                HStack {
                    Spacer()
                    Text("\(freeTextAnswer.count)/100")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(freeTextAnswer.count > 100 ? .theme.error : .theme.subtext.opacity(0.7))
                }
            }
            
            // Example suggestions
            suggestionChips
        }
        .padding(.horizontal, AppSpacing.m)
        .onAppear {
            // Auto-focus text field after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTextFieldFocused = true
            }
        }
    }
    
    private var suggestionChips: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Need inspiration?")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.theme.subtext)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(suggestionExamples, id: \.self) { suggestion in
                        suggestionChip(suggestion)
                    }
                }
                .padding(.horizontal, 24)
            }
            .padding(.horizontal, -24)
        }
    }

    private func suggestionChip(_ suggestion: String) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                freeTextAnswer = suggestion
            }

            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }) {
            Text(suggestion)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.theme.accent)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.theme.accent.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.theme.accent.opacity(0.3), lineWidth: 1.5)
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var suggestionExamples: [String] {
        [
            "Read for 20 minutes",
            "Write in my journal",
            "Practice meditation", 
            "Learn something new",
            "Exercise daily",
            "Eat mindfully"
        ]
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 40) {
        // Multiple choice preview
        QuizQuestionView(
            question: FunnelQuestion(
                id: 1,
                question: "What are you committing to check in for 100 days?",
                subtitle: "Choose what resonates most with your current goals",
                type: .multipleChoice,
                options: ["Move body", "Study/focus", "Create", "Save money"],
                isRequired: true
            ),
            selectedAnswer: .constant("Move body"),
            freeTextAnswer: .constant("")
        )
        
        Divider()
        
        // Free text preview
        QuizQuestionView(
            question: FunnelQuestion(
                id: 8,
                question: "Name your 100-day commitment",
                subtitle: "Write it in your own words (one line)",
                type: .freeText,
                options: [],
                isRequired: true
            ),
            selectedAnswer: .constant(nil),
            freeTextAnswer: .constant("Exercise for 30 minutes daily")
        )
    }
    .padding()
    .background(Color.theme.background)
}
