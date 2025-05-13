import SwiftUI

struct CheckInSuccessView: View {
    let challenge: Challenge
    let quote: Quote?
    let dayNumber: Int
    let showMilestone: Bool
    let milestoneMessage: String
    let milestoneEmoji: String
    
    @Binding var showNotePrompt: Bool
    @Binding var isPresented: Bool
    @State private var animateBackground = false
    @State private var animateContent = false
    @State private var animateQuote = false
    @State private var animateMotivation = false
    @State private var showShareButton = false
    @State private var showShareCustomizer = false
    
    // Motivational message
    @State private var motivationalMessage: String = MotivationalMessages.getRandomMessage()
    
    // ViewModel for sharing
    @ObservedObject var viewModel: CheckInViewModel
    
    var body: some View {
        ZStack {
            // Animated background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.theme.accent,
                    Color.theme.accent.opacity(0.8)
                ]),
                startPoint: animateBackground ? .topLeading : .bottomTrailing,
                endPoint: animateBackground ? .bottomTrailing : .topLeading
            )
            .ignoresSafeArea()
            .animation(Animation.easeInOut(duration: 4.0).repeatForever(autoreverses: true), value: animateBackground)
            .onAppear {
                animateBackground = true
            }
            
            // Confetti overlay for milestone days
            if isMilestoneDay {
                ConfettiView()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
            
            // Content
            VStack(spacing: 24) {
                // Title
                VStack(spacing: 8) {
                    Text("✅ You showed up for")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.9))
                    
                    Text("Day \(dayNumber) of 100")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.top, 4)
                }
                .offset(y: animateContent ? 0 : -30)
                .opacity(animateContent ? 1 : 0)
                
                // Motivational message - NEW
                Text(motivationalMessage)
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                    .offset(y: animateMotivation ? 0 : 20)
                    .opacity(animateMotivation ? 1 : 0)
                
                // Quote card
                if let quote = quote {
                    VStack(spacing: 16) {
                        Text(quote.text)
                            .font(.title3.italic())
                            .multilineTextAlignment(.center)
                            .foregroundColor(Color.theme.text)
                            .padding(.horizontal)
                        
                        Text("— \(quote.author)")
                            .font(.subheadline)
                            .foregroundColor(Color.theme.subtext)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.theme.surface)
                            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                    )
                    .padding(.horizontal, 24)
                    .offset(y: animateQuote ? 0 : 30)
                    .opacity(animateQuote ? 1 : 0)
                }
                
                Spacer()
                
                // Milestone view - we keep this for compatibility but it should never be shown
                // as we're using MilestoneCelebrationModal instead
                if showMilestone {
                    VStack(spacing: 16) {
                        Text(milestoneEmoji)
                            .font(.system(size: 60))
                        
                        Text(milestoneMessage)
                            .font(.headline)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .offset(y: animateContent ? 0 : 30)
                    .opacity(animateContent ? 1 : 0)
                }
                
                // Action buttons
                VStack(spacing: 16) {
                    if !showMilestone {
                        Button(action: {
                            showNotePrompt = true
                            isPresented = false
                        }) {
                            HStack {
                                Image(systemName: "square.and.pencil")
                                    .font(.headline)
                                Text("Why does today matter?")
                                    .font(.headline)
                            }
                            .foregroundColor(.white)
                            .padding(.vertical, 16)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white, lineWidth: 2)
                            )
                        }
                    }
                    
                    Button(action: {
                        isPresented = false
                    }) {
                        Text(showMilestone ? "Continue" : "Done")
                            .font(.headline)
                            .foregroundColor(Color.theme.accent)
                            .padding(.vertical, 16)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white)
                                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 3)
                            )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
                .offset(y: animateContent ? 0 : 30)
                .opacity(animateContent ? 1 : 0)
            }
            .padding(.top, 60)
        }
        .onAppear {
            // Populate the challenge title in the view model for sharing
            Task {
                await viewModel.prepareForCheckIn(
                    challengeId: challenge.id.uuidString,
                    currentDay: dayNumber,
                    challengeTitle: challenge.title
                )
            }
            
            // Start the animations in sequence
            withAnimation(.easeOut(duration: 0.7)) {
                animateContent = true
            }
            
            withAnimation(.easeOut(duration: 0.7).delay(0.3)) {
                animateMotivation = true
            }
            
            withAnimation(.easeOut(duration: 0.7).delay(0.6)) {
                animateQuote = true
            }
            
            withAnimation(.easeOut(duration: 0.7).delay(1.0)) {
                showShareButton = true
            }
        }
        .sheet(isPresented: $showShareCustomizer) {
            ShareCardCustomizerView(
                viewModel: viewModel,
                isPresented: $showShareCustomizer
            )
        }
    }
    
    // Helper to determine if this is a milestone day
    private var isMilestoneDay: Bool {
        return [3, 7, 30, 50, 100].contains(dayNumber)
    }
}

// Preview removed to avoid sample data usage in production code 