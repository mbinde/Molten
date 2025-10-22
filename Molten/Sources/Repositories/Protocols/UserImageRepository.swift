//
//  UserImageRepository.swift
//  Flameworker
//
//  Protocol for managing user-uploaded product images
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Owner type for user images
enum ImageOwnerType: String, CaseIterable, Codable, Sendable {
    case glassItem = "glassItem"
    case projectPlan = "projectPlan"
    case standalone = "standalone"  // Not linked to anything yet

    var displayName: String {
        switch self {
        case .glassItem: return "Glass Item"
        case .projectPlan: return "Project Plan"
        case .standalone: return "Standalone"
        }
    }
}

/// Model for user-uploaded images
nonisolated struct UserImageModel: Identifiable, Equatable, Hashable, Sendable {
    let id: UUID
    let ownerType: ImageOwnerType
    let ownerId: String?  // naturalKey for glass items, UUID.uuidString for plans, nil for standalone
    let imageType: UserImageType
    let fileExtension: String
    let dateCreated: Date
    let dateModified: Date

    /// File name on disk (UUID + extension) - for backward compatibility with FileSystem storage
    nonisolated var fileName: String {
        "\(id.uuidString).\(fileExtension)"
    }

    /// Legacy support - maps to ownerId for glass items
    nonisolated var itemNaturalKey: String? {
        ownerType == .glassItem ? ownerId : nil
    }

    nonisolated init(
        id: UUID = UUID(),
        ownerType: ImageOwnerType,
        ownerId: String?,
        imageType: UserImageType,
        fileExtension: String = "jpg",
        dateCreated: Date = Date(),
        dateModified: Date = Date()
    ) {
        self.id = id
        self.ownerType = ownerType
        self.ownerId = ownerId
        self.imageType = imageType
        self.fileExtension = fileExtension
        self.dateCreated = dateCreated
        self.dateModified = dateModified
    }

    /// Legacy initializer for backward compatibility
    nonisolated init(
        id: UUID = UUID(),
        itemNaturalKey: String,
        imageType: UserImageType,
        fileExtension: String = "jpg",
        dateAdded: Date = Date(),
        dateModified: Date = Date()
    ) {
        self.id = id
        self.ownerType = .glassItem
        self.ownerId = itemNaturalKey
        self.imageType = imageType
        self.fileExtension = fileExtension
        self.dateCreated = dateAdded
        self.dateModified = dateModified
    }
}

/// Type of user-uploaded image
enum UserImageType: String, CaseIterable, Codable, Sendable {
    case primary = "primary"       // Primary image (replaces default)
    case alternate = "alternate"   // Additional images

    var displayName: String {
        switch self {
        case .primary: return "Primary Image"
        case .alternate: return "Alternate Image"
        }
    }
}

#if canImport(UIKit)
/// Repository protocol for managing user-uploaded images
nonisolated protocol UserImageRepository {
    // MARK: - New Generic Methods (Support all owner types)

    /// Save a new image with owner information
    /// - Parameters:
    ///   - image: The UIImage to save
    ///   - ownerType: Type of owner (glassItem, projectPlan, standalone)
    ///   - ownerId: ID of the owner (natural key for glass items, UUID string for plans, nil for standalone)
    ///   - type: Type of image (primary or alternate)
    /// - Returns: The created UserImageModel
    func saveImage(_ image: UIImage, ownerType: ImageOwnerType, ownerId: String?, type: UserImageType) async throws -> UserImageModel

    /// Get all images for a specific owner
    /// - Parameters:
    ///   - ownerType: Type of owner
    ///   - ownerId: ID of the owner
    /// - Returns: Array of image models
    func getImages(ownerType: ImageOwnerType, ownerId: String) async throws -> [UserImageModel]

    /// Get primary image for a specific owner
    /// - Parameters:
    ///   - ownerType: Type of owner
    ///   - ownerId: ID of the owner
    /// - Returns: Primary image model if exists
    func getPrimaryImage(ownerType: ImageOwnerType, ownerId: String) async throws -> UserImageModel?

    /// Get all standalone images (not linked to any owner)
    /// - Returns: Array of standalone image models
    func getStandaloneImages() async throws -> [UserImageModel]

    /// Delete all images for a specific owner
    /// - Parameters:
    ///   - ownerType: Type of owner
    ///   - ownerId: ID of the owner
    func deleteAllImages(ownerType: ImageOwnerType, ownerId: String) async throws

    // MARK: - Common Methods

    /// Load image data from storage
    /// - Parameter model: The image model
    /// - Returns: UIImage if found
    func loadImage(_ model: UserImageModel) async throws -> UIImage?

    /// Delete an image by ID
    /// - Parameter id: UUID of the image to delete
    func deleteImage(_ id: UUID) async throws

    /// Update image type (e.g., promote alternate to primary)
    /// - Parameters:
    ///   - id: UUID of the image
    ///   - type: New type
    func updateImageType(_ id: UUID, type: UserImageType) async throws
}
#endif

/// Errors for user image operations
enum UserImageError: Error, LocalizedError, Equatable {
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
