import SwiftUI

struct CreateGroupChallengeView: View {
    @Environment(\.presentationMode) private var presentationMode
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var isPublic: Bool = false
    @State private var maxParticipants: Int = 3
    @State private var isCreating: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Details")) {
                    TextField("Title", text: $title)
                    TextField("Description", text: $description)
                }

                Section(header: Text("Settings")) {
                    Toggle("Public Challenge", isOn: $isPublic)
                    Stepper(value: $maxParticipants, in: 2...50) {
                        Text("Max Participants: \(maxParticipants)")
                    }
                }

                Section {
                    Button(action: {
                        Task {
                            await createChallenge()
                        }
                    }) {
                        if isCreating {
                            ProgressView()
                        } else {
                            Text("Create Challenge")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
                }
            }
            .navigationTitle("New Group Challenge")
            .navigationBarItems(leading: Button("Cancel") { presentationMode.wrappedValue.dismiss() })
            .alert(
                "Error",
                isPresented: Binding<Bool>(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                ),
                actions: {
                    Button("OK") { errorMessage = nil }
                },
                message: {
                    Text(errorMessage ?? "An unknown error occurred")
                }
            )
        }
    }

    private func createChallenge() async {
        isCreating = true
        do {
            let challenge = try await GroupChallengeService.shared.createGroupChallenge(title: title, description: description, isPublic: isPublic, maxParticipants: maxParticipants)
            // Optionally navigate to the challenge detail or show success toast
            presentationMode.wrappedValue.dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isCreating = false
    }
}

struct CreateGroupChallengeView_Previews: PreviewProvider {
    static var previews: some View {
        CreateGroupChallengeView()
    }
}
