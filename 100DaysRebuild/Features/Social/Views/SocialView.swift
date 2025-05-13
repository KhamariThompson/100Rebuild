import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct SocialView: View {
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var subscriptionService: SubscriptionService
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var username = ""
    @State private var usernameAvailable = false
    @State private var isCheckingUsername = false
    @State private var usernameValidationMessage = ""
    @State private var showingSuccessToast = false
    
    // Function to filter username to alphanumeric only
    private func filterUsername(_ input: String) -> String {
        return input.replacingOccurrences(of: "[^a-zA-Z0-9]", with: "", options: .regularExpression)
    }
    
    var body: some View {
        ZStack {
            Color.theme.background.ignoresSafeArea()
            
        ScrollView {
                VStack(spacing: 24) {
                // Header
                    communityHeader
                    
                    // Username reservation
                    usernameReservationSection
                    
                    // Community leaderboard
                    leaderboardSection
                    
                    // Friend Activity
                    friendActivitySection
                    
                    // Connect section
                    connectSection
                    
                    // Coming soon (placeholder)
                    VStack(spacing: 8) {
                        Text("More exciting features coming soon!")
                            .font(.headline)
                            .foregroundColor(.theme.subtext)
                            .padding(.top, 20)
                        
                        Text("We're building an entire social ecosystem for habit-builders! Stay tuned for daily visual logs, friend activity feeds, group challenges, and personalized insights — all designed to keep you motivated on your 100-day journey.")
                            .font(.subheadline)
                            .foregroundColor(.theme.subtext)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
            
            // Success Toast
            if showingSuccessToast {
                VStack {
                    Spacer()
                    Text("Username reserved for future social features!")
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.theme.accent)
                                .shadow(radius: 5)
                        )
                        .foregroundColor(.white)
                        .padding(.horizontal)
                        .padding(.bottom, 30)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .zIndex(100)
                .onAppear {
                    // Dismiss toast after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation {
                            showingSuccessToast = false
                        }
                    }
                }
            }
        }
        .overlay(
            Group {
                if isLoading {
                    LoadingView()
                }
            }
        )
        .alert(isPresented: Binding<Bool>(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Alert(
                title: Text("Error"),
                message: Text(errorMessage ?? "Unknown error"),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            loadUserUsername()
        }
    }
    
    private var communityHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Social is Coming to 100Days!")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.theme.text)
            
            Text("Connect with others on their 100-day journey")
                .font(.subheadline)
                .foregroundColor(.theme.subtext)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top)
    }
    
    private var usernameReservationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Claim Your Username")
                .font(.headline)
                .foregroundColor(.theme.text)
            
            Text("Social features are coming in our next major update! In the meantime, reserve your username now to secure your identity before others claim it. Soon you'll be able to add friends, join group challenges, track streaks together, and see public leaderboards.")
                .font(.subheadline)
                .foregroundColor(.theme.subtext)
                .padding(.bottom, 4)
            
            VStack(alignment: .leading, spacing: 8) {
                if !username.isEmpty && userSession.username != nil {
                    Text("Your username: @\(username)")
                        .font(.body)
                        .foregroundColor(.theme.accent)
                        .padding(.bottom, 8)
                    
                    Text("Great! Your username is reserved for when social features launch. We'll notify you when they're available.")
                        .font(.subheadline)
                        .foregroundColor(.theme.subtext)
                } else {
                    Text("Be among the first to claim your preferred username:")
                        .font(.subheadline)
                        .foregroundColor(.theme.subtext)
                    
                    TextField("Choose a username", text: $username)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.theme.surface)
                                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                        )
                        .onChange(of: username) {
                            // Filter out non-alphanumeric characters
                            username = filterUsername(username)
                            
                            // Validate username
                            validateUsername()
                        }
                    
                    if !usernameValidationMessage.isEmpty {
                        Text(usernameValidationMessage)
                            .font(.caption)
                            .foregroundColor(usernameAvailable ? .green : .red)
                            .padding(.horizontal, 4)
                    }
                    
                    Button(action: reserveUsername) {
                        HStack {
                            Text("Reserve Username")
                                .fontWeight(.semibold)
                            
                            if isCheckingUsername {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(0.7)
                                    .padding(.leading, 4)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    usernameAvailable ? Color.theme.accent : Color.gray.opacity(0.5)
                                )
                        )
                        .foregroundColor(.white)
                    }
                    .disabled(!usernameAvailable || isCheckingUsername)
                    .padding(.top, 8)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.theme.surface)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
    
    private var leaderboardSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Leaderboard")
                .font(.headline)
                .foregroundColor(.theme.text)
            
            if subscriptionService.isProUser {
                // Pro users see the actual leaderboard
                ForEach(1...5, id: \.self) { index in
                    HStack {
                        Text("\(index)")
                            .font(.headline)
                            .foregroundColor(.theme.accent)
                            .frame(width: 30)
                        
                        Image(systemName: "person.crop.circle.fill")
                            .font(.title2)
                            .foregroundColor(.theme.accent)
                        
                        Text("User \(index)")
                            .font(.body)
                            .foregroundColor(.theme.text)
                        
                        Spacer()
                        
                        Text("\(100 - index * 5) Days")
                            .font(.callout)
                            .foregroundColor(.theme.accent)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.theme.surface)
                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                    )
                }
            } else {
                // Free users see blurred content with upgrade prompt
                ProLockedView {
                VStack(spacing: 16) {
                        ForEach(1...5, id: \.self) { index in
                            HStack {
                                Text("\(index)")
                                    .font(.headline)
                                    .foregroundColor(.theme.accent)
                                    .frame(width: 30)
                                
                                Image(systemName: "person.crop.circle.fill")
                                .font(.title2)
                                .foregroundColor(.theme.accent)
                                
                                Text("User \(index)")
                                    .font(.body)
                                    .foregroundColor(.theme.text)
                                
                                Spacer()
                                
                                Text("\(100 - index * 5) Days")
                                    .font(.callout)
                                    .foregroundColor(.theme.accent)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.theme.surface)
                                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                            )
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.theme.surface)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
    
    private var friendActivitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Friend Activity")
                                .font(.headline)
                .foregroundColor(.theme.text)
            
            if subscriptionService.isProUser {
                VStack(spacing: 12) {
                    ForEach(1...3, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.headline)
                                    .foregroundColor(.theme.accent)
                                
                                Text("Friend \(index)")
                                    .font(.body)
                                .foregroundColor(.theme.text)
                            
                            Spacer()
                                
                                Text("\(index) hour\(index == 1 ? "" : "s") ago")
                                    .font(.caption)
                                    .foregroundColor(.theme.subtext)
                            }
                            
                            Text("Completed day \(index * 15) of their challenge!")
                                .font(.subheadline)
                                .foregroundColor(.theme.text)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.theme.surface)
                                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        )
                    }
                }
            } else {
                // Free users see blurred content with upgrade prompt
                ProLockedView {
                    VStack(spacing: 12) {
                        ForEach(1...3, id: \.self) { index in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "person.crop.circle.fill")
                                        .font(.headline)
                                        .foregroundColor(.theme.accent)
                                    
                                    Text("Friend \(index)")
                                        .font(.body)
                                        .foregroundColor(.theme.text)
                                    
                                    Spacer()
                                    
                                    Text("\(index) hour\(index == 1 ? "" : "s") ago")
                                        .font(.caption)
                                        .foregroundColor(.theme.subtext)
                                }
                                
                                Text("Completed day \(index * 15) of their challenge!")
                                    .font(.subheadline)
                                    .foregroundColor(.theme.text)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.theme.surface)
                                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                            )
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.theme.surface)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
    
    private var connectSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Connect")
                    .font(.headline)
                .foregroundColor(.theme.text)
            
            Button(action: {
                if let url = URL(string: "https://twitter.com/100daysapp") {
                    UIApplication.shared.open(url)
                }
            }) {
                HStack {
                    Image(systemName: "bird.fill")
                        .foregroundColor(.theme.accent)
                    
                    Text("Follow us on Twitter")
                        .font(.body)
                        .foregroundColor(.theme.text)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.theme.subtext)
                }
                .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                        .fill(Color.theme.surface)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                )
            }
            
            Button(action: {
                if let url = URL(string: "mailto:support@100days.site") {
                    UIApplication.shared.open(url)
                }
            }) {
                HStack {
                    Image(systemName: "envelope.fill")
                        .foregroundColor(.theme.accent)
                    
                    Text("Contact Support")
                        .font(.body)
                        .foregroundColor(.theme.text)
                
                Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.theme.subtext)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.theme.surface)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.theme.surface)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
    
    // MARK: - Username Functions
    
    private func loadUserUsername() {
        if let existingUsername = userSession.username {
            self.username = existingUsername
        }
    }
    
    private func validateUsername() {
        // Reset validation state
        usernameAvailable = false
        
        // Check length
        if username.count < 3 {
            usernameValidationMessage = "Username must be at least 3 characters"
            return
        }
        
        if username.count > 20 {
            usernameValidationMessage = "Username must be at most 20 characters"
            return
        }
        
        // Check for alphanumeric characters
        let allowedCharacterSet = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        if username.rangeOfCharacter(from: allowedCharacterSet.inverted) != nil {
            usernameValidationMessage = "Username can only contain letters and numbers"
            return
        }
        
        // Check availability in Firestore
        isCheckingUsername = true
        usernameValidationMessage = "Checking availability..."
        
        let db = Firestore.firestore()
        db.collection("usernames")
            .document(username.lowercased())
            .getDocument { (snapshot, error) in
                DispatchQueue.main.async {
                    self.isCheckingUsername = false
                    
                    if let error = error {
                        self.usernameValidationMessage = "Error checking username: \(error.localizedDescription)"
                        self.usernameAvailable = false
                        return
                    }
                    
                    // If document exists and doesn't belong to current user, username is taken
                    if let snapshot = snapshot, snapshot.exists {
                        if let userId = snapshot.data()?["userId"] as? String,
                           userId == Auth.auth().currentUser?.uid {
                            // User already owns this username
                            self.usernameValidationMessage = "This is your current username"
                            self.usernameAvailable = false
                        } else {
                            self.usernameValidationMessage = "Username already taken"
                            self.usernameAvailable = false
                        }
                    } else {
                        // Username is available
                        self.usernameValidationMessage = "Username available!"
                        self.usernameAvailable = true
                    }
                }
            }
    }
    
    private func reserveUsername() {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "You must be logged in to reserve a username"
            return
        }
        
        isLoading = true
        
        let db = Firestore.firestore()
        let usernameDoc = db.collection("usernames").document(username.lowercased())
        let userDoc = db.collection("users").document(userId)
        
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            // Check if username is already taken
            let usernameSnapshot: DocumentSnapshot
            do {
                try usernameSnapshot = transaction.getDocument(usernameDoc)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            // If username exists and belongs to someone else, fail
            if let usernameSnapshot = usernameSnapshot as DocumentSnapshot?, usernameSnapshot.exists {
                if let existingUserId = usernameSnapshot.data()?["userId"] as? String,
                   existingUserId != userId {
                    errorPointer?.pointee = NSError(
                        domain: "AppErrorDomain",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Username already taken"]
                    )
                    return nil
                }
            }
            
            // Set the username document
            transaction.setData([
                "userId": userId,
                "username": username.lowercased(),
                "createdAt": FieldValue.serverTimestamp()
            ], forDocument: usernameDoc)
            
            // Update the user's profile with the username
            transaction.updateData([
                "username": username.lowercased()
            ], forDocument: userDoc)
            
            return true
        }) { (result, error) in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = "Failed to reserve username: \(error.localizedDescription)"
                } else {
                    // Update local state - use the updateUsername method
                    Task {
                        do {
                            try await self.userSession.updateUsername(self.username.lowercased())
                            
                            // Show success message
                            withAnimation {
                                self.showingSuccessToast = true
                            }
                        } catch {
                            self.errorMessage = "Failed to update username: \(error.localizedDescription)"
                        }
                    }
                }
            }
        }
    }
}

// Loading view for when data is being fetched
struct LoadingView: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.2)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                SwiftUI.ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color.white))
                    .scaleEffect(1.5)
                
                Text("Loading...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.theme.accent.opacity(0.8))
            )
        }
    }
}

struct SocialView_Previews: PreviewProvider {
    static var previews: some View {
        SocialView()
            .environmentObject(UserSession.shared)
            .environmentObject(SubscriptionService.shared)
    }
} 