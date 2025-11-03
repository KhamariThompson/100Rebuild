import SwiftUI
import UIKit

struct ImageCropperView: View {
    let image: UIImage
    let onCrop: (UIImage) -> Void
    let onCancel: () -> Void
    
    @State private var isProcessing = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header with Cancel and Done buttons
                    HStack {
                        Button("Cancel") {
                            if !isProcessing {
                                DispatchQueue.main.async {
                                    dismiss()
                                    onCancel()
                                }
                            }
                        }
                        .foregroundColor(.white)
                        .font(AppTypography.headline(.medium))
                        .disabled(isProcessing)
                        
                        Spacer()
                        
                        Text("Use This Photo?")
                            .foregroundColor(.white)
                            .font(AppTypography.headline(.semibold))
                        
                        Spacer()
                        
                        Button("Done") {
                            if !isProcessing {
                                isProcessing = true
                                Task {
                                    await MainActor.run {
                                        DispatchQueue.main.async {
                                            dismiss()
                                            onCrop(image)
                                        }
                                    }
                                }
                            }
                        }
                        .foregroundColor(.white)
                        .font(AppTypography.headline(.medium))
                        .disabled(isProcessing)
                    }
                    .padding()
                    .background(Color.black.opacity(0.8))
                    
                    Spacer()
                    
                    // Simple image display
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: geometry.size.width, maxHeight: geometry.size.height * 0.7)
                    
                    Spacer()
                }
                
                if isProcessing {
                    Color.black.opacity(0.7)
                        .ignoresSafeArea()
                    
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
        .ignoresSafeArea()
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