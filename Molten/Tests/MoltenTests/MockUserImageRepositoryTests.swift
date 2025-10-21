//
//  MockUserImageRepositoryTests.swift
//  FlameworkerTests
//
//  Tests for MockUserImageRepository
//

import Testing
import Foundation
import UIKit
@testable import Molten

@Suite("MockUserImageRepository Tests")
struct MockUserImageRepositoryTests {

    @Test("Save and load image")
    func testSaveAndLoadImage() async throws {
        let repo = MockUserImageRepository()
        let testImage = createTestImage()
        let naturalKey = "test-item-001"

        // Save image
        let savedModel = try await repo.saveImage(testImage, ownerType: .glassItem, ownerId: naturalKey, type: .primary)

        #expect(savedModel.ownerType == .glassItem)
        #expect(savedModel.ownerId == naturalKey)
        #expect(savedModel.imageType == .primary)
        #expect(savedModel.fileExtension == "jpg")

        // Load image back
        let loadedImage = try await repo.loadImage(savedModel)
        #expect(loadedImage != nil)
    }

    @Test("Get primary image")
    func testGetPrimaryImage() async throws {
        let repo = MockUserImageRepository()
        let testImage = createTestImage()
        let naturalKey = "test-item-002"

        // Initially no primary image
        let initialPrimary = try await repo.getPrimaryImage(ownerType: .glassItem, ownerId: naturalKey)
        #expect(initialPrimary == nil)

        // Save primary image
        _ = try await repo.saveImage(testImage, ownerType: .glassItem, ownerId: naturalKey, type: .primary)

        // Should now have primary image
        let primary = try await repo.getPrimaryImage(ownerType: .glassItem, ownerId: naturalKey)
        #expect(primary != nil)
        #expect(primary?.ownerId == naturalKey)
        #expect(primary?.imageType == .primary)
    }

    @Test("Get all images for item")
    func testGetAllImages() async throws {
        let repo = MockUserImageRepository()
        let testImage = createTestImage()
        let naturalKey = "test-item-003"

        // Save multiple images
        _ = try await repo.saveImage(testImage, ownerType: .glassItem, ownerId: naturalKey, type: .primary)
        _ = try await repo.saveImage(testImage, ownerType: .glassItem, ownerId: naturalKey, type: .alternate)
        _ = try await repo.saveImage(testImage, ownerType: .glassItem, ownerId: naturalKey, type: .alternate)

        // Get all images
        let images = try await repo.getImages(ownerType: .glassItem, ownerId: naturalKey)
        #expect(images.count == 3)

        let primaryImages = images.filter { $0.imageType == .primary }
        #expect(primaryImages.count == 1)

        let alternateImages = images.filter { $0.imageType == .alternate }
        #expect(alternateImages.count == 2)
    }

    @Test("Delete image")
    func testDeleteImage() async throws {
        let repo = MockUserImageRepository()
        let testImage = createTestImage()
        let naturalKey = "test-item-004"

        // Save image
        let savedModel = try await repo.saveImage(testImage, ownerType: .glassItem, ownerId: naturalKey, type: .primary)

        // Verify it exists
        let loadedBefore = try await repo.loadImage(savedModel)
        #expect(loadedBefore != nil)

        // Delete it
        try await repo.deleteImage(savedModel.id)

        // Verify it's gone (returns nil, not error)
        let loadedAfter = try await repo.loadImage(savedModel)
        #expect(loadedAfter == nil)
    }

    @Test("Delete all images for item")
    func testDeleteAllImages() async throws {
        let repo = MockUserImageRepository()
        let testImage = createTestImage()
        let naturalKey = "test-item-005"

        // Save multiple images
        _ = try await repo.saveImage(testImage, ownerType: .glassItem, ownerId: naturalKey, type: .primary)
        _ = try await repo.saveImage(testImage, ownerType: .glassItem, ownerId: naturalKey, type: .alternate)
        _ = try await repo.saveImage(testImage, ownerType: .glassItem, ownerId: naturalKey, type: .alternate)

        // Verify they exist
        let imagesBefore = try await repo.getImages(ownerType: .glassItem, ownerId: naturalKey)
        #expect(imagesBefore.count == 3)

        // Delete all
        try await repo.deleteAllImages(ownerType: .glassItem, ownerId: naturalKey)

        // Verify all are gone
        let imagesAfter = try await repo.getImages(ownerType: .glassItem, ownerId: naturalKey)
        #expect(imagesAfter.isEmpty)
    }

    @Test("Update image type")
    func testUpdateImageType() async throws {
        let repo = MockUserImageRepository()
        let testImage = createTestImage()
        let naturalKey = "test-item-006"

        // Save as alternate
        let savedModel = try await repo.saveImage(testImage, ownerType: .glassItem, ownerId: naturalKey, type: .alternate)
        #expect(savedModel.imageType == .alternate)

        // Promote to primary
        try await repo.updateImageType(savedModel.id, type: .primary)

        // Verify type changed
        let images = try await repo.getImages(ownerType: .glassItem, ownerId: naturalKey)
        let updatedImage = images.first { $0.id == savedModel.id }
        #expect(updatedImage?.imageType == .primary)
    }

    @Test("Multiple items isolation")
    func testMultipleItemsIsolation() async throws {
        let repo = MockUserImageRepository()
        let testImage = createTestImage()

        // Save images for different items
        _ = try await repo.saveImage(testImage, ownerType: .glassItem, ownerId: "item-001", type: .primary)
        _ = try await repo.saveImage(testImage, ownerType: .glassItem, ownerId: "item-002", type: .primary)
        _ = try await repo.saveImage(testImage, ownerType: .glassItem, ownerId: "item-003", type: .primary)

        // Each item should only see its own images
        let item1Images = try await repo.getImages(ownerType: .glassItem, ownerId: "item-001")
        let item2Images = try await repo.getImages(ownerType: .glassItem, ownerId: "item-002")
        let item3Images = try await repo.getImages(ownerType: .glassItem, ownerId: "item-003")

        #expect(item1Images.count == 1)
        #expect(item2Images.count == 1)
        #expect(item3Images.count == 1)

        #expect(item1Images[0].ownerId == "item-001")
        #expect(item2Images[0].ownerId == "item-002")
        #expect(item3Images[0].ownerId == "item-003")
    }

    @Test("Load nonexistent image returns nil")
    func testLoadNonexistentImage() async throws {
        let repo = MockUserImageRepository()
        let fakeModel = UserImageModel(
            id: UUID(),
            ownerType: .glassItem,
            ownerId: "nonexistent",
            imageType: .primary,
            fileExtension: "jpg",
            dateCreated: Date(),
            dateModified: Date()
        )

        let loadedImage = try await repo.loadImage(fakeModel)
        #expect(loadedImage == nil)
    }

    @Test("Delete nonexistent image throws error")
    func testDeleteNonexistentImage() async throws {
        let repo = MockUserImageRepository()

        await #expect(throws: UserImageError.imageNotFound) {
            try await repo.deleteImage(UUID())
        }
    }

    @Test("Update type of nonexistent image throws error")
    func testUpdateTypeNonexistentImage() async throws {
        let repo = MockUserImageRepository()

        await #expect(throws: UserImageError.imageNotFound) {
            try await repo.updateImageType(UUID(), type: .primary)
        }
    }

    // MARK: - Test Helpers

    private func createTestImage(width: Int = 100, height: Int = 100) -> UIImage {
        let size = CGSize(width: width, height: height)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
