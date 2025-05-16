import SwiftUI
import PhotosUI

/// A struct that handles transferable data from PhotosPickerItem
/// with built-in compression for performance
@MainActor
struct PhotoTransferable: Transferable {
    let image: UIImage
    
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { data in
            guard let uiImage = UIImage(data: data) else {
                throw TransferError.importFailed
            }
            
            // Resize and compress the image for better performance
            let compressedImage = uiImage.resizedImage(targetSize: CGSize(width: 1200, height: 1200))
            return PhotoTransferable(image: compressedImage)
        }
    }
    
    /// Get compressed data for uploading to servers
    func compressedData(quality: CGFloat = 0.7) -> Data? {
        return image.jpegData(compressionQuality: quality)
    }
    
    enum TransferError: Error {
        case importFailed
    }
}

// Extension to resize UIImage with better quality
extension UIImage {
    func resizedImage(targetSize: CGSize) -> UIImage {
        // Handle the case where the image is already smaller than target size
        if self.size.width <= targetSize.width && self.size.height <= targetSize.height {
            return self
        }
        
        let size = self.size
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        
        // Use the smaller ratio to ensure the image fits within the target size
        let scaleFactor = min(widthRatio, heightRatio)
        let scaledSize = CGSize(width: size.width * scaleFactor, height: size.height * scaleFactor)
        
        let renderer = UIGraphicsImageRenderer(size: scaledSize)
        let scaledImage = renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: scaledSize))
        }
        
        return scaledImage
    }
} 