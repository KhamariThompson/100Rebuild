import SwiftUI
import PhotosUI

/// A simplified check-in sheet that appears as a bottom sheet with basic UI
struct SimpleCheckInSheet: View {
    // MARK: - Properties
    
    let challenge: Challenge
    let dayNumber: Int
    
    var onCheckIn: (String, UIImage?) -> Void
    var onDismiss: () -> Void
    
    @State private var journalText: String = ""
    @FocusState private var isJournalFocused: Bool
    
    @State private var photoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    
    // MARK: - Initialization
    
    init(
        challenge: Challenge,
        dayNumber: Int,
        onCheckIn: @escaping (String, UIImage?) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.challenge = challenge
        self.dayNumber = dayNumber
        self.onCheckIn = onCheckIn
        self.onDismiss = onDismiss
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 12)
            
            ScrollView {
                VStack(spacing: AppSpacing.l) {
                    // Header
                    headerSection
                        .padding(.horizontal, AppSpacing.m)
                    
                    // Journal
                    journalSection
                        .padding(.horizontal, AppSpacing.m)
                    
                    // Photo
                    photoSection
                        .padding(.horizontal, AppSpacing.m)
                    
                    // Check-in button
                    checkInButtonSection
                        .padding(.horizontal, AppSpacing.m)
                        .padding(.bottom, AppSpacing.l)
                }
                .padding(.top, AppSpacing.s)
            }
        }
        .padding(.bottom, 8)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.theme.background)
                .ignoresSafeArea()
        )
        .onAppear {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Day \(dayNumber) of 100")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.theme.accent)
            
            Text(challenge.title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.theme.text)
            
            HStack(spacing: AppSpacing.s) {
                HStack(spacing: 4) {
                    Text("🔥")
                        .font(.system(size: 16))
                    Text("\(challenge.streakCount) day streak")
                        .font(.subheadline)
                        .foregroundColor(.theme.subtext)
                }
                
                Spacer()
                
                Text("\(Int(challenge.progressPercentage * 100))% complete")
                    .font(.subheadline)
                    .foregroundColor(.theme.accent)
            }
            .padding(.top, AppSpacing.xxs)
        }
    }
    
    private var journalSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            HStack {
                Image(systemName: "pencil.line")
                    .foregroundColor(.theme.accent)
                Text("Journal Entry")
                    .font(.headline)
                    .foregroundColor(.theme.text)
            }
            
            ZStack(alignment: .topLeading) {
                if journalText.isEmpty {
                    Text("How did today's session go? (Optional)")
                        .font(.subheadline)
                        .foregroundColor(.theme.subtext.opacity(0.7))
                        .padding(.top, 8)
                        .padding(.leading, 4)
                }
                
                TextEditor(text: $journalText)
                    .font(.body)
                    .foregroundColor(.theme.text)
                    .frame(minHeight: 100)
                    .focused($isJournalFocused)
                    .opacity(journalText.isEmpty ? 0.25 : 1)
                    .cornerRadius(8)
            }
            .padding(AppSpacing.s)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.theme.border, lineWidth: 1)
            )
        }
    }
    
    private var photoSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            HStack {
                Image(systemName: "camera")
                    .foregroundColor(.theme.accent)
                Text("Add Photo")
                    .font(.headline)
                    .foregroundColor(.theme.text)
            }
            
            if let selectedImage = selectedImage {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .cornerRadius(AppSpacing.cardCornerRadius)
                    
                    Button {
                        self.selectedImage = nil
                        self.photoItem = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.theme.accent)
                            .background(Circle().fill(Color.white))
                    }
                    .padding(AppSpacing.xs)
                }
            } else {
                PhotosPicker(
                    selection: $photoItem,
                    matching: .images
                ) {
                    HStack {
                        Image(systemName: "photo")
                            .font(.system(size: 18))
                        Text("Choose Photo")
                            .font(.subheadline)
                    }
                    .foregroundColor(.theme.accent)
                    .padding(.vertical, AppSpacing.s)
                    .padding(.horizontal, AppSpacing.m)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.theme.accent, lineWidth: 1)
                    )
                }
                .onChange(of: photoItem) { oldValue, newValue in
                    Task {
                        if let data = try? await newValue?.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            selectedImage = image
                        }
                    }
                }
            }
        }
    }
    
    private var checkInButtonSection: some View {
        Button {
            handleCheckIn()
        } label: {
            Text("Complete Check-In")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.m)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.theme.accent, Color.theme.accent.opacity(0.8)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: Color.theme.accent.opacity(0.3), radius: 8, x: 0, y: 4)
                )
        }
        .buttonStyle(AppScaleButtonStyle())
    }
    
    // MARK: - Helper Methods
    
    private func handleCheckIn() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        onCheckIn(journalText, selectedImage)
    }
}

// MARK: - Preview
struct SimpleCheckInSheet_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                SimpleCheckInSheet(
                    challenge: Challenge.mock(
                        title: "Read 10 pages",
                        daysCompleted: 24, 
                        streakCount: 7
                    ),
                    dayNumber: 25,
                    onCheckIn: { _, _ in },
                    onDismiss: {}
                )
            }
        }
        .preferredColorScheme(.dark)
    }
}

// Helper for preview
extension Challenge {
    static func mock(title: String, daysCompleted: Int, streakCount: Int) -> Challenge {
        Challenge(
            id: UUID(),
            title: title,
            startDate: Date().addingTimeInterval(-Double(daysCompleted) * 86400),
            lastCheckInDate: Date().addingTimeInterval(-86400),
            streakCount: streakCount,
            daysCompleted: daysCompleted,
            isCompletedToday: false,
            isArchived: false,
            ownerId: "preview-user",
            lastModified: Date(),
            isTimed: false
        )
    }
} 