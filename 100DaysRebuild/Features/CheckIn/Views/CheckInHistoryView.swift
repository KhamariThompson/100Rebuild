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
    @State private var loadTask: Task<Void, Never>?

    private let firestore = Firestore.firestore()

    var body: some View {
        ZStack {
            Color.theme.background
                .ignoresSafeArea()

            VStack {
                // Title
                Text(challenge.title)
                    .font(AppTypography.title2())
                    .fontWeight(.bold)
                    .foregroundColor(.theme.text)
                    .padding(.top, AppSpacing.m)
                    .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Progress summary
                HStack(spacing: AppSpacing.m) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Days completed")
                            .font(AppTypography.subhead())
                            .foregroundColor(.theme.subtext)
                        
                        Text("\(challenge.daysCompleted)")
                            .font(AppTypography.title1())
                            .fontWeight(.bold)
                            .foregroundColor(.theme.accent)
                    }
                    
                    Divider()
                        .frame(height: 40)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current streak")
                            .font(AppTypography.subhead())
                            .foregroundColor(.theme.subtext)
                        
                        Text("\(challenge.streakCount)")
                            .font(AppTypography.title1())
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
                            .font(AppTypography.display())
                            .foregroundColor(.theme.subtext.opacity(0.5))
                        
                        Text("No check-ins yet")
                            .font(AppTypography.headline())
                            .foregroundColor(.theme.text)
                        
                        Text("Complete your first day to see it here")
                            .font(AppTypography.subhead())
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
        .id(challenge.id) // Enforce unique identity per challenge
        .sheet(isPresented: $showDetailView) {
            if let checkIn = selectedCheckIn {
                CheckInBasicDetailView(
                    checkIn: Models_CheckInRecord(
                        id: checkIn.id,
                        dayNumber: checkIn.dayNumber,
                        date: checkIn.date,
                        note: checkIn.note,
                        quote: checkIn.quote,
                        promptShown: checkIn.promptShown,
                        photoURL: checkIn.photoURL
                    ),
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
        .onDisappear {
            loadTask?.cancel()
        }
    }
    
    private func loadCheckIns() {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "Please sign in to view your check-in history"
            showError = true
            return
        }

        // Cancel previous load
        loadTask?.cancel()

        // Clear stale data immediately
        checkIns = []
        isLoading = true

        let challengeId = challenge.id.uuidString

        loadTask = Task {
            let checkInsRef = firestore
                .collection("users").document(userId)
                .collection("challenges").document(challengeId)
                .collection("checkIns")

            do {
                let snapshot = try await checkInsRef
                    .order(by: "dayNumber", descending: true)
                    .getDocuments()

                guard !Task.isCancelled else { return }

                let documents = snapshot.documents

                // Parse the check-in records
                let parsedCheckIns = documents.compactMap { document -> Views_CheckInRecord? in
                    let data = document.data()
                    
                    // Get basic check-in data
                    guard let dayNumber = data["dayNumber"] as? Int else { return nil }
                    
                    // Get timestamp or create a fallback date
                    let date = (data["date"] as? Timestamp)?.dateValue() ?? Date()
                    
                    // Get optional fields
                    let note = data["note"] as? String
                    let quoteId = data["quoteId"] as? String
                    let promptShown = data["promptShown"] as? String
                    let photoURLString = data["photoURL"] as? String
                    let photoURL: URL?
                    if let urlString = photoURLString, !urlString.isEmpty {
                        photoURL = URL(string: urlString)
                    } else {
                        photoURL = nil
                    }
                    
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

                guard !Task.isCancelled else { return }

                await MainActor.run {
                    self.checkIns = parsedCheckIns
                    self.isLoading = false
                }

            } catch {
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    self.errorMessage = "Failed to load check-ins: \(error.localizedDescription)"
                    self.showError = true
                    self.isLoading = false
                }
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