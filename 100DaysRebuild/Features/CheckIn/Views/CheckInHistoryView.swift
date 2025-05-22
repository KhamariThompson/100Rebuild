import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth

struct CheckInHistoryView: View {
    let challenge: Challenge
    
    @State private var checkIns: [Views_CheckInRecord] = []
    @State private var isLoading = false
    @State private var selectedCheckIn: Views_CheckInRecord?
    @State private var showDetailView = false
    @State private var errorMessage = ""
    @State private var showError = false
    
    private let firestore = Firestore.firestore()
    
    var body: some View {
        ZStack {
            Color.theme.background
                .ignoresSafeArea()
            
            VStack {
                // Title
                Text(challenge.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.theme.text)
                    .padding(.top, AppSpacing.m)
                    .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Progress summary
                HStack(spacing: AppSpacing.m) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Days completed")
                            .font(.subheadline)
                            .foregroundColor(.theme.subtext)
                        
                        Text("\(challenge.daysCompleted)")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.theme.accent)
                    }
                    
                    Divider()
                        .frame(height: 40)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current streak")
                            .font(.subheadline)
                            .foregroundColor(.theme.subtext)
                        
                        Text("\(challenge.streakCount)")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.theme.accent)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                
                if isLoading {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.2)
                    Spacer()
                } else if checkIns.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 60))
                            .foregroundColor(.theme.subtext.opacity(0.5))
                        
                        Text("No check-ins yet")
                            .font(.headline)
                            .foregroundColor(.theme.text)
                        
                        Text("Complete your first day to see it here")
                            .font(.subheadline)
                            .foregroundColor(.theme.subtext)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    Spacer()
                } else {
                    // Check-ins list
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(checkIns) { checkIn in
                                CheckInHistoryCard(checkIn: checkIn)
                                    .onTapGesture {
                                        selectedCheckIn = checkIn
                                        showDetailView = true
                                    }
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .navigationTitle("Check-In History")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showDetailView) {
            if let checkIn = selectedCheckIn {
                CheckInDetailView(
                    checkIn: checkIn,
                    challengeId: challenge.id.uuidString
                )
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            loadCheckIns()
        }
    }
    
    private func loadCheckIns() {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "Please sign in to view your check-in history"
            showError = true
            return
        }
        
        isLoading = true
        
        let checkInsRef = firestore
            .collection("users").document(userId)
            .collection("challenges").document(challenge.id.uuidString)
            .collection("checkIns")
        
        checkInsRef
            .order(by: "dayNumber", descending: true)
            .getDocuments { snapshot, error in
                isLoading = false
                
                if let error = error {
                    errorMessage = "Failed to load check-ins: \(error.localizedDescription)"
                    showError = true
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    return
                }
                
                // Parse the check-in records
                self.checkIns = documents.compactMap { document -> Views_CheckInRecord? in
                    let data = document.data()
                    
                    // Get basic check-in data
                    guard let dayNumber = data["dayNumber"] as? Int else { return nil }
                    
                    // Get timestamp or create a fallback date
                    let date: Date
                    if let timestamp = data["date"] as? Timestamp {
                        date = timestamp.dateValue()
                    } else {
                        date = Date()
                    }
                    
                    // Get optional fields
                    let note = data["note"] as? String
                    let quoteId = data["quoteId"] as? String
                    let promptShown = data["promptShown"] as? String
                    let photoURLString = data["photoURL"] as? String
                    let photoURL = photoURLString != nil ? URL(string: photoURLString!) : nil
                    
                    // Find quote if we have a quoteId
                    let quote: Quote?
                    if let id = quoteId {
                        quote = Quote.all.first { $0.id == id } ?? Quote.samples.first
                    } else {
                        quote = nil
                    }
                    
                    return Views_CheckInRecord(
                        id: document.documentID,
                        dayNumber: dayNumber,
                        date: date,
                        note: note,
                        quote: quote,
                        promptShown: promptShown,
                        photoURL: photoURL
                    )
                }
            }
    }
}

struct CheckInHistoryCard: View {
    let checkIn: Views_CheckInRecord
    
    var body: some View {
        AppComponents.Card {
            VStack(alignment: .leading, spacing: AppSpacing.itemSpacing) {
                // Header with day number and date
                HStack {
                    Text("Day \(checkIn.dayNumber)")
                        .font(AppTypography.headline())
                        .foregroundColor(.theme.accent)
                    
                    Spacer()
                    
                    Text(checkIn.date, style: .date)
                        .font(AppTypography.subhead())
                        .foregroundColor(.theme.subtext)
                }
                
                // If there's a photo, show it
                if checkIn.photoURL != nil {
                    AsyncImage(url: checkIn.photoURL) { phase in
                        switch phase {
                        case .empty:
                            Rectangle()
                                .fill(Color.theme.surface)
                                .overlay(ProgressView())
                                .frame(height: 160)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(height: 160)
                                .clipped()
                        case .failure:
                            Rectangle()
                                .fill(Color.theme.surface)
                                .overlay(
                                    Image(systemName: "photo.fill")
                                        .foregroundColor(.theme.subtext.opacity(0.5))
                                )
                                .frame(height: 160)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .cornerRadius(AppSpacing.cardCornerRadius)
                }
                
                // If there's a note, show a preview
                if let note = checkIn.note, !note.isEmpty {
                    Text(note)
                        .font(AppTypography.subhead())
                        .foregroundColor(.theme.text)
                        .lineLimit(2)
                        .padding(.vertical, AppSpacing.xxs)
                }
                
                // Show the quote if available
                if let quote = checkIn.quote {
                    HStack {
                        Text("\"\(quote.text)\"")
                            .font(AppTypography.caption1())
                            .italic()
                            .foregroundColor(.theme.subtext)
                            .lineLimit(1)
                        Spacer()
                    }
                }
                
                // Footer with tap to view more indication
                HStack {
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(AppTypography.caption1())
                        .foregroundColor(.theme.subtext)
                }
            }
        }
    }
}

struct CheckInDetailView: View {
    let checkIn: Views_CheckInRecord
    let challengeId: String
    
    @Environment(\.dismiss) private var dismiss
    @State private var editedNote: String
    @State private var isEditing = false
    @State private var isSaving = false
    @State private var errorMessage = ""
    @State private var showError = false
    
    private let firestore = Firestore.firestore()
    
    init(checkIn: Views_CheckInRecord, challengeId: String) {
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
                errorMessage = "Failed to save note: \(error.localizedDescription)"
                showError = true
            } else {
                // Successfully saved
                isEditing = false
            }
        }
    }
}

// Model for a check-in record
struct Views_CheckInRecord: Identifiable {
    let id: String
    let dayNumber: Int
    let date: Date
    let note: String?
    let quote: Quote?
    let promptShown: String?
    let photoURL: URL?
}

// Preview removed to avoid sample data usage in production code 