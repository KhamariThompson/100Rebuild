import SwiftUI
import UserNotifications
import Foundation
import FirebaseFirestore

// MARK: - Updated Onboarding View with Auth → Funnel → Paywall Flow
//
// CHANGED: Enhanced to enforce auth before funnel and handle different user states
// - Requires authentication before showing funnel
// - Checks for completed onboarding to skip directly to paywall if needed
// - Syncs user cohort and attributes with RevenueCat
// - Respects business rules for hard paywall

struct OnboardingView: View {
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var entitlementsAdapter: EntitlementsAdapter
    @EnvironmentObject var router: NavigationRouter
    @StateObject private var entitlements = Entitlements.shared
    @StateObject private var cohortManager = CohortManager.shared
    @StateObject private var analyticsService = AnalyticsService.shared
    
    var body: some View {
        Group {
            // Step 1: Verify user is authenticated (defensive check)
            if !userSession.isAuthenticated {
                // Redirect to auth if somehow we got here without authentication
                AuthView()
                    .transition(.opacity)
            }
            // Step 2: Check if user is already pro (for restoration cases)
            else if entitlements.effectiveIsProUser {
                // Skip funnel, go directly to main app
                MainAppView()
                    .onAppear {
                        Task {
                            await userSession.completeOnboarding()
                        }
                    }
            }
            // Step 3: Check if user already completed funnel but isn't pro
            else if userSession.hasCompletedFunnel {
                // Skip directly to paywall
                PaywallView()
                    .onDisappear {
                        Task {
                            await userSession.completeOnboarding()
                        }
                    }
                .environmentObject(analyticsService)
                .onAppear {
                    // Start paywall timer if needed
                    cohortManager.startPaywallTimer()
                    analyticsService.trackEvent("paywall_shown", properties: [
                        "source": "direct_from_onboarding",
                        "user_cohort": cohortManager.userCohort.rawValue,
                        "completed_funnel": "true"
                    ])
                }
            }
            // Step 4: Show funnel for users who haven't completed it
            else {
                // Show funnel that leads to hard paywall
                OnboardingFlowView()
                    .environmentObject(analyticsService)
                    .onAppear {
                        // Determine user cohort if not already set
                        userSession.determineUserCohort()
                    }
            }
        }
        .onAppear {
            // Refresh entitlements to check current status
            Task {
                await entitlements.refreshEntitlements()

                // Set RevenueCat attributes for cohort tracking
                if let userId = userSession.currentUser?.uid {
                    let cohortValue = cohortManager.userCohort.rawValue
                    entitlements.setUserAttributes(
                        userId: userId,
                        cohort: cohortValue,
                        funnelCompletedAt: userSession.onboardingCompletedAt,
                        firstPaywallAt: cohortManager.firstPaywallAt
                    )
                }
            }
        }
    }
}

// MARK: - Legacy Onboarding View (kept for reference but unused)

struct LegacyOnboardingView: View {
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var entitlementsAdapter: EntitlementsAdapter
    @EnvironmentObject var router: NavigationRouter
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var currentStep = 0
    @State private var userName = ""
    @State private var selectedCategory = "Fitness"
    @State private var notificationsEnabled = true
    @State private var selectedTime = Date()
    @State private var isLoading = false
    @State private var animateContent = false
    
    private let totalSteps = 4
    private let categories = ["Fitness", "Learning", "Creativity", "Mindfulness", "Career", "Health"]
    
    private let onboardingGradient = LinearGradient(
        colors: [Color.theme.accent, Color.theme.accent.opacity(0.7)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    var body: some View {
        ZStack {
            // Background
            Color.theme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with logo and progress
                headerView
                
                // Main content container
                ScrollView {
                    VStack(spacing: 0) {
                        // Current step content
                        Group {
                            switch currentStep {
                            case 0:
                                welcomeView
                            case 1:
                                nameView
                            case 2:
                                categoryView
                            case 3:
                                notificationView
                            default:
                                EmptyView()
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : 20)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 100) // Add space for buttons
                }
                
                // Action buttons
                bottomButtonsView
            }
            
            // Loading overlay
            if isLoading {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .overlay(
                        VStack(spacing: 20) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)
                            
                            Text("Setting up your account...")
                                .font(AppTypography.body())
                                .foregroundColor(.white)
                        }
                        .padding(30)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.black.opacity(0.7))
                        )
                    )
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                animateContent = true
            }
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        VStack(spacing: 16) {
            HStack {
                // Logo
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.theme.accent)
                
                Text("100Days")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.theme.text)
                
                Spacer()
                
                // Skip button (only for first steps)
                if currentStep < totalSteps - 1 {
                    Button("Skip") {
                        completeOnboarding()
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.theme.subtext)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.theme.surface)
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            // Progress steps
            HStack(spacing: 8) {
                ForEach(0..<totalSteps, id: \.self) { step in
                    Capsule()
                        .fill(currentStep >= step ? Color.theme.accent : Color.theme.border)
                        .frame(height: 4)
                        .frame(width: UIScreen.main.bounds.width / CGFloat(totalSteps) - 20)
                }
            }
            .padding(.top, 8)
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Content Views
    
    private var welcomeView: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Hero image
            ZStack {
                Circle()
                    .fill(Color.theme.accent.opacity(0.1))
                    .frame(width: 220, height: 220)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 100, weight: .regular))
                    .foregroundColor(.theme.accent)
            }
            .padding(.bottom, 40)
            
            // Welcome text
            VStack(spacing: 16) {
                Text("Welcome to 100Days")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.theme.text)
                    .multilineTextAlignment(.center)
                
                Text("Build daily habits and achieve your goals with the 100 day challenge method")
                    .font(.system(size: 18))
                    .foregroundColor(.theme.subtext)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 20)
            }
            
            Spacer()
            
            // Key features
            VStack(spacing: 24) {
                OnboardingFeatureRow(icon: "calendar.badge.clock", title: "Track Daily Progress", description: "Build consistency with daily check-ins")
                
                OnboardingFeatureRow(icon: "chart.bar.fill", title: "Visualize Growth", description: "See your progress with beautiful analytics")
                
                OnboardingFeatureRow(icon: "bell.fill", title: "Smart Reminders", description: "Never miss a day with timely notifications")
            }
            .padding(.bottom, 40)
            
            Spacer()
        }
    }
    
    private var nameView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Title
            Text("What should we call you?")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.theme.text)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            // Name field
            VStack(alignment: .leading, spacing: 12) {
                Text("Your Name")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.theme.text)
                
                TextField("Enter your name", text: $userName)
                    .font(.system(size: 18))
                    .padding()
                    .frame(height: 56)
                    .background(Color.theme.surface)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.theme.border, lineWidth: 1)
                    )
                    .textContentType(.name)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 20)
            
            Text("This helps personalize your experience")
                .font(.system(size: 14))
                .foregroundColor(.theme.subtext)
                .multilineTextAlignment(.center)
            
            Spacer()
            Spacer()
        }
    }
    
    private var categoryView: some View {
        VStack(spacing: 32) {
            // Title
            Text("What are you focusing on?")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.theme.text)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            Text("This will help us suggest challenges for you")
                .font(.system(size: 16))
                .foregroundColor(.theme.subtext)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            // Categories grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(categories, id: \.self) { category in
                    CategoryCard(
                        category: category,
                        isSelected: category == selectedCategory,
                        onTap: { selectedCategory = category }
                    )
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 20)
            
            Spacer()
        }
    }
    
    private var notificationView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Hero image
            ZStack {
                Circle()
                    .fill(Color.theme.accent.opacity(0.1))
                    .frame(width: 180, height: 180)
                
                Image(systemName: "bell.fill")
                    .font(.system(size: 70, weight: .regular))
                    .foregroundColor(.theme.accent)
            }
            .padding(.bottom, 20)
            
            // Title
            Text("Stay Consistent with Reminders")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.theme.text)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            Text("Daily reminders help you maintain your streak and build lasting habits")
                .font(.system(size: 16))
                .foregroundColor(.theme.subtext)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            // Toggle for notifications
            Toggle(isOn: $notificationsEnabled) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Enable Daily Reminders")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.theme.text)
                    
                    Text("We'll remind you to check in daily")
                        .font(.system(size: 14))
                        .foregroundColor(.theme.subtext)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: .theme.accent))
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.theme.surface)
            .cornerRadius(12)
            .padding(.horizontal, 20)
            
            // Time picker (only show if notifications enabled)
            if notificationsEnabled {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Reminder Time")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.theme.text)
                    
                    DatePicker("", selection: $selectedTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(WheelDatePickerStyle())
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                        .clipped()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.theme.surface)
                .cornerRadius(12)
                .padding(.horizontal, 20)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Bottom Buttons
    
    private var bottomButtonsView: some View {
        VStack(spacing: 16) {
            // Primary button
            Button(action: {
                if currentStep == totalSteps - 1 {
                    completeOnboarding()
                } else {
                    withAnimation {
                        animateContent = false
                        
                        // If on name step, save the name to userSession
                        if currentStep == 1 && !userName.isEmpty {
                            Task {
                                // Set as display name, not username
                                try? await userSession.updateDisplayName(userName)
                            }
                        }
                        
                        // Delay the next step appearance for smoother transition
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            currentStep += 1
                            
                            withAnimation(.easeOut(duration: 0.6)) {
                                animateContent = true
                            }
                        }
                    }
                }
            }) {
                Text(currentStep == totalSteps - 1 ? "Get Started" : "Continue")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? .black : .white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.theme.accent)
                    )
            }
            .disabled(currentStep == 1 && userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(currentStep == 1 && userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1.0)
            
            // Back button (only show if not on first step)
            if currentStep > 0 {
                Button(action: {
                    withAnimation {
                        animateContent = false
                        
                        // Delay the previous step appearance for smoother transition
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            currentStep -= 1
                            
                            withAnimation(.easeOut(duration: 0.6)) {
                                animateContent = true
                            }
                        }
                    }
                }) {
                    Text("Back")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.theme.text)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.theme.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.theme.border, lineWidth: 1)
                                )
                        )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .background(
            Rectangle()
                .fill(Color.theme.background)
                .shadow(color: Color.black.opacity(0.1), radius: 10, y: -5)
                .edgesIgnoringSafeArea(.bottom)
        )
    }
    
    // MARK: - Helper Functions
    
    private func completeOnboarding() {
        // Save user preferences
        isLoading = true
        
        // Request notifications permission if enabled
        if notificationsEnabled {
            requestNotificationsPermission()
        }
        
        // Complete onboarding in UserSession
        Task {
            print("DEBUG: Starting onboarding completion process")
            
            // Save selected category preference
            if let userId = userSession.currentUser?.uid {
                do {
                    print("DEBUG: Attempting to save category preference for user \(userId)")
                    try await Firestore.firestore().collection("users").document(userId).updateData([
                        "preferredCategory": selectedCategory
                    ])
                    print("DEBUG: Successfully saved category preference")
                } catch {
                    print("DEBUG: Error saving category preference: \(error.localizedDescription)")
                    // Continue with onboarding completion even if this fails
                }
            }
            
            print("DEBUG: Calling userSession.completeOnboarding()")
            await userSession.completeOnboarding()
            print("DEBUG: Completed userSession.completeOnboarding()")
            
            // Simulate a brief loading time
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            
            // Update UI on main thread
            await MainActor.run {
                isLoading = false
                print("DEBUG: Onboarding UI updates complete, hasCompletedOnboarding = \(userSession.hasCompletedOnboarding)")
                
                // Ensure router properly navigates to main app
                router.changeTab(to: 0) // Navigate to the first tab in the app
            }
        }
    }
    
    private func requestNotificationsPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                // Schedule notifications based on selectedTime
                scheduleNotifications()
            }
        }
    }
    
    private func scheduleNotifications() {
        let content = UNMutableNotificationContent()
        content.title = "100Days Challenge"
        content.body = "Time to check in and keep your streak going!"
        content.sound = .default
        
        var dateComponents = Calendar.current.dateComponents([.hour, .minute], from: selectedTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        let request = UNNotificationRequest(identifier: "dailyCheckIn", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - Supporting Views

struct OnboardingFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.theme.accent.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(.theme.accent)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.theme.text)
                
                Text(description)
                    .font(.system(size: 15))
                    .foregroundColor(.theme.subtext)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
    }
}

struct CategoryCard: View {
    let category: String
    let isSelected: Bool
    let onTap: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 16) {
                // Icon
                Image(systemName: iconForCategory(category))
                    .font(.system(size: 28))
                    .foregroundColor(isSelected ? (colorScheme == .dark ? .black : .white) : .theme.accent)
                
                // Label
                Text(category)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSelected ? (colorScheme == .dark ? .black : .white) : .theme.text)
            }
            .frame(height: 120)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.theme.accent : Color.theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Color.clear : Color.theme.border, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(AppScaleButtonStyle())
    }
    
    private func iconForCategory(_ category: String) -> String {
        switch category {
        case "Fitness":
            return "figure.run"
        case "Learning":
            return "book.fill"
        case "Creativity":
            return "paintbrush.fill"
        case "Mindfulness":
            return "brain.head.profile"
        case "Career":
            return "briefcase.fill"
        case "Health":
            return "heart.fill"
        default:
            return "star.fill"
        }
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
            .environmentObject(UserSession.shared)
            .environmentObject(SubscriptionStore.shared)
            .environmentObject(EntitlementsAdapter.shared)
            .environmentObject(NavigationRouter())
    }
} 