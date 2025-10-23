//
//  ProjectImageRepository.swift
//  Molten
//
//  Protocol for ProjectImage metadata persistence operations
//  This stores METADATA ONLY (caption, order, relationships)
//  Actual image storage is handled by UserImageRepository
//
//  Two-Layer Architecture:
//  - UserImageRepository: Stores actual UIImage data (file system + CloudKit backup)
//  - ProjectImageRepository: Stores metadata (caption, order, plan/log relationships)
//

import Foundation

protocol ProjectImageRepository {
    // MARK: - Metadata Operations

    /// Create image metadata record (links to UserImage with same ID)
    func createImageMetadata(_ metadata: ProjectImageModel) async throws -> ProjectImageModel

    /// Get all image metadata for a project
    func getImages(for projectId: UUID, type: ProjectCategory) async throws -> [ProjectImageModel]

    /// Get hero image metadata for a project
    func getHeroImage(for projectId: UUID, type: ProjectCategory) async throws -> ProjectImageModel?

    /// Update image metadata (caption, order, etc.)
    func updateImageMetadata(_ metadata: ProjectImageModel) async throws

    /// Delete image metadata (does NOT delete actual image from UserImageRepository)
    func deleteImageMetadata(id: UUID) async throws

    /// Reorder images for a project
    func reorderImages(projectId: UUID, type: ProjectCategory, imageIds: [UUID]) async throws
}
