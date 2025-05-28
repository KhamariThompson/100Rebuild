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
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Selected badges preview
                selectedBadgesPreview
                
                Divider()
                
                // All badges section
                ScrollView {
                    badgeSelectionContent
                }
            }
            .padding(.top)
            .navigationTitle("Edit Showcase")
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
                    .disabled(isLoading)
                }
            }
            .overlay(alignment: .bottom) {
                saveButtonOverlay
            }
            .onAppear {
                // Initialize with currently showcased badges
                selectedBadges = badgeService.showcasedBadges
            }
        }
    }
    
    // Badge selection content - extracted to avoid complex expressions
    private var badgeSelectionContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Select up to 3 badges to showcase")
                .font(.headline)
                .foregroundColor(.theme.text)
                .padding(.horizontal)
            
            badgeCategoriesContent
            
            emptyStateIfNeeded
        }
        .padding(.bottom, 100)
    }
    
    // Badge categories - extracted to simplify
    private var badgeCategoriesContent: some View {
        ForEach(BadgeCategory.allCases, id: \.self) { category in
            let categoryBadges = badgeService.badges.filter { 
                $0.category == category && $0.isUnlocked 
            }
            
            if !categoryBadges.isEmpty {
                badgeCategorySection(category: category, badges: categoryBadges)
                
                Divider()
                    .padding(.vertical, 8)
            }
        }
    }
    
    // Individual category section - further broken down
    private func badgeCategorySection(category: BadgeCategory, badges: [Badge]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Category header
            HStack {
                Image(systemName: category.icon)
                    .foregroundColor(category.color)
                
                Text(category.rawValue)
                    .font(.headline)
                    .foregroundColor(.theme.text)
            }
            .padding(.horizontal)
            
            // Badges in this category - completely redesigned
            BadgeSelectionGrid(
                badges: badges,
                selectedBadges: $selectedBadges,
                maxSelection: 3
            )
        }
    }
    
    // Empty state - extracted to simplify
    private var emptyStateIfNeeded: some View {
        Group {
            if badgeService.badges.filter({ $0.isUnlocked }).isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.theme.subtext.opacity(0.7))
                    
                    Text("No badges unlocked yet")
                        .font(.headline)
                        .foregroundColor(.theme.text)
                    
                    Text("Complete challenges to earn badges")
                        .font(.subheadline)
                        .foregroundColor(.theme.subtext)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity)
            }
        }
    }
    
    // Save button overlay - extracted to simplify
    private var saveButtonOverlay: some View {
        VStack {
            Button(action: saveShowcasedBadges) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                            .padding(.trailing, 8)
                    } else {
                        Image(systemName: "checkmark")
                    }
                    Text("Save Showcase")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.theme.accent)
                .cornerRadius(10)
                .padding(.horizontal)
                .shadow(
                    color: Color.theme.shadow.opacity(colorScheme == .dark ? 0.3 : 0.1), 
                    radius: 5, 
                    x: 0, 
                    y: 2
                )
            }
            .disabled(isLoading)
            .padding(.bottom)
        }
        .background(
            Rectangle()
                .fill(Color.theme.background.opacity(0.95))
                .edgesIgnoringSafeArea(.bottom)
                .frame(height: 100)
                .shadow(color: Color.theme.shadow.opacity(0.05), radius: 5, x: 0, y: -3)
        )
    }
    
    // Preview of selected badges
    private var selectedBadgesPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your Showcase")
                .font(.headline)
                .foregroundColor(.theme.text)
            
            HStack(spacing: 16) {
                selectedBadgesContent
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.theme.surface)
                    .shadow(
                        color: Color.theme.shadow.opacity(colorScheme == .dark ? 0.3 : 0.1), 
                        radius: 4, 
                        x: 0, 
                        y: 2
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.theme.border.opacity(colorScheme == .dark ? 0.3 : 0.2), lineWidth: 1)
            )
        }
        .padding(.horizontal)
    }
    
    // Selected badges content - extracted to simplify
    private var selectedBadgesContent: some View {
        Group {
            // Show selected badges
            ForEach(selectedBadges) { badge in
                BadgeShowcaseItem(badge: badge) {
                    // Remove from selection when tapped
                    removeSelectedBadge(badge)
                }
            }
            
            // Empty slots
            if selectedBadges.count < 3 {
                ForEach(0..<(3 - selectedBadges.count), id: \.self) { _ in
                    emptyBadgeSlot
                }
            }
        }
    }
    
    // Empty slot in selection - extracted to simplify
    private var emptyBadgeSlot: some View {
        ZStack {
            Circle()
                .fill(Color.theme.background)
                .frame(width: 70, height: 70)
            
            Circle()
                .strokeBorder(Color.theme.border.opacity(colorScheme == .dark ? 0.5 : 0.3), lineWidth: 1)
                .frame(width: 70, height: 70)
            
            Text("Select")
                .font(.system(size: 12))
                .foregroundColor(.theme.subtext)
        }
        .frame(maxWidth: .infinity)
    }
    
    // Helper method to remove a badge from selection
    private func removeSelectedBadge(_ badge: Badge) {
        if let index = selectedBadges.firstIndex(where: { $0.id == badge.id }) {
            selectedBadges.remove(at: index)
        }
    }
    
    // Save selected badges
    private func saveShowcasedBadges() {
        isLoading = true
        
        // First, unset all current showcased badges
        let currentShowcased = badgeService.showcasedBadges
        
        Task {
            // Unset all current showcased badges
            for badge in currentShowcased {
                await badgeService.setShowcasedBadge(badgeId: badge.id, isShowcased: false)
            }
            
            // Set new showcased badges
            for badge in selectedBadges {
                await badgeService.setShowcasedBadge(badgeId: badge.id, isShowcased: true)
            }
            
            await MainActor.run {
                isLoading = false
                withAnimation {
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Badge Selection Grid Components

/// Badge selection grid with checkmark indicators - completely reimplemented
struct BadgeSelectionGrid: View {
    let badges: [Badge]
    @Binding var selectedBadges: [Badge]
    let maxSelection: Int
    
    // Create fixed grid layout
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        // Simplified implementation to avoid compiler issues
        LazyVGrid(columns: columns, spacing: 16) {
            // Use ForEach with direct ID to simplify
            ForEach(badges) { badge in
                // Create simple badge selection item
                simpleBadgeSelectionItem(badge)
            }
        }
        .padding(.horizontal)
    }
    
    // Helper method to create a badge selection item
    private func simpleBadgeSelectionItem(_ badge: Badge) -> some View {
        let isSelected = selectedBadges.contains { $0.id == badge.id }
        
        return BadgeSelectionItemSimplified(
            badge: badge,
            isSelected: isSelected,
            onTap: {
                toggleBadgeSelection(badge)
            }
        )
    }
    
    // Toggle badge selection
    private func toggleBadgeSelection(_ badge: Badge) {
        if let index = selectedBadges.firstIndex(where: { $0.id == badge.id }) {
            // Deselect
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedBadges.remove(at: index)
            }
        } else if selectedBadges.count < maxSelection {
            // Select if under max limit
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedBadges.append(badge)
            }
        } else {
            // Provide haptic feedback if max limit reached
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }
    }
}

// Simplified badge selection item to avoid compiler complexity
struct BadgeSelectionItemSimplified: View {
    let badge: Badge
    let isSelected: Bool
    let onTap: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: onTap) {
            // Much simpler implementation
            VStack(spacing: 4) {
                // Badge icon
                ZStack {
                    Circle()
                        .fill(backgroundColorForBadge)
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: badge.iconName)
                        .font(.system(size: 24))
                        .foregroundColor(iconColorForBadge)
                }
                
                // Badge name
                Text(badge.name)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.theme.text)
                    .lineLimit(1)
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.theme.accent)
                        .font(.system(size: 16))
                }
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.theme.accent.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // Simplified color calculations
    private var backgroundColorForBadge: Color {
        let opacity = colorScheme == .dark ? 0.25 : 0.15
        return badge.category.color.opacity(opacity)
    }
    
    private var iconColorForBadge: Color {
        let opacity = colorScheme == .dark ? 0.9 : 1.0
        return badge.category.color.opacity(opacity)
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
