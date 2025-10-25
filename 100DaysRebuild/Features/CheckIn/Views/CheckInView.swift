import SwiftUI

struct CheckInView: View {
    @StateObject private var viewModel = CheckInViewModel()

    var body: some View {
        ZStack {
            // Existing overlays

            // Milestone Share Modal
            if viewModel.showMilestoneShare, let quote = viewModel.currentQuote {
                MilestoneShareView(
                    milestone: viewModel.currentDay,
                    challengeTitle: viewModel.challengeTitle,
                    username: UserSession.shared.username ?? "You",
                    quote: quote,
                    onDismiss: {
                        viewModel.showMilestoneShare = false
                    }
                )
                .animation(.easeInOut(duration: 0.3), value: viewModel.showMilestoneShare)
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
    }
}

#Preview {
    CheckInView()
} 