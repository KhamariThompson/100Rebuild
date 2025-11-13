import SwiftUI

/// Create a new 100-day challenge
/// Simplified and optimized with proper typography matching the app
struct NewChallengeView: View {
    @Binding var isPresented: Bool
    @Binding var challengeTitle: String
    let onCreateChallenge: (String, Bool) -> Void

    // Challenge configuration
    @State private var isTimed: Bool = false

    // UI state
    @State private var animateElements: Bool = false
    @FocusState private var isTitleFocused: Bool

    // Constants
    private let titleCharLimit = 50

    // Environment
    @EnvironmentObject private var subscriptionStore: SubscriptionStore
    @EnvironmentObject private var entitlementsAdapter: EntitlementsAdapter
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var userSession: UserSession
    @Environment(\.colorScheme) private var colorScheme

    // Popular challenge suggestions
    private let challengeSuggestions = [
        "Go to the gym",
        "Read 10 pages",
        "No sugar",
        "Code every day",
        "Meditate",
        "Drink water",
        "Write journal",
        "Take a photo",
        "Practice music"
    ]

    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.theme.background.ignoresSafeArea()

                // Main content
                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.xl) {
                        // Hero Section
                        heroSection
                            .padding(.top, AppSpacing.m)

                        // Main Form Content
                        VStack(spacing: AppSpacing.l) {
                            // Challenge Title Input
                            titleInputSection

                            // Timer Challenge Toggle
                            timerSection

                            // Popular Suggestions
                            suggestionsSection
                        }
                        .padding(.horizontal, AppSpacing.l)

                        // Bottom spacing for create button
                        Spacer(minLength: 120)
                    }
                    .padding(.bottom, 100)
                }
                .simultaneousGesture(
                    TapGesture().onEnded { _ in
                        hideKeyboard()
                    }
                )

                // Floating Create Button
                VStack {
                    Spacer()
                    createButton
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("New Challenge")
                        .font(AppTypography.headline())
                        .foregroundColor(.theme.text)
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { isPresented = false }) {
                        Text("Cancel")
                            .font(AppTypography.body())
                            .foregroundColor(.theme.accent)
                    }
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        animateElements = true
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        isTitleFocused = true
                    }
                }
            }
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: AppSpacing.s) {
            Group {
                if #available(iOS 17.0, *) {
                    Image(systemName: "sparkles")
                        .font(AppTypography.largeTitle(.bold))
                        .foregroundColor(.theme.accent)
                        .symbolEffect(.bounce, value: animateElements)
                } else {
                    Image(systemName: "sparkles")
                        .font(AppTypography.largeTitle(.bold))
                        .foregroundColor(.theme.accent)
                }
            }

            Text("Start Your 100-Day Journey")
                .font(AppTypography.title3())
                .foregroundColor(.theme.text)

            Text("Commit to a daily habit and track your progress")
                .font(AppTypography.subhead())
                .foregroundColor(.theme.subtext)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)
        }
        .frame(maxWidth: .infinity)
        .opacity(animateElements ? 1 : 0)
        .offset(y: animateElements ? 0 : -20)
    }

    // MARK: - Title Input Section

    private var titleInputSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            HStack {
                Text("What do you want to do for 100 days?")
                    .font(AppTypography.headline())
                    .foregroundColor(.theme.text)

                Spacer()

                Text("\(challengeTitle.count)/\(titleCharLimit)")
                    .font(AppTypography.subhead())
                    .foregroundColor(characterCountColor(count: challengeTitle.count, limit: titleCharLimit))
            }

            ZStack(alignment: .leading) {
                if challengeTitle.isEmpty && !isTitleFocused {
                    Text("e.g., Read 10 pages, Meditate, No sugar")
                        .font(AppTypography.body())
                        .foregroundColor(.theme.subtext.opacity(0.5))
                        .padding(.leading, AppSpacing.m)
                        .padding(.vertical, AppSpacing.m)
                }

                TextField("", text: Binding(
                    get: { challengeTitle },
                    set: { challengeTitle = String($0.prefix(titleCharLimit)) }
                ))
                .font(AppTypography.headline())
                .padding(AppSpacing.m)
                .background(
                    RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                        .fill(Color.theme.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                        .stroke(isTitleFocused ? Color.theme.accent : Color.theme.surface.opacity(0.1), lineWidth: isTitleFocused ? 2 : 1)
                )
                .focused($isTitleFocused)
                .submitLabel(.done)
                .onSubmit {
                    if !challengeTitle.isEmpty {
                        hideKeyboard()
                    }
                }
            }
        }
        .padding(AppSpacing.m)
        .background(
            RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                .fill(Color.theme.surface)
                .shadow(color: Color.theme.shadow.opacity(0.05), radius: 4, x: 0, y: 2)
        )
        .opacity(animateElements ? 1 : 0)
        .offset(y: animateElements ? 0 : 20)
    }

    // MARK: - Timer Section

    private var timerSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            Toggle(isOn: $isTimed) {
                HStack(spacing: AppSpacing.m) {
                    ZStack {
                        Circle()
                            .fill(isTimed ? Color.theme.accent.opacity(0.15) : Color.theme.surface)
                            .frame(width: 48, height: 48)

                        Image(systemName: "timer")
                            .font(AppTypography.title3())
                            .foregroundColor(isTimed ? .theme.accent : .theme.subtext)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Timer Challenge")
                            .font(AppTypography.headline())
                            .foregroundColor(.theme.text)

                        Text("Require a timer for each check-in")
                            .font(AppTypography.subhead())
                            .foregroundColor(.theme.subtext)
                    }

                    Spacer()
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: .theme.accent))

            if isTimed {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Perfect for activities like meditation, exercise, or focused work sessions")
                        .font(AppTypography.subhead())
                        .foregroundColor(.theme.subtext)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, AppSpacing.xs)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(AppSpacing.m)
        .background(
            RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                .fill(Color.theme.surface)
                .shadow(color: Color.theme.shadow.opacity(0.05), radius: 4, x: 0, y: 2)
        )
        .opacity(animateElements ? 1 : 0)
        .offset(y: animateElements ? 0 : 20)
    }

    // MARK: - Suggestions Section

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            Text("Popular challenge ideas")
                .font(AppTypography.headline())
                .foregroundColor(.theme.text)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.s) {
                    ForEach(Array(challengeSuggestions.enumerated()), id: \.offset) { index, suggestion in
                        Button(action: {
                            challengeTitle = suggestion
                            hideKeyboard()
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                        }) {
                            HStack(spacing: AppSpacing.xs) {
                                Image(systemName: iconForSuggestion(index))
                                    .font(AppTypography.subhead())
                                    .foregroundColor(.theme.accent)

                                Text(suggestion)
                                    .font(AppTypography.body())
                                    .foregroundColor(.theme.text)
                            }
                            .padding(.horizontal, AppSpacing.m)
                            .padding(.vertical, AppSpacing.s)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.theme.surface)
                                    .shadow(color: Color.theme.shadow.opacity(0.05), radius: 2, x: 0, y: 1)
                            )
                        }
                        .buttonStyle(ChallengeScaleButtonStyle())
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .opacity(animateElements ? 1 : 0)
        .offset(y: animateElements ? 0 : 20)
    }

    // MARK: - Create Button

    private var createButton: some View {
        VStack(spacing: 0) {
            // Gradient fade effect
            LinearGradient(
                gradient: Gradient(
                    colors: [
                        Color.theme.background.opacity(0),
                        Color.theme.background.opacity(0.95),
                        Color.theme.background
                    ]
                ),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 40)

            Button(action: {
                hideKeyboard()
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                onCreateChallenge(challengeTitle, isTimed)
            }) {
                HStack(spacing: AppSpacing.s) {
                    Image(systemName: "plus.circle.fill")
                        .font(AppTypography.headline())

                    Text("Start 100-Day Challenge")
                        .font(AppTypography.headline())
                }
                .foregroundColor(colorScheme == .dark ? .black : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.m)
                .background(
                    RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.theme.accent,
                                    Color.theme.accent.opacity(0.8)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: Color.theme.accent.opacity(0.3), radius: 8, x: 0, y: 4)
                )
            }
            .buttonStyle(ChallengeScaleButtonStyle())
            .disabled(challengeTitle.isEmpty)
            .opacity(challengeTitle.isEmpty ? 0.5 : 1.0)
            .padding(.horizontal, AppSpacing.l)
            .padding(.bottom, AppSpacing.l)
            .background(Color.theme.background)
        }
        .opacity(animateElements ? 1 : 0)
        .offset(y: animateElements ? 0 : 40)
    }

    // MARK: - Helper Functions

    private func hideKeyboard() {
        isTitleFocused = false
    }

    private func characterCountColor(count: Int, limit: Int) -> Color {
        let ratio = Double(count) / Double(limit)
        if ratio >= 1.0 {
            return .red
        } else if ratio >= 0.8 {
            return .orange
        } else {
            return .theme.subtext
        }
    }

    private func iconForSuggestion(_ index: Int) -> String {
        let icons = ["figure.run", "book.fill", "carrot.fill", "laptopcomputer", "brain.head.profile", "drop.fill", "doc.text.fill", "camera.fill", "music.note"]
        return icons[index % icons.count]
    }
}

// MARK: - Scale Button Style

struct ChallengeScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Preview

struct NewChallengeView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NewChallengeView(
                isPresented: .constant(true),
                challengeTitle: .constant(""),
                onCreateChallenge: { _, _ in }
            )
            .environmentObject(SubscriptionStore.shared)
            .environmentObject(EntitlementsAdapter.shared)
            .environmentObject(ThemeManager.shared)
            .environmentObject(UserSession.shared)
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")

            NewChallengeView(
                isPresented: .constant(true),
                challengeTitle: .constant("Read 10 pages"),
                onCreateChallenge: { _, _ in }
            )
            .environmentObject(SubscriptionStore.shared)
            .environmentObject(EntitlementsAdapter.shared)
            .environmentObject(ThemeManager.shared)
            .environmentObject(UserSession.shared)
            .preferredColorScheme(.light)
            .previewDisplayName("Light Mode - With Text")
        }
    }
}
