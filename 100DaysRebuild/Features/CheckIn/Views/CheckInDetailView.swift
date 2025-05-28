import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct CheckInBasicDetailView: View {
    let checkIn: Models_CheckInRecord
    let challengeId: String
    
    @Environment(\.dismiss) private var dismiss
    @State private var editedNote: String
    @State private var isEditing = false
    @State private var isSaving = false
    @State private var errorMessage = ""
    @State private var showError = false
    
    private let firestore = Firestore.firestore()
    
    init(checkIn: Models_CheckInRecord, challengeId: String) {
        self.checkIn = checkIn
        self.challengeId = challengeId
        self._editedNote = State(initialValue: checkIn.note ?? "")
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Day \(checkIn.dayNumber)")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.theme.accent)
                        
                        Text(checkIn.date, style: .date)
                            .font(.headline)
                            .foregroundColor(.theme.subtext)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Photo if available
                    if let photoURL = checkIn.photoURL {
                        AsyncImage(url: photoURL) { phase in
                            switch phase {
                            case .empty:
                                Rectangle()
                                    .fill(Color.theme.surface)
                                    .overlay(ProgressView())
                                    .frame(height: 240)
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 240)
                                    .clipped()
                            case .failure:
                                Rectangle()
                                    .fill(Color.theme.surface)
                                    .overlay(
                                        Image(systemName: "photo.fill")
                                            .foregroundColor(.theme.subtext.opacity(0.5))
                                    )
                                    .frame(height: 240)
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .cornerRadius(16)
                    }
                    
                    // Prompt if available
                    if let prompt = checkIn.promptShown {
                        Text(prompt)
                            .font(.headline)
                            .foregroundColor(.theme.accent)
                            .padding(.top, 8)
                    }
                    
                    // Note
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Note")
                                .font(.headline)
                                .foregroundColor(.theme.text)
                            
                            Spacer()
                            
                            Button(action: {
                                isEditing.toggle()
                            }) {
                                Text(isEditing ? "Done" : "Edit")
                                    .font(.subheadline)
                                    .foregroundColor(.theme.accent)
                            }
                        }
                        
                        if isEditing {
                            TextEditor(text: $editedNote)
                                .frame(minHeight: 150)
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.theme.accent.opacity(0.3), lineWidth: 1)
                                )
                                .padding(.top, 4)
                            
                            Button(action: {
                                saveNote()
                            }) {
                                if isSaving {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .padding(.horizontal, 16)
                                } else {
                                    Text("Save Changes")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 16)
                                }
                            }
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.theme.accent)
                            )
                            .disabled(isSaving)
                            .padding(.top, 8)
                            
                        } else {
                            Text(checkIn.note ?? "No note for this day")
                                .foregroundColor(checkIn.note == nil ? .theme.subtext : .theme.text)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.theme.surface)
                                )
                        }
                    }
                    
                    // Quote
                    if let quote = checkIn.quote {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Daily Quote")
                                .font(.headline)
                                .foregroundColor(.theme.text)
                            
                            VStack(spacing: 8) {
                                Text(quote.text)
                                    .font(.body)
                                    .italic()
                                    .foregroundColor(.theme.text)
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                Text("— \(quote.author)")
                                    .font(.subheadline)
                                    .foregroundColor(.theme.subtext)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.theme.surface)
                            )
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Check-In Details")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading: Button("Close") { dismiss() })
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func saveNote() {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "Please sign in to update your note"
            showError = true
            return
        }
        
        isSaving = true
        
        let checkInRef = firestore
            .collection("users").document(userId)
            .collection("challenges").document(challengeId)
            .collection("checkIns").document("day\(checkIn.dayNumber)")
        
        checkInRef.updateData([
            "note": editedNote
        ]) { error in
            isSaving = false
            
            if let error = error {
                errorMessage = error.localizedDescription
                showError = true
            } else {
                isEditing = false
            }
        }
    }
} 