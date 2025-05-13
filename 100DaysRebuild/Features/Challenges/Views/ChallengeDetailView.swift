import SwiftUI

struct ChallengeDetailView: View {
    let challenge: Challenge
    @ObservedObject var viewModel: ChallengesViewModel
    @State private var showCheckInSheet = false
    @State private var showEditSheet = false
    @State private var showHistoryView = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Challenge header
                VStack(alignment: .leading, spacing: 8) {
                    Text(challenge.title)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.theme.text)
                    
                    Text("Started on \(challenge.startDate, style: .date)")
                        .font(.subheadline)
                        .foregroundColor(.theme.subtext)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                
                // Progress card
                VStack(spacing: 16) {
                    // Day progress
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Day")
                                .font(.headline)
                                .foregroundColor(.theme.subtext)
                            
                            Text("\(challenge.daysCompleted)/100")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.theme.text)
                        }
                        
                        Spacer()
                        
                        ProgressCircle(
                            progress: Double(challenge.daysCompleted) / 100.0,
                            size: 70,
                            lineWidth: 8
                        )
                    }
                    
                    // Progress bar
                    ProgressBar(value: Double(challenge.daysCompleted) / 100.0)
                        .frame(height: 8)
                    
                    // Current streak
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Current Streak")
                                .font(.headline)
                                .foregroundColor(.theme.subtext)
                            
                            Text("\(challenge.streakCount) days")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.theme.text)
                        }
                        
                        Spacer()
                        
                        Image(systemName: challenge.streakCount > 0 ? "flame.fill" : "flame")
                            .font(.system(size: 30))
                            .foregroundColor(challenge.streakCount > 0 ? .orange : .theme.subtext)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.theme.surface)
                        .shadow(color: Color.theme.shadow.opacity(0.1), radius: 5, x: 0, y: 2)
                )
                .padding(.horizontal)
                
                // Action buttons
                VStack(spacing: 16) {
                    Button(action: {
                        showCheckInSheet = true
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.headline)
                            Text("Check In for Today")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    challenge.isCompletedToday 
                                    ? Color.gray 
                                    : Color.theme.accent
                                )
                        )
                    }
                    .disabled(challenge.isCompletedToday)
                    
                    Button(action: {
                        showHistoryView = true
                    }) {
                        HStack {
                            Image(systemName: "calendar")
                                .font(.headline)
                            Text("View Check-In History")
                                .font(.headline)
                        }
                        .foregroundColor(.theme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.theme.accent, lineWidth: 1)
                        )
                    }
                    
                    Button(action: {
                        showEditSheet = true
                    }) {
                        HStack {
                            Image(systemName: "pencil")
                                .font(.headline)
                            Text("Edit Challenge")
                                .font(.headline)
                        }
                        .foregroundColor(.theme.subtext)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.theme.subtext.opacity(0.5), lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding(.vertical, 20)
        }
        .background(Color.theme.background.ignoresSafeArea())
        .navigationTitle("Challenge Details")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showCheckInSheet) {
            EnhancedCheckInView(
                challengesViewModel: viewModel,
                challenge: challenge
            )
        }
        .sheet(isPresented: $showEditSheet) {
            EditChallengeSheet(viewModel: viewModel, challenge: challenge)
        }
        .navigationDestination(isPresented: $showHistoryView) {
            CheckInHistoryView(challenge: challenge)
        }
    }
}

struct ProgressBar: View {
    var value: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .opacity(0.2)
                    .foregroundColor(.theme.accent)
                
                Rectangle()
                    .frame(width: min(CGFloat(self.value) * geometry.size.width, geometry.size.width), height: geometry.size.height)
                    .foregroundColor(.theme.accent)
                    .animation(.linear, value: value)
            }
            .cornerRadius(45)
        }
    }
}

struct ProgressCircle: View {
    var progress: Double
    var size: CGFloat
    var lineWidth: CGFloat
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    Color.theme.accent.opacity(0.2),
                    lineWidth: lineWidth
                )
            
            Circle()
                .trim(from: 0, to: CGFloat(min(progress, 1.0)))
                .stroke(
                    Color.theme.accent,
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear, value: progress)
            
            Text("\(Int(progress * 100))%")
                .font(.caption)
                .bold()
                .foregroundColor(.theme.text)
        }
        .frame(width: size, height: size)
    }
}

// Preview removed to avoid sample data usage in production code 