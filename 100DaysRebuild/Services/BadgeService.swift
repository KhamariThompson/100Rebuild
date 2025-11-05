import Foundation
import FirebaseFirestore
import FirebaseAuth
import SwiftUI
import Combine

@MainActor
class BadgeService: ObservableObject {
    static let shared = BadgeService()
    
    // Published properties
    @Published private(set) var badges: [Badge] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?
    @Published private(set) var lastRefreshTime: Date? = nil
    @Published private(set) var showcasedBadges: [Badge] = []
    
    // Notification for badge updates
    static let badgesDidUpdateNotification = Notification.Name("badgesDidUpdate")
    static let badgeUnlockedNotification = Notification.Name("badgeUnlocked")

    // Dependencies
    private lazy var firestore = Firestore.firestore()
    private let challengeStore = ChallengeStore.shared
    private var cancellables = Set<AnyCancellable>()
    private var loadTask: Task<Void, Never>? = nil
    
    private init() {
        // Observe challenge updates to check for new badges
        NotificationCenter.default
            .publisher(for: ChallengeStore.challengesDidUpdateNotification)
            .sink { [weak self] _ in
                Task {
                    await self?.checkForNewBadges()
                }
            }
            .store(in: &cancellables)
        
        // Add observer for auth state changes to reload badges on login
        NotificationCenter.default
            .publisher(for: NSNotification.Name("AuthStateChanged"))
            .sink { [weak self] _ in
                Task { @MainActor in
                    if Auth.auth().currentUser != nil {
                        // User is logged in, reload badges
                        print("BadgeService - Auth state changed, reloading badges")
                        await self?.loadBadges()
                    }
                }
            }
            .store(in: &cancellables)
        
        // Load badges when app starts
        Task {
            await loadBadges()
        }
    }
    
    /// Load badges from Firestore
    func loadBadges() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isLoading = true
        error = nil
        
        do {
            // Get all possible badges with their status
            let userBadgesRef = firestore
                .collection("users")
                .document(userId)
                .collection("badges")
            
            let snapshot = try await userBadgesRef.getDocuments()
            
            var loadedBadges: [Badge] = []
            
            // First, create all possible badges with default values
            var allBadges = BadgeConfig.allBadges
            
            // Update with stored values from Firestore if they exist
            for document in snapshot.documents {
                let data = document.data()
                
                if let badgeId = data["id"] as? String,
                   let index = allBadges.firstIndex(where: { $0.id == badgeId }) {
                    var badge = allBadges[index]
                    
                    // Update with stored values
                    badge.unlockedAt = data["unlockedAt"] as? Timestamp
                    badge.currentProgress = data["currentProgress"] as? Int ?? 0
                    badge.isShowcased = data["isShowcased"] as? Bool ?? false
                    
                    loadedBadges.append(badge)
                    allBadges.remove(at: index)
                }
            }
            
            // Add remaining badges that are not yet in Firestore
            loadedBadges.append(contentsOf: allBadges)
            
            // Sort badges by category and locked/unlocked status
            loadedBadges.sort { (a, b) -> Bool in
                if a.category != b.category {
                    return a.category.rawValue < b.category.rawValue
                }
                if a.isUnlocked != b.isUnlocked {
                    return a.isUnlocked && !b.isUnlocked
                }
                return a.name < b.name
            }
            
            await MainActor.run {
                self.badges = loadedBadges
                self.showcasedBadges = loadedBadges.filter { $0.isShowcased }
                self.lastRefreshTime = Date()
                self.isLoading = false
                
                // Notify observers that badges have been updated
                NotificationCenter.default.post(name: Self.badgesDidUpdateNotification, object: nil)
            }
        } catch {
            await MainActor.run {
                self.error = error
                self.isLoading = false
                print("Error loading badges: \(error.localizedDescription)")
            }
        }
    }
    
    /// Check for and award new badges based on current app state
    func checkForNewBadges() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        // Don't check too frequently
        if let lastRefresh = lastRefreshTime, Date().timeIntervalSince(lastRefresh) < 60 {
            return
        }
        
        // Get required data
        let userStats = UserStatsService.shared.userStats
        let challenges = challengeStore.challenges
        
        // Get check-in records (you'd need to implement this)
        let checkInRecords = await getCheckInRecords(userId: userId)
        
        // Check each badge's criteria
        for (index, badge) in badges.enumerated() {
            // Skip already unlocked badges
            if badge.isUnlocked { continue }
            
            // Check if badge should be unlocked
            let shouldUnlock = BadgeConfig.shouldUnlockBadge(
                badge: badge,
                userStats: userStats,
                challenges: challenges,
                checkInRecords: checkInRecords
            )
            
            if shouldUnlock {
                await unlockBadge(badgeId: badge.id)
                
                // Notify about badge unlock
                NotificationCenter.default.post(
                    name: Self.badgeUnlockedNotification,
                    object: badge
                )
            }
        }
    }
    
    /// Unlock a badge
    func unlockBadge(badgeId: String) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            // Find the badge to get its required value
            guard let badge = badges.first(where: { $0.id == badgeId }) else {
                print("Error: Badge with ID \(badgeId) not found")
                return
            }
            
            let badgeRef = firestore
                .collection("users")
                .document(userId)
                .collection("badges")
                .document(badgeId)
            
            // Update Firestore with correct progress value (not a timestamp)
            try await badgeRef.setData([
                "id": badgeId,
                "unlockedAt": FieldValue.serverTimestamp(),
                "currentProgress": badge.requiredValue // Use the actual required value, not a timestamp
            ], merge: true)
            
            // Update local data
            await MainActor.run {
                if let index = self.badges.firstIndex(where: { $0.id == badgeId }) {
                    var updatedBadge = self.badges[index]
                    updatedBadge.unlockedAt = Timestamp(date: Date())
                    updatedBadge.currentProgress = updatedBadge.requiredValue
                    self.badges[index] = updatedBadge
                    
                    print("Badge unlocked: \(updatedBadge.name) with progress \(updatedBadge.currentProgress)/\(updatedBadge.requiredValue)")
                    
                    // Notify about update
                    NotificationCenter.default.post(name: Self.badgesDidUpdateNotification, object: nil)
                    // Also notify about the specific badge being unlocked
                    NotificationCenter.default.post(name: Self.badgeUnlockedNotification, object: updatedBadge)
                }
            }
        } catch {
            print("Error unlocking badge: \(error.localizedDescription)")
        }
    }
    
    /// Update a badge's progress
    func updateBadgeProgress(badgeId: String, progress: Int) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            let badgeRef = firestore
                .collection("users")
                .document(userId)
                .collection("badges")
                .document(badgeId)
            
            // Update Firestore
            try await badgeRef.setData([
                "id": badgeId,
                "currentProgress": progress
            ], merge: true)
            
            // Update local data
            await MainActor.run {
                if let index = self.badges.firstIndex(where: { $0.id == badgeId }) {
                    var updatedBadge = self.badges[index]
                    updatedBadge.currentProgress = progress
                    self.badges[index] = updatedBadge
                    
                    // Notify about update
                    NotificationCenter.default.post(name: Self.badgesDidUpdateNotification, object: nil)
                }
            }
        } catch {
            print("Error updating badge progress: \(error.localizedDescription)")
        }
    }
    
    /// Set a badge as showcased
    func setShowcasedBadge(badgeId: String, isShowcased: Bool) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        // Check if there are already 3 showcased badges and trying to add another
        if isShowcased {
            let currentShowcasedCount = showcasedBadges.count
            if currentShowcasedCount >= 3 {
                // Remove the oldest showcased badge
                if let oldestShowcased = showcasedBadges.first {
                    await setShowcasedBadge(badgeId: oldestShowcased.id, isShowcased: false)
                }
            }
        }
        
        do {
            let badgeRef = firestore
                .collection("users")
                .document(userId)
                .collection("badges")
                .document(badgeId)
            
            // Update Firestore
            try await badgeRef.setData([
                "id": badgeId,
                "isShowcased": isShowcased
            ], merge: true)
            
            // Update local data
            await MainActor.run {
                if let index = self.badges.firstIndex(where: { $0.id == badgeId }) {
                    var updatedBadge = self.badges[index]
                    updatedBadge.isShowcased = isShowcased
                    self.badges[index] = updatedBadge
                    
                    // Update showcased badges
                    self.showcasedBadges = self.badges.filter { $0.isShowcased }
                    
                    // Notify about update
                    NotificationCenter.default.post(name: Self.badgesDidUpdateNotification, object: nil)
                }
            }
        } catch {
            print("Error updating showcased status: \(error.localizedDescription)")
        }
    }
    
    /// Get all check-in records for a user
    private func getCheckInRecords(userId: String) async -> [Models_CheckInRecord] {
        var records: [Models_CheckInRecord] = []
        
        do {
            // Get check-in records for all challenges
            let challenges = challengeStore.challenges
            
            for challenge in challenges {
                let recordsRef = firestore
                    .collection("users")
                    .document(userId)
                    .collection("challenges")
                    .document(challenge.id.uuidString)
                    .collection("checkIns")
                
                let snapshot = try await recordsRef.getDocuments()
                
                for document in snapshot.documents {
                    let data = document.data()
                    
                    let id = document.documentID
                    let dayNumber = data["dayNumber"] as? Int ?? 0
                    let date = (data["date"] as? Timestamp)?.dateValue() ?? Date()
                    let note = data["note"] as? String
                    let photoURLString = data["photoURL"] as? String
                    let photoURL: URL?
                    if let urlString = photoURLString, !urlString.isEmpty {
                        photoURL = URL(string: urlString)
                    } else {
                        photoURL = nil
                    }
                    
                    let record = Models_CheckInRecord(
                        id: id,
                        dayNumber: dayNumber,
                        date: date,
                        note: note,
                        quote: nil,
                        promptShown: nil,
                        photoURL: photoURL
                    )
                    
                    records.append(record)
                }
            }
        } catch {
            print("Error fetching check-in records: \(error.localizedDescription)")
        }
        
        return records
    }
    
    /// Get badges by category
    func getBadgesByCategory(category: BadgeCategory) -> [Badge] {
        return badges.filter { $0.category == category }
    }
    
    /// Get unlocked badges
    func getUnlockedBadges() -> [Badge] {
        return badges.filter { $0.isUnlocked }
    }
    
    /// Get next badge to unlock
    func getNextBadgeToUnlock() -> Badge? {
        return badges
            .filter { !$0.isUnlocked }
            .sorted { $0.requiredValue < $1.requiredValue }
            .first
    }
    
    /// Reset all state to initial values
    @MainActor
    func reset() {
        // Reset all published properties
        badges = []
        isLoading = false
        error = nil
        lastRefreshTime = nil
        showcasedBadges = []
        
        // Cancel any pending tasks
        loadTask?.cancel()
        loadTask = nil
        
        // Cancel any subscriptions
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
        
        print("BadgeService - Reset complete")
    }
    
    // MARK: - Badge Evaluation Methods
    
    /// Evaluate badges after a check-in
    func evaluateBadgesAfterCheckIn(challengeId: String) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            // Get user stats for badge evaluations
            let userStats = await UserStatsService.shared.userStats
            
            // Get all challenge data for the user
            let challenges = await ChallengeStore.shared.challenges
            
            // Get check-in records
            let checkInRecords = await getCheckInRecords(userId: userId)
            
            // Evaluate each badge to see if conditions are met
            for badge in BadgeConfig.allBadges {
                // Skip badges that are already unlocked
                if await isUnlocked(badgeId: badge.id) {
                    continue
                }
                
                // Calculate current progress based on badge type
                var currentProgress = 0
                var shouldUnlock = false
                
                switch badge.id {
                case "day_one_warrior", "five_day_spark", "firestarter", "momentum_machine", "unstoppable", "hundred_club":
                    // Streak and consistency badges - progress is current streak
                    currentProgress = userStats.currentStreak
                    shouldUnlock = currentProgress >= badge.requiredValue
                    
                case "try_again_champ", "comeback_kid", "no_excuses":
                    // These need custom logic specific to each badge
                    continue
                    
                case "silent_streaker":
                    // Check if user has been consistent without posting
                    currentProgress = userStats.currentStreak
                    shouldUnlock = currentProgress >= badge.requiredValue
                    
                case "snap_savant":
                    // Count check-ins with photos
                    currentProgress = checkInRecords.filter { $0.photoURL != nil }.count
                    shouldUnlock = currentProgress >= badge.requiredValue
                    
                case "reflection_master":
                    // Count check-ins with notes
                    currentProgress = checkInRecords.filter { $0.note != nil && !($0.note?.isEmpty ?? true) }.count
                    shouldUnlock = currentProgress >= badge.requiredValue
                    
                case "share_the_win":
                    // This would need specific tracking of shares
                    continue
                    
                case "ten_days_strong", "twenty_five_percent", "halfway_hero", "final_stretch", "completionist":
                    // Milestone badges - progress is total days completed across all challenges
                    let totalDaysCompleted = challenges.reduce(0) { $0 + $1.daysCompleted }
                    currentProgress = totalDaysCompleted
                    shouldUnlock = currentProgress >= badge.requiredValue
                    
                default:
                    // Calculate days completed in last 30 days
                    let calendar = Calendar.current
                    let today = Date()
                    currentProgress = 0
                    
                    for i in 0..<30 {
                        guard let date = calendar.date(byAdding: .day, value: -i, to: today) else {
                            continue
                        }
                        
                        // Check if any challenge was completed on this date
                        var wasCompletedOnDate = false
                        for challenge in challenges {
                            if let lastCheckIn = challenge.lastCheckInDate {
                                if calendar.isDate(lastCheckIn, inSameDayAs: date) {
                                    wasCompletedOnDate = true
                                    break
                                }
                            }
                            if wasCompletedOnDate {
                                break
                            }
                        }
                        
                        // Also check the check-in records directly
                        if !wasCompletedOnDate {
                            wasCompletedOnDate = checkInRecords.contains { record in
                                calendar.isDate(record.date, inSameDayAs: date)
                            }
                        }
                        
                        if wasCompletedOnDate {
                            currentProgress += 1
                        }
                    }
                    
                    shouldUnlock = currentProgress >= badge.requiredValue
                }
                
                // Always update progress even if not unlocking
                await updateBadgeProgress(badgeId: badge.id, progress: currentProgress)
                
                // If badge should be unlocked, unlock it
                if shouldUnlock {
                    await unlockBadge(badgeId: badge.id)
                }
            }
            
            // Force a refresh of badges to update the UI
            await loadBadges()
            
        } catch {
            print("Error evaluating badges: \(error.localizedDescription)")
        }
    }
    
    /// Check if a badge is unlocked
    private func isUnlocked(badgeId: String) async -> Bool {
        // Get from local cache first
        if let unlockedBadge = badges.first(where: { $0.id == badgeId && $0.isUnlocked }) {
            return true
        }
        
        // Otherwise check Firestore
        guard let userId = Auth.auth().currentUser?.uid else { return false }
        
        do {
            let badgeDoc = try await firestore.collection("users").document(userId)
                .collection("badges").document(badgeId).getDocument()
            
            return badgeDoc.exists
        } catch {
            print("Error checking badge unlock status: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Unlock a badge and save to Firestore
    private func unlockBadge(badge: Badge, userId: String) async {
        do {
            // Create badge document in Firestore
            try await firestore.collection("users").document(userId)
                .collection("badges").document(badge.id).setData([
                    "id": badge.id,
                    "name": badge.name,
                    "category": badge.category.rawValue,
                    "unlockedAt": Timestamp(date: Date()),
                    "iconName": badge.iconName
                ])
            
            // Update local badge cache
            await updateBadge(badge: badge, isUnlocked: true)
            
            // Post notification for badge unlock
            NotificationCenter.default.post(
                name: BadgeService.badgeUnlockedNotification,
                object: badge
            )
            
            print("Badge unlocked: \(badge.name)")
        } catch {
            print("Error unlocking badge: \(error.localizedDescription)")
        }
    }
    
    /// Update a badge in the local cache
    private func updateBadge(badge: Badge, isUnlocked: Bool = false) async {
        await MainActor.run {
            if let index = self.badges.firstIndex(where: { $0.id == badge.id }) {
                var updatedBadge = self.badges[index]
                
                if isUnlocked && !updatedBadge.isUnlocked {
                    updatedBadge.unlockedAt = Timestamp(date: Date())
                    updatedBadge.currentProgress = updatedBadge.requiredValue
                }
                
                self.badges[index] = updatedBadge
                
                // Update showcased badges if needed
                if updatedBadge.isShowcased {
                    self.showcasedBadges = self.badges.filter { $0.isShowcased }
                }
                
                // Notify about update
                NotificationCenter.default.post(name: Self.badgesDidUpdateNotification, object: nil)
            }
        }
    }
} 