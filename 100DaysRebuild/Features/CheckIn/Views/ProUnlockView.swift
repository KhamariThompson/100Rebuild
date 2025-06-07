import SwiftUI
import FirebaseAuth
import RevenueCat

struct ProUnlockView: View {
    @EnvironmentObject var subscriptionService: SubscriptionService
    @State private var isLoading = false
    @State private var showingPaywall = false
    @State private var showDiagnosticsResults = false
    @State private var showRepairSuccessAlert = false
    @State private var showRepairFailureAlert = false
    
    var body: some View {
        // Completely hide this diagnostic view from users
        EmptyView()
    }
    
    private func debugSubscription() async {
        print("🔐 ProUnlockView: Running subscription diagnostics")
        
        // Check user identification
        if let currentUser = Auth.auth().currentUser {
            print("🔐 ProUnlockView: Current Firebase UID: \(currentUser.uid)")
            print("🔐 ProUnlockView: Current RevenueCat appUserID: \(Purchases.shared.appUserID)")
            
            if Purchases.shared.appUserID != currentUser.uid {
                print("🔐 ProUnlockView: User ID mismatch detected")
                await subscriptionService.identifyCurrentUser()
            }
        } else {
            print("🔐 ProUnlockView: No Firebase user signed in")
        }
        
        // Run receipt validation
        let receiptStatus = await subscriptionService.debugReceiptStatus()
        print("🔐 ProUnlockView: Receipt validation status: \(receiptStatus)")
        
        // Show alert with diagnostics results
        showDiagnosticsResults = true
    }
    
    private func repairSubscription() async {
        print("🔐 ProUnlockView: Attempting subscription repair")
        
        let success = await subscriptionService.attemptSubscriptionRepair()
        
        // Update the UI based on repair result
        if success {
            showRepairSuccessAlert = true
        } else {
            showRepairFailureAlert = true
        }
    }
} 