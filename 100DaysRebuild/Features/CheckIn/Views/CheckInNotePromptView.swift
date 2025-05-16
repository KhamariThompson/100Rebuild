import SwiftUI
import PhotosUI

struct CheckInNotePromptView: View {
    let challenge: Challenge
    let dayNumber: Int
    let prompt: String
    
    @ObservedObject var viewModel: CheckInViewModel
    @Binding var isPresented: Bool
    @FocusState private var isTextFieldFocused: Bool
    @State private var showImagePicker = false
    @State private var photoItem: PhotosPickerItem?
    @State private var showAnimation = false
    
    var body: some View {
        ZStack {
            // Background with gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.theme.background, Color.theme.background.opacity(0.9)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .onTapGesture {
                dismissKeyboard()
            }
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Day \(dayNumber) Reflection")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.theme.text)
                            .padding(.top, 8)
                        
                        Text(challenge.title)
                            .font(.system(size: 18))
                            .foregroundColor(.theme.subtext)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.regularMaterial)
                            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
                    )
                    .opacity(showAnimation ? 1 : 0)
                    .offset(y: showAnimation ? 0 : -20)
                    
                    // Prompt card
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Today's Prompt")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.theme.subtext)
                        
                        Text(prompt)
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(.theme.accent)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.regularMaterial)
                            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
                    )
                    .opacity(showAnimation ? 1 : 0)
                    .offset(y: showAnimation ? 0 : -15)
                    
                    // Journal input card
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Your Reflection")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.theme.text)
                        
                        TextEditor(text: $viewModel.note)
                            .focused($isTextFieldFocused)
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                            .frame(minHeight: 150)
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.theme.surface.opacity(0.8))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.theme.accent.opacity(0.2), lineWidth: 1)
                            )
                            .overlay(
                                Group {
                                    if viewModel.note.isEmpty && !isTextFieldFocused {
                                        Text("Write your thoughts here...")
                                            .foregroundColor(.theme.subtext.opacity(0.6))
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 20)
                                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                            .allowsHitTesting(false)
                                    }
                                }
                            )
                            .accessibilityHint("Journal entry. Double tap to edit.")
                            .onChange(of: viewModel.note) { oldValue, newValue in
                                if newValue.count % 20 == 0 && newValue.count > 0 {
                                    let generator = UIImpactFeedbackGenerator(style: .light)
                                    generator.impactOccurred()
                                }
                            }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.regularMaterial)
                            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
                    )
                    .opacity(showAnimation ? 1 : 0)
                    .offset(y: showAnimation ? 0 : -10)
                    
                    // Photo attachment card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Add Photo (Optional)")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.theme.text)
                        
                        if let selectedImage = viewModel.selectedImage {
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: selectedImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 200)
                                    .frame(maxWidth: .infinity)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 3)
                                
                                Button(action: {
                                    viewModel.selectedImage = nil
                                    photoItem = nil
                                }) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.black.opacity(0.7))
                                            .frame(width: 30, height: 30)
                                        
                                        Image(systemName: "xmark")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                                .padding(8)
                            }
                        } else {
                            PhotosPicker(selection: $photoItem, matching: .images) {
                                VStack {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 30))
                                        .foregroundColor(.theme.accent.opacity(0.8))
                                        .padding(.bottom, 8)
                                    
                                    Text("Add a photo to your reflection")
                                        .font(.system(size: 14))
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(.theme.subtext)
                                }
                                .frame(height: 120)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.theme.surface.opacity(0.8))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.theme.accent.opacity(0.2), lineWidth: 1)
                                )
                            }
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.regularMaterial)
                            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
                    )
                    .opacity(showAnimation ? 1 : 0)
                    .offset(y: showAnimation ? 0 : 10)
                    .onChange(of: photoItem) {
                        if let newValue = photoItem {
                            loadTransferable(from: newValue)
                        }
                    }
                    
                    // Action buttons
                    VStack(spacing: 16) {
                        Button(action: {
                            Task {
                                // Save the note and photo
                                await viewModel.saveCheckInDetails()
                                isPresented = false
                                
                                // Provide haptic feedback on successful save
                                let generator = UINotificationFeedbackGenerator()
                                generator.notificationOccurred(.success)
                            }
                        }) {
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .padding(.vertical, 16)
                                    .frame(maxWidth: .infinity)
                            } else {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(.white)
                                        .padding(.trailing, 6)
                                    
                                    Text("Save")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                                .padding(.vertical, 16)
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.theme.accent, Color.theme.accent.opacity(0.8)]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .shadow(color: Color.theme.accent.opacity(0.3), radius: 10, x: 0, y: 5)
                        )
                        .disabled(viewModel.isLoading)
                        
                        Button(action: {
                            isPresented = false
                        }) {
                            Text("Skip")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.theme.subtext)
                                .padding(.vertical, 16)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .opacity(showAnimation ? 1 : 0)
                    .padding(.bottom, 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
            }
            .safeAreaInset(edge: .top) {
                HStack {
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.theme.text)
                            .padding(10)
                            .background(
                                Circle()
                                    .fill(Color.theme.surface)
                                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                            )
                    }
                    .accessibilityLabel("Close reflection view")
                    
                    Spacer()
                    
                    Text("Journal")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.theme.text)
                    
                    Spacer()
                    
                    // Empty view to balance the layout
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 36, height: 36)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .background(
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea()
                )
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isTextFieldFocused = false
                }
                .foregroundColor(.theme.accent)
                .fontWeight(.semibold)
            }
        }
        .onAppear {
            // Focus the text field automatically
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                isTextFieldFocused = true
            }
            
            // Animate elements in
            withAnimation(.easeOut(duration: 0.5)) {
                showAnimation = true
            }
            
            // Light haptic feedback
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
        }
    }
    
    private func dismissKeyboard() {
        isTextFieldFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), 
                                      to: nil, from: nil, for: nil)
    }
    
    private func loadTransferable(from imageSelection: PhotosPickerItem) {
        imageSelection.loadTransferable(type: PhotoTransferable.self) { result in
            Task { @MainActor in
                guard imageSelection == photoItem else { return }
                
                switch result {
                case .success(let photoTransferable?):
                    viewModel.selectedImage = photoTransferable.image
                    
                    // Provide haptic feedback on successful image selection
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    
                case .success(nil):
                    print("No photo transferable data available")
                case .failure(let error):
                    print("Error loading image: \(error)")
                }
            }
        }
    }
}

// Preview removed to avoid sample data usage in production code 