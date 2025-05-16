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
                    Color.theme.accent.opacity(0.8),
                    Color.theme.accent.opacity(0.5)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blur(radius: animateBackground ? 30 : 50)
            .scaleEffect(animateBackground ? 1.1 : 1.0)
            .animation(
                Animation.easeInOut(duration: 8.0).repeatForever(autoreverses: true),
                value: animateBackground
            )
            .ignoresSafeArea()
            .overlay {
                ZStack {
                    // Particles
                    ForEach(0..<20) { index in
                        let size = CGFloat.random(in: 5...15)
                        let xPosition = CGFloat.random(in: 0...UIScreen.main.bounds.width)
                        let yPosition = CGFloat.random(in: 0...UIScreen.main.bounds.height)
                        
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: size, height: size)
                            .position(x: xPosition, y: yPosition)
                            .animation(
                                Animation.easeInOut(duration: Double.random(in: 10...20))
                                    .repeatForever(autoreverses: true),
                                value: animateBackground
                            )
                    }
                }
                .mask(
                    LinearGradient(
                        gradient: Gradient(colors: [.white.opacity(0.3), .clear]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            
            // Content
            ScrollView {
                VStack(spacing: 30) {
                    // Checkmark success animation
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.15))
                            .frame(width: 130, height: 130)
                            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                        
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 110, height: 110)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 60, weight: .bold))
                            .foregroundColor(.white)
                            .offset(y: animateContent ? 0 : -100)
                            .opacity(animateContent ? 1 : 0)
                            .animation(.spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0.5).delay(0.1), value: animateContent)
                    }
                    .padding(.top, 40)
                    
                    // Day completion text
                    VStack(spacing: 10) {
                        Text("Day \(dayNumber) Complete!")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .opacity(animateContent ? 1 : 0)
                            .offset(y: animateContent ? 0 : 20)
                            .animation(.easeOut(duration: 0.5).delay(0.3), value: animateContent)
                        
                        Text(challenge.title)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .opacity(animateContent ? 1 : 0)
                            .offset(y: animateContent ? 0 : 20)
                            .animation(.easeOut(duration: 0.5).delay(0.4), value: animateContent)
                        
                        HStack(spacing: 8) {
                            Text("Current streak:")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.8))
                            
                            Text("\(challenge.streakCount) days")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.top, 4)
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : 20)
                        .animation(.easeOut(duration: 0.5).delay(0.5), value: animateContent)
                    }
                    
                    // Quote card
                    if let quote = quote, !quote.text.isEmpty {
                        VStack(spacing: 16) {
                            Text(quote.text)
                                .font(.system(size: 18, weight: .medium))
                                .italic()
                                .foregroundColor(.theme.text)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Text("— \(quote.author)")
                                .font(.system(size: 14))
                                .foregroundColor(.theme.subtext)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 24)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.ultraThinMaterial)
                                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                        )
                        .padding(.horizontal, 20)
                        .opacity(animateQuote ? 1 : 0)
                        .offset(y: animateQuote ? 0 : 30)
                        .animation(.easeOut(duration: 0.6).delay(0.7), value: animateQuote)
                    }
                    
                    // Motivational message
                    Text(motivationalMessage)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 10)
                        .opacity(animateMotivation ? 1 : 0)
                        .offset(y: animateMotivation ? 0 : 20)
                        .animation(.easeOut(duration: 0.5).delay(0.9), value: animateMotivation)
                    
                    // Action buttons
                    VStack(spacing: 16) {
                        // Add notes button
                        Button(action: {
                            showNotePrompt = true
                            isPresented = false
                        }) {
                            HStack {
                                Image(systemName: "square.and.pencil")
                                    .font(.system(size: 18))
                                
                                Text("Add Journal Entry")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white.opacity(0.25))
                                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                            )
                        }
                        .accessibilityLabel("Add journal entry")
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : 20)
                        .animation(.easeOut(duration: 0.5).delay(1.1), value: animateContent)
                        
                        // Share achievement button
                        Button(action: {
                            showShareCustomizer = true
                        }) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 18))
                                
                                Text("Share Your Achievement")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                            .foregroundColor(.theme.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white)
                                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                            )
                        }
                        .accessibilityLabel("Share your achievement")
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : 20)
                        .animation(.easeOut(duration: 0.5).delay(1.2), value: animateContent)
                        
                        // Continue button
                        Button(action: {
                            isPresented = false
                        }) {
                            Text("Continue")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.vertical, 8)
                        }
                        .accessibilityLabel("Continue without adding notes")
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : 20)
                        .animation(.easeOut(duration: 0.5).delay(1.3), value: animateContent)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 50)
                }
            }
            .sheet(isPresented: $showShareCustomizer) {
                ShareCardCustomizerView(viewModel: viewModel, dayNumber: dayNumber, challenge: challenge)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                animateBackground = true
                withAnimation {
                    animateContent = true
                    animateQuote = true
                    animateMotivation = true
                }
            }
            
            // Haptic feedback
            let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
            impactHeavy.impactOccurred()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                let impactLight = UIImpactFeedbackGenerator(style: .light)
                impactLight.impactOccurred()
            }
        }
    }
}

// Preview removed to avoid sample data usage in production code 