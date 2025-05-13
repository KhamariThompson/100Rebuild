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
            Color.theme.background
                .ignoresSafeArea()
                .onTapGesture {
                    isTextFieldFocused = false
                }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Day \(dayNumber) Reflection")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.theme.text)
                        
                        Text(challenge.title)
                            .font(.headline)
                            .foregroundColor(.theme.subtext)
                    }
                    .padding(.top, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .opacity(showAnimation ? 1 : 0)
                    .offset(y: showAnimation ? 0 : -20)
                    
                    // Prompt
                    Text(prompt)
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(.theme.accent)
                        .opacity(showAnimation ? 1 : 0)
                        .offset(y: showAnimation ? 0 : -15)
                    
                    // Note input
                    VStack(alignment: .leading, spacing: 14) {
                        TextEditor(text: $viewModel.note)
                            .focused($isTextFieldFocused)
                            .frame(minHeight: 150)
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.theme.accent.opacity(0.3), lineWidth: 1)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.theme.surface)
                                    )
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
                            .contentShape(Rectangle())
                    }
                    .opacity(showAnimation ? 1 : 0)
                    .offset(y: showAnimation ? 0 : -10)
                    
                    // Photo attachment
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Add Photo (Optional)")
                            .font(.headline)
                            .foregroundColor(.theme.text)
                        
                        if let selectedImage = viewModel.selectedImage {
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: selectedImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 200)
                                    .frame(maxWidth: .infinity)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                
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
                                    Image(systemName: "photo")
                                        .font(.system(size: 30))
                                        .foregroundColor(.theme.accent.opacity(0.8))
                                        .padding(.bottom, 8)
                                    
                                    Text("Add a photo to your reflection")
                                        .font(.subheadline)
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(.theme.subtext)
                                }
                                .frame(height: 120)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.theme.accent.opacity(0.3), lineWidth: 1)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color.theme.surface)
                                        )
                                )
                            }
                        }
                    }
                    .opacity(showAnimation ? 1 : 0)
                    .offset(y: showAnimation ? 0 : 10)
                    .onChange(of: photoItem) {
                        if let newValue = photoItem {
                            loadTransferable(from: newValue)
                        }
                    }
                    
                    // Helper tip
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Why reflect?")
                            .font(.headline)
                            .foregroundColor(.theme.text)
                        
                        Text("Studies show that writing down your reflections improves habit formation and leads to greater success in maintaining long-term habits.")
                            .font(.caption)
                            .foregroundColor(.theme.subtext)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.theme.surface)
                    )
                    .opacity(showAnimation ? 1 : 0)
                    .offset(y: showAnimation ? 0 : 15)
                    
                    // Action buttons
                    VStack(spacing: 16) {
                        Button(action: {
                            Task {
                                // Save the note and photo
                                await viewModel.saveCheckInDetails()
                                isPresented = false
                            }
                        }) {
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .padding(.vertical, 16)
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text("Save")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.vertical, 16)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.theme.accent)
                        )
                        .disabled(viewModel.isLoading)
                        
                        Button(action: {
                            isPresented = false
                        }) {
                            Text("Skip")
                                .font(.headline)
                                .foregroundColor(.theme.subtext)
                                .padding(.vertical, 16)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .opacity(showAnimation ? 1 : 0)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 50)
                .contentShape(Rectangle())
                .onTapGesture {
                    isTextFieldFocused = false
                }
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
        }
    }
    
    private func loadTransferable(from imageSelection: PhotosPickerItem) {
        imageSelection.loadTransferable(type: Data.self) { result in
            Task { @MainActor in
                guard imageSelection == photoItem else { return }
                
                switch result {
                case .success(let data?):
                    if let uiImage = UIImage(data: data) {
                        viewModel.selectedImage = uiImage
                    }
                case .success(nil):
                    print("No data available")
                case .failure(let error):
                    print("Error loading image: \(error)")
                }
            }
        }
    }
}

// Preview removed to avoid sample data usage in production code 