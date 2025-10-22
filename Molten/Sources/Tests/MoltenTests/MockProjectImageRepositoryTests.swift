//
//  MockProjectImageRepositoryTests.swift
//  Molten
//
//  Tests for MockProjectImageRepository
//

import Testing
import Foundation
@testable import Molten

/// Tests for MockProjectImageRepository
@Suite("MockProjectImageRepository Tests")
struct MockProjectImageRepositoryTests {

    // MARK: - Test Setup

    let repository: MockProjectImageRepository

    init() {
        repository = MockProjectImageRepository()
    }

    // MARK: - Create Tests

    @Test("Create image metadata")
    func testCreateImageMetadata() async throws {
        let imageId = UUID()
        let projectId = UUID()
        let metadata = ProjectImageModel(
            id: imageId,
            projectId: projectId,
            projectCategory: .plan,
            fileExtension: "jpg",
            caption: "Test image",
            order: 0
        )

        let created = try await repository.createImageMetadata(metadata)

        #expect(created.id == imageId)
        #expect(created.projectId == projectId)
        #expect(created.caption == "Test image")

        // Verify it's stored
        let count = await repository.getImageCount()
        #expect(count == 1)
    }

    // MARK: - Read Tests

    @Test("Get images for project")
    func testGetImagesForProject() async throws {
        let projectId = UUID()

        // Create multiple images
        let image1 = ProjectImageModel(
            id: UUID(),
            projectId: projectId,
            projectCategory: .plan,
            fileExtension: "jpg",
            caption: "First",
            order: 0
        )
        let image2 = ProjectImageModel(
            id: UUID(),
            projectId: projectId,
            projectCategory: .plan,
            fileExtension: "png",
            caption: "Second",
            order: 1
        )

        _ = try await repository.createImageMetadata(image1)
        _ = try await repository.createImageMetadata(image2)

        // Fetch images
        let images = try await repository.getImages(for: projectId, type: .plan)

        #expect(images.count == 2)
        #expect(images[0].order == 0)
        #expect(images[1].order == 1)
        #expect(images[0].caption == "First")
        #expect(images[1].caption == "Second")
    }

    @Test("Get images filters by project type")
    func testGetImagesFiltersByProjectType() async throws {
        let projectId = UUID()

        // Create images for different project types with same ID
        let planImage = ProjectImageModel(
            id: UUID(),
            projectId: projectId,
            projectCategory: .plan,
            fileExtension: "jpg",
            caption: "Plan image",
            order: 0
        )
        let logImage = ProjectImageModel(
            id: UUID(),
            projectId: projectId,
            projectCategory: .log,
            fileExtension: "jpg",
            caption: "Log image",
            order: 0
        )

        _ = try await repository.createImageMetadata(planImage)
        _ = try await repository.createImageMetadata(logImage)

        // Fetch plan images
        let planImages = try await repository.getImages(for: projectId, type: .plan)
        #expect(planImages.count == 1)
        #expect(planImages[0].caption == "Plan image")

        // Fetch log images
        let logImages = try await repository.getImages(for: projectId, type: .log)
        #expect(logImages.count == 1)
        #expect(logImages[0].caption == "Log image")
    }

    @Test("Get images returns empty when no images exist")
    func testGetImagesReturnsEmptyWhenNone() async throws {
        let projectId = UUID()
        let images = try await repository.getImages(for: projectId, type: .plan)
        #expect(images.isEmpty)
    }

    @Test("Get hero image returns first image")
    func testGetHeroImageReturnsFirst() async throws {
        let projectId = UUID()

        // Create multiple images
        let firstImage = ProjectImageModel(
            id: UUID(),
            projectId: projectId,
            projectCategory: .plan,
            fileExtension: "jpg",
            caption: "First",
            order: 0
        )
        let secondImage = ProjectImageModel(
            id: UUID(),
            projectId: projectId,
            projectCategory: .plan,
            fileExtension: "jpg",
            caption: "Second",
            order: 1
        )

        _ = try await repository.createImageMetadata(firstImage)
        _ = try await repository.createImageMetadata(secondImage)

        // Get hero image
        let hero = try await repository.getHeroImage(for: projectId, type: .plan)

        #expect(hero != nil)
        #expect(hero?.id == firstImage.id)
        #expect(hero?.caption == "First")
    }

    // MARK: - Update Tests

    @Test("Update image metadata")
    func testUpdateImageMetadata() async throws {
        let imageId = UUID()
        let projectId = UUID()

        // Create original
        let original = ProjectImageModel(
            id: imageId,
            projectId: projectId,
            projectCategory: .plan,
            fileExtension: "jpg",
            caption: "Original",
            order: 0
        )
        _ = try await repository.createImageMetadata(original)

        // Update
        let updated = ProjectImageModel(
            id: imageId,
            projectId: projectId,
            projectCategory: .plan,
            fileExtension: "jpg",
            caption: "Updated",
            order: 0
        )
        try await repository.updateImageMetadata(updated)

        // Verify
        let images = try await repository.getImages(for: projectId, type: .plan)
        #expect(images.count == 1)
        #expect(images[0].caption == "Updated")
    }

    @Test("Reorder images")
    func testReorderImages() async throws {
        let projectId = UUID()
        let id1 = UUID()
        let id2 = UUID()
        let id3 = UUID()

        // Create three images
        _ = try await repository.createImageMetadata(ProjectImageModel(
            id: id1,
            projectId: projectId,
            projectCategory: .plan,
            fileExtension: "jpg",
            caption: "First",
            order: 0
        ))
        _ = try await repository.createImageMetadata(ProjectImageModel(
            id: id2,
            projectId: projectId,
            projectCategory: .plan,
            fileExtension: "jpg",
            caption: "Second",
            order: 1
        ))
        _ = try await repository.createImageMetadata(ProjectImageModel(
            id: id3,
            projectId: projectId,
            projectCategory: .plan,
            fileExtension: "jpg",
            caption: "Third",
            order: 2
        ))

        // Reorder: reverse
        try await repository.reorderImages(projectId: projectId, type: .plan, imageIds: [id3, id2, id1])

        // Verify new order
        let images = try await repository.getImages(for: projectId, type: .plan)
        #expect(images.count == 3)
        #expect(images[0].id == id3)
        #expect(images[1].id == id2)
        #expect(images[2].id == id1)
    }

    // MARK: - Delete Tests

    @Test("Delete image metadata")
    func testDeleteImageMetadata() async throws {
        let imageId = UUID()
        let projectId = UUID()

        // Create image
        let metadata = ProjectImageModel(
            id: imageId,
            projectId: projectId,
            projectCategory: .plan,
            fileExtension: "jpg",
            caption: "Test",
            order: 0
        )
        _ = try await repository.createImageMetadata(metadata)

        // Verify it exists
        var count = await repository.getImageCount()
        #expect(count == 1)

        // Delete
        try await repository.deleteImageMetadata(id: imageId)

        // Verify it's gone
        count = await repository.getImageCount()
        #expect(count == 0)

        let images = try await repository.getImages(for: projectId, type: .plan)
        #expect(images.isEmpty)
    }

    // MARK: - Helper Method Tests

    @Test("Clear all images")
    func testClearAll() async throws {
        // Create multiple images
        for i in 0..<5 {
            let metadata = ProjectImageModel(
                id: UUID(),
                projectId: UUID(),
                projectCategory: .plan,
                fileExtension: "jpg",
                caption: "Image \(i)",
                order: i
            )
            _ = try await repository.createImageMetadata(metadata)
        }

        // Verify they exist
        var count = await repository.getImageCount()
        #expect(count == 5)

        // Clear all
        await repository.clearAll()

        // Verify all gone
        count = await repository.getImageCount()
        #expect(count == 0)
    }
}
