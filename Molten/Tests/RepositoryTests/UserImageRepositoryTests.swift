//
//  UserImageRepositoryTests.swift
//  Flameworker
//
//  Tests for UserImageRepository implementations (Mock and Core Data)
//

#if canImport(Testing)
import Testing
import Foundation
import UIKit
@testable import Molten

@Suite("UserImageRepository Tests")
struct UserImageRepositoryTests {

    // MARK: - Test Helpers

    func createTestImage(width: Int = 100, height: Int = 100, color: UIColor = .red) -> UIImage {
        let size = CGSize(width: width, height: height)
        UIGraphicsBeginImageContext(size)
        color.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image ?? UIImage()
    }

    // MARK: - Save Image Tests

    @Test("Save primary image successfully")
    func testSavePrimaryImage() async throws {
        let repository = MockUserImageRepository()
        let image = createTestImage(color: .blue)

        let model = try await repository.saveImage(image, ownerType: .glassItem, ownerId: "be-clear-000", type: .primary)

        #expect(model.ownerType == .glassItem)
        #expect(model.ownerId == "be-clear-000")
        #expect(model.imageType == .primary)
        #expect(model.fileExtension == "jpg")
        #expect(await repository.getImageCount() == 1)
    }

    @Test("Save alternate image successfully")
    func testSaveAlternateImage() async throws {
        let repository = MockUserImageRepository()
        let image = createTestImage(color: .green)

        let model = try await repository.saveImage(image, ownerType: .glassItem, ownerId: "cim-007-000", type: .alternate)

        #expect(model.ownerType == .glassItem)
        #expect(model.ownerId == "cim-007-000")
        #expect(model.imageType == .alternate)
        #expect(await repository.getImageCount() == 1)
    }

    @Test("Save multiple alternate images for same item")
    func testSaveMultipleAlternateImages() async throws {
        let repository = MockUserImageRepository()

        let image1 = createTestImage(color: .red)
        let image2 = createTestImage(color: .blue)
        let image3 = createTestImage(color: .green)

        _ = try await repository.saveImage(image1, ownerType: .glassItem, ownerId: "be-clear-000", type: .alternate)
        _ = try await repository.saveImage(image2, ownerType: .glassItem, ownerId: "be-clear-000", type: .alternate)
        _ = try await repository.saveImage(image3, ownerType: .glassItem, ownerId: "be-clear-000", type: .alternate)

        #expect(await repository.getImageCount() == 3)

        let images = try await repository.getImages(ownerType: .glassItem, ownerId: "be-clear-000")
        #expect(images.count == 3)
        #expect(images.allSatisfy { $0.imageType == .alternate })
    }

    @Test("Save new primary image replaces existing primary")
    func testSaveNewPrimaryReplacesExisting() async throws {
        let repository = MockUserImageRepository()

        let image1 = createTestImage(color: .red)
        let image2 = createTestImage(color: .blue)

        let model1 = try await repository.saveImage(image1, ownerType: .glassItem, ownerId: "be-clear-000", type: .primary)
        let model2 = try await repository.saveImage(image2, ownerType: .glassItem, ownerId: "be-clear-000", type: .primary)

        #expect(await repository.getImageCount() == 1)

        let primaryImage = try await repository.getPrimaryImage(ownerType: .glassItem, ownerId: "be-clear-000")
        #expect(primaryImage?.id == model2.id)
        #expect(primaryImage?.imageType == .primary)
    }

    // MARK: - Load Image Tests

    @Test("Load saved image successfully")
    func testLoadImage() async throws {
        let repository = MockUserImageRepository()
        let originalImage = createTestImage(width: 50, height: 50, color: .blue)

        let model = try await repository.saveImage(originalImage, ownerType: .glassItem, ownerId: "be-clear-000", type: .primary)
        let loadedImage = try await repository.loadImage(model)

        #expect(loadedImage != nil)
        #expect(loadedImage?.size.width == 50)
        #expect(loadedImage?.size.height == 50)
    }

    @Test("Load non-existent image returns nil")
    func testLoadNonExistentImage() async throws {
        let repository = MockUserImageRepository()
        let model = UserImageModel(ownerType: .glassItem, ownerId: "be-clear-000", imageType: .primary, fileExtension: "jpg")

        let loadedImage = try await repository.loadImage(model)

        #expect(loadedImage == nil)
    }

    // MARK: - Get Images Tests

    @Test("Get images for item with multiple images")
    func testGetImagesForItem() async throws {
        let repository = MockUserImageRepository()

        let image1 = createTestImage(color: .red)
        let image2 = createTestImage(color: .blue)
        let image3 = createTestImage(color: .green)

        _ = try await repository.saveImage(image1, ownerType: .glassItem, ownerId: "be-clear-000", type: .primary)
        _ = try await repository.saveImage(image2, ownerType: .glassItem, ownerId: "be-clear-000", type: .alternate)
        _ = try await repository.saveImage(image3, ownerType: .glassItem, ownerId: "be-clear-000", type: .alternate)

        let images = try await repository.getImages(ownerType: .glassItem, ownerId: "be-clear-000")

        #expect(images.count == 3)
        #expect(images.contains { $0.imageType == .primary })
        #expect(images.filter { $0.imageType == .alternate }.count == 2)
    }

    @Test("Get images returns empty array for item with no images")
    func testGetImagesNoImages() async throws {
        let repository = MockUserImageRepository()

        let images = try await repository.getImages(ownerType: .glassItem, ownerId: "be-clear-000")

        #expect(images.isEmpty)
    }

    @Test("Get images only returns images for specified item")
    func testGetImagesFiltersByItem() async throws {
        let repository = MockUserImageRepository()

        let image1 = createTestImage(color: .red)
        let image2 = createTestImage(color: .blue)

        _ = try await repository.saveImage(image1, ownerType: .glassItem, ownerId: "be-clear-000", type: .primary)
        _ = try await repository.saveImage(image2, ownerType: .glassItem, ownerId: "cim-007-000", type: .primary)

        let item1Images = try await repository.getImages(ownerType: .glassItem, ownerId: "be-clear-000")
        let item2Images = try await repository.getImages(ownerType: .glassItem, ownerId: "cim-007-000")

        #expect(item1Images.count == 1)
        #expect(item2Images.count == 1)
        #expect(item1Images.first?.ownerId == "be-clear-000")
        #expect(item2Images.first?.ownerId == "cim-007-000")
    }

    @Test("Get images sorted by date added descending")
    func testGetImagesSortedByDate() async throws {
        let repository = MockUserImageRepository()

        let image1 = createTestImage(color: .red)
        _ = try await repository.saveImage(image1, ownerType: .glassItem, ownerId: "be-clear-000", type: .alternate)

        try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds

        let image2 = createTestImage(color: .blue)
        _ = try await repository.saveImage(image2, ownerType: .glassItem, ownerId: "be-clear-000", type: .alternate)

        try await Task.sleep(nanoseconds: 10_000_000)

        let image3 = createTestImage(color: .green)
        _ = try await repository.saveImage(image3, ownerType: .glassItem, ownerId: "be-clear-000", type: .alternate)

        let images = try await repository.getImages(ownerType: .glassItem, ownerId: "be-clear-000")

        #expect(images.count == 3)
        // Most recent should be first
        #expect(images[0].dateCreated >= images[1].dateCreated)
        #expect(images[1].dateCreated >= images[2].dateCreated)
    }

    // MARK: - Get Primary Image Tests

    @Test("Get primary image successfully")
    func testGetPrimaryImage() async throws {
        let repository = MockUserImageRepository()

        let primaryImage = createTestImage(color: .red)
        let alternateImage = createTestImage(color: .blue)

        let primaryModel = try await repository.saveImage(primaryImage, ownerType: .glassItem, ownerId: "be-clear-000", type: .primary)
        _ = try await repository.saveImage(alternateImage, ownerType: .glassItem, ownerId: "be-clear-000", type: .alternate)

        let fetched = try await repository.getPrimaryImage(ownerType: .glassItem, ownerId: "be-clear-000")

        #expect(fetched?.id == primaryModel.id)
        #expect(fetched?.imageType == .primary)
    }

    @Test("Get primary image returns nil when no primary exists")
    func testGetPrimaryImageNoPrimary() async throws {
        let repository = MockUserImageRepository()

        let alternateImage = createTestImage(color: .blue)
        _ = try await repository.saveImage(alternateImage, ownerType: .glassItem, ownerId: "be-clear-000", type: .alternate)

        let fetched = try await repository.getPrimaryImage(ownerType: .glassItem, ownerId: "be-clear-000")

        #expect(fetched == nil)
    }

    @Test("Get primary image returns nil for item with no images")
    func testGetPrimaryImageNoImages() async throws {
        let repository = MockUserImageRepository()

        let fetched = try await repository.getPrimaryImage(ownerType: .glassItem, ownerId: "be-clear-000")

        #expect(fetched == nil)
    }

    // MARK: - Delete Image Tests

    @Test("Delete image successfully")
    func testDeleteImage() async throws {
        let repository = MockUserImageRepository()

        let image = createTestImage(color: .red)
        let model = try await repository.saveImage(image, ownerType: .glassItem, ownerId: "be-clear-000", type: .primary)

        #expect(await repository.getImageCount() == 1)

        try await repository.deleteImage(model.id)

        #expect(await repository.getImageCount() == 0)
        let images = try await repository.getImages(ownerType: .glassItem, ownerId: "be-clear-000")
        #expect(images.isEmpty)
    }

    @Test("Delete non-existent image throws error")
    func testDeleteNonExistentImage() async throws {
        let repository = MockUserImageRepository()

        await #expect(throws: UserImageError.imageNotFound) {
            try await repository.deleteImage(UUID())
        }
    }

    @Test("Delete one image leaves others intact")
    func testDeleteOneImageLeavesOthers() async throws {
        let repository = MockUserImageRepository()

        let image1 = createTestImage(color: .red)
        let image2 = createTestImage(color: .blue)

        let model1 = try await repository.saveImage(image1, ownerType: .glassItem, ownerId: "be-clear-000", type: .primary)
        _ = try await repository.saveImage(image2, ownerType: .glassItem, ownerId: "be-clear-000", type: .alternate)

        #expect(await repository.getImageCount() == 2)

        try await repository.deleteImage(model1.id)

        #expect(await repository.getImageCount() == 1)
        let images = try await repository.getImages(ownerType: .glassItem, ownerId: "be-clear-000")
        #expect(images.count == 1)
        #expect(images.first?.imageType == .alternate)
    }

    // MARK: - Delete All Images Tests

    @Test("Delete all images for item")
    func testDeleteAllImagesForItem() async throws {
        let repository = MockUserImageRepository()

        let image1 = createTestImage(color: .red)
        let image2 = createTestImage(color: .blue)
        let image3 = createTestImage(color: .green)

        _ = try await repository.saveImage(image1, ownerType: .glassItem, ownerId: "be-clear-000", type: .primary)
        _ = try await repository.saveImage(image2, ownerType: .glassItem, ownerId: "be-clear-000", type: .alternate)
        _ = try await repository.saveImage(image3, ownerType: .glassItem, ownerId: "be-clear-000", type: .alternate)

        #expect(await repository.getImageCount() == 3)

        try await repository.deleteAllImages(ownerType: .glassItem, ownerId: "be-clear-000")

        #expect(await repository.getImageCount() == 0)
        let images = try await repository.getImages(ownerType: .glassItem, ownerId: "be-clear-000")
        #expect(images.isEmpty)
    }

    @Test("Delete all images only affects specified item")
    func testDeleteAllImagesOnlyAffectsItem() async throws {
        let repository = MockUserImageRepository()

        let image1 = createTestImage(color: .red)
        let image2 = createTestImage(color: .blue)

        _ = try await repository.saveImage(image1, ownerType: .glassItem, ownerId: "be-clear-000", type: .primary)
        _ = try await repository.saveImage(image2, ownerType: .glassItem, ownerId: "cim-007-000", type: .primary)

        try await repository.deleteAllImages(ownerType: .glassItem, ownerId: "be-clear-000")

        #expect(await repository.getImageCount() == 1)
        let remainingImages = try await repository.getImages(ownerType: .glassItem, ownerId: "cim-007-000")
        #expect(remainingImages.count == 1)
    }

    @Test("Delete all images for item with no images succeeds")
    func testDeleteAllImagesNoImages() async throws {
        let repository = MockUserImageRepository()

        try await repository.deleteAllImages(ownerType: .glassItem, ownerId: "be-clear-000")

        #expect(await repository.getImageCount() == 0)
    }

    // MARK: - Update Image Type Tests

    @Test("Update image type from alternate to primary")
    func testUpdateImageTypeToPrimary() async throws {
        let repository = MockUserImageRepository()

        let image = createTestImage(color: .red)
        let model = try await repository.saveImage(image, ownerType: .glassItem, ownerId: "be-clear-000", type: .alternate)

        try await repository.updateImageType(model.id, type: .primary)

        let updated = try await repository.getPrimaryImage(ownerType: .glassItem, ownerId: "be-clear-000")
        #expect(updated?.id == model.id)
        #expect(updated?.imageType == .primary)
    }

    @Test("Update image type from primary to alternate")
    func testUpdateImageTypeToAlternate() async throws {
        let repository = MockUserImageRepository()

        let image = createTestImage(color: .red)
        let model = try await repository.saveImage(image, ownerType: .glassItem, ownerId: "be-clear-000", type: .primary)

        try await repository.updateImageType(model.id, type: .alternate)

        let primary = try await repository.getPrimaryImage(ownerType: .glassItem, ownerId: "be-clear-000")
        #expect(primary == nil)

        let images = try await repository.getImages(ownerType: .glassItem, ownerId: "be-clear-000")
        #expect(images.count == 1)
        #expect(images.first?.imageType == .alternate)
    }

    @Test("Promote alternate to primary demotes existing primary")
    func testPromoteAlternateDemotesExistingPrimary() async throws {
        let repository = MockUserImageRepository()

        let image1 = createTestImage(color: .red)
        let image2 = createTestImage(color: .blue)

        let model1 = try await repository.saveImage(image1, ownerType: .glassItem, ownerId: "be-clear-000", type: .primary)
        let model2 = try await repository.saveImage(image2, ownerType: .glassItem, ownerId: "be-clear-000", type: .alternate)

        try await repository.updateImageType(model2.id, type: .primary)

        let primary = try await repository.getPrimaryImage(ownerType: .glassItem, ownerId: "be-clear-000")
        #expect(primary?.id == model2.id)

        let images = try await repository.getImages(ownerType: .glassItem, ownerId: "be-clear-000")
        let alternates = images.filter { $0.imageType == .alternate }
        #expect(alternates.count == 1)
        #expect(alternates.first?.id == model1.id)
    }

    @Test("Update image type on non-existent image throws error")
    func testUpdateImageTypeNonExistent() async throws {
        let repository = MockUserImageRepository()

        await #expect(throws: UserImageError.imageNotFound) {
            try await repository.updateImageType(UUID(), type: .primary)
        }
    }

    @Test("Update image type updates dateModified")
    func testUpdateImageTypeUpdatesDateModified() async throws {
        let repository = MockUserImageRepository()

        let image = createTestImage(color: .red)
        let model = try await repository.saveImage(image, ownerType: .glassItem, ownerId: "be-clear-000", type: .alternate)

        let originalDateModified = model.dateModified

        try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds

        try await repository.updateImageType(model.id, type: .primary)

        let images = try await repository.getImages(ownerType: .glassItem, ownerId: "be-clear-000")
        let updated = images.first { $0.id == model.id }

        #expect(updated != nil)
        #expect(updated!.dateModified > originalDateModified)
    }

    // MARK: - Complex Scenarios

    @Test("Multiple items with their own primary images")
    func testMultipleItemsWithPrimaryImages() async throws {
        let repository = MockUserImageRepository()

        let image1 = createTestImage(color: .red)
        let image2 = createTestImage(color: .blue)
        let image3 = createTestImage(color: .green)

        _ = try await repository.saveImage(image1, ownerType: .glassItem, ownerId: "be-clear-000", type: .primary)
        _ = try await repository.saveImage(image2, ownerType: .glassItem, ownerId: "cim-007-000", type: .primary)
        _ = try await repository.saveImage(image3, ownerType: .glassItem, ownerId: "ef-striking-000", type: .primary)

        #expect(await repository.getImageCount() == 3)

        let primary1 = try await repository.getPrimaryImage(ownerType: .glassItem, ownerId: "be-clear-000")
        let primary2 = try await repository.getPrimaryImage(ownerType: .glassItem, ownerId: "cim-007-000")
        let primary3 = try await repository.getPrimaryImage(ownerType: .glassItem, ownerId: "ef-striking-000")

        #expect(primary1 != nil)
        #expect(primary2 != nil)
        #expect(primary3 != nil)
        #expect(primary1?.ownerId == "be-clear-000")
        #expect(primary2?.ownerId == "cim-007-000")
        #expect(primary3?.ownerId == "ef-striking-000")
    }

    @Test("Item with mixed primary and alternate images")
    func testItemWithMixedImages() async throws {
        let repository = MockUserImageRepository()

        let primary = createTestImage(color: .red)
        let alt1 = createTestImage(color: .blue)
        let alt2 = createTestImage(color: .green)
        let alt3 = createTestImage(color: .yellow)

        _ = try await repository.saveImage(primary, ownerType: .glassItem, ownerId: "be-clear-000", type: .primary)
        _ = try await repository.saveImage(alt1, ownerType: .glassItem, ownerId: "be-clear-000", type: .alternate)
        _ = try await repository.saveImage(alt2, ownerType: .glassItem, ownerId: "be-clear-000", type: .alternate)
        _ = try await repository.saveImage(alt3, ownerType: .glassItem, ownerId: "be-clear-000", type: .alternate)

        let images = try await repository.getImages(ownerType: .glassItem, ownerId: "be-clear-000")
        let primaryImage = try await repository.getPrimaryImage(ownerType: .glassItem, ownerId: "be-clear-000")

        #expect(images.count == 4)
        #expect(images.filter { $0.imageType == .primary }.count == 1)
        #expect(images.filter { $0.imageType == .alternate }.count == 3)
        #expect(primaryImage != nil)
    }

    @Test("Reset clears all images")
    func testReset() async throws {
        let repository = MockUserImageRepository()

        let image1 = createTestImage(color: .red)
        let image2 = createTestImage(color: .blue)
        let image3 = createTestImage(color: .green)

        _ = try await repository.saveImage(image1, ownerType: .glassItem, ownerId: "be-clear-000", type: .primary)
        _ = try await repository.saveImage(image2, ownerType: .glassItem, ownerId: "cim-007-000", type: .primary)
        _ = try await repository.saveImage(image3, ownerType: .glassItem, ownerId: "ef-striking-000", type: .alternate)

        #expect(await repository.getImageCount() == 3)

        await repository.reset()

        #expect(await repository.getImageCount() == 0)
        let images1 = try await repository.getImages(ownerType: .glassItem, ownerId: "be-clear-000")
        let images2 = try await repository.getImages(ownerType: .glassItem, ownerId: "cim-007-000")
        let images3 = try await repository.getImages(ownerType: .glassItem, ownerId: "ef-striking-000")
        #expect(images1.isEmpty)
        #expect(images2.isEmpty)
        #expect(images3.isEmpty)
    }
}
#endif
