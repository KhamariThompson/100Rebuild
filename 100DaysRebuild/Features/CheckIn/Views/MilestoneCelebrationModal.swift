import SwiftUI
import Firebase
import UIKit

struct MilestoneCelebrationModal: View {
    let dayNumber: Int
    let challengeId: String
    let challengeTitle: String
    @Binding var isPresented: Bool
    @StateObject var viewModel = MilestoneCelebrationViewModel()
    @State private var showShareCard = false
    
    // Animation states
    @State private var animateBackground = false
    @State private var animateBadge = false
    @State private var animateTitle = false
    @State private var animateSubtitle = false
    @State private var animateButtons = false
    
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
            .onAppear {
                withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                    animateBackground = true
                }
            }
            
            // Confetti overlay
            ConfettiView(intensity: getConfettiIntensity(), duration: 8.0)
                .ignoresSafeArea()
                .allowsHitTesting(false)
            
            // Modal content
            VStack(spacing: 30) {
                Spacer()
                
                // Badge or emoji
                Text(viewModel.getMilestoneEmoji(for: dayNumber))
                    .font(.system(size: 100))
                    .scaleEffect(animateBadge ? 1.0 : 0.5)
                    .opacity(animateBadge ? 1.0 : 0.0)
                    .padding(.bottom, 10)
                
                // Title text
                Text("You've hit Day \(dayNumber) of 100!")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .offset(y: animateTitle ? 0 : 30)
                    .opacity(animateTitle ? 1.0 : 0.0)
                
                // Motivational subtext
                Text(viewModel.getMilestoneMessage(for: dayNumber))
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                    .padding(.top, 5)
                    .offset(y: animateSubtitle ? 0 : 20)
                    .opacity(animateSubtitle ? 1.0 : 0.0)
                
                Spacer()
                
                // Buttons
                VStack(spacing: 16) {
                    Button(action: {
                        showShareCard = true
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share Your Progress")
                        }
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
                    
                    Button(action: {
                        isPresented = false
                    }) {
                        Text("Keep Going")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.vertical, 16)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white, lineWidth: 2)
                            )
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 40)
                .offset(y: animateButtons ? 0 : 30)
                .opacity(animateButtons ? 1.0 : 0.0)
            }
        }
        .onAppear {
            // Create animation sequence
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                animateBadge = true
            }
            
            withAnimation(.easeOut(duration: 0.7).delay(0.3)) {
                animateTitle = true
            }
            
            withAnimation(.easeOut(duration: 0.7).delay(0.5)) {
                animateSubtitle = true
            }
            
            withAnimation(.easeOut(duration: 0.7).delay(0.7)) {
                animateButtons = true
            }
            
            // Mark this milestone as seen
            viewModel.markMilestoneAsSeen(challengeId: challengeId, day: dayNumber)
        }
        .sheet(isPresented: $showShareCard) {
            MilestoneShareCardView(
                dayNumber: dayNumber,
                challengeTitle: challengeTitle,
                isPresented: $showShareCard
            )
        }
    }
    
    // Adjust confetti intensity based on the milestone significance
    private func getConfettiIntensity() -> CGFloat {
        switch dayNumber {
        case 100: return 2.0  // Maximum celebration for completion
        case 50: return 1.5   // Strong celebration for halfway
        case 30: return 1.2   // Moderate celebration
        case 7: return 1.0    // Standard celebration
        case 3: return 0.8    // Light celebration
        default: return 1.0
        }
    }
}

// View for sharing milestone
struct MilestoneShareCardView: View {
    let dayNumber: Int
    let challengeTitle: String
    @Binding var isPresented: Bool
    @State private var shareImage: UIImage?
    @State private var showShareSheet = false
    @State private var selectedLayout: MilestoneShareCardGenerator.CardLayout = .modern
    
    // Quote to show on the card
    @State private var quote: Quote? = Quote.getRandomQuote()
    
    var body: some View {
        NavigationView {
            VStack {
                ScrollView {
                    VStack(spacing: 20) {
                        // Preview of the share card
                        if let image = shareImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 3)
                                .padding()
                        } else {
                            ProgressView()
                                .padding()
                        }
                        
                        // Layout options
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Card Style")
                                .font(.headline)
                                .foregroundColor(.theme.text)
                            
                            HStack(spacing: 12) {
                                LayoutOptionButton(
                                    layout: .modern,
                                    isSelected: selectedLayout == .modern,
                                    action: {
                                        selectedLayout = .modern
                                        generateShareImage()
                                    }
                                )
                                
                                LayoutOptionButton(
                                    layout: .classic,
                                    isSelected: selectedLayout == .classic,
                                    action: {
                                        selectedLayout = .classic
                                        generateShareImage()
                                    }
                                )
                                
                                LayoutOptionButton(
                                    layout: .minimal,
                                    isSelected: selectedLayout == .minimal,
                                    action: {
                                        selectedLayout = .minimal
                                        generateShareImage()
                                    }
                                )
                            }
                            .padding(.horizontal)
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Share Your Milestone")
            .navigationBarItems(leading: Button("Cancel") {
                isPresented = false
            })
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        showShareSheet = true
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.theme.accent)
                                .shadow(color: Color.theme.accent.opacity(0.3), radius: 5, x: 0, y: 3)
                        )
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                }
            }
            .onAppear {
                generateShareImage()
            }
            .sheet(isPresented: $showShareSheet) {
                if let image = shareImage {
                    ShareSheet(items: [image])
                }
            }
        }
    }
    
    private func generateShareImage() {
        // Use the MilestoneShareCardGenerator
        let image = MilestoneShareCardGenerator.generateMilestoneCard(
            currentDay: dayNumber,
            challengeTitle: challengeTitle,
            quote: quote,
            backgroundStyle: .gradient([Color.theme.accent, Color.theme.accent.opacity(0.7)]),
            layout: selectedLayout
        )
        
        self.shareImage = image
    }
}

// Layout option button component
struct LayoutOptionButton: View {
    let layout: MilestoneShareCardGenerator.CardLayout
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                Text(layoutName)
                    .font(.caption)
                    .foregroundColor(isSelected ? .theme.accent : .theme.text)
                
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.theme.surface)
                        .frame(width: 80, height: 50)
                        .shadow(color: Color.theme.shadow.opacity(0.1), radius: 3, x: 0, y: 2)
                    
                    Image(systemName: layoutIcon)
                        .font(.title3)
                        .foregroundColor(isSelected ? .theme.accent : .theme.subtext)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.theme.accent : Color.clear, lineWidth: 2)
                )
            }
        }
    }
    
    private var layoutName: String {
        switch layout {
        case .modern: return "Modern"
        case .classic: return "Classic"
        case .minimal: return "Minimal"
        }
    }
    
    private var layoutIcon: String {
        switch layout {
        case .modern: return "square.3.stack.3d"
        case .classic: return "rectangle.grid.1x2"
        case .minimal: return "rectangle.fill.on.rectangle.fill"
        }
    }
}

struct MilestoneCelebrationModal_Previews: PreviewProvider {
    static var previews: some View {
        MilestoneCelebrationModal(
            dayNumber: 30,
            challengeId: "sample-challenge",
            challengeTitle: "Learn iOS Development",
            isPresented: .constant(true)
        )
    }
} 