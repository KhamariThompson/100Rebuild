import SwiftUI

/// A component to display showcased badges on the profile
struct BadgeShowcaseView: View {
    let badges: [Badge]
    let onTap: (Badge) -> Void
    let onEditTap: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            // Section header
            HStack {
                Text("Badge Showcase")
                    .font(AppTypography.headline())
                    .foregroundColor(.theme.text)
                
                Spacer()
                
                // Edit button
                Button(action: onEditTap) {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                            .font(.system(size: 10))
                        
                        Text("Edit")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.theme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .strokeBorder(Color.theme.accent, lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, AppSpacing.screenHorizontalPadding)
            
            // Badge display
            if badges.isEmpty {
                emptyShowcaseView
            } else {
                showcaseBadgesView
            }
        }
    }
    
    // Empty state when no badges are showcased
    private var emptyShowcaseView: some View {
        VStack(spacing: 12) {
            Image(systemName: "trophy")
                .font(.system(size: 30))
                .foregroundColor(.theme.subtext.opacity(0.7))
            
            Text("Showcase your favorite badges here")
                .font(AppTypography.callout())
                .foregroundColor(.theme.text)
                .multilineTextAlignment(.center)
            
            Button(action: onEditTap) {
                Text("Select Badges")
                    .font(AppTypography.footnote())
                    .fontWeight(.medium)
                    .foregroundColor(.theme.accent)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.theme.accent, lineWidth: 1.5)
                    )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(AppSpacing.m)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                .fill(Color.theme.surface)
                .shadow(color: Color.theme.shadow.opacity(colorScheme == .dark ? 0.3 : 0.1), 
                       radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal, AppSpacing.screenHorizontalPadding)
    }
    
    // View for displaying showcased badges
    private var showcaseBadgesView: some View {
        HStack(spacing: 16) {
            ForEach(badges) { badge in
                BadgeShowcaseItem(badge: badge, onTap: { onTap(badge) })
            }
            
            // If less than 3 badges, show placeholder(s)
            if badges.count < 3 {
                ForEach(0..<(3 - badges.count), id: \.self) { _ in
                    emptyBadgeSlot
                }
            }
        }
        .padding(AppSpacing.m)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                .fill(Color.theme.surface)
                .shadow(color: Color.theme.shadow.opacity(colorScheme == .dark ? 0.3 : 0.1), 
                       radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal, AppSpacing.screenHorizontalPadding)
    }
    
    // Empty badge slot
    private var emptyBadgeSlot: some View {
        ZStack {
            Circle()
                .fill(Color.theme.background)
                .frame(width: 70, height: 70)
            
            Circle()
                .strokeBorder(Color.theme.border.opacity(colorScheme == .dark ? 0.5 : 0.3), lineWidth: 1)
                .frame(width: 70, height: 70)
            
            Image(systemName: "plus")
                .font(.system(size: 20))
                .foregroundColor(.theme.subtext.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .onTapGesture {
            onEditTap()
        }
    }
}

/// Individual badge item in the showcase
struct BadgeShowcaseItem: View {
    let badge: Badge
    let onTap: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 6) {
            // Badge icon
            ZStack {
                // Background circle - ensure good contrast in both modes
                Circle()
                    .fill(adaptiveBackgroundColor)
                    .frame(width: 70, height: 70)
                
                // Border
                Circle()
                    .strokeBorder(adaptiveBorderColor, lineWidth: 1.5)
                    .frame(width: 70, height: 70)
                
                // Icon
                Image(systemName: badge.iconName)
                    .font(.system(size: 30))
                    .foregroundColor(adaptiveIconColor)
            }
            .shadow(color: badge.category.color.opacity(colorScheme == .dark ? 0.3 : 0.2), 
                   radius: 4, x: 0, y: 2)
            
            // Badge name
            Text(badge.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.theme.text)
                .multilineTextAlignment(.center)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
    
    // Adaptive colors based on color scheme
    private var adaptiveBackgroundColor: Color {
        if colorScheme == .dark {
            // Darker background but still visible in dark mode
            return badge.category.color.opacity(0.25)
        } else {
            return badge.category.color.opacity(0.15)
        }
    }
    
    private var adaptiveBorderColor: Color {
        if colorScheme == .dark {
            // More vibrant border in dark mode for better visibility
            return badge.category.color.opacity(0.5)
        } else {
            return badge.category.color.opacity(0.3)
        }
    }
    
    private var adaptiveIconColor: Color {
        if colorScheme == .dark {
            // Brighter icon in dark mode
            return badge.category.color.opacity(0.9)
        } else {
            return badge.category.color
        }
    }
}

/// Badge showcase editor view
struct BadgeShowcaseEditorView: View {
    @EnvironmentObject private var badgeService: BadgeService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var selectedBadges: [Badge] = []
    @State private var isLoading = false
    @State private var showOnlyUnlocked = true
    @State private var selectedCategory: BadgeCategory? = nil
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.theme.background.ignoresSafeArea()
                
                VStack(spacing: 16) {
                    // Selected badges preview with improved styling
                    VStack(spacing: 12) {
                        Text("Your Showcase")
                            .font(.headline)
                            .foregroundColor(.theme.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                        
                        selectedBadgesPreview
                    }
                    .padding(.top)
                    
                    // Filter controls
                    HStack {
                        // Category filter
                        Menu {
                            Button(action: {
                                withAnimation {
                                    selectedCategory = nil
                                }
                            }) {
                                Label("All Categories", systemImage: "tag")
                                    .foregroundColor(.theme.accent)
                            }
                            
                            Divider()
                            
                            ForEach(BadgeCategory.allCases, id: \.self) { category in
                                Button(action: {
                                    withAnimation {
                                        selectedCategory = category
                                    }
                                }) {
                                    Label(category.rawValue, systemImage: category.icon)
                                        .foregroundColor(category.color)
                                }
                            }
                        } label: {
                            HStack {
                                if let category = selectedCategory {
                                    Label(category.rawValue, systemImage: category.icon)
                                        .foregroundColor(category.color)
                                } else {
                                    Text("All Categories")
                                        .foregroundColor(.theme.text)
                                }
                                
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 12))
                                    .foregroundColor(.theme.subtext)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(
                                Capsule()
                                    .fill(Color.theme.surface)
                                    .shadow(color: Color.theme.shadow.opacity(0.1), radius: 2, x: 0, y: 1)
                            )
                        }
                        
                        Spacer()
                        
                        // Toggle to show only unlocked badges
                        Toggle("Unlocked Only", isOn: $showOnlyUnlocked)
                            .toggleStyle(SwitchToggleStyle(tint: .theme.accent))
                            .font(.footnote)
                            .labelsHidden()
                        
                        Text("Unlocked Only")
                            .font(.footnote)
                            .foregroundColor(.theme.subtext)
                    }
                    .padding(.horizontal)
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Scrollable badge selection grid with improved interaction
                    ScrollView {
                        Text("Select up to 3 badges to showcase on your profile")
                            .font(.subheadline)
                            .foregroundColor(.theme.subtext)
                            .multilineTextAlignment(.center)
                            .padding(.top, 8)
                            .padding(.bottom, 16)
                        
                        badgeSelectionContent
                            .padding(.horizontal)
                    }
                    
                    // Save button with improved feedback
                    saveButtonOverlay
                }
            }
            .navigationTitle("Edit Badge Showcase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.theme.accent)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveShowcasedBadges()
                    }
                    .foregroundColor(.theme.accent)
                    .opacity(selectedBadges.isEmpty ? 0.5 : 1.0)
                    .disabled(selectedBadges.isEmpty || isLoading)
                }
            }
            .onAppear {
                // Initialize with currently showcased badges
                selectedBadges = badgeService.showcasedBadges
            }
        }
    }
    
    // Badge selection content with visual indication of selection state
    private var badgeSelectionContent: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 3), spacing: 20) {
            ForEach(filteredBadges) { badge in
                BadgeSelectionItem(
                    badge: badge,
                    isSelected: selectedBadges.contains(badge),
                    onTap: {
                        toggleBadgeSelection(badge)
                    }
                )
            }
        }
        .padding(.bottom, 100) // Add space for the bottom overlay
    }
    
    // Selected badges preview
    private var selectedBadgesPreview: some View {
        HStack(spacing: 20) {
            // Show selected badges
            ForEach(selectedBadges) { badge in
                BadgeShowcasePreviewItem(badge: badge) {
                    toggleBadgeSelection(badge)
                }
            }
            
            // Add empty slots if needed
            if selectedBadges.count < 3 {
                ForEach(0..<(3 - selectedBadges.count), id: \.self) { _ in
                    emptyBadgeSlot
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.theme.surface)
                .shadow(color: Color.theme.shadow.opacity(0.1), radius: 4, x: 0, y: 2)
        )
        .padding(.horizontal)
    }
    
    // Empty badge slot
    private var emptyBadgeSlot: some View {
        ZStack {
            Circle()
                .fill(Color.theme.background)
                .frame(width: 70, height: 70)
            
            Circle()
                .strokeBorder(Color.theme.border.opacity(0.3), lineWidth: 1)
                .frame(width: 70, height: 70)
            
            Image(systemName: "plus")
                .font(.system(size: 20))
                .foregroundColor(.theme.subtext.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }
    
    // Save button overlay
    private var saveButtonOverlay: some View {
        VStack {
            Button(action: {
                saveShowcasedBadges()
            }) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.8)
                            .padding(.trailing, 8)
                    }
                    
                    Text("Save Selection")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(selectedBadges.isEmpty ? Color.gray : Color.theme.accent)
                )
                .shadow(color: (selectedBadges.isEmpty ? Color.gray : Color.theme.accent).opacity(0.3), radius: 5, x: 0, y: 2)
            }
            .disabled(selectedBadges.isEmpty || isLoading)
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
        .background(
            Rectangle()
                .fill(Color.theme.background.opacity(0.9))
                .edgesIgnoringSafeArea(.bottom)
                .frame(height: 90)
                .background(.ultraThinMaterial)
        )
    }
    
    // Helper method to toggle badge selection
    private func toggleBadgeSelection(_ badge: Badge) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        if selectedBadges.contains(badge) {
            selectedBadges.removeAll { $0.id == badge.id }
        } else {
            // Only allow up to 3 badges
            if selectedBadges.count < 3 {
                selectedBadges.append(badge)
            } else {
                // Replace the first badge if already at limit
                selectedBadges.removeFirst()
                selectedBadges.append(badge)
            }
        }
    }
    
    // Save selected badges to user's profile
    private func saveShowcasedBadges() {
        isLoading = true
        
        Task {
            // First clear all showcased badges
            for badge in badgeService.showcasedBadges {
                await badgeService.setShowcasedBadge(badgeId: badge.id, isShowcased: false)
            }
            
            // Then set the new selection
            for badge in selectedBadges {
                await badgeService.setShowcasedBadge(badgeId: badge.id, isShowcased: true)
            }
            
            await MainActor.run {
                isLoading = false
                dismiss()
            }
        }
    }
    
    // Filter badges based on current settings
    private var filteredBadges: [Badge] {
        var badges = badgeService.badges
        
        // Filter by unlock status if required
        if showOnlyUnlocked {
            badges = badges.filter { $0.isUnlocked }
        }
        
        // Filter by category if selected
        if let category = selectedCategory {
            badges = badges.filter { $0.category == category }
        }
        
        return badges
    }
}

// Badge showcase preview item
struct BadgeShowcasePreviewItem: View {
    let badge: Badge
    let onRemove: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Badge icon
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(badge.category.color.opacity(0.15))
                        .frame(width: 70, height: 70)
                    
                    Circle()
                        .strokeBorder(badge.category.color.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 70, height: 70)
                    
                    Image(systemName: badge.iconName)
                        .font(.system(size: 30))
                        .foregroundColor(badge.category.color)
                }
                
                Text(badge.name)
                    .font(.caption)
                    .foregroundColor(.theme.text)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: 80)
            }
            
            // Remove button
            Button(action: onRemove) {
                ZStack {
                    Circle()
                        .fill(Color.theme.error)
                        .frame(width: 22, height: 22)
                    
                    Image(systemName: "minus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .offset(x: 6, y: -6)
        }
        .frame(maxWidth: .infinity)
    }
}

// Badge selection item with clear selection state
struct BadgeSelectionItem: View {
    let badge: Badge
    let isSelected: Bool
    let onTap: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                // Badge icon with selection indicator
                ZStack {
                    // Background circle
                    Circle()
                        .fill(backgroundColor)
                        .frame(width: 70, height: 70)
                    
                    // Selection ring
                    if isSelected {
                        Circle()
                            .strokeBorder(badge.category.color, lineWidth: 3)
                            .frame(width: 70, height: 70)
                    } else {
                        Circle()
                            .strokeBorder(borderColor, lineWidth: 1)
                            .frame(width: 70, height: 70)
                    }
                    
                    // Icon
                    Image(systemName: badge.iconName)
                        .font(.system(size: 30))
                        .foregroundColor(iconColor)
                    
                    // Selected checkmark indicator
                    if isSelected {
                        ZStack {
                            Circle()
                                .fill(badge.category.color)
                                .frame(width: 24, height: 24)
                            
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .shadow(color: badge.category.color.opacity(0.3), radius: 2, x: 0, y: 1)
                        .offset(x: 24, y: -24)
                    }
                    
                    // Locked overlay
                    if !badge.isUnlocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Color.gray.opacity(0.7))
                            .background(
                                Circle()
                                    .fill(Color.theme.surface)
                                    .frame(width: 20, height: 20)
                            )
                            .offset(x: 24, y: 24)
                    }
                }
                .shadow(color: isSelected ? badge.category.color.opacity(0.3) : Color.clear, radius: 4, x: 0, y: 2)
                
                // Badge name
                Text(badge.name)
                    .font(.caption)
                    .foregroundColor(isSelected ? badge.category.color : .theme.text)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 8)
            .frame(height: 120)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
    
    // Dynamic colors based on selection state and color scheme
    private var backgroundColor: Color {
        if isSelected {
            return badge.category.color.opacity(colorScheme == .dark ? 0.3 : 0.15)
        } else if !badge.isUnlocked {
            return Color.gray.opacity(0.1)
        } else {
            return badge.category.color.opacity(0.1)
        }
    }
    
    private var borderColor: Color {
        if !badge.isUnlocked {
            return Color.gray.opacity(0.3)
        } else {
            return badge.category.color.opacity(0.3)
        }
    }
    
    private var iconColor: Color {
        if isSelected {
            return badge.category.color
        } else if !badge.isUnlocked {
            return Color.gray.opacity(0.5)
        } else {
            return badge.category.color.opacity(0.8)
        }
    }
}

// MARK: - Helper Views

/// Badge icon with background circle
struct BadgeIconView: View {
    let iconName: String
    let color: Color
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack {
            Circle()
                .fill(adaptiveBackgroundColor)
                .frame(width: 56, height: 56)
            
            Image(systemName: iconName)
                .font(.system(size: 24))
                .foregroundColor(adaptiveIconColor)
        }
    }
    
    // Adaptive colors based on color scheme
    private var adaptiveBackgroundColor: Color {
        if colorScheme == .dark {
            return color.opacity(0.25)
        } else {
            return color.opacity(0.15)
        }
    }
    
    private var adaptiveIconColor: Color {
        if colorScheme == .dark {
            return color.opacity(0.9)
        } else {
            return color
        }
    }
}

/// Badge name label
struct BadgeNameLabel: View {
    let name: String
    
    var body: some View {
        Text(name)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.theme.text)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}

/// Selection checkmark indicator
struct SelectionCheckmark: View {
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.theme.accent)
                .frame(width: 22, height: 22)
                .shadow(
                    color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.2), 
                    radius: 2, 
                    x: 0, 
                    y: 1
                )
            
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
        }
        .offset(x: 25, y: -25)
    }
} 
