import SwiftUI

/// A view for creating a new challenge with timer option
struct NewChallengeView: View {
    @Binding var isPresented: Bool
    @Binding var challengeTitle: String
    let onCreateChallenge: (String, Bool) -> Void
    
    @State private var isTimed: Bool = false
    @State private var showTimedInfo: Bool = false
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @FocusState private var isTitleFocused: Bool
    
    // Popular challenge suggestions
    private let challengeSuggestions = [
        "Go to the gym",
        "Read 10 pages",
        "No sugar",
        "Code every day",
        "Meditate",
        "Drink a gallon of water",
        "Write journal entry",
        "Take a daily photo",
        "Practice an instrument"
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("New Challenge")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.theme.text)
                    
                    Spacer()
                    
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.theme.subtext)
                    }
                }
                .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                .padding(.top, AppSpacing.m)
                .padding(.bottom, AppSpacing.m)
                
                ScrollView {
                    VStack(spacing: AppSpacing.l) {
                        // Challenge title input
                        VStack(alignment: .leading, spacing: AppSpacing.s) {
                            Text("What do you want to do for 100 days?")
                                .font(.headline)
                                .foregroundColor(.theme.text)
                            
                            TextField("e.g., Read 10 pages, Meditate, No sugar", text: $challengeTitle)
                                .font(.system(size: 18))
                                .padding(AppSpacing.m)
                                .background(Color.theme.surface)
                                .cornerRadius(AppSpacing.cardCornerRadius)
                                .focused($isTitleFocused)
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                        
                        // Timer option
                        VStack(alignment: .leading, spacing: AppSpacing.s) {
                            Toggle(isOn: $isTimed) {
                                HStack {
                                    Image(systemName: "timer")
                                        .foregroundColor(.theme.accent)
                                    
                                    Text("Require timer to check in")
                                        .font(.headline)
                                        .foregroundColor(.theme.text)
                                    
                                    Button(action: { showTimedInfo.toggle() }) {
                                        Image(systemName: "info.circle")
                                            .foregroundColor(.theme.accent.opacity(0.7))
                                    }
                                }
                            }
                            .toggleStyle(SwitchToggleStyle(tint: .theme.accent))
                            
                            if showTimedInfo {
                                Text("Timer challenges require you to complete a timed session before you can check in. Great for focused activities like meditation, workouts, or coding practice.")
                                    .font(.subheadline)
                                    .foregroundColor(.theme.subtext)
                                    .padding(AppSpacing.m)
                                    .background(
                                        RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                                            .fill(Color.theme.surface)
                                    )
                                    .padding(.vertical, AppSpacing.xs)
                            }
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                        
                        // Popular suggestions
                        VStack(alignment: .leading, spacing: AppSpacing.s) {
                            Text("Popular ideas")
                                .font(.headline)
                                .foregroundColor(.theme.text)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: AppSpacing.s) {
                                    ForEach(challengeSuggestions, id: \.self) { suggestion in
                                        Button(action: {
                                            challengeTitle = suggestion
                                        }) {
                                            Text(suggestion)
                                                .font(.system(size: 15))
                                                .padding(.horizontal, AppSpacing.m)
                                                .padding(.vertical, AppSpacing.s)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .fill(Color.theme.surface)
                                                )
                                                .foregroundColor(.theme.text)
                                        }
                                    }
                                }
                                .padding(.vertical, AppSpacing.xs)
                            }
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                        
                        // Pro limit warning
                        if !subscriptionService.isProUser {
                            proLimitWarning
                                .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, AppSpacing.m)
                }
                
                // Create button
                Button(action: {
                    onCreateChallenge(challengeTitle, isTimed)
                }) {
                    Text("Start Challenge")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.m)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.theme.accent, Color.theme.accent.opacity(0.8)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        )
                }
                .buttonStyle(AppScaleButtonStyle())
                .padding(AppSpacing.m)
                .disabled(challengeTitle.isEmpty)
                .opacity(challengeTitle.isEmpty ? 0.5 : 1.0)
            }
            .background(Color.theme.background.ignoresSafeArea())
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isTitleFocused = true
                }
            }
        }
    }
    
    // Pro limit warning when user has 3+ challenges as a free user
    private var proLimitWarning: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            HStack {
                Image(systemName: "lock.fill")
                    .foregroundColor(.theme.accent)
                
                Text("Pro Feature")
                    .font(.headline)
                    .foregroundColor(.theme.accent)
                
                Spacer()
            }
            
            Text("Free users can create up to 2 active challenges.")
                .font(.subheadline)
                .foregroundColor(.theme.text)
            
            Text("Upgrade to Pro to create unlimited challenges.")
                .font(.subheadline)
                .foregroundColor(.theme.subtext)
                .padding(.top, AppSpacing.xxs)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.theme.accent.opacity(0.1), Color.theme.surface]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.theme.shadow.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
}

struct NewChallengeView_Previews: PreviewProvider {
    static var previews: some View {
        NewChallengeView(
            isPresented: .constant(true),
            challengeTitle: .constant(""),
            onCreateChallenge: { _, _ in }
        )
        .environmentObject(SubscriptionService.shared)
    }
} 