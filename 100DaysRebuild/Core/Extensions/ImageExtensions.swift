import SwiftUI

// MARK: - UIImage Extensions
extension UIImage {
    /// Resize an image while maintaining aspect ratio to fit within the given dimensions
    func resized(to targetSize: CGSize) -> UIImage {
        let size = self.size
        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height
        
        let scaleFactor = min(widthRatio, heightRatio)
        let scaledSize = CGSize(width: size.width * scaleFactor, height: size.height * scaleFactor)
        
        let renderer = UIGraphicsImageRenderer(size: scaledSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: scaledSize))
        }
    }
    
    /// Create a circular cropped image
    func circleCropped() -> UIImage {
        let shortestSide = min(size.width, size.height)
        let squareSize = CGSize(width: shortestSide, height: shortestSide)
        
        // Crop to square first
        let squareRect = CGRect(
            x: (size.width - shortestSide) / 2,
            y: (size.height - shortestSide) / 2,
            width: shortestSide,
            height: shortestSide
        )
        
        guard let cgImage = self.cgImage?.cropping(to: squareRect) else { return self }
        let squareImage = UIImage(cgImage: cgImage)
        
        // Now create circular image
        let renderer = UIGraphicsImageRenderer(size: squareSize)
        return renderer.image { context in
            context.cgContext.addEllipse(in: CGRect(origin: .zero, size: squareSize))
            context.cgContext.clip()
            squareImage.draw(in: CGRect(origin: .zero, size: squareSize))
        }
    }
    
    /// Compress image to JPEG with specified quality
    func compressedJPEG(quality: CGFloat = 0.7) -> Data? {
        return self.jpegData(compressionQuality: quality)
    }
}

// MARK: - Profile Picture View
struct ProfilePictureView: View {
    let url: URL?
    let size: CGFloat
    
    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                ProgressView()
                    .frame(width: size, height: size)
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
                    .circularAvatarStyle(size: size)
            case .failure:
                Image(systemName: "person.circle.fill")
                    .font(.system(size: size))
                    .foregroundColor(.theme.accent)
            @unknown default:
                Image(systemName: "person.circle.fill")
                    .font(.system(size: size))
                    .foregroundColor(.theme.accent)
            }
        }
    }
}

// MARK: - AsyncImage Extensions
extension AsyncImage {
    /// Creates an AsyncImage specifically styled for profile pictures
    static func profilePicture(url: URL?, size: CGFloat = 100) -> ProfilePictureView {
        return ProfilePictureView(url: url, size: size)
    }
}

// MARK: - View Extensions for Fallback Images
extension Image {
    /// Creates a fallback view for AppIconRounded
    static func appIconWithFallback(size: CGFloat = 80) -> some View {
        Group {
            if let _ = UIImage(named: "AppIconRounded") {
                Image("AppIconRounded")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .cornerRadius(size * 0.2)
            } else if let _ = UIImage(named: "AppIcon") {
                Image("AppIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .cornerRadius(size * 0.2)
            } else {
                // Ultimate fallback if no app icon assets are found
                Image(systemName: "app.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .foregroundColor(.theme.accent)
                    .background(Color.theme.surface)
                    .cornerRadius(size * 0.2)
            }
        }
        .shadow(color: Color.theme.shadow.opacity(0.2), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Image Loading Error Handling View Modifier
struct ImageLoadingErrorModifier: ViewModifier {
    let imageName: String
    @State private var imageLoadFailed = false
    
    init(imageName: String) {
        self.imageName = imageName
        // Check if image exists
        self._imageLoadFailed = State(initialValue: UIImage(named: imageName) == nil)
    }
    
    func body(content: Content) -> some View {
        Group {
            if imageLoadFailed {
                fallbackImage
            } else {
                content
                    .onAppear {
                        // Double-check image loading on appear
                        if UIImage(named: imageName) == nil {
                            imageLoadFailed = true
                        }
                    }
            }
        }
    }
    
    var fallbackImage: some View {
        if imageName == "AppIconRounded" {
            return AnyView(Image.appIconWithFallback())
        } else {
            return AnyView(
                Image(systemName: "photo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.gray)
            )
        }
    }
}

extension View {
    func withImageFallback(for imageName: String) -> some View {
        self.modifier(ImageLoadingErrorModifier(imageName: imageName))
    }
} 