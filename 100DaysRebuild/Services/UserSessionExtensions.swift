import Foundation
import FirebaseFirestore
import RevenueCat

// MARK: - User Session Extensions for Onboarding Funnel
//
// CHANGED: Extended UserSession with additional attributes for the onboarding funnel
// - Added onboardingCompletedAt timestamp
// - Added RevenueCat subscriber attribute syncing
// - Integration with CohortManager

extension UserSession {
    // MARK: - Additional Properties
    
    /// Storage keys for user state
    private enum StorageKeys {
        static let onboardingCompletedAt = "onboardingCompletedAt"
    }
    
    /// Get the onboarding completion date
    var onboardingCompletedAt: Date? {
        return UserDefaults.standard.object(forKey: StorageKeys.onboardingCompletedAt) as? Date
    }
    
    /// Check if user has completed onboarding
    var hasCompletedFunnel: Bool {
        return onboardingCompletedAt != nil
    }
    
    // MARK: - Funnel Completion Methods
    
    /// Complete the onboarding funnel and mark timestamp
    /// NOTE: This does NOT grant app access - user must subscribe first
    func completeFunnel() {
        let now = Date()

        // Store locally
        UserDefaults.standard.set(now, forKey: StorageKeys.onboardingCompletedAt)

        // Update Firestore if user is authenticated
        // IMPORTANT: We do NOT set hasCompletedOnboarding here
        // That only happens after successful subscription purchase
        if let userId = currentUser?.uid {
            Task {
                do {
                    try await Firestore.firestore().collection("users").document(userId).updateData([
                        "onboardingCompletedAt": now,
                        "funnelCompleted": true
                        // NOTE: hasCompletedOnboarding is NOT set here
                    ])

                    print("✅ UserSession: Funnel completion saved to Firestore (not granting app access)")
                } catch {
                    print("❌ UserSession: Failed to save funnel completion to Firestore - \(error.localizedDescription)")
                }
            }
        }

        // Sync with RevenueCat subscriber attributes
        syncFunnelAttributesToRevenueCat()

        // DO NOT call completeOnboarding() here - that only happens after Pro purchase
    }
    
    /// Reset funnel completion state (for testing)
    func resetFunnel() {
        UserDefaults.standard.removeObject(forKey: StorageKeys.onboardingCompletedAt)
    }
    
    // MARK: - RevenueCat Attribute Syncing
    
    /// Sync all funnel-related attributes to RevenueCat
    func syncFunnelAttributesToRevenueCat() {
        guard let userId = currentUser?.uid else { return }
        
        let cohortManager = CohortManager.shared
        let attributes: [String: String] = [
            "user_id": userId,
            "cohort": cohortManager.userCohort.rawValue,
            "onboarding_completed_at": onboardingCompletedAt?.ISO8601Format() ?? "",
            "first_paywall_at": cohortManager.firstPaywallAt?.ISO8601Format() ?? ""
        ]
        
        // Set RevenueCat attributes
        Task {
            for (key, value) in attributes {
                Purchases.shared.setAttributes([key: value])
                print("📊 RevenueCat: Set attribute \(key)=\(value)")
            }
        }
    }
    
    // MARK: - Cohort Management
    
    /// Determine and set the user's cohort if not already set
    func determineUserCohort() {
        let cohortManager = CohortManager.shared
        
        // Check if the user already has account creation date in Firestore
        if let userId = currentUser?.uid {
            Task {
                do {
                    let document = try await Firestore.firestore().collection("users").document(userId).getDocument()
                    
                    if let creationDate = document.data()?["createdAt"] as? Timestamp {
                        // If user was created before a certain date, they're legacy
                        let cutoverDate = Calendar.current.date(from: DateComponents(year: 2023, month: 12, day: 31)) ?? Date()
                        
                        if creationDate.dateValue() < cutoverDate {
                            cohortManager.setUserCohort(.legacyPreUpdate)
                        } else {
                            cohortManager.setUserCohort(.newAfterUpdate)
                        }
                    } else {
                        // No creation date found, default to new user
                        cohortManager.setUserCohort(.newAfterUpdate)
                    }
                    
                    // Sync cohort to RevenueCat
                    syncFunnelAttributesToRevenueCat()
                    
                } catch {
                    print("❌ UserSession: Failed to determine user cohort - \(error.localizedDescription)")
                    // Default to new user on error
                    cohortManager.setUserCohort(.newAfterUpdate)
                }
            }
        }
    }
    
    /// Determine user cohort after successful authentication
    func determineUserCohortAfterAuth() {
        // Determine user cohort after successful auth
        determineUserCohort()
    }
}
