import SwiftUI
import Foundation
import UIKit

/// Memory Management Utilities for the 100DaysRebuild app
/// This class provides functions to optimize memory usage and prevent crashes
class MemoryManager {
    static let shared = MemoryManager()
    
    private let imageCache = NSCache<NSString, UIImage>()
    private var imageFetchTasks: [String: Task<Void, Never>] = [:]
    
    init() {
        // Set up cache limits
        imageCache.countLimit = 50 // Maximum number of images to cache
        imageCache.totalCostLimit = 50 * 1024 * 1024 // 50MB maximum cache size
        
        // Listen for memory warnings
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    // Handle memory warnings by clearing caches
    @objc private func handleMemoryWarning() {
        print("⚠️ Memory warning received - clearing caches")
        clearAllCaches()
    }
    
    // Clear all cached data
    func clearAllCaches() {
        imageCache.removeAllObjects()
        URLCache.shared.removeAllCachedResponses()
        
        // Cancel any ongoing image fetch tasks
        for (_, task) in imageFetchTasks {
            task.cancel()
        }
        imageFetchTasks.removeAll()
    }
    
    // Optimize image loading for memory efficiency
    func loadOptimizedImage(from url: URL, completion: @escaping (UIImage?) -> Void) {
        // Check cache first
        let cacheKey = url.absoluteString as NSString
        if let cachedImage = imageCache.object(forKey: cacheKey) {
            completion(cachedImage)
            return
        }
        
        // Cancel existing task for this URL if any
        imageFetchTasks[url.absoluteString]?.cancel()
        
        // Create a new task for fetching
        let task = Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if Task.isCancelled { return }
                
                // Downscale image if needed before caching
                if let image = UIImage(data: data) {
                    let optimizedImage = optimizeImageForMemory(image)
                    
                    // Cache the optimized image
                    self.imageCache.setObject(optimizedImage, forKey: cacheKey)
                    
                    // Return on main thread
                    await MainActor.run {
                        completion(optimizedImage)
                    }
                } else {
                    await MainActor.run {
                        completion(nil)
                    }
                }
            } catch {
                if !Task.isCancelled {
                    print("Error loading image: \(error.localizedDescription)")
                    await MainActor.run {
                        completion(nil)
                    }
                }
            }
            
            // Remove task from tracking
            if url.absoluteString == url.absoluteString {
                self.imageFetchTasks.removeValue(forKey: url.absoluteString)
            }
        }
        
        // Store the task
        imageFetchTasks[url.absoluteString] = task
    }
    
    // Optimize image size for memory efficiency
    private func optimizeImageForMemory(_ image: UIImage) -> UIImage {
        let maxDimension: CGFloat = 1200 // Maximum dimension for any image
        
        // Check if image needs resizing
        let size = image.size
        if size.width <= maxDimension && size.height <= maxDimension {
            return image
        }
        
        // Calculate new size maintaining aspect ratio
        var newSize: CGSize
        if size.width > size.height {
            let ratio = maxDimension / size.width
            newSize = CGSize(width: maxDimension, height: size.height * ratio)
        } else {
            let ratio = maxDimension / size.height
            newSize = CGSize(width: size.width * ratio, height: maxDimension)
        }
        
        // Render resized image
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        
        return resizedImage
    }
    
    // Monitor memory usage
    func currentMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return info.resident_size
        } else {
            return 0
        }
    }
    
    // Format memory usage for display
    func formattedMemoryUsage() -> String {
        let usageBytes = currentMemoryUsage()
        
        if usageBytes < 1024 {
            return "\(usageBytes) bytes"
        } else if usageBytes < 1024 * 1024 {
            let kb = Double(usageBytes) / 1024.0
            return String(format: "%.1f KB", kb)
        } else {
            let mb = Double(usageBytes) / (1024.0 * 1024.0)
            return String(format: "%.1f MB", mb)
        }
    }
    
    // Alert if memory usage is getting high
    func checkMemoryUsage() -> Bool {
        let usageMB = Double(currentMemoryUsage()) / (1024.0 * 1024.0)
        
        // Alert if using more than 150MB
        if usageMB > 150 {
            print("⚠️ High memory usage: \(String(format: "%.1f MB", usageMB))")
            clearAllCaches()
            return true
        }
        
        return false
    }
}

// MARK: - SwiftUI Image Extension
// Add a SwiftUI extension for loading optimized images
extension Image {
    static func optimized(url: URL?, placeholder: Image = Image(systemName: "photo")) -> some View {
        OptimizedImageView(url: url, placeholder: placeholder)
    }
}

// Optimized image view that uses the memory manager
struct OptimizedImageView: View {
    let url: URL?
    let placeholder: Image
    
    @State private var image: UIImage? = nil
    @State private var isLoading = false
    
    var body: some View {
        ZStack {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                placeholder
                    .resizable()
                    .scaledToFit()
                
                if isLoading {
                    ProgressView()
                }
            }
        }
        .onAppear {
            loadImage()
        }
        .onChange(of: url) { _ in
            loadImage()
        }
    }
    
    private func loadImage() {
        guard let url = url, image == nil, !isLoading else { return }
        
        isLoading = true
        
        MemoryManager.shared.loadOptimizedImage(from: url) { loadedImage in
            image = loadedImage
            isLoading = false
        }
    }
} 