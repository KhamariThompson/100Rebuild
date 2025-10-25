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

    // Photo limit based on subscription status
    private var photoLimit: Int {
        entitlementsAdapter.hasProAccess ? 3 : 1
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
            // Blurred background overlay - removing blur for better performance
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissKeyboard()
                    onDismiss()
                }
            
            // Main floating card
            VStack(spacing: AppSpacing.m) {
                // Header with done button and close button
                HStack {
                    headerSection
                    
                    Spacer()
                    
                    // X button to close the sheet
                    Button(action: {
                        dismissKeyboard()
                        onDismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.theme.subtext)
                    }
                    .buttonStyle(AppScaleButtonStyle())
                }
                
                // Journal
                journalSection
                
                // Photo
                photoSection
                
                // Check-in button
                checkInButtonSection
            }
            .padding(AppSpacing.l)
            .background(
                ZStack {
                    // Background fill
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.theme.background)
                    
                    // Simplified border without blur for better performance
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.theme.accent, lineWidth: 1.5)
                }
            )
            .frame(maxWidth: UIScreen.main.bounds.width * 0.85)
            .frame(maxHeight: UIScreen.main.bounds.height * 0.5)
            
            // Success animation overlay - simplified
            if showingSuccessAnimation {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 70))
                        .foregroundColor(.theme.accent)
                    
                    Text("Check-In Saved!")
                        .font(.title2)
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
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text("Day \(dayNumber) of 100")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.theme.accent)
            
            Text(challenge.title)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.theme.text)
            
            HStack(spacing: AppSpacing.s) {
                HStack(spacing: 4) {
                    Text("🔥")
                        .font(.system(size: 14))
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
                    Text("Write your thoughts...")
                        .font(.subheadline)
                        .foregroundColor(.theme.subtext.opacity(0.7))
                        .padding(.top, 8)
                        .padding(.leading, 4)
                }
                
                TextEditor(text: $journalText)
                    .font(.body)
                    .foregroundColor(.theme.text)
                    .frame(height: 80)
                    .focused($isJournalFocused)
                    .opacity(journalText.isEmpty ? 0.25 : 1)
                    .cornerRadius(8)
                    .scrollContentBackground(.hidden)
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") {
                                dismissKeyboard()
                            }
                        }
                    }
            }
            .padding(AppSpacing.s)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.theme.surface.opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.theme.border, lineWidth: 1)
                    )
            )
        }
    }
    
    private var photoSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            HStack {
                Image(systemName: "camera")
                    .foregroundColor(.theme.accent)
                    
                Spacer()
                
                Text("Photos remaining: \(photosRemaining)/\(photoLimit)")
                    .font(.caption)
                    .foregroundColor(.theme.subtext)
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
                                        .font(.system(size: 22))
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
                    HStack {
                        Image(systemName: "photo")
                            .font(.system(size: 16))
                        Text("Add Photo")
                            .font(.subheadline)
                    }
                    .foregroundColor(.theme.accent)
                    .padding(.vertical, AppSpacing.s)
                    .padding(.horizontal, AppSpacing.m)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.theme.accent, lineWidth: 1)
                    )
                }
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
            } else if !entitlementsAdapter.hasProAccess && selectedImages.count >= 1 {
                // Upgrade prompt for non-Pro users who hit the limit
                Button {
                    showUpgradePrompt = true
                } label: {
                    HStack {
                        Image(systemName: "crown")
                            .font(.system(size: 16))
                        Text("Upgrade to Add More Photos")
                            .font(.subheadline)
                    }
                    .foregroundColor(.yellow)
                    .padding(.vertical, AppSpacing.s)
                    .padding(.horizontal, AppSpacing.m)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.yellow, lineWidth: 1)
                    )
                }
                .alert("Upgrade to Pro", isPresented: $showUpgradePrompt) {
                    Button("Not Now", role: .cancel) { }
                    Button("Upgrade") {
                        // TODO: Trigger paywall via navigation
                    }
                } message: {
                    Text("Pro users can add up to 3 photos per check-in. Upgrade to unlock this feature!")
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
        
        // Ensure we're not on the main thread for heavy image processing
        if Thread.isMainThread {
            return await Task.detached(priority: .userInitiated) { 
                let renderer = UIGraphicsImageRenderer(size: scaledSize)
                return renderer.image { _ in
                    image.draw(in: CGRect(origin: .zero, size: scaledSize))
                }
            }.value
        } else {
            // Already on a background thread, proceed directly
            let renderer = UIGraphicsImageRenderer(size: scaledSize)
            return renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: scaledSize))
            }
        }
    }
    
    private var checkInButtonSection: some View {
        Button {
            // Dismiss keyboard before handling check-in
            dismissKeyboard()
            handleCheckIn()
        } label: {
            Text("Complete Check-In")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(colorScheme == .dark ? .black : .white)
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