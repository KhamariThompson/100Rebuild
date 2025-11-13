import Foundation
import FirebaseStorage
import FirebaseAuth
import UIKit

/// Service for uploading and managing check-in photos in Firebase Storage
/// BUSINESS MODEL: Everyone gets 1 photo per check-in
@MainActor
public class PhotoStorageService {
    public static let shared = PhotoStorageService()

    private let storage = Storage.storage()
    private let maxImageSize: CGFloat = 1200
    private let compressionQuality: CGFloat = 0.7

    private init() {}

    /// Upload a check-in photo to Firebase Storage
    /// - Parameters:
    ///   - image: The UIImage to upload
    ///   - challengeId: The challenge ID this check-in belongs to
    ///   - checkInId: The unique check-in ID
    /// - Returns: The download URL of the uploaded photo
    public func uploadCheckInPhoto(
        image: UIImage,
        challengeId: String,
        checkInId: String
    ) async throws -> URL {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw PhotoStorageError.notAuthenticated
        }

        // Compress and resize image
        guard let imageData = try await prepareImageData(image) else {
            throw PhotoStorageError.invalidImage
        }

        // Create storage path: users/{userId}/checkIns/{challengeId}/{checkInId}.jpg
        let filename = "\(checkInId).jpg"
        let storageRef = storage.reference()
            .child("users")
            .child(userId)
            .child("checkIns")
            .child(challengeId)
            .child(filename)

        // Set metadata
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        metadata.customMetadata = [
            "challengeId": challengeId,
            "checkInId": checkInId,
            "uploadedAt": ISO8601DateFormatter().string(from: Date())
        ]

        // Upload the image
        _ = try await storageRef.putDataAsync(imageData, metadata: metadata)

        // Get download URL
        let downloadURL = try await storageRef.downloadURL()

        print("✅ Photo uploaded successfully: \(downloadURL.absoluteString)")

        return downloadURL
    }

    /// Download a check-in photo from Firebase Storage
    /// - Parameter url: The download URL of the photo
    /// - Returns: The downloaded UIImage
    public func downloadCheckInPhoto(from url: URL) async throws -> UIImage {
        let (data, _) = try await URLSession.shared.data(from: url)

        guard let image = UIImage(data: data) else {
            throw PhotoStorageError.invalidImage
        }

        return image
    }

    /// Delete a check-in photo from Firebase Storage
    /// - Parameter url: The download URL of the photo to delete
    public func deleteCheckInPhoto(at url: URL) async throws {
        guard Auth.auth().currentUser != nil else {
            throw PhotoStorageError.notAuthenticated
        }

        // Create a reference from the URL
        let storageRef = storage.reference(forURL: url.absoluteString)

        // Delete the file
        try await storageRef.delete()

        print("✅ Photo deleted successfully")
    }

    // MARK: - Private Helpers

    /// Prepare image data by resizing and compressing
    private func prepareImageData(_ image: UIImage) async throws -> Data? {
        return await Task.detached(priority: .userInitiated) {
            // Resize image if needed
            let resizedImage = self.resizeImage(image, maxSize: self.maxImageSize)

            // Compress to JPEG
            return resizedImage.jpegData(compressionQuality: self.compressionQuality)
        }.value
    }

    /// Resize image maintaining aspect ratio
    nonisolated private func resizeImage(_ image: UIImage, maxSize: CGFloat) -> UIImage {
        // If image is already small enough, return it
        if image.size.width <= maxSize && image.size.height <= maxSize {
            return image
        }

        // Calculate new size maintaining aspect ratio
        let widthRatio = maxSize / image.size.width
        let heightRatio = maxSize / image.size.height
        let scaleFactor = min(widthRatio, heightRatio)
        let newSize = CGSize(
            width: image.size.width * scaleFactor,
            height: image.size.height * scaleFactor
        )

        // Render the resized image
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

// MARK: - Errors

public enum PhotoStorageError: Error, LocalizedError {
    case notAuthenticated
    case invalidImage
    case uploadFailed
    case downloadFailed
    case deleteFailed

    public var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to upload photos"
        case .invalidImage:
            return "The image is invalid or corrupted"
        case .uploadFailed:
            return "Failed to upload photo. Please try again."
        case .downloadFailed:
            return "Failed to download photo. Please check your connection."
        case .deleteFailed:
            return "Failed to delete photo. Please try again."
        }
    }
}
