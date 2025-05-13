import Foundation
import Firebase
import FirebaseFirestore
import FirebaseAuth  // Add Auth import
import FirebaseStorage  // Add Storage import

// Import the new model
import SwiftUI // Required to ensure access to UI components 

@MainActor
class CheckInHistoryViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var checkIns: [Models_CheckInRecord] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var showError = false
    @Published var hasMoreData = true
    @Published var selectedMonth: Date = Date()
    @Published var groupedCheckIns: [String: [Models_CheckInRecord]] = [:]
    @Published var calendarDates: [Date] = []
    @Published var checkInsByDate: [Date: Models_CheckInRecord] = [:]
    
    // MARK: - Private Properties
    
    private let firestore = Firestore.firestore()
    private var challenge: Challenge
    private var lastDocumentSnapshot: DocumentSnapshot?
    private let batchSize = 15
    private var isLoadingMore = false
    
    // MARK: - Initialization
    
    init(challenge: Challenge) {
        self.challenge = challenge
    }
    
    // MARK: - Public Methods
    
    /// Loads the initial batch of check-ins
    func loadInitialCheckIns() async {
        guard !isLoading else { return }
        
        isLoading = true
        checkIns = []
        lastDocumentSnapshot = nil
        hasMoreData = true
        groupedCheckIns = [:]
        
        do {
            do {
                try await loadCheckInBatch()
            } catch {
                throw error
            }
            organizeCheckInsIntoGroups()
            buildCalendarData()
        } catch {
            handleError(error)
        }
        
        isLoading = false
    }
    
    /// Loads more check-ins if available (for pagination)
    func loadMoreCheckInsIfNeeded() async {
        guard hasMoreData && !isLoading && !isLoadingMore else { return }
        
        isLoadingMore = true
        
        do {
            try await loadCheckInBatch()
            organizeCheckInsIntoGroups()
            buildCalendarData()
        } catch {
            handleError(error)
        }
        
        isLoadingMore = false
    }
    
    /// Updates a check-in's note
    func updateCheckInNote(for checkIn: Models_CheckInRecord, newNote: String) {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "Please sign in to update your note"
            showError = true
            return
        }
        
        // Update Firestore with new note
        let checkInRef = firestore
            .collection("users").document(userId)
            .collection("challenges").document(challenge.id.uuidString)
            .collection("checkIns").document("day\(checkIn.dayNumber)")
        
        // Create a task that can throw errors
        Task {
            do {
                // Create a Sendable dictionary for Firestore
                let updateData: [String: Any] = ["note": newNote]
                
                // Explicitly run as an async operation
                try await checkInRef.setData(updateData, merge: true)
                
                // Update local data
                if let index = checkIns.firstIndex(where: { $0.id == checkIn.id }) {
                    var updatedCheckIn = checkIn
                    updatedCheckIn.note = newNote
                    checkIns[index] = updatedCheckIn
                    
                    // Update grouped data
                    organizeCheckInsIntoGroups()
                    
                    // Update calendar data
                    if let date = Calendar.current.startOfDay(for: checkIn.date) as Date? {
                        checkInsByDate[date] = updatedCheckIn
                    }
                }
            } catch {
                handleError(error)
            }
        }
    }
    
    /// Updates a check-in's photo
    func updateCheckInPhoto(for checkIn: Models_CheckInRecord, newPhoto: UIImage) async {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "Please sign in to update your photo"
            showError = true
            return
        }
        
        do {
            // Upload photo to Firebase Storage
            let storage = Storage.storage()
            let storageRef = storage.reference()
            
            // Create a unique filename
            let fileName = "\(UUID().uuidString).jpg"
            let imageRef = storageRef.child("users/\(userId)/check-ins/\(fileName)")
            
            // Compress the image
            guard let imageData = newPhoto.jpegData(compressionQuality: 0.7) else {
                throw NSError(domain: "app", code: 0, userInfo: [NSLocalizedDescriptionKey: "Could not compress image"])
            }
            
            // Upload the image
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            
            let _ = try await imageRef.putDataAsync(imageData, metadata: metadata)
            let downloadURL = try await imageRef.downloadURL()
            
            // Update Firestore with new photo URL
            let checkInRef = firestore
                .collection("users").document(userId)
                .collection("challenges").document(challenge.id.uuidString)
                .collection("checkIns").document("day\(checkIn.dayNumber)")
            
            // Create a Sendable dictionary for Firestore
            let updateData: [String: Any] = ["photoURL": downloadURL.absoluteString]
            
            // Explicitly run on MainActor to handle the non-Sendable type safely
            await MainActor.run {
                checkInRef.updateData(updateData) { error in
                    if let error = error {
                        self.handleError(error)
                    }
                }
            }
            
            // Update local data
            if let index = checkIns.firstIndex(where: { $0.id == checkIn.id }) {
                var updatedCheckIn = checkIn
                updatedCheckIn.photoURL = downloadURL
                checkIns[index] = updatedCheckIn
                
                // Update grouped data
                organizeCheckInsIntoGroups()
                
                // Update calendar data
                if let date = Calendar.current.startOfDay(for: checkIn.date) as Date? {
                    checkInsByDate[date] = updatedCheckIn
                }
            }
        } catch {
            handleError(error)
        }
    }
    
    /// Sets the selected month for filtering
    func setSelectedMonth(_ date: Date) {
        selectedMonth = date
        buildCalendarData()
    }
    
    /// Builds calendar dates for the selected month
    func buildCalendarData() {
        let calendar = Calendar.current
        
        // Get start of the selected month
        guard let startDate = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth)),
              // Get the range of days in the month
              let range = calendar.range(of: .day, in: .month, for: startDate) else {
            return
        }
        
        // Generate array of dates for the month
        calendarDates = range.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: startDate)
        }
        
        // Populate checkInsByDate for faster lookup
        checkInsByDate = [:]
        for checkIn in checkIns {
            if let date = calendar.startOfDay(for: checkIn.date) as Date? {
                checkInsByDate[date] = checkIn
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Loads a batch of check-ins from Firestore
    private func loadCheckInBatch() async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "CheckInHistory", code: 1, userInfo: [NSLocalizedDescriptionKey: "Please sign in to view your check-in history"])
        }
        
        var query: Query = firestore
            .collection("users").document(userId)
            .collection("challenges").document(challenge.id.uuidString)
            .collection("checkIns")
            .order(by: "dayNumber", descending: true)
            .limit(to: batchSize)
        
        // If we have a last document, start after it for pagination
        if let lastDoc = lastDocumentSnapshot {
            query = query.start(afterDocument: lastDoc)
        }
        
        let snapshot = try await query.getDocuments()
        
        // Store the last document for pagination
        lastDocumentSnapshot = snapshot.documents.last
        
        // If we got fewer documents than requested, there's no more data
        if snapshot.documents.count < batchSize {
            hasMoreData = false
        }
        
        let newCheckIns = snapshot.documents.compactMap { document -> Models_CheckInRecord? in
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
            
            return Models_CheckInRecord(
                id: document.documentID,
                dayNumber: dayNumber,
                date: date,
                note: note,
                quote: quote,
                promptShown: promptShown,
                photoURL: photoURL
            )
        }
        
        // Append to existing check-ins
        self.checkIns.append(contentsOf: newCheckIns)
    }
    
    /// Organizes check-ins into groups by month/year
    private func organizeCheckInsIntoGroups() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        
        var newGroupedCheckIns: [String: [Models_CheckInRecord]] = [:]
        
        for checkIn in checkIns {
            let monthYearString = dateFormatter.string(from: checkIn.date)
            
            if newGroupedCheckIns[monthYearString] == nil {
                newGroupedCheckIns[monthYearString] = []
            }
            
            newGroupedCheckIns[monthYearString]?.append(checkIn)
        }
        
        // Sort each group by day number in descending order
        for (key, checkIns) in newGroupedCheckIns {
            newGroupedCheckIns[key] = checkIns.sorted { $0.dayNumber > $1.dayNumber }
        }
        
        self.groupedCheckIns = newGroupedCheckIns
    }
    
    /// Handles errors that may occur during operations
    private func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
    }
} 