import SwiftUI
import Firebase
import FirebaseFirestore

// MARK: - Journey Card Model

struct JourneyCard: Identifiable {
    let id = UUID()
    enum CardType {
        case photoNote(photo: URL?, note: String, dayNumber: Int, date: Date)
        case milestone(message: String, emoji: String, dayNumber: Int?, date: Date)
    }
    let type: CardType
    
    // Factory methods for creating different card types
    static func photoNoteCard(photo: URL?, note: String, dayNumber: Int, date: Date) -> JourneyCard {
        JourneyCard(type: .photoNote(photo: photo, note: note, dayNumber: dayNumber, date: date))
    }
    
    static func streakCard(streakDays: Int, date: Date) -> JourneyCard {
        JourneyCard(type: .milestone(
            message: "You checked in \(streakDays) days in a row",
            emoji: "✅",
            dayNumber: nil,
            date: date
        ))
    }
    
    static func weekCompleteCard(weekNumber: Int, date: Date) -> JourneyCard {
        JourneyCard(type: .milestone(
            message: "Week \(weekNumber) complete!",
            emoji: "🔥",
            dayNumber: weekNumber * 7,
            date: date
        ))
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
    @ObservedObject var viewModel: UPViewModel
    private let cardHeight: CGFloat = 180
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Journey So Far")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.theme.text)
            
            if viewModel.journeyCards.isEmpty {
                emptyJourneyView
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(viewModel.journeyCards) { card in
                            switch card.type {
                            case .photoNote(let photo, let note, let dayNumber, let date):
                                PhotoNoteCard(
                                    photo: photo,
                                    note: note,
                                    dayNumber: dayNumber,
                                    date: date,
                                    height: cardHeight
                                )
                                
                            case .milestone(let message, let emoji, let dayNumber, let date):
                                MilestoneCard(
                                    message: message,
                                    emoji: emoji,
                                    dayNumber: dayNumber,
                                    date: date,
                                    height: cardHeight
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
                .frame(height: cardHeight)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.theme.surface)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal)
    }
    
    private var emptyJourneyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 32))
                .foregroundColor(.theme.accent)
            
            Text("Your journey will appear here after your first check-in")
                .font(.subheadline)
                .foregroundColor(.theme.subtext)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(height: cardHeight)
        .frame(maxWidth: .infinity)
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