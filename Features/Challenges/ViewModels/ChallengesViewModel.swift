// MARK: - Check-In Logic
@MainActor
func checkIn(to challenge: Challenge, note: String = "") async {
    guard !isLoading, let userId = userSession.currentUser?.uid else { 
        print("DEBUG: CheckIn aborted - loading or no user")
        return 
    }
    
    isLoading = true
    print("DEBUG: Starting check-in for challenge \(challenge.id)")
    
    do {
        // Get a reference to the challenge document
        let challengeRef = firestore
            .collection("users").document(userId)
            .collection("challenges").document(challenge.id.uuidString)
        
        // Create check-in data
        let date = Date()
        let dayNumber = challenge.daysCompleted + 1
        
        print("DEBUG: Creating check-in with dayNumber: \(dayNumber)")
        
        // Add to check-ins subcollection
        let checkInRef = challengeRef.collection("checkIns").document()
        
        // Create check-in data
        var checkInData: [String: Any] = [
            "date": date,
            "dayNumber": dayNumber
        ]
        
        if !note.isEmpty {
            checkInData["note"] = note
        }
        
        // First attempt to write the check-in
        do {
            print("DEBUG: Writing check-in document")
            try await checkInRef.setData(checkInData)
            print("DEBUG: Check-in document written successfully")
        } catch {
            print("ERROR: Failed to write check-in: \(error.localizedDescription)")
            handleError(error)
            return
        }
        
        // After successful check-in write, update the challenge
        print("DEBUG: Updating challenge metadata")
        
        do {
            try await challengeRef.updateData([
                "daysCompleted": challenge.daysCompleted + 1,
                "streakCount": challenge.streakCount + 1,
                "lastCheckInDate": date,
                "lastModified": date,
                "isCompletedToday": true
            ])
            print("DEBUG: Challenge metadata updated successfully")
            
            // After confirmed Firestore write, update local state
            if let index = challenges.firstIndex(where: { $0.id == challenge.id }) {
                print("DEBUG: Updating local challenge data")
                challenges[index].daysCompleted += 1
                challenges[index].streakCount += 1
                challenges[index].lastCheckInDate = date
                challenges[index].lastModified = date
                challenges[index].isCompletedToday = true
                
                // Save to local cache
                saveChallengesLocally()
            }
            
            // Trigger haptic feedback for successful check-in
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            print("DEBUG: Check-in completed successfully")
        } catch {
            print("ERROR: Failed to update challenge after check-in: \(error.localizedDescription)")
            handleError(error)
            return
        }
    } catch {
        print("ERROR: Check-in overall failure: \(error.localizedDescription)")
        handleError(error)
    }
    
    isLoading = false
} 