import SwiftUI
import PhotosUI
import UIKit

/// A modern floating modal check-in sheet with glowing effect
struct SimpleCheckInSheet: View {
    // MARK: - Properties
    
    let challenge: Challenge
    let dayNumber: Int
    
    var onCheckIn: (String, UIImage?) -> Void
    var onDismiss: () -> Void
    
    @State private var journalText: String = ""
    @FocusState private var isJournalFocused: Bool
    
    @State private var photoItem: PhotosPickerItem?
    @State private var selectedImages: [UIImage] = []
    @State private var showingPhotoOptions = false
    @State private var showingCamera = false
    @State private var showingPhotoLibrary = false
    @State private var showUpgradePrompt = false
    @State private var showingSuccessAnimation = false
    @State private var isLoadingImage = false
    
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var entitlementsAdapter: EntitlementsAdapter
    @Environment(\.colorScheme) private var colorScheme

    // Photo limit - everyone gets 1 photo per check-in
    private var photoLimit: Int {
        return 1
    }
    
    private var photosRemaining: Int {
        photoLimit - selectedImages.count
    }
    
    // Check if user has provided required input to enable check-in
    private var hasRequiredInput: Bool {
        // Always return true to make journal and photo optional
        return true
    }
    
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
        
        // Pre-initialize all states to avoid computations during view rendering
        _isLoadingImage = State(initialValue: false)
        _journalText = State(initialValue: "")
        _photoItem = State(initialValue: nil)
        _selectedImages = State(initialValue: [])
        _showingPhotoOptions = State(initialValue: false)
        _showingCamera = State(initialValue: false)
        _showingPhotoLibrary = State(initialValue: false)
        _showUpgradePrompt = State(initialValue: false)
        _showingSuccessAnimation = State(initialValue: false)
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Beautiful backdrop blur
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissKeyboard()
                    onDismiss()
                }

            // Main floating card with premium design
            VStack(spacing: 0) {
                // Enhanced header section
                VStack(spacing: 12) {
                    HStack {
                        Spacer()

                        // Close button
                        Button(action: {
                            dismissKeyboard()
                            onDismiss()
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.theme.surface.opacity(0.8))
                                    .frame(width: 32, height: 32)

                                Image(systemName: "xmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.theme.subtext)
                            }
                        }
                        .buttonStyle(AppScaleButtonStyle())
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                    headerSection
                        .padding(.horizontal, 24)
                }
                .padding(.bottom, 24)
                .background(
                    LinearGradient(
                        colors: [
                            Color.theme.accent.opacity(0.08),
                            Color.theme.background.opacity(0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Journal
                        journalSection

                        // Photo
                        photoSection
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                }

                // Check-in button - fixed at bottom
                VStack(spacing: 0) {
                    Divider()
                        .background(Color.theme.border.opacity(0.2))

                    checkInButtonSection
                        .padding(.horizontal, 24)
                        .padding(.vertical, 20)
                }
                .background(Color.theme.background.opacity(0.98))
            }
            .frame(maxWidth: min(420, UIScreen.main.bounds.width * 0.92))
            .frame(maxHeight: min(680, UIScreen.main.bounds.height * 0.85))
            .background(
                ZStack {
                    // Premium card background
                    RoundedRectangle(cornerRadius: 28)
                        .fill(Color.theme.background)

                    // Accent border glow
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.theme.accent.opacity(0.3),
                                    Color.theme.accent.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                }
                .shadow(color: Color.theme.accent.opacity(0.15), radius: 30, x: 0, y: 15)
                .shadow(color: Color.black.opacity(0.2), radius: 15, x: 0, y: 8)
            )
            .clipShape(RoundedRectangle(cornerRadius: 28))
            
            // Success animation overlay - simplified
            if showingSuccessAnimation {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(AppTypography.display())
                        .foregroundColor(.theme.accent)
                    
                    Text("Check-In Saved!")
                        .font(AppTypography.title2())
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }
        }
        // Add camera presentation sheet
        .sheet(isPresented: $showingCamera) {
            CameraImagePicker(selectedImages: .init(get: { self.selectedImages }, set: { newImages in
                if let images = newImages, !images.isEmpty {
                    self.selectedImages = images
                }
            }))
        }
        // Use separate state variable for photo library picker
        .photosPicker(isPresented: $showingPhotoLibrary, selection: $photoItem, matching: .images, photoLibrary: .shared())
        .onAppear {
            print("Sheet onAppear at \(Date())")
            
            // Don't focus initially to avoid keyboard automatically appearing
            // The user can tap on the text field when they're ready to type
            isJournalFocused = false
        }
    }
    
    // MARK: - Helper Functions
    
    private func dismissKeyboard() {
        isJournalFocused = false
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Day badge
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.theme.accent, Color.theme.accent.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)

                    Text("\(dayNumber)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Day \(dayNumber) of 100")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.theme.accent)

                    Text("\(Int(challenge.progressPercentage * 100))% Complete")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.theme.subtext)
                }

                Spacer()
            }

            // Challenge title
            Text(challenge.title)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(.theme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(2)

            // Streak info
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Text("🔥")
                        .font(.system(size: 18))
                    Text("\(challenge.streakCount) day streak")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.theme.text)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.theme.accent.opacity(0.12))
                )

                Spacer()
            }
        }
    }
    
    private var journalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.theme.accent.opacity(0.15))
                        .frame(width: 32, height: 32)

                    Image(systemName: "pencil.line")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.theme.accent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Journal Entry")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.theme.text)

                    Text("Optional - Capture your thoughts")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.theme.subtext)
                }
            }

            ZStack(alignment: .topLeading) {
                if journalText.isEmpty {
                    Text("How did it go today? Any insights or reflections...")
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundColor(.theme.subtext.opacity(0.6))
                        .padding(.top, 12)
                        .padding(.leading, 16)
                        .padding(.trailing, 16)
                }

                TextEditor(text: $journalText)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(.theme.text)
                    .frame(height: 100)
                    .focused($isJournalFocused)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button {
                                dismissKeyboard()
                            } label: {
                                Text("Done")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(.theme.accent)
                            }
                        }
                    }
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isJournalFocused ? Color.theme.accent.opacity(0.4) : Color.theme.border.opacity(0.3),
                                lineWidth: isJournalFocused ? 2 : 1
                            )
                    )
            )
        }
    }
    
    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.theme.accent.opacity(0.15))
                        .frame(width: 32, height: 32)

                    Image(systemName: "camera.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.theme.accent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Add Photo")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.theme.text)

                    Text("Optional - Capture your progress")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.theme.subtext)
                }

                Spacer()

                if photosRemaining < photoLimit {
                    Text("\(selectedImages.count)/\(photoLimit)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.theme.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.theme.accent.opacity(0.12))
                        )
                }
            }
            
            // Display selected images
            if !selectedImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(0..<selectedImages.count, id: \.self) { index in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: selectedImages[index])
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 120)
                                    .cornerRadius(12)
                                
                                Button {
                                    // Remove this specific image
                                    selectedImages.remove(at: index)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(AppTypography.title2())
                                        .foregroundColor(.theme.accent)
                                        .background(Circle().fill(Color.white))
                                }
                                .padding(AppSpacing.xs)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            
            if isLoadingImage {
                // Show loading indicator when image is loading
                HStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(.theme.accent)
                    Spacer()
                }
                .frame(height: 80)
                .frame(maxWidth: .infinity)
                .background(Color.theme.surface.opacity(0.5))
                .cornerRadius(12)
            }
            
            // Add Photo button - only show if photos remaining
            if photosRemaining > 0 {
                Button {
                    // Show photo options using proper SwiftUI confirmationDialog
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()

                    // Show the confirmation dialog
                    showingPhotoOptions = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Choose Photo")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.theme.accent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.theme.accent.opacity(0.4), lineWidth: 1.5)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.theme.accent.opacity(0.06))
                            )
                    )
                }
                .buttonStyle(AppScaleButtonStyle())
                .confirmationDialog("Add Photo", isPresented: $showingPhotoOptions) {
                    Button("Take Photo") {
                        // Use a slight delay to avoid animation conflicts
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            self.showingCamera = true
                        }
                    }
                    
                    Button("Choose from Library") {
                        // Use a slight delay to avoid animation conflicts
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            // Create a new PhotosPicker presentation using the dedicated state variable
                            self.photoItem = nil  // Reset any previous selection
                            self.showingPhotoLibrary = true // Use separate state variable
                        }
                    }
                }
            }
        }
        // Add PhotosPicker as a view modifier for better reliability
        .onChange(of: photoItem) { newValue in
            if newValue != nil {
                isLoadingImage = true
                
                // Process the image selection with better error handling
                Task {
                    do {
                        if let photoItem = newValue, 
                           let imageData = try? await photoItem.loadTransferable(type: Data.self),
                           let image = UIImage(data: imageData) {
                            
                            // Process on background thread before updating UI
                            let processedImage = await processImage(image)
                            
                            // Update UI on main thread
                            await MainActor.run {
                                self.selectedImages.append(processedImage)
                                self.isLoadingImage = false
                            }
                        } else {
                            print("Failed to load image from photo library")
                            await MainActor.run {
                                self.isLoadingImage = false
                            }
                        }
                    } catch {
                        print("Error loading image: \(error.localizedDescription)")
                        await MainActor.run {
                            self.isLoadingImage = false
                        }
                    }
                }
            }
        }
    }
    
    // Process image on background thread to avoid UI blocking
    private func processImage(_ image: UIImage) async -> UIImage {
        // Resize and compress the image for better performance
        let targetSize = CGSize(width: 1200, height: 1200)

        // If image is already small enough, return it as is
        if image.size.width <= targetSize.width && image.size.height <= targetSize.height {
            return image
        }

        // Calculate new size maintaining aspect ratio
        let widthRatio = targetSize.width / image.size.width
        let heightRatio = targetSize.height / image.size.height
        let scaleFactor = min(widthRatio, heightRatio)
        let scaledSize = CGSize(width: image.size.width * scaleFactor, height: image.size.height * scaleFactor)

        // Perform image processing on a detached task (background thread)
        return await Task.detached(priority: .userInitiated) {
            let renderer = UIGraphicsImageRenderer(size: scaledSize)
            return renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: scaledSize))
            }
        }.value
    }
    
    private var checkInButtonSection: some View {
        Button {
            // Dismiss keyboard before handling check-in
            dismissKeyboard()
            handleCheckIn()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20, weight: .bold))

                Text("Complete Check-In")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                ZStack {
                    LinearGradient(
                        colors: [Color.theme.accent, Color.theme.accent.opacity(0.85)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )

                    // Subtle shine effect
                    LinearGradient(
                        colors: [Color.white.opacity(0.2), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.theme.accent.opacity(0.4), radius: 12, x: 0, y: 6)
            .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
        }
        .disabled(!hasRequiredInput)
        .opacity(hasRequiredInput ? 1.0 : 0.6)
        .buttonStyle(AppScaleButtonStyle())
    }
    
    // MARK: - Helper Methods
    
    private func handleCheckIn() {
        // Don't allow check-in without valid input
        guard hasRequiredInput else { return }
        
        // Provide immediate haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Call onCheckIn immediately with current values - using first image for backward compatibility
        onCheckIn(self.journalText, selectedImages.first)
    }
}

// MARK: - Camera Image Picker
struct CameraImagePicker: UIViewControllerRepresentable {
    // Binding to modify selected image
    @Binding var selectedImage: UIImage?
    @Binding var selectedImages: [UIImage]?
    
    init(selectedImage: Binding<UIImage?>) {
        self._selectedImage = selectedImage
        self._selectedImages = .constant(nil)
    }
    
    init(selectedImages: Binding<[UIImage]?>) {
        self._selectedImages = selectedImages
        self._selectedImage = .constant(nil)
    }
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraImagePicker

        init(_ parent: CameraImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                // Update the appropriate binding
                if parent.selectedImage != nil {
                    parent.selectedImage = image
                } else if parent.selectedImages != nil {
                    parent.selectedImages?.append(image)
                }
            }
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Preview
struct SimpleCheckInSheet_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
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
            .environmentObject(SubscriptionStore.shared)
            .environmentObject(EntitlementsAdapter.shared)
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