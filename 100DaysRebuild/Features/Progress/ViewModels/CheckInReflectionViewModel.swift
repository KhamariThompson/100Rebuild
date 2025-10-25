import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

@MainActor
class CheckInReflectionViewModel: ObservableObject {
    @Published var checkInRecord: Models_CheckInRecord?
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""
    
    private let challengeId: String
    private let firestore = Firestore.firestore()
    
    init(challengeId: String) {
        self.challengeId = challengeId
    }
    
    func loadCheckInData(for date: Date) async {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "You must be signed in to view check-in data"
            showError = true
            return
        }
        
        isLoading = true
        showError = false
        errorMessage = ""
        checkInRecord = nil
        
        do {
            // Normalize the date to start of day
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: date)
            
            // Query for check-ins on the selected date
            let checkInsRef = firestore
                .collection("users")
                .document(userId)
                .collection("challenges")
                .document(challengeId)
                .collection("checkIns")
            
            // Query for check-ins on the specific date
            let snapshot = try await checkInsRef
                .whereField("date", isEqualTo: Timestamp(date: startOfDay))
                .getDocuments()
            
            if let document = snapshot.documents.first {
                let data = document.data()
                
                // Parse the check-in data
                let dayNumber = data["dayNumber"] as? Int ?? 0
                let note = data["note"] as? String
                let photoURLString = data["photoURL"] as? String
                let photoURL = photoURLString != nil ? URL(string: photoURLString!) : nil
                
                // Parse quote if available
                var quote: Quote?
                if let quoteData = data["quote"] as? [String: Any],
                   let text = quoteData["text"] as? String,
                   let author = quoteData["author"] as? String {
                    quote = Quote(text: text, author: author)
                }
                
                // Parse prompt if available
                let promptShown = data["promptShown"] as? String
                
                checkInRecord = Models_CheckInRecord(
                    id: document.documentID,
                    dayNumber: dayNumber,
                    date: startOfDay,
                    note: note,
                    quote: quote,
                    promptShown: promptShown,
                    photoURL: photoURL
                )
            }
            
            isLoading = false
            
        } catch {
            isLoading = false
            showError = true
            errorMessage = "Failed to load check-in data: \(error.localizedDescription)"
        }
    }
} 