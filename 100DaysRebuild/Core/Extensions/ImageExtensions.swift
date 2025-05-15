import SwiftUI
import UIKit
import PhotosUI

// MARK: - Global Image Cache Manager
final class ImageCacheManager {
    static let shared = ImageCacheManager()
    
    // Configure URLCache for all images
    let cache: URLCache = {
        let cacheSizeMemory = 50 * 1024 * 1024 // 50 MB memory cache
        let cacheSizeDisk = 150 * 1024 * 1024  // 150 MB disk cache
        let cache = URLCache(memoryCapacity: cacheSizeMemory, diskCapacity: cacheSizeDisk, diskPath: "image_cache")
        return cache
    }()
    
    // In-memory cache for UIImages to avoid reloading
    private var imageCache = NSCache<NSString, UIImage>()
    
    private init() {
        // Configure cache limits
        imageCache.countLimit = 100 // Max number of items
        imageCache.totalCostLimit = 50 * 1024 * 1024 // 50 MB memory limit
    }
    
    // Store an image in the memory cache
    func setImage(_ image: UIImage, forKey key: String) {
        imageCache.setObject(image, forKey: key as NSString)
    }
    
    // Retrieve an image from the memory cache
    func image(forKey key: String) -> UIImage? {
        return imageCache.object(forKey: key as NSString)
    }
    
    // Clear all cached images
    func clearCache() {
        imageCache.removeAllObjects()
        cache.removeAllCachedResponses()
    }
    
    // Generate a cache key from a URL
    func cacheKey(for url: URL) -> String {
        return url.absoluteString
    }
}

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

// MARK: - Camera & Photo Library Access
/// Source type for image selection
enum ImageSource {
    case photoLibrary
    case camera
}

/// UIImagePickerController wrapper for SwiftUI
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Binding var isPresented: Bool
    var source: ImageSource = .photoLibrary
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        
        init(parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.isPresented = false
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isPresented = false
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        
        switch source {
        case .camera:
            picker.sourceType = .camera
        case .photoLibrary:
            picker.sourceType = .photoLibrary
        }
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
}

// MARK: - Profile Picture View
struct ProfilePictureView: View {
    let url: URL?
    let size: CGFloat
    @State private var imageLoadingError = false
    
    var body: some View {
        CachedAsyncImage(url: url) { phase in
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
                // Handle any future cases that might be added
                Image(systemName: "person.circle.fill")
                    .font(.system(size: size))
                    .foregroundColor(.theme.accent)
            }
        }
        .transition(.opacity.combined(with: .scale))
    }
}

// MARK: - Cached AsyncImage Implementation
struct CachedAsyncImage<Content: View>: View {
    private let url: URL?
    private let scale: CGFloat
    private let transaction: Transaction
    private let content: (AsyncImagePhase) -> Content
    
    init(
        url: URL?,
        scale: CGFloat = 1.0,
        transaction: Transaction = Transaction(),
        @ViewBuilder content: @escaping (AsyncImagePhase) -> Content
    ) {
        self.url = url
        self.scale = scale
        self.transaction = transaction
        self.content = content
    }
    
    var body: some View {
        if let url = url {
            if let cachedImage = ImageCacheManager.shared.image(forKey: url.absoluteString) {
                content(.success(Image(uiImage: cachedImage)))
            } else {
                AsyncImage(
                    url: url,
                    scale: scale,
                    transaction: transaction
                ) { phase in
                    // First check for success to trigger caching
                    if case .success(_) = phase {
                        cacheImageInBackground(url: url)
                    }
                    
                    // Then return the content
                    return content(phase)
                }
            }
        } else {
            content(.empty)
        }
    }
    
    private func cacheImageInBackground(url: URL) {
        Task { @MainActor in
            // Use a proper implementation for caching
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let uiImage = UIImage(data: data) {
                    ImageCacheManager.shared.setImage(uiImage, forKey: url.absoluteString)
                }
            } catch {
                print("Failed to cache image: \(error)")
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

// MARK: - AsyncImage with URLCache
extension AsyncImage where Content: View {
    init(
        url: URL?,
        urlCache: URLCache? = nil,
        @ViewBuilder content: @escaping (AsyncImagePhase) -> Content
    ) {
        let config = URLSessionConfiguration.default
        if let urlCache = urlCache {
            config.urlCache = urlCache
        }
        
        if let url = url {
            var urlRequest = URLRequest(url: url)
            // Cache for up to one day
            urlRequest.cachePolicy = .returnCacheDataElseLoad
        }
        
        self.init(url: url, transaction: Transaction(animation: .easeInOut)) { phase in
            content(phase)
        }
    }
}

// MARK: - View Extensions for Fallback Images
extension Image {
    /// Creates a properly fallbacked app icon view regardless of whether AppIconRounded exists
    static func appIconWithFallback(size: CGFloat = 80) -> AnyView {
        // Try each option in sequence with guaranteed fallbacks
        if UIImage(named: "AppIcon") != nil {
            // Use AppIcon if available (this should always be available)
            return AnyView(
                Image("AppIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .cornerRadius(size * 0.2)
                    .shadow(color: Color.theme.shadow.opacity(0.2), radius: 10, x: 0, y: 5)
            )
        } else {
            // Ultimate fallback using SF Symbol
            return AnyView(
                Image(systemName: "app.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .foregroundColor(.theme.accent)
                    .background(Color.theme.surface)
                    .cornerRadius(size * 0.2)
                    .shadow(color: Color.theme.shadow.opacity(0.2), radius: 10, x: 0, y: 5)
            )
        }
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
    
    func circularAvatarStyle(size: CGFloat) -> some View {
        self
            .frame(width: size, height: size)
            .clipShape(Circle())
    }
}
