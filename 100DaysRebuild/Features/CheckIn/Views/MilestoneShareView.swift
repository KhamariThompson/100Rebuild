import SwiftUI
import UIKit

struct MilestoneShareView: View {
    let milestone: Int
    let challengeTitle: String
    let username: String
    let quote: Quote?
    let onDismiss: () -> Void
    
    @State private var shareableImage: UIImage?
    @State private var isGeneratingImage = false
    @State private var showShareSheet = false
    @State private var selectedLayout: MilestoneShareCardGenerator.CardLayout = .modern
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }
            
            VStack(spacing: AppSpacing.l) {
                // Header
                headerView
                
                // Card Preview
                cardPreviewView
                
                // Layout Selector
                layoutSelectorView
                
                // Action Buttons
                actionButtonsView
            }
            .padding(AppSpacing.screenHorizontalPadding)
        }
        .onAppear {
            generateShareableImage()
        }
        .sheet(isPresented: $showShareSheet) {
            if let shareableImage = shareableImage {
                ShareSheet(items: [shareableImage, shareText])
            }
        }
    }
    
    private var headerView: some View {
        VStack(spacing: AppSpacing.s) {
            HStack {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                
                Spacer()
                
                Text("🎉 Celebrate Your Win!")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                // Placeholder for balance
                Color.clear.frame(width: 32, height: 32)
            }
            
            Text("Share your milestone and inspire others to start their journey!")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
    }
    
    private var cardPreviewView: some View {
        Group {
            if isGeneratingImage {
                VStack(spacing: AppSpacing.m) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                    
                    Text("Creating your milestone card...")
                        .foregroundColor(.white.opacity(0.8))
                        .font(.subheadline)
                }
                .frame(width: 300, height: 450)
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
            } else if let shareableImage = shareableImage {
                Image(uiImage: shareableImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 300, maxHeight: 450)
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: isGeneratingImage)
    }
    
    private var layoutSelectorView: some View {
        VStack(spacing: AppSpacing.s) {
            Text("Choose Style")
                .font(.headline)
                .foregroundColor(.white)
            
            HStack(spacing: AppSpacing.s) {
                ForEach([MilestoneShareCardGenerator.CardLayout.modern, .classic, .minimal], id: \.self) { layout in
                    Button(action: {
                        selectedLayout = layout
                        generateShareableImage()
                    }) {
                        VStack(spacing: 4) {
                            layoutPreviewIcon(for: layout)
                            
                            Text(layoutName(for: layout))
                                .font(.caption)
                                .foregroundColor(selectedLayout == layout ? Color.theme.accent : .white.opacity(0.7))
                        }
                        .padding(AppSpacing.s)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedLayout == layout ? Color.theme.accent.opacity(0.2) : Color.white.opacity(0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedLayout == layout ? Color.theme.accent : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    private var actionButtonsView: some View {
        VStack(spacing: AppSpacing.s) {
            // Primary Share Button
            Button(action: { showShareSheet = true }) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Share to Social Media")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.buttonVerticalPadding)
                .background(
                    LinearGradient(
                        colors: [Color.theme.accent, Color.theme.accent.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(shareableImage == nil)
            .opacity(shareableImage == nil ? 0.6 : 1.0)
            
            // Secondary Skip Button
            Button(action: onDismiss) {
                Text("Maybe Later")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func layoutPreviewIcon(for layout: MilestoneShareCardGenerator.CardLayout) -> some View {
        Group {
            switch layout {
            case .modern:
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(LinearGradient(colors: [Color.theme.accent, Color.theme.accent.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    
                    VStack(spacing: 1) {
                        Text("21")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(.white)
                        Rectangle()
                            .fill(Color.white.opacity(0.8))
                            .frame(width: 12, height: 1)
                        Text("DAY")
                            .font(.system(size: 4, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 32, height: 48)
                
            case .classic:
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.theme.gradientStart)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                    
                    VStack(spacing: 1) {
                        Text("21")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                        Text("DAY")
                            .font(.system(size: 4, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .frame(width: 32, height: 48)
                
            case .minimal:
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.black.opacity(0.7))
                    
                    Text("21")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white)
                }
                .frame(width: 32, height: 48)
            }
        }
    }
    
    private func layoutName(for layout: MilestoneShareCardGenerator.CardLayout) -> String {
        switch layout {
        case .modern: return "Modern"
        case .classic: return "Classic"
        case .minimal: return "Minimal"
        }
    }
    
    private func generateShareableImage() {
        isGeneratingImage = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let backgroundStyle: MilestoneShareCardGenerator.BackgroundStyle
            
            switch selectedLayout {
            case .modern:
                backgroundStyle = .gradient([Color.theme.accent, Color.theme.gradientEnd])
            case .classic:
                backgroundStyle = .gradient([Color.theme.gradientStart, Color.theme.gradientEnd])
            case .minimal:
                backgroundStyle = .solid(Color.black.opacity(0.8))
            }
            
            let image = MilestoneShareCardGenerator.generateMilestoneCard(
                currentDay: milestone,
                challengeTitle: challengeTitle,
                quote: quote,
                backgroundStyle: backgroundStyle,
                layout: selectedLayout
            )
            
            DispatchQueue.main.async {
                self.shareableImage = image
                self.isGeneratingImage = false
            }
        }
    }
    
    private var shareText: String {
        switch milestone {
        case 100:
            return "🎉 I just completed my 100-day journey with \(challengeTitle)! 100 days of consistency and I feel amazing. Who's ready to start their own transformation? Download 100Days App and let's do this together! #100DaysChallenge #HabitTracker #Consistency"
        case let day where [7, 21, 30, 50, 75, 90].contains(day):
            return "🔥 Day \(milestone) of \(challengeTitle) complete! Building habits one day at a time. The momentum is real! Join me on the 100Days App. #Day\(milestone) #HabitBuilding #100DaysChallenge #ConsistencyWins"
        default:
            return "✅ Day \(milestone) of \(challengeTitle) in the books! Every day is progress. Building something amazing with the 100Days App! #HabitTracker #DailyProgress #100DaysChallenge"
        }
    }
}

// MARK: - ShareSheet Integration
// ShareSheet is defined in Utilities/ShareSheet.swift

#Preview {
    MilestoneShareView(
        milestone: 30,
        challengeTitle: "Morning Workout",
        username: "sarah_fitness",
        quote: Quote(text: "Success is the sum of small efforts, repeated day in and day out.", author: "Robert Collier"),
        onDismiss: {}
    )
} 