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
        VStack(spacing: AppSpacing.s) {
            Text(question.question)
                .font(AppTypography.title2(.semibold))
                .foregroundColor(.theme.text)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
            
            if let subtitle = question.subtitle {
                Text(subtitle)
                    .font(AppTypography.subhead(.regular))
                    .foregroundColor(.theme.subtext)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            }
        }
        .padding(.horizontal, AppSpacing.m)
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
            HStack {
                Text(option)
                    .font(AppTypography.body(.medium))
                    .foregroundColor(selectedAnswer == option ? Color.adaptiveForeground(for: .light) : .theme.text)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                // Selection indicator
                if selectedAnswer == option {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(Color.adaptiveForeground(for: .light))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, AppSpacing.m)
            .padding(.vertical, AppSpacing.buttonVerticalPadding)
            .background(
                RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                    .fill(selectedAnswer == option ? Color.theme.accent : Color.theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                            .stroke(
                                selectedAnswer == option ? Color.theme.accent : Color.theme.border,
                                lineWidth: selectedAnswer == option ? 2 : 1
                            )
                    )
            )
            .shadow(
                color: selectedAnswer == option 
                    ? Color.theme.accent.opacity(0.2)
                    : Color.theme.shadow.opacity(0.05),
                radius: selectedAnswer == option ? 8 : 4,
                x: 0,
                y: selectedAnswer == option ? 4 : 2
            )
            .scaleEffect(selectedAnswer == option ? 1.02 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
                .accessibilityLabel(option)
                .accessibilityAddTraits(selectedAnswer == option ? [.isSelected] : [])
                .accessibilityHint("Double tap to select this option")
                .accessibilityValue(selectedAnswer == option ? "Selected" : "Not selected")
    }
    
    // MARK: - Free Text Input
    
    private var freeTextInput: some View {
        VStack(spacing: AppSpacing.m) {
            // Input field
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Your commitment:")
                    .font(AppTypography.subhead(.medium))
                    .foregroundColor(.theme.text)
                
                TextField("e.g., Exercise for 30 minutes daily", text: $freeTextAnswer)
                    .font(AppTypography.body(.regular))
                    .padding(.horizontal, AppSpacing.m)
                    .padding(.vertical, AppSpacing.buttonVerticalPadding)
                    .background(
                        RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                            .fill(Color.theme.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                                    .stroke(
                                        isTextFieldFocused ? Color.theme.accent : Color.theme.border,
                                        lineWidth: isTextFieldFocused ? 2 : 1
                                    )
                            )
                    )
                    .focused($isTextFieldFocused)
                    .submitLabel(.done)
                    .onSubmit {
                        isTextFieldFocused = false
                    }
                
                // Character hint
                HStack {
                    Spacer()
                    Text("\(freeTextAnswer.count)/100")
                        .font(AppTypography.caption1(.regular))
                        .foregroundColor(freeTextAnswer.count > 100 ? .theme.error : .theme.subtext)
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
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Need inspiration?")
                .font(AppTypography.caption1(.medium))
                .foregroundColor(.theme.subtext)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.xs) {
                    ForEach(suggestionExamples, id: \.self) { suggestion in
                        suggestionChip(suggestion)
                    }
                }
                .padding(.horizontal, AppSpacing.m)
            }
            .padding(.horizontal, -AppSpacing.m)
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
                .font(AppTypography.caption1(.medium))
                .foregroundColor(.theme.accent)
                .padding(.horizontal, AppSpacing.s)
                .padding(.vertical, AppSpacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.theme.accent.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.theme.accent.opacity(0.3), lineWidth: 1)
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
