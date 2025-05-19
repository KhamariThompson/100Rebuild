import SwiftUI
import Firebase
import PhotosUI
import Foundation

struct CheckInDetailModalView: View {
    @ObservedObject var viewModel: CheckInHistoryViewModel
    let checkIn: Models_CheckInRecord
    let challengeTitle: String
    
    @Environment(\.dismiss) private var dismiss
    @State private var editedNote: String
    @State private var isEditingNote = false
    @State private var isSharingCard = false
    @State private var showingActionSheet = false
    @State private var showingPhotosPicker = false
    @State private var selectedImageData: Data?
    @State private var selectedImage: UIImage?
    @State private var isZoomingPhoto = false
    @State private var showPhotoOptions = false
    
    // Photo picker
    @State private var photoItem: PhotosPickerItem?
    
    // Animation states
    @State private var animateContent = false
    
    init(viewModel: CheckInHistoryViewModel, checkIn: Models_CheckInRecord, challengeTitle: String) {
        self.viewModel = viewModel
        self.checkIn = checkIn
        self.challengeTitle = challengeTitle
        self._editedNote = State(initialValue: checkIn.note ?? "")
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header with day number and date
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Day \(checkIn.dayNumber)")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.theme.accent)
                        
                        Text(checkIn.date, style: .date)
                            .font(.headline)
                            .foregroundColor(.theme.subtext)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .offset(y: animateContent ? 0 : -20)
                    .opacity(animateContent ? 1 : 0)
                    
                    // Photo if available
                    if checkIn.photoURL != nil || selectedImage != nil {
                        ZStack {
                            if let selectedImage = selectedImage {
                                Image(uiImage: selectedImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: .infinity)
                                    .cornerRadius(16)
                                    .onTapGesture {
                                        isZoomingPhoto = true
                                    }
                            } else {
                                AsyncImage(url: checkIn.photoURL) { phase in
                                    switch phase {
                                    case .empty:
                                        Rectangle()
                                            .fill(Color.theme.surface)
                                            .overlay(ProgressView())
                                            .frame(height: 240)
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFit()
                                            .frame(maxWidth: .infinity)
                                            .onTapGesture {
                                                isZoomingPhoto = true
                                            }
                                    case .failure:
                                        Rectangle()
                                            .fill(Color.theme.surface)
                                            .overlay(
                                                Image(systemName: "photo.fill")
                                                    .foregroundColor(.theme.subtext.opacity(0.5))
                                            )
                                            .frame(height: 240)
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                                .cornerRadius(16)
                            }
                            
                            // Photo edit button
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    
                                    Button(action: {
                                        showPhotoOptions = true
                                    }) {
                                        Image(systemName: "pencil.circle.fill")
                                            .font(.title)
                                            .foregroundColor(.theme.accent)
                                            .background(
                                                Circle()
                                                    .fill(Color.white)
                                                    .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                                            )
                                    }
                                    .padding(12)
                                }
                            }
                        }
                        .offset(y: animateContent ? 0 : 20)
                        .opacity(animateContent ? 1 : 0)
                    } else {
                        // No photo, show add photo button
                        Button(action: {
                            showingPhotosPicker = true
                        }) {
                            HStack {
                                Image(systemName: "photo.badge.plus")
                                Text("Add Photo")
                            }
                            .font(.headline)
                            .foregroundColor(.theme.accent)
                            .padding(.vertical, 16)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.theme.accent, lineWidth: 1.5)
                                    .background(Color.theme.surface.cornerRadius(12))
                            )
                        }
                        .offset(y: animateContent ? 0 : 20)
                        .opacity(animateContent ? 1 : 0)
                    }
                    
                    // Prompt if available
                    if let prompt = checkIn.promptShown {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Reflection Prompt")
                                .font(.headline)
                                .foregroundColor(.theme.text)
                            
                            Text(prompt)
                                .font(.subheadline)
                                .foregroundColor(.theme.accent)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.theme.accent.opacity(0.1))
                                )
                        }
                        .offset(y: animateContent ? 0 : 20)
                        .opacity(animateContent ? 1 : 0)
                    }
                    
                    // Notes section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Note")
                                .font(.headline)
                                .foregroundColor(.theme.text)
                            
                            Spacer()
                            
                            Button(action: {
                                isEditingNote.toggle()
                            }) {
                                Text(isEditingNote ? "Save" : "Edit")
                                    .font(.subheadline)
                                    .foregroundColor(.theme.accent)
                            }
                        }
                        
                        if isEditingNote {
                            TextEditor(text: $editedNote)
                                .frame(minHeight: 120)
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.theme.accent.opacity(0.3), lineWidth: 1)
                                )
                                .padding(.top, 4)
                                .onChange(of: editedNote) { oldValue, newValue in
                                    // Auto-save if needed
                                }
                        } else {
                            Text(checkIn.note ?? "No note added for this day")
                                .foregroundColor(checkIn.note == nil ? .theme.subtext : .theme.text)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.theme.surface)
                                )
                        }
                    }
                    .offset(y: animateContent ? 0 : 20)
                    .opacity(animateContent ? 1 : 0)
                    
                    // Quote
                    if let quote = checkIn.quote {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Daily Quote")
                                .font(.headline)
                                .foregroundColor(.theme.text)
                            
                            VStack(spacing: 16) {
                                Text(quote.text)
                                    .font(.body)
                                    .italic()
                                    .foregroundColor(.theme.text)
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.horizontal)
                                
                                Text("— \(quote.author)")
                                    .font(.subheadline)
                                    .foregroundColor(.theme.subtext)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                    .padding(.trailing)
                            }
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.theme.surface)
                            )
                        }
                        .offset(y: animateContent ? 0 : 20)
                        .opacity(animateContent ? 1 : 0)
                    }
                    
                    // Share button
                    Button(action: {
                        isSharingCard = true
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share this check-in")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.theme.accent)
                                .shadow(color: Color.theme.accent.opacity(0.3), radius: 5, x: 0, y: 3)
                        )
                    }
                    .padding(.top, 8)
                    .offset(y: animateContent ? 0 : 20)
                    .opacity(animateContent ? 1 : 0)
                }
                .padding()
            }
            .navigationTitle("Check-In Details")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Close") { dismiss() },
                trailing: Button(action: {
                    showingActionSheet = true
                }) {
                    Image(systemName: "ellipsis")
                }
            )
            .photosPicker(isPresented: $showingPhotosPicker, selection: $photoItem, matching: .images)
            .onChange(of: photoItem) { oldValue, newValue in
                Task {
                    // Add a minimal sleep to ensure there's a suspension point
                    try? await Task.sleep(nanoseconds: 1_000_000) // 1 millisecond
                    
                    if let data = try? await newValue?.loadTransferable(type: Data.self) {
                        selectedImageData = data
                        if let uiImage = UIImage(data: data) {
                            selectedImage = uiImage
                            // Upload the image when selected
                            await viewModel.updateCheckInPhoto(for: checkIn, newPhoto: uiImage)
                        }
                    }
                }
            }
            .onChange(of: isEditingNote) { oldValue, newValue in
                if oldValue == true && newValue == false {
                    // Save the note when exiting edit mode
                    Task {
                        viewModel.updateCheckInNote(for: checkIn, newNote: editedNote)
                    }
                }
            }
            .confirmationDialog("Photo Options", isPresented: $showPhotoOptions, titleVisibility: .visible) {
                Button("View Full Size") {
                    isZoomingPhoto = true
                }
                Button("Replace Photo") {
                    showingPhotosPicker = true
                }
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog("Check-In Actions", isPresented: $showingActionSheet, titleVisibility: .visible) {
                Button("Edit Note") {
                    isEditingNote = true
                }
                Button("Add/Replace Photo") {
                    showingPhotosPicker = true
                }
                Button("Share Check-In") {
                    isSharingCard = true
                }
                Button("Cancel", role: .cancel) {}
            }
            .fullScreenCover(isPresented: $isZoomingPhoto) {
                ZStack {
                    Color.black.ignoresSafeArea()
                    
                    if let selectedImage = selectedImage {
                        Image(uiImage: selectedImage)
                            .resizable()
                            .scaledToFit()
                    } else if let photoURL = checkIn.photoURL {
                        AsyncImage(url: photoURL) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFit()
                            case .failure:
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.largeTitle)
                                    .foregroundColor(.white)
                            @unknown default:
                                EmptyView()
                            }
                        }
                    }
                    
                    VStack {
                        HStack {
                            Spacer()
                            
                            Button(action: {
                                isZoomingPhoto = false
                            }) {
                                Image(systemName: "xmark")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .background(
                                        Circle()
                                            .fill(Color.black.opacity(0.6))
                                    )
                            }
                            .padding()
                        }
                        
                        Spacer()
                    }
                }
                .statusBar(hidden: true)
            }
            .sheet(isPresented: $isSharingCard) {
                ShareCardView(
                    dayNumber: checkIn.dayNumber,
                    date: checkIn.date,
                    image: selectedImage,
                    imageURL: checkIn.photoURL,
                    note: checkIn.note,
                    quote: checkIn.quote,
                    challengeTitle: challengeTitle
                )
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.5)) {
                    animateContent = true
                }
            }
        }
    }
}

struct ShareCardView: View {
    let dayNumber: Int
    let date: Date
    let image: UIImage?
    let imageURL: URL?
    let note: String?
    let quote: Quote?
    let challengeTitle: String
    
    @Environment(\.dismiss) private var dismiss
    @State private var shareImage: UIImage?
    @State private var showingShareSheet = false
    
    var body: some View {
        NavigationView {
            VStack {
                ShareCard(
                    dayNumber: dayNumber,
                    date: date,
                    image: image,
                    imageURL: imageURL,
                    note: note,
                    quote: quote,
                    challengeTitle: challengeTitle
                )
                .padding()
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        generateShareImage()
                    }
                }
                
                Button(action: {
                    generateShareImage()
                    showingShareSheet = true
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.theme.accent)
                    )
                    .padding()
                }
            }
            .navigationTitle("Share Check-In")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading: Button("Cancel") { dismiss() })
            .sheet(isPresented: $showingShareSheet) {
                if let image = shareImage {
                    ShareSheet(items: [image])
                }
            }
        }
    }
    
    private func generateShareImage() {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1080, height: 1920))
        
        shareImage = renderer.image { context in
            // Draw the card as an image
            let viewController = UIHostingController(
                rootView: ShareCard(
                    dayNumber: dayNumber,
                    date: date,
                    image: image,
                    imageURL: imageURL,
                    note: note,
                    quote: quote,
                    challengeTitle: challengeTitle
                )
                .frame(width: 1080, height: 1920)
                .background(Color.theme.background)
            )
            
            viewController.view.frame = CGRect(x: 0, y: 0, width: 1080, height: 1920)
            viewController.view.drawHierarchy(in: viewController.view.bounds, afterScreenUpdates: true)
        }
    }
}

struct ShareCard: View {
    let dayNumber: Int
    let date: Date
    let image: UIImage?
    let imageURL: URL?
    let note: String?
    let quote: Quote?
    let challengeTitle: String
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Text("100 Days Challenge")
                    .font(.headline)
                    .foregroundColor(.theme.subtext)
                
                Text(challengeTitle)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.theme.text)
                    .multilineTextAlignment(.center)
            }
            
            // Day number
            Text("DAY \(dayNumber)")
                .font(.system(size: 64, weight: .black, design: .rounded))
                .foregroundColor(.theme.accent)
            
            // Date
            Text(date, style: .date)
                .font(.headline)
                .foregroundColor(.theme.subtext)
            
            // Photo if available
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
            } else if let imageURL = imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(Color.theme.surface)
                            .overlay(ProgressView())
                            .frame(height: 300)
                            .cornerRadius(16)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                    case .failure:
                        Rectangle()
                            .fill(Color.theme.surface)
                            .overlay(
                                Image(systemName: "photo.fill")
                                    .foregroundColor(.theme.subtext.opacity(0.5))
                            )
                            .frame(height: 300)
                            .cornerRadius(16)
                    @unknown default:
                        EmptyView()
                    }
                }
            }
            
            // Note if available
            if let note = note, !note.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("My Reflection:")
                        .font(.headline)
                        .foregroundColor(.theme.text)
                    
                    Text(note)
                        .font(.body)
                        .foregroundColor(.theme.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.theme.surface)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                )
            }
            
            // Quote if available
            if let quote = quote {
                VStack(spacing: 12) {
                    Text(quote.text)
                        .font(.body)
                        .italic()
                        .foregroundColor(.theme.text)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text("— \(quote.author)")
                        .font(.subheadline)
                        .foregroundColor(.theme.subtext)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.theme.surface)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                )
            }
            
            Spacer()
            
            // Footer
            HStack {
                Spacer()
                
                Text("@100DaysApp")
                    .font(.caption)
                    .foregroundColor(.theme.subtext)
            }
        }
        .padding(24)
        .background(Color.theme.background)
    }
}

// Preview removed to avoid sample data usage in production code 