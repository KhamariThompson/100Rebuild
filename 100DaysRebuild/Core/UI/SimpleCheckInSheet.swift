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
    @State private var selectedImage: UIImage?
    @State private var showingPhotoOptions = false
    @State private var showingCamera = false
    @State private var showUpgradePrompt = false
    @State private var showingSuccessAnimation = false
    @State private var isLoadingImage = false
    
    @EnvironmentObject var subscriptionService: SubscriptionService
    @Environment(\.colorScheme) private var colorScheme
    
    // Photo limit based on subscription status
    private var photoLimit: Int {
        subscriptionService.isProUser ? 3 : 1
    }
    
    private var photosRemaining: Int {
        photoLimit - (selectedImage != nil ? 1 : 0)
    }
    
    // Check if user has provided required input to enable check-in
    private var hasRequiredInput: Bool {
        !journalText.isEmpty || selectedImage != nil
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
        
        // Pre-initialize for faster loading
        _isLoadingImage = State(initialValue: false)
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Blurred background overlay
            Color.black.opacity(0.4)
                .blur(radius: 1)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }
            
            // Main floating card
            VStack(spacing: AppSpacing.m) {
                // Header
                headerSection
                
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
                    
                    // Glowing border effect
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.theme.accent, lineWidth: 1.5)
                        .blur(radius: 3)
                        .opacity(0.7)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: UUID())
                }
            )
            .frame(maxWidth: UIScreen.main.bounds.width * 0.85)
            .frame(maxHeight: UIScreen.main.bounds.height * 0.5)
            .shadow(color: Color.theme.accent.opacity(0.2), radius: 15, x: 0, y: 0)
            
            // Success animation overlay
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
                .transition(.scale.combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showingCamera) {
            CameraImagePicker(selectedImage: $selectedImage)
        }
        .onAppear {
            // Ensure the UI is ready immediately by pre-rendering key components
            DispatchQueue.main.async {
                // Immediately set focus to journal text field to indicate interactivity
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isJournalFocused = true
                }
                
                // Prepare haptic feedback engine in advance
                let _ = UIImpactFeedbackGenerator(style: .medium)
            }
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
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
            
            if let selectedImage = selectedImage {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 120)
                        .cornerRadius(12)
                    
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
            } else if isLoadingImage {
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
            } else {
                Button {
                    if photosRemaining > 0 {
                        showingPhotoOptions = true
                    } else {
                        showUpgradePrompt = true
                    }
                } label: {
                    HStack {
                        Image(systemName: "photo")
                            .font(.system(size: 16))
                        Text("Choose Photo")
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
                        showingCamera = true
                    }
                    
                    PhotosPicker(
                        selection: $photoItem,
                        matching: .images
                    ) {
                        Text("Choose from Library")
                    }
                }
                .alert("Upgrade to Pro", isPresented: $showUpgradePrompt) {
                    Button("Not Now", role: .cancel) { }
                    Button("Upgrade") {
                        subscriptionService.presentSubscriptionSheet()
                    }
                } message: {
                    Text("Pro users can add up to 3 photos per check-in. Upgrade to unlock this feature!")
                }
            }
        }
        .onChange(of: photoItem) { newValue in
            if newValue != nil {
                isLoadingImage = true
                
                // Use Task.detached to ensure this runs in the background with high priority
                Task.detached(priority: .userInitiated) {
                    if let photoItem = newValue {
                        do {
                            // Load transferable data directly
                            let data = try await photoItem.loadTransferable(type: Data.self)
                            
                            if let data = data, let image = UIImage(data: data) {
                                // Process on background thread before updating UI
                                let processedImage = await processImage(image)
                                
                                // Update UI on main thread
                                await MainActor.run {
                                    selectedImage = processedImage
                                    isLoadingImage = false
                                }
                            } else {
                                await MainActor.run {
                                    isLoadingImage = false
                                }
                            }
                        } catch {
                            print("Error loading image: \(error.localizedDescription)")
                            await MainActor.run {
                                isLoadingImage = false
                            }
                        }
                    } else {
                        await MainActor.run {
                            isLoadingImage = false
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
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Show success animation
        withAnimation(.spring()) {
            showingSuccessAnimation = true
        }
        
        // Delay to show animation before dismissing
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            // Only complete the check-in if user has provided required input
            if self.hasRequiredInput {
                onCheckIn(journalText, selectedImage)
            }
        }
    }
}

// MARK: - Camera Image Picker
struct CameraImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    
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
                parent.selectedImage = image
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
            .environmentObject(SubscriptionService.shared)
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