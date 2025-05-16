import SwiftUI

struct ChallengeDetailView: View {
    let challenge: Challenge
    @ObservedObject var viewModel: ChallengesViewModel
    @State private var showCheckInSheet = false
    @State private var showEditSheet = false
    @State private var showHistoryView = false
    @State private var showTimerSession = false
    
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
                    
                    if challenge.isTimed {
                        HStack {
                            Image(systemName: "timer")
                                .foregroundColor(.theme.accent)
                            Text("Timed Challenge")
                                .font(.caption)
                                .foregroundColor(.theme.accent)
                                .fontWeight(.medium)
                        }
                        .padding(.top, 4)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                
                // Progress card
                challengeProgressCard
                
                // Stats
                challengeStatsCard
                
                // Action buttons
                VStack(spacing: 16) {
                    // Check-in button: Either show timer or regular check-in
                    if challenge.isTimed {
                        Button(action: {
                            showTimerSession = true
                        }) {
                            HStack {
                                Image(systemName: "timer")
                                    .font(.headline)
                                Text(challenge.isCompletedToday ? "Completed Today" : "Start Timer Session")
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
                    } else {
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
                    }
                    
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
        .sheet(isPresented: $showTimerSession) {
            TimerSessionView(challenge: challenge)
        }
        .sheet(isPresented: $showEditSheet) {
            EditChallengeSheet(viewModel: viewModel, challenge: challenge)
        }
        .navigationDestination(isPresented: $showHistoryView) {
            CheckInHistoryView(challenge: challenge)
        }
    }
    
    private var challengeProgressCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Progress bar with percentage
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 16)
                    
                    // Filled portion with gradient
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [.theme.accent, .theme.accent.opacity(0.7)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(16, geo.size.width * challenge.progressPercentage), height: 16)
                }
            }
            .frame(height: 16)
            
            // Info row with day count and percentage
            HStack {
                VStack(alignment: .leading) {
                    Text("Day \(challenge.daysCompleted)/100")
                        .font(.headline)
                        .foregroundColor(.theme.text)
                    Text("\(Int(challenge.progressPercentage * 100))% complete")
                        .font(.subheadline)
                        .foregroundColor(.theme.subtext)
                }
                
                Spacer()
                
                // Streak indicator
                VStack(alignment: .trailing) {
                    HStack(spacing: 4) {
                        Text("\(challenge.streakCount)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.theme.text)
                        
                        Text("day streak")
                            .font(.caption)
                            .foregroundColor(.theme.subtext)
                    }
                    
                    Text(challenge.streakEmoji)
                        .font(.subheadline)
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
    }
    
    private var challengeStatsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Stats")
                .font(.headline)
                .foregroundColor(.theme.text)
            
            // Days remaining
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.theme.accent)
                
                VStack(alignment: .leading) {
                    Text("\(challenge.daysRemaining)")
                        .font(.headline)
                        .foregroundColor(.theme.text)
                    
                    Text("Days Remaining")
                        .font(.caption)
                        .foregroundColor(.theme.subtext)
                }
                
                Spacer()
                
                // Current streak
                Image(systemName: "flame.fill")
                    .foregroundColor(.theme.accent)
                
                VStack(alignment: .leading) {
                    Text("\(challenge.streakCount)")
                        .font(.headline)
                        .foregroundColor(.theme.text)
                    
                    Text("Current Streak")
                        .font(.caption)
                        .foregroundColor(.theme.subtext)
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