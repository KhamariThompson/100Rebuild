import SwiftUI

// Extension to ensure we always use the enhanced history view
extension View {
    func historyNavigation(isPresented: Binding<Bool>, challenge: Challenge) -> some View {
        self.sheet(isPresented: isPresented) {
            EnhancedCheckInHistoryView(challenge: challenge)
        }
    }
    
    func checkInNavigation(isPresented: Binding<Bool>, challenge: Challenge, viewModel: ChallengesViewModel) -> some View {
        self.sheet(isPresented: isPresented) {
            EnhancedCheckInView(
                challengesViewModel: viewModel,
                challenge: challenge
            )
        }
    }
}

// Helper struct to enhance navigation to check-in history from anywhere
struct CheckInHistoryButton: View {
    let challenge: Challenge
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
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
    }
} 