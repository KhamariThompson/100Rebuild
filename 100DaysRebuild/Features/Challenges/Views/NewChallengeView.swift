import SwiftUI

struct NewChallengeView: View {
    @Binding var isPresented: Bool
    @Binding var challengeTitle: String
    @State private var isTimed: Bool = false
    @FocusState private var isTitleFocused: Bool
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @EnvironmentObject private var notificationService: NotificationService
    var onCreateChallenge: (String, Bool) -> Void
    
    // Popular challenge suggestions
    private let challengeSuggestions = [
        "Go to the gym",
        "Read 10 pages",
        "No sugar",
        "Code every day",
        "Meditate",
        "Drink a gallon of water"
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Challenge Details")) {
                    TextField("Title", text: $challengeTitle)
                        .focused($isTitleFocused)
                    
                    Toggle(isOn: $isTimed) {
                        HStack {
                            Image(systemName: "timer")
                                .foregroundColor(.theme.accent)
                            Text("Require timer to check in")
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .theme.accent))
                    
                    if isTimed {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Timer challenges require you to complete a timed session before checking in.")
                                .font(.callout)
                                .foregroundColor(.theme.subtext)
                                .padding(.vertical, 4)
                        }
                    }
                }
                
                Section(header: Text("Popular Challenge Ideas")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(challengeSuggestions, id: \.self) { suggestion in
                                Button(action: {
                                    challengeTitle = suggestion
                                }) {
                                    Text(suggestion)
                                        .font(.footnote)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(Color.theme.surface)
                                                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                                        )
                                        .foregroundColor(.theme.text)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .padding(.horizontal, -16)
                }
                
                Section {
                    Button("Create Challenge") {
                        onCreateChallenge(challengeTitle, isTimed)
                        isPresented = false
                    }
                    .disabled(challengeTitle.isEmpty)
                }
            }
            .navigationTitle("New Challenge")
            .navigationBarItems(trailing: Button("Cancel") { isPresented = false })
            .onAppear {
                // Auto-focus the title field when the view appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isTitleFocused = true
                }
            }
        }
    }
} 