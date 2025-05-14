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
    @State private var imageLoadingError = false
    
    // Configure URLCache for profile images
    private static let imageCache: URLCache = {
        let cacheSizeMemory = 50 * 1024 * 1024 // 50 MB memory cache
        let cacheSizeDisk = 100 * 1024 * 1024  // 100 MB disk cache
        let cache = URLCache(memoryCapacity: cacheSizeMemory, diskCapacity: cacheSizeDisk, diskPath: "profile_images")
        return cache
    }()
    
    var body: some View {
        AsyncImage(url: url, urlCache: Self.imageCache) { phase in
            switch phase {
            case .empty:
                ZStack {
                    Circle()
                        .fill(Color.theme.surface)
                        .frame(width: size, height: size)
                    
                    ProgressView()
                        .frame(width: size, height: size)
                }
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
                    .circularAvatarStyle(size: size)
                    .onAppear {
                        imageLoadingError = false
                    }
            case .failure:
                Image(systemName: "person.circle.fill")
                    .font(.system(size: size))
                    .foregroundColor(.theme.accent)
                    .onAppear {
                        imageLoadingError = true
                        print("Failed to load profile image: \(url?.absoluteString ?? "nil")")
                    }
            @unknown default:
                Image(systemName: "person.circle.fill")
                    .font(.system(size: size))
                    .foregroundColor(.theme.accent)
            }
        }
        .transition(.opacity.combined(with: .scale))
    }
}

// MARK: - AsyncImage Extensions
extension AsyncImage {
    /// Creates an AsyncImage specifically styled for profile pictures
    static func profilePicture(url: URL?, size: CGFloat = 100) -> ProfilePictureView {
        return ProfilePictureView(url: url, size: size)
    }
}

// MARK: - AsyncImage with URLCache
extension AsyncImage where Content: View {
    init(
        url: URL?,
        urlCache: URLCache? = nil,
        @ViewBuilder content: @escaping (AsyncImagePhase) -> Content
    ) {
        if let urlCache = urlCache, let url = url {
            let config = URLSessionConfiguration.default
            config.urlCache = urlCache
            let session = URLSession(configuration: config)
            
            var urlRequest = URLRequest(url: url)
            // Cache for up to one day
            urlRequest.cachePolicy = .returnCacheDataElseLoad
            
            self.init(url: url, transaction: Transaction(animation: .easeInOut)) { phase in
                content(phase)
            }
        } else {
            self.init(url: url) { phase in
                content(phase)
            }
        }
    }
}

// MARK: - View Extensions for Fallback Images
extension Image {
    /// Creates a properly fallbacked app icon view regardless of whether AppIconRounded exists
    static func appIconWithFallback(size: CGFloat = 80) -> some View {
        // Try each option in sequence with guaranteed fallbacks
        Group {
            if let _ = UIImage(named: "AppIcon") {
                // Use AppIcon if available (this should always be available)
                Image("AppIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .cornerRadius(size * 0.2)
            } else {
                // Ultimate fallback using SF Symbol
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
        // Always use appIconWithFallback for any app icon related requests
        if imageName == "AppIconRounded" || imageName == "AppIcon" {
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