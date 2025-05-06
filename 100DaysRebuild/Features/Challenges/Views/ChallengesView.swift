import SwiftUI

struct ChallengesView: View {
    @StateObject private var viewModel = ChallengesViewModel()
    @EnvironmentObject private var subscriptionService: SubscriptionService
    
    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.challenges) { challenge in
                    ChallengeCardView(challenge: challenge, onCheckIn: {
                        Task {
                            await viewModel.checkIn(to: challenge)
                        }
                    })
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Challenges")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { viewModel.isShowingNewChallenge = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $viewModel.isShowingNewChallenge) {
                NewChallengeSheet(viewModel: viewModel)
                    .environmentObject(subscriptionService)
            }
        }
    }
}

struct NewChallengeSheet: View {
    @ObservedObject var viewModel: ChallengesViewModel
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var subscriptionService: SubscriptionService
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Challenge Details")) {
                    TextField("Title", text: $viewModel.challengeTitle)
                }
                
                Section {
                    Button("Create Challenge") {
                        Task {
                            await viewModel.createChallenge(title: viewModel.challengeTitle)
                            dismiss()
                        }
                    }
                    .disabled(viewModel.challengeTitle.isEmpty)
                }
            }
            .navigationTitle("New Challenge")
            .navigationBarItems(trailing: Button("Cancel") { dismiss() })
        }
    }
}

struct ChallengesView_Previews: PreviewProvider {
    static var previews: some View {
        ChallengesView()
            .environmentObject(SubscriptionService.shared)
            .environmentObject(UserSession.shared)
    }
} 