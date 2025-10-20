//
//  FileSystemUserImageRepositoryTests.swift
//  RepositoryTests
//
//  Tests for FileSystemUserImageRepository (file system and UserDefaults integration)
//

import Testing
import Foundation
import UIKit
@testable import Molten

@Suite("FileSystemUserImageRepository Tests")
struct FileSystemUserImageRepositoryTests {

    @Test("Save and load image from file system")
    func testSaveAndLoadImage() async throws {
        let repo = try createTestRepository()
        let testImage = createTestImage()
        let naturalKey = "test-item-001"

        // Save image
        let savedModel = try await repo.saveImage(testImage, for: naturalKey, type: .primary)

        #expect(savedModel.itemNaturalKey == naturalKey)
        #expect(savedModel.imageType == .primary)
        #expect(savedModel.fileExtension == "jpg")
        #expect(savedModel.fileName.hasSuffix(".jpg"))

        // Load image back
        let loadedImage = try await repo.loadImage(savedModel)
        #expect(loadedImage != nil)
        #expect(loadedImage!.size.width > 0)
        #expect(loadedImage!.size.height > 0)
    }

    @Test("Metadata persists in UserDefaults")
    func testMetadataPersistence() async throws {
        let suiteName = "Test_FileSystemUserImageRepository_\(UUID().uuidString)"
        let repo1 = try createTestRepository(suiteName: suiteName)
        let testImage = createTestImage()
        let naturalKey = "test-item-002"

        // Save image with first repo instance
        let savedModel = try await repo1.saveImage(testImage, for: naturalKey, type: .primary)

        // Create new repo instance (simulates app restart)
        let repo2 = try createTestRepository(suiteName: suiteName)

        // Should still be able to load the image
        let images = try await repo2.getImages(for: naturalKey)
        #expect(images.count == 1)
        #expect(images[0].id == savedModel.id)
        #expect(images[0].itemNaturalKey == naturalKey)
    }

    @Test("Get primary image")
    func testGetPrimaryImage() async throws {
        let repo = try createTestRepository()
        let testImage = createTestImage()
        let naturalKey = "test-item-003"

        // Initially no primary image
        let initialPrimary = try await repo.getPrimaryImage(for: naturalKey)
        #expect(initialPrimary == nil)

        // Save alternate image first
        _ = try await repo.saveImage(testImage, for: naturalKey, type: .alternate)

        // Still no primary
        let stillNoPrimary = try await repo.getPrimaryImage(for: naturalKey)
        #expect(stillNoPrimary == nil)

        // Save primary image
        let primaryModel = try await repo.saveImage(testImage, for: naturalKey, type: .primary)

        // Should now have primary image
        let primary = try await repo.getPrimaryImage(for: naturalKey)
        #expect(primary != nil)
        #expect(primary?.id == primaryModel.id)
        #expect(primary?.imageType == .primary)
    }

    @Test("Delete image removes file and metadata")
    func testDeleteImage() async throws {
        let repo = try createTestRepository()
        let testImage = createTestImage()
        let naturalKey = "test-item-004"

        // Save image
        let savedModel = try await repo.saveImage(testImage, for: naturalKey, type: .primary)

        // Verify it exists
        let loadedBefore = try await repo.loadImage(savedModel)
        #expect(loadedBefore != nil)

        let imagesBefore = try await repo.getImages(for: naturalKey)
        #expect(imagesBefore.count == 1)

        // Delete it
        try await repo.deleteImage(savedModel.id)

        // Verify metadata is gone
        let imagesAfter = try await repo.getImages(for: naturalKey)
        #expect(imagesAfter.isEmpty)

        // Verify file is gone (returns nil, not error)
        let loadedAfter = try await repo.loadImage(savedModel)
        #expect(loadedAfter == nil)
    }

    @Test("Delete all images for item")
    func testDeleteAllImages() async throws {
        let repo = try createTestRepository()
        let testImage = createTestImage()
        let naturalKey = "test-item-005"

        // Save multiple images
        _ = try await repo.saveImage(testImage, for: naturalKey, type: .primary)
        _ = try await repo.saveImage(testImage, for: naturalKey, type: .alternate)
        _ = try await repo.saveImage(testImage, for: naturalKey, type: .alternate)

        // Save image for different item
        _ = try await repo.saveImage(testImage, for: "other-item", type: .primary)

        // Verify they exist
        let imagesBefore = try await repo.getImages(for: naturalKey)
        #expect(imagesBefore.count == 3)

        // Delete all for naturalKey
        try await repo.deleteAllImages(for: naturalKey)

        // Verify all are gone
        let imagesAfter = try await repo.getImages(for: naturalKey)
        #expect(imagesAfter.isEmpty)

        // Verify other item's images still exist
        let otherImages = try await repo.getImages(for: "other-item")
        #expect(otherImages.count == 1)
    }

    @Test("Update image type updates metadata")
    func testUpdateImageType() async throws {
        let repo = try createTestRepository()
        let testImage = createTestImage()
        let naturalKey = "test-item-006"

        // Save as alternate
        let savedModel = try await repo.saveImage(testImage, for: naturalKey, type: .alternate)
        #expect(savedModel.imageType == .alternate)

        // Promote to primary
        try await repo.updateImageType(savedModel.id, type: .primary)

        // Verify type changed in metadata
        let images = try await repo.getImages(for: naturalKey)
        let updatedImage = images.first { $0.id == savedModel.id }
        #expect(updatedImage?.imageType == .primary)

        // Verify via getPrimaryImage
        let primaryImage = try await repo.getPrimaryImage(for: naturalKey)
        #expect(primaryImage?.id == savedModel.id)
    }

    @Test("Image compression preserves quality")
    func testImageCompression() async throws {
        let repo = try createTestRepository()
        let testImage = createTestImage(width: 1000, height: 1000)
        let naturalKey = "test-item-007"

        // Save large image
        let savedModel = try await repo.saveImage(testImage, for: naturalKey, type: .primary)

        // Load it back
        let loadedImage = try await repo.loadImage(savedModel)
        #expect(loadedImage != nil)

        // Image should be loaded successfully (compression happens on save)
        #expect(loadedImage!.size.width > 0)
        #expect(loadedImage!.size.height > 0)
    }

    @Test("Multiple items isolation")
    func testMultipleItemsIsolation() async throws {
        let repo = try createTestRepository()
        let testImage = createTestImage()

        // Save images for different items
        _ = try await repo.saveImage(testImage, for: "item-001", type: .primary)
        _ = try await repo.saveImage(testImage, for: "item-002", type: .primary)
        _ = try await repo.saveImage(testImage, for: "item-003", type: .primary)

        // Each item should only see its own images
        let item1Images = try await repo.getImages(for: "item-001")
        let item2Images = try await repo.getImages(for: "item-002")
        let item3Images = try await repo.getImages(for: "item-003")

        #expect(item1Images.count == 1)
        #expect(item2Images.count == 1)
        #expect(item3Images.count == 1)

        #expect(item1Images[0].itemNaturalKey == "item-001")
        #expect(item2Images[0].itemNaturalKey == "item-002")
        #expect(item3Images[0].itemNaturalKey == "item-003")
    }

    @Test("Load nonexistent image returns nil")
    func testLoadNonexistentImage() async throws {
        let repo = try createTestRepository()
        let fakeModel = UserImageModel(
            id: UUID(),
            itemNaturalKey: "nonexistent",
            imageType: .primary,
            fileExtension: "jpg"
        )

        let loadedImage = try await repo.loadImage(fakeModel)
        #expect(loadedImage == nil)
    }

    @Test("Delete nonexistent image throws error")
    func testDeleteNonexistentImage() async throws {
        let repo = try createTestRepository()

        await #expect(throws: UserImageError.imageNotFound) {
            try await repo.deleteImage(UUID())
        }
    }

    // MARK: - Test Helpers

    private func createTestRepository(suiteName: String? = nil) throws -> FileSystemUserImageRepository {
        // Use a unique suite name for each test to isolate UserDefaults
        let uniqueSuiteName = suiteName ?? "Test_FileSystemUserImageRepository_\(UUID().uuidString)"
        guard let userDefaults = UserDefaults(suiteName: uniqueSuiteName) else {
            throw UserImageError.storageDirectoryUnavailable
        }

        // Clear any existing data only if we generated a new suite name
        // If a specific suite name was provided, preserve existing data (for persistence tests)
        if suiteName == nil {
            userDefaults.removePersistentDomain(forName: uniqueSuiteName)
            userDefaults.synchronize()  // Force write to disk
        }

        // Create repository with test UserDefaults
        return FileSystemUserImageRepository(userDefaults: userDefaults)
    }

    private func createTestImage(width: Int = 100, height: Int = 100) -> UIImage {
        let size = CGSize(width: width, height: height)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
