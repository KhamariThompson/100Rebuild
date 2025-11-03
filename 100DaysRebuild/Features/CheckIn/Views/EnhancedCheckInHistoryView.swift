import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct EnhancedCheckInHistoryView: View {
    let challenge: Challenge
    @StateObject private var viewModel: EnhancedCheckInHistoryViewModel
    @State private var selectedDate: Date = Date()
    @State private var showingImagePicker = false
    @State private var showingDetailView = false
    @State private var selectedCheckIn: Models_CheckInRecord?
    
    init(challenge: Challenge) {
        self.challenge = challenge
        self._viewModel = StateObject(wrappedValue: EnhancedCheckInHistoryViewModel(challenge: challenge))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Calendar header
            HStack {
                Button(action: { viewModel.previousMonth() }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.theme.accent)
                }
                
                Spacer()
                
                Text(viewModel.currentMonthYear)
                    .font(.headline)
                    .foregroundColor(.theme.text)
                
                Spacer()
                
                Button(action: { viewModel.nextMonth() }) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.theme.accent)
                }
            }
            .padding()
            
            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                // Day headers
                ForEach(viewModel.dayHeaders, id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .foregroundColor(.theme.subtext)
                }
                
                // Calendar days
                ForEach(viewModel.daysInMonth, id: \.self) { date in
                    if let checkIn = viewModel.checkIns[date] {
                        EnhancedCalendarDayView(
                            date: date,
                            isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                            checkIn: checkIn
                        )
                        .onTapGesture {
                            selectedDate = date
                            selectedCheckIn = checkIn
                            showingDetailView = true
                        }
                    } else {
                        EnhancedCalendarDayView(
                            date: date,
                            isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                            checkIn: nil
                        )
                        .onTapGesture {
                            selectedDate = date
                            showingImagePicker = true
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color.theme.background)
        .sheet(isPresented: $showingImagePicker) {
            CheckInSheet(
                challengeId: challenge.id.uuidString,
                date: selectedDate,
                onDismiss: {
                    showingImagePicker = false
                    viewModel.loadCheckIns()
                }
            )
        }
        .sheet(isPresented: $showingDetailView) {
            if let checkIn = selectedCheckIn {
                CheckInBasicDetailView(checkIn: checkIn, challengeId: challenge.id.uuidString)
            }
        }
        .onAppear {
            viewModel.loadCheckIns()
        }
    }
}

// MARK: - View Model
@MainActor
class EnhancedCheckInHistoryViewModel: ObservableObject {
    @Published var checkIns: [Date: Models_CheckInRecord] = [:]
    @Published var currentMonth: Date = Date()
    private let challenge: Challenge

    init(challenge: Challenge) {
        self.challenge = challenge
    }
    
    var currentMonthYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonth)
    }
    
    var dayHeaders: [String] {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return (0...6).map { day in
            let date = Calendar.current.date(byAdding: .day, value: day, to: Calendar.current.date(from: DateComponents(year: 2024, month: 1, day: 1))!)!
            return formatter.string(from: date)
        }
    }
    
    var daysInMonth: [Date] {
        let calendar = Calendar.current
        let range = calendar.range(of: .day, in: .month, for: currentMonth)!
        let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth))!
        
        return range.map { day in
            calendar.date(byAdding: .day, value: day - 1, to: firstDay)!
        }
    }
    
    func previousMonth() {
        currentMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth)!
        loadCheckIns()
    }
    
    func nextMonth() {
        currentMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth)!
        loadCheckIns()
    }
    
    func loadCheckIns() {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        let db = Firestore.firestore()
        let checkInsRef = db
            .collection("users").document(userId)
            .collection("challenges").document(challenge.id.uuidString)
            .collection("checkIns")

        Task {
            do {
                let snapshot = try await checkInsRef.getDocuments()
                var newCheckIns: [Date: Models_CheckInRecord] = [:]

                for document in snapshot.documents {
                    let data = document.data()

                    // Get basic check-in data
                    guard let dayNumber = data["dayNumber"] as? Int else { continue }

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

                    let checkIn = Models_CheckInRecord(
                        id: document.documentID,
                        dayNumber: dayNumber,
                        date: date,
                        note: note,
                        quote: quote,
                        promptShown: promptShown,
                        photoURL: photoURL
                    )

                    newCheckIns[date] = checkIn
                }

                // Since we're @MainActor, this update happens on the main thread automatically
                self.checkIns = newCheckIns
            } catch {
                print("Error loading check-ins: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Calendar Day View
struct EnhancedCalendarDayView: View {
    let date: Date
    let isSelected: Bool
    let checkIn: Models_CheckInRecord?
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(checkIn != nil ? Color.theme.accent.opacity(0.1) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.theme.accent : Color.clear, lineWidth: 2)
                )
            
            VStack(spacing: 4) {
                // Day number
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.subheadline)
                    .foregroundColor(checkIn != nil ? .theme.text : .theme.subtext)
                
                // Visual indicators for content
                HStack(spacing: 4) {
                    // Photo indicator
                    if checkIn?.photoURL != nil {
                        Image(systemName: "photo.fill")
                            .font(AppTypography.caption2())
                            .foregroundColor(.theme.accent)
                    }
                    
                    // Journal indicator
                    if let note = checkIn?.note, !note.isEmpty {
                        Image(systemName: "text.book.closed")
                            .font(AppTypography.caption2())
                            .foregroundColor(.theme.accent)
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .aspectRatio(1, contentMode: .fill)
        .contentShape(Rectangle()) // Make entire cell tappable
        .opacity(isDateInCurrentMonth(date) ? 1.0 : 0.4) // Dim days not in current month
    }
    
    // Helper to check if date is in the current month
    private func isDateInCurrentMonth(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let currentMonth = calendar.component(.month, from: Date())
        return month == currentMonth
    }
}

// MARK: - Check In Sheet
struct CheckInSheet: View {
    let challengeId: String
    let date: Date
    let onDismiss: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var note: String = ""
    @State private var selectedImage: UIImage?
    @State private var isUploading = false
    @State private var errorMessage = ""
    @State private var showError = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Date header
                    Text(date, style: .date)
                        .font(.headline)
                        .foregroundColor(.theme.subtext)
                    
                    // Photo picker
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 200)
                            .cornerRadius(12)
                    } else {
                        Button(action: {
                            // Show image picker
                        }) {
                            VStack {
                                Image(systemName: "photo")
                                    .font(.largeTitle)
                                    .foregroundColor(.theme.accent)
                                Text("Add Photo")
                                    .font(.subheadline)
                                    .foregroundColor(.theme.accent)
                            }
                            .frame(height: 200)
                            .frame(maxWidth: .infinity)
                            .background(Color.theme.surface)
                            .cornerRadius(12)
                        }
                    }
                    
                    // Note field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Note")
                            .font(.headline)
                            .foregroundColor(.theme.text)
                        
                        TextEditor(text: $note)
                            .frame(minHeight: 150)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.theme.accent.opacity(0.3), lineWidth: 1)
                            )
                    }
                    
                    // Save button
                    Button(action: saveCheckIn) {
                        if isUploading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .padding(.horizontal, 16)
                        } else {
                            Text("Save Check-In")
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
                    .disabled(isUploading)
                }
                .padding()
            }
            .navigationTitle("New Check-In")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading: Button("Cancel") { dismiss() })
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func saveCheckIn() {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "Please sign in to save your check-in"
            showError = true
            return
        }
        
        isUploading = true
        
        // First upload image if selected
        if let image = selectedImage {
            // Upload image and get URL
            // Then save check-in with image URL
        } else {
            // Save check-in without image
            saveCheckInToFirestore(photoURL: nil)
        }
    }
    
    private func saveCheckInToFirestore(photoURL: URL?) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        let checkInRef = db
            .collection("users").document(userId)
            .collection("challenges").document(challengeId)
            .collection("checkIns").document("day\(Calendar.current.component(.day, from: date))")
        
        let checkInData: [String: Any] = [
            "date": date,
            "note": note,
            "photoURL": photoURL?.absoluteString as Any,
            "dayNumber": Calendar.current.component(.day, from: date)
        ]
        
        checkInRef.setData(checkInData) { error in
            isUploading = false
            
            if let error = error {
                errorMessage = error.localizedDescription
                showError = true
            } else {
                onDismiss()
                dismiss()
            }
        }
    }
}

// MARK: - Full Screen Image View
struct FullScreenImageView: View {
    let imageURL: URL
    let day: Int
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }
                    
                    Spacer()
                    
                    Text("Day \(day) Photo")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Share button
                    Button(action: {
                        // Add sharing functionality
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }
                }
                .padding()
                
                // Image with zoom/pan capabilities
                CachedAsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .scaleEffect(scale)
                            .offset(offset)
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        let delta = value / lastScale
                                        lastScale = value
                                        scale = min(max(scale * delta, 1), 4)
                                    }
                                    .onEnded { _ in
                                        lastScale = 1.0
                                        if scale < 1.1 {
                                            withAnimation {
                                                scale = 1.0
                                                offset = .zero
                                            }
                                        }
                                    }
                            )
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        if scale > 1 {
                                            offset = CGSize(
                                                width: lastOffset.width + value.translation.width,
                                                height: lastOffset.height + value.translation.height
                                            )
                                        }
                                    }
                                    .onEnded { _ in
                                        lastOffset = offset
                                        if scale < 1.1 {
                                            withAnimation {
                                                offset = .zero
                                            }
                                        }
                                    }
                            )
                            .onTapGesture(count: 2) {
                                withAnimation {
                                    if scale > 1 {
                                        scale = 1.0
                                        offset = .zero
                                        lastOffset = .zero
                                    } else {
                                        scale = 2.0
                                    }
                                }
                            }
                    case .failure:
                        VStack {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.largeTitle)
                                .foregroundColor(.white)
                            Text("Failed to load image")
                                .foregroundColor(.white)
                        }
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Footer with instructions
                Text("Pinch to zoom • Double-tap to reset")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.bottom)
            }
        }
    }
}

// MARK: - Preview removed to avoid sample data usage in production code 