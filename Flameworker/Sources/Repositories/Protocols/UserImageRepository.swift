//
//  UserImageRepository.swift
//  Flameworker
//
//  Protocol for managing user-uploaded product images
//

import Foundation
import UIKit

/// Model for user-uploaded images
struct UserImageModel: Identifiable, Equatable {
    let id: UUID
    let itemNaturalKey: String
    let imageType: UserImageType
    let fileExtension: String
    let dateAdded: Date
    let dateModified: Date

    /// File name on disk (UUID + extension)
    var fileName: String {
        "\(id.uuidString).\(fileExtension)"
    }

    init(
        id: UUID = UUID(),
        itemNaturalKey: String,
        imageType: UserImageType,
        fileExtension: String,
        dateAdded: Date = Date(),
        dateModified: Date = Date()
    ) {
        self.id = id
        self.itemNaturalKey = itemNaturalKey
        self.imageType = imageType
        self.fileExtension = fileExtension
        self.dateAdded = dateAdded
        self.dateModified = dateModified
    }
}

/// Type of user-uploaded image
enum UserImageType: String, CaseIterable, Codable {
    case primary = "primary"       // Primary image (replaces default)
    case alternate = "alternate"   // Additional images

    var displayName: String {
        switch self {
        case .primary: return "Primary Image"
        case .alternate: return "Alternate Image"
        }
    }
}

/// Repository protocol for managing user-uploaded images
protocol UserImageRepository {
    /// Save a new image for an item
    /// - Parameters:
    ///   - image: The UIImage to save
    ///   - itemNaturalKey: Natural key of the glass item
    ///   - type: Type of image (primary or alternate)
    /// - Returns: The created UserImageModel
    func saveImage(_ image: UIImage, for itemNaturalKey: String, type: UserImageType) async throws -> UserImageModel

    /// Load image data from disk
    /// - Parameter model: The image model
    /// - Returns: UIImage if found
    func loadImage(_ model: UserImageModel) async throws -> UIImage?

    /// Get all images for an item
    /// - Parameter itemNaturalKey: Natural key of the glass item
    /// - Returns: Array of image models
    func getImages(for itemNaturalKey: String) async throws -> [UserImageModel]

    /// Get primary image for an item (if any)
    /// - Parameter itemNaturalKey: Natural key of the glass item
    /// - Returns: Primary image model if exists
    func getPrimaryImage(for itemNaturalKey: String) async throws -> UserImageModel?

    /// Delete an image
    /// - Parameter id: UUID of the image to delete
    func deleteImage(_ id: UUID) async throws

    /// Delete all images for an item
    /// - Parameter itemNaturalKey: Natural key of the glass item
    func deleteAllImages(for itemNaturalKey: String) async throws

    /// Update image type (e.g., promote alternate to primary)
    /// - Parameters:
    ///   - id: UUID of the image
    ///   - type: New type
    func updateImageType(_ id: UUID, type: UserImageType) async throws
}

/// Errors for user image operations
enum UserImageError: Error, LocalizedError {
    case imageNotFound
    case failedToSaveImage(String)
    case failedToLoadImage(String)
    case failedToDeleteImage(String)
    case invalidImageData
    case storageDirectoryUnavailable

    var errorDescription: String? {
        switch self {
        case .imageNotFound:
            return "Image not found"
        case .failedToSaveImage(let reason):
            return "Failed to save image: \(reason)"
        case .failedToLoadImage(let reason):
            return "Failed to load image: \(reason)"
        case .failedToDeleteImage(let reason):
            return "Failed to delete image: \(reason)"
        case .invalidImageData:
            return "Invalid image data"
        case .storageDirectoryUnavailable:
            return "Storage directory is unavailable"
        }
    }
}
