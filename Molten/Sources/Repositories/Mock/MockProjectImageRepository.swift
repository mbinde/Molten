//
//  MockProjectImageRepository.swift
//  Molten
//
//  Mock implementation of ProjectImageRepository for testing
//  Stores image metadata in memory
//

import Foundation

/// Mock implementation of ProjectImageRepository for testing
class MockProjectImageRepository: @unchecked Sendable, ProjectImageRepository {
    private var images: [UUID: ProjectImageModel] = [:]
    private let queue = DispatchQueue(label: "mock.projectimage.repository", attributes: .concurrent)

    nonisolated init() {}

    // MARK: - Create

    func createImageMetadata(_ metadata: ProjectImageModel) async throws -> ProjectImageModel {
        await withCheckedContinuation { continuation in
            queue.async(flags: .barrier) {
                self.images[metadata.id] = metadata
                continuation.resume(returning: metadata)
            }
        }
    }

    // MARK: - Read

    func getImages(for projectId: UUID, type: ProjectType) async throws -> [ProjectImageModel] {
        await withCheckedContinuation { continuation in
            queue.async {
                let filtered = self.images.values.filter { $0.projectId == projectId && $0.projectType == type }
                let sorted = filtered.sorted { $0.order < $1.order }
                continuation.resume(returning: sorted)
            }
        }
    }

    func getHeroImage(for projectId: UUID, type: ProjectType) async throws -> ProjectImageModel? {
        // In mock, just return the first image (order 0) as hero
        let allImages = try await getImages(for: projectId, type: type)
        return allImages.first
    }

    // MARK: - Update

    func updateImageMetadata(_ metadata: ProjectImageModel) async throws {
        await withCheckedContinuation { continuation in
            queue.async(flags: .barrier) {
                guard self.images[metadata.id] != nil else {
                    continuation.resume(returning: ())
                    return
                }
                self.images[metadata.id] = metadata
                continuation.resume(returning: ())
            }
        }
    }

    func reorderImages(projectId: UUID, type: ProjectType, imageIds: [UUID]) async throws {
        await withCheckedContinuation { continuation in
            queue.async(flags: .barrier) {
                for (index, imageId) in imageIds.enumerated() {
                    if var image = self.images[imageId] {
                        // Create updated image with new order
                        let updated = ProjectImageModel(
                            id: image.id,
                            projectId: image.projectId,
                            projectType: image.projectType,
                            fileExtension: image.fileExtension,
                            caption: image.caption,
                            dateAdded: image.dateAdded,
                            order: index
                        )
                        self.images[imageId] = updated
                    }
                }
                continuation.resume(returning: ())
            }
        }
    }

    // MARK: - Delete

    func deleteImageMetadata(id: UUID) async throws {
        await withCheckedContinuation { continuation in
            queue.async(flags: .barrier) {
                self.images.removeValue(forKey: id)
                continuation.resume(returning: ())
            }
        }
    }

    // MARK: - Test Helpers

    /// Get count of stored images (for testing)
    func getImageCount() async -> Int {
        await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: self.images.count)
            }
        }
    }

    /// Clear all images (for testing)
    func clearAll() async {
        await withCheckedContinuation { continuation in
            queue.async(flags: .barrier) {
                self.images.removeAll()
                continuation.resume(returning: ())
            }
        }
    }
}
