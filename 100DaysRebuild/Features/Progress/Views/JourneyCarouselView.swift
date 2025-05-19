import SwiftUI
import Firebase
import FirebaseFirestore

// MARK: - Journey Card Model

struct JourneyCard: Identifiable {
    let id = UUID()
    let type: JourneyCardType
    
    enum JourneyCardType {
        case milestone(message: String, emoji: String, dayNumber: Int?, date: Date)
        case streak(count: Int, date: Date)
        case completion(title: String, date: Date)
        case photoNote(photo: URL?, note: String, dayNumber: Int, date: Date)
    }
    
    // Factory methods for creating different card types
    static func streakCard(streakDays: Int, date: Date) -> JourneyCard {
        JourneyCard(type: .streak(count: streakDays, date: date))
    }
    
    static func weekCompleteCard(weekNumber: Int, date: Date) -> JourneyCard {
        JourneyCard(type: .completion(title: "Week \(weekNumber) complete!", date: date))
    }
    
    static func photoNoteCard(photo: URL?, note: String, dayNumber: Int, date: Date) -> JourneyCard {
        JourneyCard(type: .photoNote(photo: photo, note: note, dayNumber: dayNumber, date: date))
    }
    
    static func milestoneCard(dayNumber: Int, date: Date) -> JourneyCard {
        let message: String
        let emoji: String
        
        switch dayNumber {
        case 1:
            message = "First day completed!"
            emoji = "🎉"
        case 10:
            message = "10 days down, 90 to go!"
            emoji = "🚀"
        case 25:
            message = "You're 25% through your journey!"
            emoji = "🌱"
        case 30:
            message = "30 days - A whole month complete!"
            emoji = "🏆"
        case 50:
            message = "Halfway there! 50 days complete!"
            emoji = "⭐️"
        case 75:
            message = "75% complete - almost there!"
            emoji = "💪"
        case 90:
            message = "90 days - the finish line is in sight!"
            emoji = "🏁"
        case 100:
            message = "Challenge complete! Congratulations!"
            emoji = "🎊"
        default:
            if dayNumber % 5 == 0 {
                message = "Day \(dayNumber) complete!"
                emoji = "📌"
            } else {
                message = "Keep going! \(100 - dayNumber) days left"
                emoji = "👏"
            }
        }
        
        return JourneyCard(type: .milestone(
            message: message,
            emoji: emoji,
            dayNumber: dayNumber,
            date: date
        ))
    }
}

// MARK: - Journey Carousel View

struct JourneyCarouselView: View {
    @ObservedObject var viewModel: ProgressDashboardViewModel
    @Environment(\.colorScheme) var colorScheme
    
    // For animation and interaction
    @State private var currentIndex: Int = 0
    @State private var dragOffset: CGFloat = 0
    @State private var isAnimating = false
    
    // Card animation timing
    let animationDelayBase: Double = 0.2
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Your Journey")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.theme.text)
                
                Spacer()
                
                // Only show pagination controls if there are multiple cards
                if viewModel.journeyCards.count > 1 {
                    HStack(spacing: 12) {
                        Button(action: previousCard) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(currentIndex > 0 ? .theme.accent : .theme.subtext.opacity(0.3))
                                .padding(8)
                                .background(Circle().fill(Color.theme.background))
                                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                        }
                        .disabled(currentIndex <= 0)
                        
                        Button(action: nextCard) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(currentIndex < viewModel.journeyCards.count - 1 ? .theme.accent : .theme.subtext.opacity(0.3))
                                .padding(8)
                                .background(Circle().fill(Color.theme.background))
                                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                        }
                        .disabled(currentIndex >= viewModel.journeyCards.count - 1)
                    }
                }
            }
            
            // Journey timeline cards
            if viewModel.journeyCards.isEmpty {
                emptyJourneyView
            } else {
                // Main carousel
                GeometryReader { geometry in
                    let cardWidth = geometry.size.width - 40
                    
                    ZStack {
                        ForEach(Array(viewModel.journeyCards.enumerated()), id: \.element.id) { index, card in
                            JourneyCardViewComponent(card: card)
                                .frame(width: cardWidth)
                                .offset(x: CGFloat(index - currentIndex) * cardWidth + dragOffset)
                                .scaleEffect(scaleForCard(index: index))
                                .opacity(opacityForCard(index: index))
                                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
                                .zIndex(index == currentIndex ? 1 : 0)
                                .accessibilityHidden(index != currentIndex)
                        }
                    }
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: dragOffset)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentIndex)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                dragOffset = value.translation.width
                            }
                            .onEnded { value in
                                let threshold = cardWidth / 2
                                if value.translation.width > threshold && currentIndex > 0 {
                                    currentIndex -= 1
                                    hapticFeedback(style: .soft)
                                } else if value.translation.width < -threshold && currentIndex < viewModel.journeyCards.count - 1 {
                                    currentIndex += 1
                                    hapticFeedback(style: .soft)
                                }
                                dragOffset = 0
                            }
                    )
                }
                .frame(height: 180)
                
                // Pagination indicator
                if viewModel.journeyCards.count > 1 {
                    HStack(spacing: 8) {
                        ForEach(0..<viewModel.journeyCards.count, id: \.self) { index in
                            Circle()
                                .fill(index == currentIndex ? Color.theme.accent : Color.theme.subtext.opacity(0.3))
                                .frame(width: index == currentIndex ? 8 : 6, height: index == currentIndex ? 8 : 6)
                                .animation(.spring(response: 0.3), value: currentIndex)
                        }
                    }
                    .padding(.top, 8)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.theme.surface)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal)
        .onAppear {
            // Start appearance animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeIn(duration: 0.5)) {
                    isAnimating = true
                }
            }
        }
    }
    
    // Empty state view when there are no journey cards
    private var emptyJourneyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "map")
                .font(.system(size: 40))
                .foregroundColor(.theme.accent.opacity(0.6))
                .padding(.bottom, 4)
            
            Text("Your journey is just beginning")
                .font(.headline)
                .multilineTextAlignment(.center)
            
            Text("Complete your first challenge to start tracking your progress")
                .font(.subheadline)
                .foregroundColor(.theme.subtext)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(height: 180)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
    
    // Calculate scale based on card position
    private func scaleForCard(index: Int) -> CGFloat {
        let offset = abs(index - currentIndex)
        
        if offset > 0 {
            return 0.95 - (0.05 * CGFloat(min(offset, 1)))
        }
        
        return 1.0
    }
    
    // Calculate opacity based on card position
    private func opacityForCard(index: Int) -> Double {
        let offset = abs(index - currentIndex)
        if offset > 1 {
            return 0
        }
        return 1.0 - (0.4 * Double(offset))
    }
    
    // Navigation actions
    private func nextCard() {
        if currentIndex < viewModel.journeyCards.count - 1 {
            hapticFeedback(style: .light)
            currentIndex += 1
        }
    }
    
    private func previousCard() {
        if currentIndex > 0 {
            hapticFeedback(style: .light)
            currentIndex -= 1
        }
    }
    
    // Haptic feedback helper
    private func hapticFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}

// Individual journey card view
struct JourneyCardViewComponent: View {
    let card: JourneyCard
    
    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.theme.surface)
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            
            // Card Content
            VStack(alignment: .leading, spacing: 12) {
                switch card.type {
                case .photoNote(_, let note, let dayNumber, let date):
                    cardHeader(title: "Day \(dayNumber)", date: date)
                    
                    Text(note)
                        .font(.body)
                        .foregroundColor(.theme.text)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                    
                case .milestone(let message, let emoji, let dayNumber, let date):
                    HStack {
                        if let day = dayNumber {
                            cardHeader(title: "Day \(day)", date: date)
                        } else {
                            cardHeader(title: "Milestone", date: date)
                        }
                    }
                    
                    HStack(alignment: .center, spacing: 8) {
                        // Show SF Symbol if it's valid, otherwise show as emoji
                        if emoji.hasPrefix("sf:") {
                            let sfName = String(emoji.dropFirst(3))
                            Image(systemName: sfName)
                                .font(.largeTitle)
                                .foregroundColor(.theme.accent)
                        } else {
                            Text(emoji)
                                .font(.largeTitle)
                        }
                        
                        Text(message)
                            .font(.headline)
                            .foregroundColor(.theme.text)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }
                    
                case .streak(let count, let date):
                    cardHeader(title: "Streak", date: date)
                    
                    HStack(alignment: .center, spacing: 8) {
                        Image(systemName: "flame.fill")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        
                        Text("\(count)-day streak! Keep it up!")
                            .font(.headline)
                            .foregroundColor(.theme.text)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }
                    
                case .completion(let title, let date):
                    cardHeader(title: "Milestone", date: date)
                    
                    HStack(alignment: .center, spacing: 8) {
                        Image(systemName: "trophy.fill")
                            .font(.largeTitle)
                            .foregroundColor(.theme.accent)
                        
                        Text(title)
                            .font(.headline)
                            .foregroundColor(.theme.text)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }
                }
                
                Spacer()
            }
            .padding()
            .frame(width: 280, height: 160)
        }
    }
    
    private func cardHeader(title: String, date: Date) -> some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(.theme.accent)
            
            Spacer()
            
            Text(date, style: .date)
                .font(.caption)
                .foregroundColor(.theme.subtext)
        }
    }
}

// Extension to blend colors
extension Color {
    func blended(with color: Color, ratio: Double = 0.5) -> Color {
        // Simple linear interpolation between colors using UIColor
        let backgroundColor = UIColor(self)
        let foregroundColor = UIColor(color)
        
        var bgR: CGFloat = 0, bgG: CGFloat = 0, bgB: CGFloat = 0, bgA: CGFloat = 0
        var fgR: CGFloat = 0, fgG: CGFloat = 0, fgB: CGFloat = 0, fgA: CGFloat = 0
        
        // Get components with default fallbacks
        backgroundColor.getRed(&bgR, green: &bgG, blue: &bgB, alpha: &bgA)
        foregroundColor.getRed(&fgR, green: &fgG, blue: &fgB, alpha: &fgA)
        
        let r = bgR * CGFloat(1 - ratio) + fgR * CGFloat(ratio)
        let g = bgG * CGFloat(1 - ratio) + fgG * CGFloat(ratio)
        let b = bgB * CGFloat(1 - ratio) + fgB * CGFloat(ratio)
        let a = bgA * CGFloat(1 - ratio) + fgA * CGFloat(ratio)
        
        return Color(red: Double(r), green: Double(g), blue: Double(b), opacity: Double(a))
    }
}

// Preview struct for Xcode previews
struct JourneyCarouselView_Previews: PreviewProvider {
    static var previews: some View {
        JourneyCarouselView(viewModel: ProgressDashboardViewModel.shared)
            .padding()
            .background(Color.theme.background)
            .previewLayout(.sizeThatFits)
    }
}

// MARK: - Card Components

struct PhotoNoteCard: View {
    let photo: URL?
    let note: String
    let dayNumber: Int
    let date: Date
    let height: CGFloat
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text("Day \(dayNumber)")
                    .font(.headline)
                    .foregroundColor(.theme.accent)
                
                Spacer()
                
                Text(date, style: .date)
                    .font(.caption)
                    .foregroundColor(.theme.subtext)
            }
            
            Spacer()
            
            // Photo
            if let photoURL = photo {
                AsyncImage(url: photoURL) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(height: height - 80)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(height: height - 80)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    case .failure:
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundColor(.theme.subtext.opacity(0.5))
                            .frame(height: height - 80)
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(height: height - 80)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            // Note
            if !note.isEmpty {
                Text(note)
                    .font(.subheadline)
                    .foregroundColor(.theme.text)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Spacer()
            }
            
            Spacer()
        }
        .padding()
        .frame(width: 160, height: height)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.theme.surface)
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
}

struct MilestoneCard: View {
    let message: String
    let emoji: String
    let dayNumber: Int?
    let date: Date
    let height: CGFloat
    
    var body: some View {
        VStack(spacing: 16) {
            if let dayNumber = dayNumber {
                Text("Day \(dayNumber)")
                    .font(.headline)
                    .foregroundColor(.theme.accent)
            }
            
            Text(emoji)
                .font(.system(size: 42))
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.theme.text)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
            
            Spacer()
            
            Text(date, style: .date)
                .font(.caption)
                .foregroundColor(.theme.subtext)
        }
        .padding()
        .frame(width: 160, height: height)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.theme.surface)
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
}

// MARK: - Journey Card Detail View

struct JourneyCardDetailView: View {
    let card: JourneyCard
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Card content based on type
                    switch card.type {
                    case .photoNote(let photo, let note, let dayNumber, let date):
                        Text("Day \(dayNumber)")
                            .font(.title)
                            .foregroundColor(.theme.accent)
                        
                        Text(date, style: .date)
                            .font(.subheadline)
                            .foregroundColor(.theme.subtext)
                        
                        Divider()
                        
                        if let photoURL = photo {
                            AsyncImage(url: photoURL) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                        .frame(height: 300)
                                        .frame(maxWidth: .infinity)
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFit()
                                        .cornerRadius(12)
                                case .failure:
                                    Image(systemName: "photo")
                                        .font(.system(size: 80))
                                        .foregroundColor(.theme.subtext.opacity(0.5))
                                        .frame(height: 300)
                                        .frame(maxWidth: .infinity)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                            .padding(.vertical)
                        }
                        
                        Text(note)
                            .font(.body)
                            .foregroundColor(.theme.text)
                            .multilineTextAlignment(.leading)
                        
                    case .milestone(let message, let emoji, let dayNumber, let date):
                        if let day = dayNumber {
                            Text("Day \(day)")
                                .font(.title)
                                .foregroundColor(.theme.accent)
                        } else {
                            Text("Milestone")
                                .font(.title)
                                .foregroundColor(.theme.accent)
                        }
                        
                        Text(date, style: .date)
                            .font(.subheadline)
                            .foregroundColor(.theme.subtext)
                        
                        Divider()
                        
                        HStack(alignment: .center, spacing: 16) {
                            // Show SF Symbol if it's valid, otherwise show as emoji
                            if emoji.hasPrefix("sf:") {
                                let sfName = String(emoji.dropFirst(3))
                                Image(systemName: sfName)
                                    .font(.system(size: 60))
                                    .foregroundColor(.theme.accent)
                            } else {
                                Text(emoji)
                                    .font(.system(size: 60))
                            }
                            
                            Text(message)
                                .font(.headline)
                                .foregroundColor(.theme.text)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(.vertical)
                        
                        Text("This milestone marks an important point in your 100-day journey. Keep up the great work!")
                            .font(.body)
                            .foregroundColor(.theme.subtext)
                            .padding(.top)
                            
                    case .streak(let count, let date):
                        Text("Streak Milestone")
                            .font(.title)
                            .foregroundColor(.theme.accent)
                        
                        Text(date, style: .date)
                            .font(.subheadline)
                            .foregroundColor(.theme.subtext)
                        
                        Divider()
                        
                        HStack(alignment: .center, spacing: 16) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.orange)
                            
                            Text("\(count)-day streak! Keep it up!")
                                .font(.headline)
                                .foregroundColor(.theme.text)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(.vertical)
                        
                        Text("Maintaining a streak is a powerful way to build momentum. You're doing great!")
                            .font(.body)
                            .foregroundColor(.theme.subtext)
                            .padding(.top)
                            
                    case .completion(let title, let date):
                        Text("Achievement")
                            .font(.title)
                            .foregroundColor(.theme.accent)
                        
                        Text(date, style: .date)
                            .font(.subheadline)
                            .foregroundColor(.theme.subtext)
                        
                        Divider()
                        
                        HStack(alignment: .center, spacing: 16) {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.theme.accent)
                            
                            Text(title)
                                .font(.headline)
                                .foregroundColor(.theme.text)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(.vertical)
                        
                        Text("This achievement marks a significant milestone in your journey. Well done!")
                            .font(.body)
                            .foregroundColor(.theme.subtext)
                            .padding(.top)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationBarTitle("Journey Details", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
} 