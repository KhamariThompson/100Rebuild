import SwiftUI

/// An enhanced view for creating a new challenge with multiple configuration options
struct NewChallengeView: View {
    @Binding var isPresented: Bool
    @Binding var challengeTitle: String
    let onCreateChallenge: (String, Bool) -> Void
    
    // Challenge configuration
    @State private var isTimed: Bool = false
    @State private var isPublic: Bool = true
    @State private var selectedCategory: ChallengeCategory = .general
    @State private var minDuration: Int = 15
    @State private var selectedIcon: String = "checkmark.circle.fill"
    @State private var showCategoryPicker = false
    @State private var showIconPicker = false
    @State private var challengeDescription: String = ""
    
    // UI state
    @State private var showTimedInfo: Bool = false
    @State private var animateElements: Bool = false
    @FocusState private var isTitleFocused: Bool
    
    // Environment
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @EnvironmentObject private var themeManager: ThemeManager
    
    // Icon choices
    private let iconOptions = [
        "checkmark.circle.fill", "figure.run", "book.fill", "heart.fill", 
        "brain.head.profile", "drop.fill", "camera.fill", "music.note",
        "paintbrush.fill", "gamecontroller.fill", "leaf.fill", "sun.max.fill",
        "moon.fill", "guitar", "briefcase.fill", "pills.fill",
        "fork.knife", "cup.and.saucer.fill", "bicycle", "clock.fill"
    ]
    
    // Popular challenge suggestions
    private let challengeSuggestions = [
        "Go to the gym",
        "Read 10 pages",
        "No sugar",
        "Code every day",
        "Meditate",
        "Drink a gallon of water",
        "Write journal entry",
        "Take a daily photo",
        "Practice an instrument"
    ]
    
    // Categories
    private enum ChallengeCategory: String, CaseIterable, Identifiable {
        case general = "General"
        case fitness = "Fitness"
        case mindfulness = "Mindfulness"
        case productivity = "Productivity"
        case creativity = "Creativity"
        case health = "Health"
        case learning = "Learning"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .general: return "star.fill"
            case .fitness: return "figure.run"
            case .mindfulness: return "brain.head.profile"
            case .productivity: return "checkmark.circle.fill"
            case .creativity: return "paintbrush.fill"
            case .health: return "heart.fill"
            case .learning: return "book.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .general: return .blue
            case .fitness: return .orange
            case .mindfulness: return .purple
            case .productivity: return .green
            case .creativity: return .pink
            case .health: return .red
            case .learning: return .yellow
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.theme.background.ignoresSafeArea()
                
                // Main content
                ScrollView {
                    VStack(spacing: AppSpacing.xl) {
                        // Challenge title input
                        VStack(alignment: .leading, spacing: AppSpacing.s) {
                            Text("What do you want to do for 100 days?")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(.theme.text)
                            
                            ZStack(alignment: .leading) {
                                if challengeTitle.isEmpty {
                                    Text("e.g., Read 10 pages, Meditate, No sugar")
                                        .foregroundColor(.theme.subtext.opacity(0.6))
                                        .padding(.leading, AppSpacing.m)
                                }
                                
                                TextField("", text: $challengeTitle)
                                    .font(.system(size: 18))
                                    .padding(AppSpacing.m)
                                    .background(Color.theme.surface)
                                    .cornerRadius(AppSpacing.cardCornerRadius)
                                    .focused($isTitleFocused)
                                    .submitLabel(.next)
                            }
                        }
                        .padding(.top, AppSpacing.m)
                        .offset(y: animateElements ? 0 : 20)
                        .opacity(animateElements ? 1 : 0)
                        
                        // Challenge icon & category selection
                        HStack(spacing: AppSpacing.l) {
                            // Icon selector
                            VStack(alignment: .center, spacing: AppSpacing.xs) {
                                Text("Icon")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(.theme.subtext)
                                
                                Button(action: {
                                    withAnimation {
                                        showIconPicker.toggle()
                                    }
                                }) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.theme.accent.opacity(0.1))
                                            .frame(width: 60, height: 60)
                                        
                                        Image(systemName: selectedIcon)
                                            .font(.system(size: 30))
                                            .foregroundColor(Color.theme.accent)
                                    }
                                }
                            }
                            
                            // Category selector
                            VStack(alignment: .center, spacing: AppSpacing.xs) {
                                Text("Category")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(.theme.subtext)
                                
                                Button(action: {
                                    withAnimation {
                                        showCategoryPicker.toggle()
                                    }
                                }) {
                                    HStack(spacing: AppSpacing.xs) {
                                        Image(systemName: selectedCategory.icon)
                                            .foregroundColor(selectedCategory.color)
                                        
                                        Text(selectedCategory.rawValue)
                                            .font(.system(size: 16, weight: .medium, design: .rounded))
                                            .foregroundColor(.theme.text)
                                        
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 12))
                                            .foregroundColor(.theme.subtext)
                                    }
                                    .padding(.horizontal, AppSpacing.m)
                                    .padding(.vertical, AppSpacing.s)
                                    .background(
                                        RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                                            .fill(Color.theme.surface)
                                    )
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal)
                        .offset(y: animateElements ? 0 : 20)
                        .opacity(animateElements ? 1 : 0)
                        
                        // Configuration cards
                        VStack(spacing: AppSpacing.m) {
                            // Description (optional)
                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                Text("Description (optional)")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(.theme.text)
                                
                                ZStack(alignment: .topLeading) {
                                    if challengeDescription.isEmpty {
                                        Text("What's your goal? Be specific to stay motivated.")
                                            .font(.system(size: 15))
                                            .foregroundColor(.theme.subtext.opacity(0.6))
                                            .padding(.top, AppSpacing.m)
                                            .padding(.leading, AppSpacing.m)
                                    }
                                    
                                    TextEditor(text: $challengeDescription)
                                        .font(.system(size: 15))
                                        .frame(minHeight: 80)
                                        .padding(AppSpacing.xs)
                                        .background(Color.theme.surface)
                                        .cornerRadius(AppSpacing.cardCornerRadius)
                                }
                                .frame(height: 100)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, AppSpacing.s)
                            .background(
                                RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                                    .fill(Color.theme.surface)
                            )
                            
                            // Timer option
                            configCard(title: "Timer Challenge") {
                                VStack(alignment: .leading, spacing: AppSpacing.s) {
                                    Toggle(isOn: $isTimed) {
                                        HStack {
                                            Image(systemName: "timer")
                                                .foregroundColor(.theme.accent)
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("Require timer to check in")
                                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                                    .foregroundColor(.theme.text)
                                                
                                                Text("Great for focused activities like meditation")
                                                    .font(.system(size: 13))
                                                    .foregroundColor(.theme.subtext)
                                            }
                                            
                                            Spacer()
                                        }
                                    }
                                    .toggleStyle(SwitchToggleStyle(tint: .theme.accent))
                                    
                                    if isTimed {
                                        Divider()
                                        
                                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                            Text("Minimum Session Duration")
                                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                                .foregroundColor(.theme.text)
                                            
                                            Picker("Duration", selection: $minDuration) {
                                                Text("5 minutes").tag(5)
                                                Text("10 minutes").tag(10)
                                                Text("15 minutes").tag(15)
                                                Text("20 minutes").tag(20)
                                                Text("30 minutes").tag(30)
                                                Text("45 minutes").tag(45)
                                                Text("60 minutes").tag(60)
                                            }
                                            .pickerStyle(SegmentedPickerStyle())
                                            .colorMultiply(Color.theme.accent)
                                        }
                                    }
                                }
                            }
                            
                            // Visibility option
                            configCard(title: "Challenge Privacy") {
                                Toggle(isOn: $isPublic) {
                                    HStack {
                                        Image(systemName: isPublic ? "eye.fill" : "eye.slash.fill")
                                            .foregroundColor(isPublic ? .theme.accent : .theme.subtext)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(isPublic ? "Public Challenge" : "Private Challenge")
                                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                                .foregroundColor(.theme.text)
                                            
                                            Text(isPublic ? "Others can see your progress" : "Only you can see this challenge")
                                                .font(.system(size: 13))
                                                .foregroundColor(.theme.subtext)
                                        }
                                        
                                        Spacer()
                                    }
                                }
                                .toggleStyle(SwitchToggleStyle(tint: .theme.accent))
                            }
                        }
                        .offset(y: animateElements ? 0 : 20)
                        .opacity(animateElements ? 1 : 0)
                        
                        // Popular suggestions
                        VStack(alignment: .leading, spacing: AppSpacing.s) {
                            Text("Popular challenge ideas")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(.theme.text)
                                .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: AppSpacing.s) {
                                    ForEach(Array(challengeSuggestions.enumerated()), id: \.offset) { index, suggestion in
                                        Button(action: {
                                            challengeTitle = suggestion
                                        }) {
                                            HStack {
                                                Image(systemName: iconForSuggestion(index))
                                                    .foregroundColor(.theme.accent)
                                                
                                                Text(suggestion)
                                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                                    .foregroundColor(.theme.text)
                                            }
                                            .padding(.horizontal, AppSpacing.m)
                                            .padding(.vertical, AppSpacing.s)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(Color.theme.surface)
                                                    .shadow(color: Color.theme.shadow.opacity(0.05), radius: 2, x: 0, y: 1)
                                            )
                                        }
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.vertical, AppSpacing.xs)
                            }
                        }
                        .offset(y: animateElements ? 0 : 20)
                        .opacity(animateElements ? 1 : 0)
                        
                        // Pro limit warning
                        if !subscriptionService.isProUser {
                            proLimitWarning
                                .padding(.horizontal)
                                .offset(y: animateElements ? 0 : 20)
                                .opacity(animateElements ? 1 : 0)
                        }
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.bottom, 100)
                }
                
                // Bottom action button
                VStack {
                    Spacer()
                    
                    createButton
                        .offset(y: animateElements ? 0 : 40)
                        .opacity(animateElements ? 1 : 0)
                }
                
                // Category picker sheet
                if showCategoryPicker {
                    categoryPickerOverlay
                }
                
                // Icon picker sheet
                if showIconPicker {
                    iconPickerOverlay
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("New Challenge")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.theme.text)
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { isPresented = false }) {
                        Text("Cancel")
                            .foregroundColor(.theme.accent)
                    }
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        animateElements = true
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        isTitleFocused = true
                    }
                }
            }
        }
    }
    
    // Create button that stays at the bottom
    private var createButton: some View {
        Button(action: {
            onCreateChallenge(challengeTitle, isTimed)
        }) {
            Text("Start 100-Day Challenge")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.m)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.theme.accent, Color.theme.accent.opacity(0.8)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color.theme.accent.opacity(0.3), radius: 8, x: 0, y: 4)
                )
        }
        .buttonStyle(AppScaleButtonStyle())
        .padding(.horizontal, AppSpacing.l)
        .padding(.bottom, AppSpacing.l)
        .disabled(challengeTitle.isEmpty)
        .opacity(challengeTitle.isEmpty ? 0.5 : 1.0)
        .background(
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(
                            colors: [
                                Color.theme.background.opacity(0),
                                Color.theme.background
                            ]
                        ),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 100)
                .edgesIgnoringSafeArea(.bottom)
        )
    }
    
    // Category picker overlay
    private var categoryPickerOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        showCategoryPicker = false
                    }
                }
            
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                Text("Select Category")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.theme.text)
                    .padding(.top, AppSpacing.m)
                
                Divider()
                
                ScrollView {
                    VStack(spacing: AppSpacing.s) {
                        ForEach(ChallengeCategory.allCases) { category in
                            Button(action: {
                                selectedCategory = category
                                withAnimation {
                                    showCategoryPicker = false
                                }
                            }) {
                                HStack(spacing: AppSpacing.m) {
                                    Image(systemName: category.icon)
                                        .font(.system(size: 20))
                                        .foregroundColor(category.color)
                                        .frame(width: 24)
                                    
                                    Text(category.rawValue)
                                        .font(.system(size: 17, design: .rounded))
                                        .foregroundColor(.theme.text)
                                    
                                    Spacer()
                                    
                                    if category == selectedCategory {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.theme.accent)
                                    }
                                }
                                .padding(.vertical, AppSpacing.s)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.l)
            .padding(.bottom, AppSpacing.m)
            .frame(maxWidth: .infinity, maxHeight: 400)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.theme.background)
                    .shadow(color: Color.black.opacity(0.2), radius: 16, x: 0, y: 5)
            )
            .padding(.horizontal, AppSpacing.l)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .zIndex(10)
    }
    
    // Icon picker overlay
    private var iconPickerOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        showIconPicker = false
                    }
                }
            
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                Text("Select Icon")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.theme.text)
                    .padding(.top, AppSpacing.m)
                
                Divider()
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: AppSpacing.m), count: 5), spacing: AppSpacing.m) {
                    ForEach(iconOptions, id: \.self) { icon in
                        Button(action: {
                            selectedIcon = icon
                            withAnimation {
                                showIconPicker = false
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(icon == selectedIcon ? Color.theme.accent.opacity(0.15) : Color.theme.surface)
                                    .frame(width: 56, height: 56)
                                
                                Image(systemName: icon)
                                    .font(.system(size: 24))
                                    .foregroundColor(icon == selectedIcon ? Color.theme.accent : .theme.text)
                            }
                            .overlay(
                                Circle()
                                    .stroke(icon == selectedIcon ? Color.theme.accent : Color.clear, lineWidth: 2)
                            )
                        }
                    }
                }
                .padding(.bottom, AppSpacing.m)
            }
            .padding(.horizontal, AppSpacing.l)
            .frame(maxWidth: .infinity, maxHeight: 380)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.theme.background)
                    .shadow(color: Color.black.opacity(0.2), radius: 16, x: 0, y: 5)
            )
            .padding(.horizontal, AppSpacing.l)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .zIndex(10)
    }
    
    // Configuration card helper
    private func configCard<Content: View>(title: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            content()
        }
        .padding(.horizontal)
        .padding(.vertical, AppSpacing.m)
        .background(
            RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                .fill(Color.theme.surface)
                .shadow(color: Color.theme.shadow.opacity(0.05), radius: 2, x: 0, y: 1)
        )
        .padding(.horizontal)
    }
    
    // Pro limit warning when user has 3+ challenges as a free user
    private var proLimitWarning: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            HStack {
                Image(systemName: "crown.fill")
                    .foregroundColor(.yellow)
                
                Text("Pro Feature")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.theme.accent)
                
                Spacer()
            }
            
            Text("Free users can create up to 2 active challenges")
                .font(.system(size: 15, design: .rounded))
                .foregroundColor(.theme.text)
            
            Text("Upgrade to Pro to create unlimited challenges, access premium icons, and unlock timer features")
                .font(.system(size: 14))
                .foregroundColor(.theme.subtext)
                .padding(.top, AppSpacing.xxs)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.theme.accent.opacity(0.1), Color.theme.surface]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.theme.shadow.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
    
    // Helper to get appropriate icon for a suggestion
    private func iconForSuggestion(_ index: Int) -> String {
        switch index % 9 {
        case 0: return "figure.run"
        case 1: return "book.fill"
        case 2: return "carrot.fill"
        case 3: return "laptopcomputer"
        case 4: return "brain.head.profile"
        case 5: return "drop.fill"
        case 6: return "pencil.and.paper" 
        case 7: return "camera.fill"
        case 8: return "music.note"
        default: return "star.fill"
        }
    }
}

struct NewChallengeView_Previews: PreviewProvider {
    static var previews: some View {
        NewChallengeView(
            isPresented: .constant(true),
            challengeTitle: .constant(""),
            onCreateChallenge: { _, _ in }
        )
        .environmentObject(SubscriptionService.shared)
        .environmentObject(ThemeManager.shared)
    }
} 