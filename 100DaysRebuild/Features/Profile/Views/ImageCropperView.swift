import SwiftUI
import UIKit

struct ImageCropperView: View {
    let image: UIImage
    let onCrop: (UIImage) -> Void
    let onCancel: () -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var isProcessing = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.presentationMode) private var presentationMode
    
    // Increased crop size for better visibility
    private let cropSize: CGFloat = 300
    private let maxScale: CGFloat = 5.0
    private let minScale: CGFloat = 0.5
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    // Background
                    Color.black
                        .ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                        // Image cropping area
                        ZStack {
                            // Background image with improved scaling
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .scaleEffect(scale)
                                .offset(offset)
                                .gesture(
                                    SimultaneousGesture(
                                        MagnificationGesture()
                                            .onChanged { value in
                                                let delta = value / lastScale
                                                lastScale = value
                                                scale = min(max(scale * delta, minScale), maxScale)
                                            }
                                            .onEnded { _ in
                                                lastScale = 1.0
                                            },
                                        DragGesture()
                                            .onChanged { value in
                                                isDragging = true
                                                offset = CGSize(
                                                    width: lastOffset.width + value.translation.width,
                                                    height: lastOffset.height + value.translation.height
                                                )
                                            }
                                            .onEnded { _ in
                                                isDragging = false
                                                lastOffset = offset
                                            }
                                    )
                                )
                            
                            // Circular mask with improved visibility
                            ZStack {
                                // Outer dimmed area
                                Color.black.opacity(0.7)
                                    .mask(
                                        Circle()
                                            .frame(width: cropSize, height: cropSize)
                                            .blendMode(.destinationOut)
                                    )
                                
                                // Circular mask with improved visibility
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                                    .frame(width: cropSize, height: cropSize)
                                
                                // Grid lines with improved visibility
                                VStack(spacing: cropSize/3) {
                                    ForEach(0..<2) { _ in
                                        Rectangle()
                                            .fill(Color.white.opacity(0.5))
                                            .frame(height: 1)
                                    }
                                }
                                .frame(width: cropSize)
                                
                                HStack(spacing: cropSize/3) {
                                    ForEach(0..<2) { _ in
                                        Rectangle()
                                            .fill(Color.white.opacity(0.5))
                                            .frame(width: 1)
                                    }
                                }
                                .frame(height: cropSize)
                            }
                        }
                        .frame(width: geometry.size.width, height: geometry.size.width)
                        .clipped()
                        
                        Spacer()
                        
                        // Bottom instructions with improved visibility
                        VStack(spacing: 12) {
                            Text("Pinch to zoom")
                                .foregroundColor(.white)
                                .font(.system(size: 16, weight: .medium))
                            
                            Text("Drag to reposition")
                                .foregroundColor(.white)
                                .font(.system(size: 16, weight: .medium))
                        }
                        .padding(.bottom, 40)
                    }
                    
                    if isProcessing {
                        Color.black.opacity(0.7)
                            .ignoresSafeArea()
                        
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("Edit Photo")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            // Use presentationMode for more reliable dismissal
                            presentationMode.wrappedValue.dismiss()
                            onCancel()
                        }
                        .foregroundColor(.white)
                        .disabled(isProcessing)
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            isProcessing = true
                            Task {
                                let croppedImage = await cropImage()
                                await MainActor.run {
                                    // Use presentationMode for more reliable dismissal
                                    presentationMode.wrappedValue.dismiss()
                                    onCrop(croppedImage)
                                }
                            }
                        }
                        .foregroundColor(.white)
                        .fontWeight(.bold)
                        .disabled(isProcessing)
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .preferredColorScheme(.dark)
        .accentColor(.white)
        // Apply fixes when the view appears to ensure proper presentation
        .onAppear {
            AppFixes.shared.applyAllFixes()
        }
    }
    
    private func cropImage() async -> UIImage {
        return await Task.detached {
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: cropSize, height: cropSize))
            
            let croppedImage = renderer.image { context in
                // Create circular clipping path
                let circlePath = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: cropSize, height: cropSize))
                circlePath.addClip()
                
                // Calculate the scaled and offset image rect
                let imageSize = image.size
                let scale = max(cropSize / imageSize.width, cropSize / imageSize.height) * self.scale
                let scaledSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
                
                let x = (cropSize - scaledSize.width) / 2 + offset.width
                let y = (cropSize - scaledSize.height) / 2 + offset.height
                
                // Draw the image
                image.draw(in: CGRect(x: x, y: y, width: scaledSize.width, height: scaledSize.height))
            }
            
            // Compress the image
            return compressImage(croppedImage)
        }.value
    }
    
    private func compressImage(_ image: UIImage) -> UIImage {
        let maxSize: CGFloat = 1024 // Maximum dimension
        let compressionQuality: CGFloat = 0.8 // Increased quality
        
        // Calculate new size maintaining aspect ratio
        let size = image.size
        let widthRatio = maxSize / size.width
        let heightRatio = maxSize / size.height
        let ratio = min(widthRatio, heightRatio)
        
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        // Create new image with calculated size
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        // Compress the resized image
        if let imageData = resizedImage?.jpegData(compressionQuality: compressionQuality),
           let compressedImage = UIImage(data: imageData) {
            return compressedImage
        }
        
        return image
    }
}

// MARK: - Preview Provider
struct ImageCropperView_Previews: PreviewProvider {
    static var previews: some View {
        ImageCropperView(
            image: UIImage(systemName: "person.circle.fill")!,
            onCrop: { _ in },
            onCancel: {}
        )
    }
} 