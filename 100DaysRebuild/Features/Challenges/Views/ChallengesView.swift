import SwiftUI

struct ChallengesView: View {
    @StateObject private var viewModel = ChallengesViewModel()
    @EnvironmentObject private var subscriptionService: SubscriptionService
    
    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.challenges) { challenge in
                    ChallengeCardView(challenge: challenge)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Challenges")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { viewModel.showNewChallenge = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $viewModel.showNewChallenge) {
                NewChallengeSheet(viewModel: viewModel)
            }
        }
    }
}

struct NewChallengeSheet: View {
    @ObservedObject var viewModel: ChallengesViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Challenge Details")) {
                    TextField("Title", text: $viewModel.newChallengeTitle)
                }
                
                Section {
                    Button("Create Challenge") {
                        Task {
                            await viewModel.createChallenge()
                            dismiss()
                        }
                    }
                    .disabled(viewModel.newChallengeTitle.isEmpty)
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
            .environmentObject(SubscriptionService())
    }
} 