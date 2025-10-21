//
//  UserImageRepositoryTests.swift
//  MoltenTests
//
//  Unit tests for UserImageRepository using mock implementation
//

import Testing
import Foundation
@testable import Molten

#if canImport(UIKit)
import UIKit

@Suite("UserImageRepository - Mock Implementation")
struct UserImageRepositoryTests {

    // MARK: - Test Setup

    func createTestImage(color: UIColor = .red, size: CGSize = CGSize(width: 100, height: 100)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    // MARK: - Save Image Tests

    @Test("Save primary image for glass item")
    func savePrimaryImageForGlassItem() async throws {
        // Given
        let repository = MockUserImageRepository()
        let testImage = createTestImage(color: .blue)
        let naturalKey = "bullseye-clear-001"

        // When
        let savedModel = try await repository.saveImage(
            testImage,
            ownerType: .glassItem,
            ownerId: naturalKey,
            type: .primary
        )

        // Then
        #expect(savedModel.ownerType == .glassItem)
        #expect(savedModel.ownerId == naturalKey)
        #expect(savedModel.imageType == .primary)
        #expect(savedModel.fileExtension == "jpg")

        // Verify image can be loaded
        let loadedImage = try await repository.loadImage(savedModel)
        #expect(loadedImage != nil)
    }

    @Test("Save alternate image for glass item")
    func saveAlternateImageForGlassItem() async throws {
        // Given
        let repository = MockUserImageRepository()
        let testImage = createTestImage(color: .green)
        let naturalKey = "bullseye-clear-001"

        // When
        let savedModel = try await repository.saveImage(
            testImage,
            ownerType: .glassItem,
            ownerId: naturalKey,
            type: .alternate
        )

        // Then
        #expect(savedModel.imageType == .alternate)
    }

    @Test("Save primary image demotes existing primary")
    func savePrimaryImageDemotesExisting() async throws {
        // Given
        let repository = MockUserImageRepository()
        let naturalKey = "bullseye-clear-001"
        let firstImage = createTestImage(color: .red)
        let secondImage = createTestImage(color: .blue)

        // When - save first primary image
        let firstModel = try await repository.saveImage(
            firstImage,
            ownerType: .glassItem,
            ownerId: naturalKey,
            type: .primary
        )

        // Then - verify first is primary
        let primaryAfterFirst = try await repository.getPrimaryImage(ownerType: .glassItem, ownerId: naturalKey)
        #expect(primaryAfterFirst?.id == firstModel.id)

        // When - save second primary image (should demote first)
        _ = try await repository.saveImage(
            secondImage,
            ownerType: .glassItem,
            ownerId: naturalKey,
            type: .primary
        )

        // Then - verify only second is primary now
        let primaryAfterSecond = try await repository.getPrimaryImage(ownerType: .glassItem, ownerId: naturalKey)
        #expect(primaryAfterSecond?.id != firstModel.id)

        // Verify both images still exist
        let allImages = try await repository.getImages(ownerType: .glassItem, ownerId: naturalKey)
        #expect(allImages.count == 2)
    }

    @Test("Save image for project plan")
    func saveImageForProjectPlan() async throws {
        // Given
        let repository = MockUserImageRepository()
        let testImage = createTestImage(color: .purple)
        let planId = UUID().uuidString

        // When
        let savedModel = try await repository.saveImage(
            testImage,
            ownerType: .projectPlan,
            ownerId: planId,
            type: .primary
        )

        // Then
        #expect(savedModel.ownerType == .projectPlan)
        #expect(savedModel.ownerId == planId)
    }

    @Test("Save standalone image")
    func saveStandaloneImage() async throws {
        // Given
        let repository = MockUserImageRepository()
        let testImage = createTestImage(color: .orange)

        // When
        let savedModel = try await repository.saveImage(
            testImage,
            ownerType: .standalone,
            ownerId: nil,
            type: .primary
        )

        // Then
        #expect(savedModel.ownerType == .standalone)
        #expect(savedModel.ownerId == nil)
    }

    // MARK: - Get Images Tests

    @Test("Get all images for owner")
    func getAllImagesForOwner() async throws {
        // Given
        let repository = MockUserImageRepository()
        let naturalKey = "bullseye-clear-001"

        // When - save multiple images
        _ = try await repository.saveImage(
            createTestImage(color: .red),
            ownerType: .glassItem,
            ownerId: naturalKey,
            type: .primary
        )
        _ = try await repository.saveImage(
            createTestImage(color: .blue),
            ownerType: .glassItem,
            ownerId: naturalKey,
            type: .alternate
        )
        _ = try await repository.saveImage(
            createTestImage(color: .green),
            ownerType: .glassItem,
            ownerId: naturalKey,
            type: .alternate
        )

        // Then
        let images = try await repository.getImages(ownerType: .glassItem, ownerId: naturalKey)
        #expect(images.count == 3)
    }

    @Test("Get images returns empty for non-existent owner")
    func getImagesReturnsEmptyForNonExistentOwner() async throws {
        // Given
        let repository = MockUserImageRepository()

        // When
        let images = try await repository.getImages(ownerType: .glassItem, ownerId: "nonexistent")

        // Then
        #expect(images.isEmpty)
    }

    @Test("Get images sorted by date created descending")
    func getImagesSortedByDateDescending() async throws {
        // Given
        let repository = MockUserImageRepository()
        let naturalKey = "bullseye-clear-001"

        // When - save images with slight delays to ensure different timestamps
        let first = try await repository.saveImage(
            createTestImage(color: .red),
            ownerType: .glassItem,
            ownerId: naturalKey,
            type: .alternate
        )
        try await Task.sleep(for: .milliseconds(10))

        let second = try await repository.saveImage(
            createTestImage(color: .blue),
            ownerType: .glassItem,
            ownerId: naturalKey,
            type: .alternate
        )
        try await Task.sleep(for: .milliseconds(10))

        let third = try await repository.saveImage(
            createTestImage(color: .green),
            ownerType: .glassItem,
            ownerId: naturalKey,
            type: .alternate
        )

        // Then - should be in reverse chronological order (newest first)
        let images = try await repository.getImages(ownerType: .glassItem, ownerId: naturalKey)
        #expect(images[0].id == third.id)
        #expect(images[1].id == second.id)
        #expect(images[2].id == first.id)
    }

    @Test("Get images filters by owner type and ID")
    func getImagesFiltersByOwner() async throws {
        // Given
        let repository = MockUserImageRepository()

        // When - save images for different owners
        _ = try await repository.saveImage(
            createTestImage(color: .red),
            ownerType: .glassItem,
            ownerId: "item-1",
            type: .primary
        )
        _ = try await repository.saveImage(
            createTestImage(color: .blue),
            ownerType: .glassItem,
            ownerId: "item-2",
            type: .primary
        )
        _ = try await repository.saveImage(
            createTestImage(color: .green),
            ownerType: .projectPlan,
            ownerId: "plan-1",
            type: .primary
        )

        // Then - each query returns only its images
        let item1Images = try await repository.getImages(ownerType: .glassItem, ownerId: "item-1")
        #expect(item1Images.count == 1)

        let item2Images = try await repository.getImages(ownerType: .glassItem, ownerId: "item-2")
        #expect(item2Images.count == 1)

        let plan1Images = try await repository.getImages(ownerType: .projectPlan, ownerId: "plan-1")
        #expect(plan1Images.count == 1)
    }

    // MARK: - Get Primary Image Tests

    @Test("Get primary image returns correct image")
    func getPrimaryImageReturnsCorrectImage() async throws {
        // Given
        let repository = MockUserImageRepository()
        let naturalKey = "bullseye-clear-001"

        // When
        let primaryModel = try await repository.saveImage(
            createTestImage(color: .red),
            ownerType: .glassItem,
            ownerId: naturalKey,
            type: .primary
        )
        _ = try await repository.saveImage(
            createTestImage(color: .blue),
            ownerType: .glassItem,
            ownerId: naturalKey,
            type: .alternate
        )

        // Then
        let retrieved = try await repository.getPrimaryImage(ownerType: .glassItem, ownerId: naturalKey)
        #expect(retrieved?.id == primaryModel.id)
        #expect(retrieved?.imageType == .primary)
    }

    @Test("Get primary image returns nil when none exists")
    func getPrimaryImageReturnsNilWhenNoneExists() async throws {
        // Given
        let repository = MockUserImageRepository()
        let naturalKey = "bullseye-clear-001"

        // When - only save alternate images
        _ = try await repository.saveImage(
            createTestImage(color: .blue),
            ownerType: .glassItem,
            ownerId: naturalKey,
            type: .alternate
        )

        // Then
        let primary = try await repository.getPrimaryImage(ownerType: .glassItem, ownerId: naturalKey)
        #expect(primary == nil)
    }

    // MARK: - Get Standalone Images Tests

    @Test("Get standalone images returns only standalone")
    func getStandaloneImagesReturnsOnlyStandalone() async throws {
        // Given
        let repository = MockUserImageRepository()

        // When - save mix of images
        _ = try await repository.saveImage(
            createTestImage(color: .red),
            ownerType: .glassItem,
            ownerId: "item-1",
            type: .primary
        )
        _ = try await repository.saveImage(
            createTestImage(color: .blue),
            ownerType: .standalone,
            ownerId: nil,
            type: .primary
        )
        _ = try await repository.saveImage(
            createTestImage(color: .green),
            ownerType: .standalone,
            ownerId: nil,
            type: .alternate
        )

        // Then
        let standaloneImages = try await repository.getStandaloneImages()
        #expect(standaloneImages.count == 2)
        #expect(standaloneImages.allSatisfy { $0.ownerType == .standalone })
    }

    // MARK: - Delete Tests

    @Test("Delete image by ID")
    func deleteImageById() async throws {
        // Given
        let repository = MockUserImageRepository()
        let naturalKey = "bullseye-clear-001"
        let savedModel = try await repository.saveImage(
            createTestImage(color: .red),
            ownerType: .glassItem,
            ownerId: naturalKey,
            type: .primary
        )

        // When
        try await repository.deleteImage(savedModel.id)

        // Then - image should be gone
        let images = try await repository.getImages(ownerType: .glassItem, ownerId: naturalKey)
        #expect(images.isEmpty)
    }

    @Test("Delete non-existent image throws error")
    func deleteNonExistentImageThrowsError() async throws {
        // Given
        let repository = MockUserImageRepository()
        let nonExistentId = UUID()

        // When/Then
        await #expect(throws: UserImageError.imageNotFound) {
            try await repository.deleteImage(nonExistentId)
        }
    }

    @Test("Delete all images for owner")
    func deleteAllImagesForOwner() async throws {
        // Given
        let repository = MockUserImageRepository()
        let naturalKey = "bullseye-clear-001"

        // When - save multiple images
        _ = try await repository.saveImage(
            createTestImage(color: .red),
            ownerType: .glassItem,
            ownerId: naturalKey,
            type: .primary
        )
        _ = try await repository.saveImage(
            createTestImage(color: .blue),
            ownerType: .glassItem,
            ownerId: naturalKey,
            type: .alternate
        )
        _ = try await repository.saveImage(
            createTestImage(color: .green),
            ownerType: .glassItem,
            ownerId: "other-item",
            type: .primary
        )

        // When - delete all for specific owner
        try await repository.deleteAllImages(ownerType: .glassItem, ownerId: naturalKey)

        // Then - only that owner's images are deleted
        let deletedOwnerImages = try await repository.getImages(ownerType: .glassItem, ownerId: naturalKey)
        #expect(deletedOwnerImages.isEmpty)

        let otherOwnerImages = try await repository.getImages(ownerType: .glassItem, ownerId: "other-item")
        #expect(otherOwnerImages.count == 1)
    }

    // MARK: - Update Image Type Tests

    @Test("Update image type from alternate to primary")
    func updateImageTypeFromAlternateToPrimary() async throws {
        // Given
        let repository = MockUserImageRepository()
        let naturalKey = "bullseye-clear-001"
        let savedModel = try await repository.saveImage(
            createTestImage(color: .red),
            ownerType: .glassItem,
            ownerId: naturalKey,
            type: .alternate
        )

        // When
        try await repository.updateImageType(savedModel.id, type: .primary)

        // Then
        let primary = try await repository.getPrimaryImage(ownerType: .glassItem, ownerId: naturalKey)
        #expect(primary?.id == savedModel.id)
    }

    @Test("Update to primary demotes existing primary")
    func updateToPrimaryDemotesExisting() async throws {
        // Given
        let repository = MockUserImageRepository()
        let naturalKey = "bullseye-clear-001"

        let existingPrimary = try await repository.saveImage(
            createTestImage(color: .red),
            ownerType: .glassItem,
            ownerId: naturalKey,
            type: .primary
        )
        let alternate = try await repository.saveImage(
            createTestImage(color: .blue),
            ownerType: .glassItem,
            ownerId: naturalKey,
            type: .alternate
        )

        // When - promote alternate to primary
        try await repository.updateImageType(alternate.id, type: .primary)

        // Then - new one is primary
        let primary = try await repository.getPrimaryImage(ownerType: .glassItem, ownerId: naturalKey)
        #expect(primary?.id == alternate.id)

        // And old primary is demoted
        let allImages = try await repository.getImages(ownerType: .glassItem, ownerId: naturalKey)
        let oldPrimaryImage = allImages.first { $0.id == existingPrimary.id }
        #expect(oldPrimaryImage?.imageType == .alternate)
    }

    @Test("Update non-existent image throws error")
    func updateNonExistentImageThrowsError() async throws {
        // Given
        let repository = MockUserImageRepository()
        let nonExistentId = UUID()

        // When/Then
        await #expect(throws: UserImageError.imageNotFound) {
            try await repository.updateImageType(nonExistentId, type: .primary)
        }
    }

    // MARK: - Load Image Tests

    @Test("Load image returns correct image data")
    func loadImageReturnsCorrectImageData() async throws {
        // Given
        let repository = MockUserImageRepository()
        let testImage = createTestImage(color: .red, size: CGSize(width: 100, height: 100))
        let naturalKey = "bullseye-clear-001"

        // When
        let savedModel = try await repository.saveImage(
            testImage,
            ownerType: .glassItem,
            ownerId: naturalKey,
            type: .primary
        )

        // Then
        let loadedImage = try await repository.loadImage(savedModel)
        #expect(loadedImage != nil)
        #expect(loadedImage?.size == testImage.size)
    }

    @Test("Load image for non-existent model returns nil")
    func loadImageForNonExistentModelReturnsNil() async throws {
        // Given
        let repository = MockUserImageRepository()
        let nonExistentModel = UserImageModel(
            id: UUID(),
            ownerType: .glassItem,
            ownerId: "nonexistent",
            imageType: .primary,
            fileExtension: "jpg"
        )

        // When
        let loadedImage = try await repository.loadImage(nonExistentModel)

        // Then
        #expect(loadedImage == nil)
    }

    // MARK: - Test Helpers

    @Test("Reset clears all images")
    func resetClearsAllImages() async throws {
        // Given
        let repository = MockUserImageRepository()
        _ = try await repository.saveImage(
            createTestImage(color: .red),
            ownerType: .glassItem,
            ownerId: "item-1",
            type: .primary
        )
        _ = try await repository.saveImage(
            createTestImage(color: .blue),
            ownerType: .projectPlan,
            ownerId: "plan-1",
            type: .primary
        )

        // When
        await repository.reset()

        // Then
        let count = await repository.getImageCount()
        #expect(count == 0)
    }

    // MARK: - Complex Scenarios

    @Test("Multiple items with their own primary images")
    func multipleItemsWithOwnPrimaryImages() async throws {
        // Given
        let repository = MockUserImageRepository()

        // When - save primary for multiple items
        _ = try await repository.saveImage(
            createTestImage(color: .red),
            ownerType: .glassItem,
            ownerId: "item-1",
            type: .primary
        )
        _ = try await repository.saveImage(
            createTestImage(color: .blue),
            ownerType: .glassItem,
            ownerId: "item-2",
            type: .primary
        )
        _ = try await repository.saveImage(
            createTestImage(color: .green),
            ownerType: .glassItem,
            ownerId: "item-3",
            type: .primary
        )

        // Then - each has its own primary
        let count = await repository.getImageCount()
        #expect(count == 3)

        let primary1 = try await repository.getPrimaryImage(ownerType: .glassItem, ownerId: "item-1")
        let primary2 = try await repository.getPrimaryImage(ownerType: .glassItem, ownerId: "item-2")
        let primary3 = try await repository.getPrimaryImage(ownerType: .glassItem, ownerId: "item-3")

        #expect(primary1 != nil)
        #expect(primary2 != nil)
        #expect(primary3 != nil)
    }

    @Test("Item with mixed primary and alternate images")
    func itemWithMixedPrimaryAndAlternateImages() async throws {
        // Given
        let repository = MockUserImageRepository()
        let naturalKey = "bullseye-clear-001"

        // When - save mixed images
        _ = try await repository.saveImage(
            createTestImage(color: .red),
            ownerType: .glassItem,
            ownerId: naturalKey,
            type: .primary
        )
        _ = try await repository.saveImage(
            createTestImage(color: .blue),
            ownerType: .glassItem,
            ownerId: naturalKey,
            type: .alternate
        )
        _ = try await repository.saveImage(
            createTestImage(color: .green),
            ownerType: .glassItem,
            ownerId: naturalKey,
            type: .alternate
        )

        // Then
        let images = try await repository.getImages(ownerType: .glassItem, ownerId: naturalKey)
        let primaryImage = try await repository.getPrimaryImage(ownerType: .glassItem, ownerId: naturalKey)

        #expect(images.count == 3)
        #expect(images.filter { $0.imageType == .primary }.count == 1)
        #expect(images.filter { $0.imageType == .alternate }.count == 2)
        #expect(primaryImage != nil)
    }
}
#endif
