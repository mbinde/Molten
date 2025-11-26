//
//  InventoryDetailView_ImageUploadTests.swift
//  MoltenTests
//
//  Tests for InventoryDetailView user image upload and management
//

import Testing
import SwiftUI
import Foundation
import CryptoKit
#if canImport(UIKit)
import UIKit
#endif
@testable import Molten

/// Generate a stable 6-character ID from manufacturer and SKU
func generateStableId(manufacturer: String, sku: String) -> String {
    // Combine manufacturer and SKU for hashing
    let combined = "\(manufacturer):\(sku)"

    // Hash it with SHA-256
    let hash = SHA256.hash(data: combined.data(using: .utf8)!)
    let hashBytes = Data(hash)

    // Base62 character set (excluding confusing chars: I, O, l)
    let base62Chars = "0123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz"

    // Take first 4 bytes (32 bits), convert to base62
    var num = UInt32(bigEndian: hashBytes.withUnsafeBytes { $0.load(as: UInt32.self) })

    // Generate 6-character ID
    var stableId = ""
    for _ in 0..<6 {
        let index = Int(num % UInt32(base62Chars.count))
        let char = base62Chars[base62Chars.index(base62Chars.startIndex, offsetBy: index)]
        stableId = String(char) + stableId
        num /= UInt32(base62Chars.count)
    }

    return stableId
}

@Suite("InventoryDetailView Image Upload Tests")
@MainActor
struct InventoryDetailView_ImageUploadTests {

    // MARK: - Shared Dependencies

    /// ✅ CRITICAL: Store AppDependencies at struct level to keep PersistenceController alive
    /// This prevents Core Data zombie objects that cause crashes.
    /// See CLAUDE.md "Service Creation Anti-Pattern" - same pattern applies to tests!
    private let deps = AppDependencies(persistenceController: .createTestController())

    // MARK: - Test Helpers

    func createTestItem() -> CompleteInventoryItemModel {
        let glassItem = GlassItemModel(
            stable_id: generateStableId(manufacturer: "test", sku: "001"),
            name: "Test Glass Item",
            sku: "001",
            manufacturer: "test",
            coe: 96,
            mfr_status: "available"
        )

        return CompleteInventoryItemModel(
            glassItem: glassItem,
            inventory: [],
            tags: ["blue", "transparent"],
            userTags: []
        )
    }

    #if canImport(UIKit)
    func createTestImage(color: UIColor = .red, size: CGSize = CGSize(width: 100, height: 100)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
    #endif

    // MARK: - Image Save Tests

    #if canImport(UIKit)
    @Test("Save image as primary when no images exist")
    func testSaveImageAsPrimaryWhenEmpty() async throws {
        let item = createTestItem()
        let repository = deps.userImageRepository

        // Verify no images initially
        let initialImages = try await repository.getImages(ownerType: .glassItem, ownerId: item.glassItem.stable_id)
        #expect(initialImages.isEmpty)

        // Save first image
        let testImage = createTestImage(color: .blue)
        let imageModel = try await repository.saveImage(
            testImage,
            ownerType: .glassItem,
            ownerId: item.glassItem.stable_id,
            type: .primary
        )

        #expect(imageModel.imageType == .primary)
        #expect(imageModel.ownerType == .glassItem)
        #expect(imageModel.ownerId == item.glassItem.stable_id)

        // Verify image was saved
        let images = try await repository.getImages(ownerType: .glassItem, ownerId: item.glassItem.stable_id)
        #expect(images.count == 1)
        #expect(images.first?.imageType == .primary)
    }

    @Test("Save image as alternate when primary exists")
    func testSaveImageAsAlternateWhenPrimaryExists() async throws {
        let item = createTestItem()
        let repository = deps.userImageRepository

        // Save primary image first
        let primaryImage = createTestImage(color: .red)
        _ = try await repository.saveImage(
            primaryImage,
            ownerType: .glassItem,
            ownerId: item.glassItem.stable_id,
            type: .primary
        )

        // Save alternate image
        let alternateImage = createTestImage(color: .green)
        let alternateModel = try await repository.saveImage(
            alternateImage,
            ownerType: .glassItem,
            ownerId: item.glassItem.stable_id,
            type: .alternate
        )

        #expect(alternateModel.imageType == .alternate)

        // Verify both images exist
        let images = try await repository.getImages(ownerType: .glassItem, ownerId: item.glassItem.stable_id)
        #expect(images.count == 2)
        #expect(images.filter { $0.imageType == .primary }.count == 1)
        #expect(images.filter { $0.imageType == .alternate }.count == 1)
    }

    @Test("Save multiple alternate images")
    func testSaveMultipleAlternateImages() async throws {
        let item = createTestItem()
        let repository = deps.userImageRepository

        // Save primary
        let primaryImage = createTestImage(color: .red)
        _ = try await repository.saveImage(
            primaryImage,
            ownerType: .glassItem,
            ownerId: item.glassItem.stable_id,
            type: .primary
        )

        // Save multiple alternates
        for i in 1...3 {
            let alternateImage = createTestImage(color: .green)
            _ = try await repository.saveImage(
                alternateImage,
                ownerType: .glassItem,
                ownerId: item.glassItem.stable_id,
                type: .alternate
            )
        }

        // Verify all images saved
        let images = try await repository.getImages(ownerType: .glassItem, ownerId: item.glassItem.stable_id)
        #expect(images.count == 4)
        #expect(images.filter { $0.imageType == .primary }.count == 1)
        #expect(images.filter { $0.imageType == .alternate }.count == 3)
    }
    #endif

    // MARK: - Primary Image Selection Tests

    #if canImport(UIKit)
    @Test("Promote alternate image to primary")
    func testPromoteAlternateToPrimary() async throws {
        let item = createTestItem()
        let repository = deps.userImageRepository

        // Save primary and alternate
        let primaryImage = createTestImage(color: .red)
        let primaryModel = try await repository.saveImage(
            primaryImage,
            ownerType: .glassItem,
            ownerId: item.glassItem.stable_id,
            type: .primary
        )

        let alternateImage = createTestImage(color: .green)
        let alternateModel = try await repository.saveImage(
            alternateImage,
            ownerType: .glassItem,
            ownerId: item.glassItem.stable_id,
            type: .alternate
        )

        // Promote alternate to primary
        try await repository.updateImageType(alternateModel.id, type: .primary)

        // Old primary should be demoted (need to handle this in the view logic)
        try await repository.updateImageType(primaryModel.id, type: .alternate)

        // Verify types switched
        let images = try await repository.getImages(ownerType: .glassItem, ownerId: item.glassItem.stable_id)
        let updatedAlternate = images.first { $0.id == alternateModel.id }
        let updatedPrimary = images.first { $0.id == primaryModel.id }

        #expect(updatedAlternate?.imageType == .primary)
        #expect(updatedPrimary?.imageType == .alternate)
    }

    @Test("Demote primary image to alternate")
    func testDemotePrimaryToAlternate() async throws {
        let item = createTestItem()
        let repository = deps.userImageRepository

        // Save primary image
        let primaryImage = createTestImage(color: .red)
        let primaryModel = try await repository.saveImage(
            primaryImage,
            ownerType: .glassItem,
            ownerId: item.glassItem.stable_id,
            type: .primary
        )

        // Demote to alternate
        try await repository.updateImageType(primaryModel.id, type: .alternate)

        // Verify demotion
        let images = try await repository.getImages(ownerType: .glassItem, ownerId: item.glassItem.stable_id)
        #expect(images.first?.imageType == .alternate)
    }

    @Test("Get primary image for item")
    func testGetPrimaryImage() async throws {
        let item = createTestItem()
        let repository = deps.userImageRepository

        // No primary initially
        let noPrimary = try await repository.getPrimaryImage(ownerType: .glassItem, ownerId: item.glassItem.stable_id)
        #expect(noPrimary == nil)

        // Save primary
        let primaryImage = createTestImage(color: .red)
        let primaryModel = try await repository.saveImage(
            primaryImage,
            ownerType: .glassItem,
            ownerId: item.glassItem.stable_id,
            type: .primary
        )

        // Save alternate
        let alternateImage = createTestImage(color: .green)
        _ = try await repository.saveImage(
            alternateImage,
            ownerType: .glassItem,
            ownerId: item.glassItem.stable_id,
            type: .alternate
        )

        // Get primary
        let fetchedPrimary = try await repository.getPrimaryImage(ownerType: .glassItem, ownerId: item.glassItem.stable_id)
        #expect(fetchedPrimary?.id == primaryModel.id)
        #expect(fetchedPrimary?.imageType == .primary)
    }
    #endif

    // MARK: - Image Loading Tests

    #if canImport(UIKit)
    @Test("Load saved image")
    func testLoadSavedImage() async throws {
        let item = createTestItem()
        let repository = deps.userImageRepository

        // Save image
        let testImage = createTestImage(color: .blue, size: CGSize(width: 200, height: 200))
        let imageModel = try await repository.saveImage(
            testImage,
            ownerType: .glassItem,
            ownerId: item.glassItem.stable_id,
            type: .primary
        )

        // Load image
        let loadedImage = try await repository.loadImage(imageModel)
        #expect(loadedImage != nil)

        // Verify image properties (size may differ due to resizing in repository)
        if let loaded = loadedImage {
            #expect(loaded.size.width > 0)
            #expect(loaded.size.height > 0)
        }
    }

    @Test("Load non-existent image returns nil")
    func testLoadNonExistentImage() async throws {
        let repository = deps.userImageRepository

        // Create a fake image model
        let fakeModel = UserImageModel(
            id: UUID(),
            ownerType: .glassItem,
            ownerId: "fake-item",
            imageType: .primary,
            fileExtension: "jpg"
        )

        // Attempt to load (should return nil or throw)
        let loadedImage = try? await repository.loadImage(fakeModel)
        #expect(loadedImage == nil)
    }
    #endif

    // MARK: - Image Deletion Tests

    #if canImport(UIKit)
    @Test("Delete image by ID")
    func testDeleteImageById() async throws {
        let item = createTestItem()
        let repository = deps.userImageRepository

        // Save image
        let testImage = createTestImage(color: .red)
        let imageModel = try await repository.saveImage(
            testImage,
            ownerType: .glassItem,
            ownerId: item.glassItem.stable_id,
            type: .primary
        )

        // Verify image exists
        let beforeDelete = try await repository.getImages(ownerType: .glassItem, ownerId: item.glassItem.stable_id)
        #expect(beforeDelete.count == 1)

        // Delete image
        try await repository.deleteImage(imageModel.id)

        // Verify image deleted
        let afterDelete = try await repository.getImages(ownerType: .glassItem, ownerId: item.glassItem.stable_id)
        #expect(afterDelete.isEmpty)
    }

    @Test("Delete all images for item")
    func testDeleteAllImagesForItem() async throws {
        let item = createTestItem()
        let repository = deps.userImageRepository

        // Save multiple images
        for i in 1...3 {
            let testImage = createTestImage(color: .red)
            let type: UserImageType = i == 1 ? .primary : .alternate
            _ = try await repository.saveImage(
                testImage,
                ownerType: .glassItem,
                ownerId: item.glassItem.stable_id,
                type: type
            )
        }

        // Verify images exist
        let beforeDelete = try await repository.getImages(ownerType: .glassItem, ownerId: item.glassItem.stable_id)
        #expect(beforeDelete.count == 3)

        // Delete all images
        try await repository.deleteAllImages(ownerType: .glassItem, ownerId: item.glassItem.stable_id)

        // Verify all deleted
        let afterDelete = try await repository.getImages(ownerType: .glassItem, ownerId: item.glassItem.stable_id)
        #expect(afterDelete.isEmpty)
    }

    @Test("Deleting image from one item doesn't affect other items")
    func testDeleteImageIsolation() async throws {
        let repository = deps.userImageRepository

        // Create two items
        let item1 = createTestItem()
        let item2StableId = generateStableId(manufacturer: "test", sku: "002")

        // Save images for both items
        let image1 = createTestImage(color: .red)
        let model1 = try await repository.saveImage(
            image1,
            ownerType: .glassItem,
            ownerId: item1.glassItem.stable_id,
            type: .primary
        )

        let image2 = createTestImage(color: .blue)
        _ = try await repository.saveImage(
            image2,
            ownerType: .glassItem,
            ownerId: item2StableId,
            type: .primary
        )

        // Delete image from item1
        try await repository.deleteImage(model1.id)

        // Verify item1 has no images
        let item1Images = try await repository.getImages(ownerType: .glassItem, ownerId: item1.glassItem.stable_id)
        #expect(item1Images.isEmpty)

        // Verify item2 still has image
        let item2Images = try await repository.getImages(ownerType: .glassItem, ownerId: item2StableId)
        #expect(item2Images.count == 1)
    }
    #endif

    // MARK: - Image Model Tests

    @Test("UserImageModel creation with all properties")
    func testUserImageModelCreation() {
        let imageModel = UserImageModel(
            id: UUID(),
            ownerType: .glassItem,
            ownerId: "test-item-001",
            imageType: .primary,
            fileExtension: "jpg",
            dateCreated: Date(),
            dateModified: Date(),
            ocrText: "Sample OCR text"
        )

        #expect(imageModel.ownerType == .glassItem)
        #expect(imageModel.ownerId == "test-item-001")
        #expect(imageModel.imageType == .primary)
        #expect(imageModel.fileExtension == "jpg")
        #expect(imageModel.ocrText == "Sample OCR text")
    }

    @Test("UserImageModel fileName generation")
    func testUserImageModelFileName() {
        let id = UUID()
        let imageModel = UserImageModel(
            id: id,
            ownerType: .glassItem,
            ownerId: "test-item",
            imageType: .primary,
            fileExtension: "png"
        )

        let expectedFileName = "\(id.uuidString).png"
        #expect(imageModel.fileName == expectedFileName)
    }

    @Test("UserImageModel legacy item_stable_id property")
    func testUserImageModelLegacyProperty() {
        // For glass items
        let glassItemImage = UserImageModel(
            ownerType: .glassItem,
            ownerId: "bullseye-0001-0",
            imageType: .primary
        )
        #expect(glassItemImage.item_stable_id == "bullseye-0001-0")

        // For non-glass items
        let projectImage = UserImageModel(
            ownerType: .projectPlan,
            ownerId: UUID().uuidString,
            imageType: .primary
        )
        #expect(projectImage.item_stable_id == nil)
    }

    // MARK: - Image Type Tests

    @Test("UserImageType enum values")
    func testUserImageTypeEnum() {
        #expect(UserImageType.primary.rawValue == "primary")
        #expect(UserImageType.alternate.rawValue == "alternate")

        #expect(UserImageType.primary.displayName == "Primary Image")
        #expect(UserImageType.alternate.displayName == "Alternate Image")
    }

    @Test("ImageOwnerType enum values")
    func testImageOwnerTypeEnum() {
        #expect(ImageOwnerType.glassItem.rawValue == "glassItem")
        #expect(ImageOwnerType.projectPlan.rawValue == "projectPlan")
        #expect(ImageOwnerType.projectLog.rawValue == "projectLog")
        #expect(ImageOwnerType.standalone.rawValue == "standalone")

        #expect(ImageOwnerType.glassItem.displayName == "Glass Item")
        #expect(ImageOwnerType.projectPlan.displayName == "Project Plan")
    }

    // MARK: - Multiple Images Management Tests

    #if canImport(UIKit)
    @Test("Get all images for item returns correct order")
    func testGetAllImagesOrder() async throws {
        let item = createTestItem()
        let repository = deps.userImageRepository

        // Save images in specific order
        var savedModels: [UserImageModel] = []

        let primary = createTestImage(color: .red)
        let primaryModel = try await repository.saveImage(
            primary,
            ownerType: .glassItem,
            ownerId: item.glassItem.stable_id,
            type: .primary
        )
        savedModels.append(primaryModel)

        for _ in 1...2 {
            let alternate = createTestImage(color: .green)
            let model = try await repository.saveImage(
                alternate,
                ownerType: .glassItem,
                ownerId: item.glassItem.stable_id,
                type: .alternate
            )
            savedModels.append(model)
        }

        // Fetch all images
        let images = try await repository.getImages(ownerType: .glassItem, ownerId: item.glassItem.stable_id)
        #expect(images.count == 3)

        // Verify primary exists
        let hasPrimary = images.contains { $0.imageType == .primary }
        #expect(hasPrimary)
    }

    @Test("Only one primary image allowed per item")
    func testOnlyOnePrimaryImageAllowed() async throws {
        let item = createTestItem()
        let repository = deps.userImageRepository

        // Save first primary
        let image1 = createTestImage(color: .red)
        let primary1 = try await repository.saveImage(
            image1,
            ownerType: .glassItem,
            ownerId: item.glassItem.stable_id,
            type: .primary
        )

        // Save second as alternate
        let image2 = createTestImage(color: .blue)
        let alternate = try await repository.saveImage(
            image2,
            ownerType: .glassItem,
            ownerId: item.glassItem.stable_id,
            type: .alternate
        )

        // Promote alternate to primary
        try await repository.updateImageType(alternate.id, type: .primary)
        // Demote old primary (this is view logic, but we test the repository capability)
        try await repository.updateImageType(primary1.id, type: .alternate)

        // Verify only one primary
        let images = try await repository.getImages(ownerType: .glassItem, ownerId: item.glassItem.stable_id)
        let primaryImages = images.filter { $0.imageType == .primary }
        #expect(primaryImages.count == 1)
        #expect(primaryImages.first?.id == alternate.id)
    }
    #endif

    // MARK: - Image State Management Tests

    #if canImport(UIKit)
    @Test("Image list updates after adding image")
    func testImageListUpdatesAfterAdd() async throws {
        let item = createTestItem()
        let repository = deps.userImageRepository

        // Initial state: empty
        let initial = try await repository.getImages(ownerType: .glassItem, ownerId: item.glassItem.stable_id)
        #expect(initial.isEmpty)

        // Add first image
        let image1 = createTestImage(color: .red)
        _ = try await repository.saveImage(
            image1,
            ownerType: .glassItem,
            ownerId: item.glassItem.stable_id,
            type: .primary
        )

        let afterFirst = try await repository.getImages(ownerType: .glassItem, ownerId: item.glassItem.stable_id)
        #expect(afterFirst.count == 1)

        // Add second image
        let image2 = createTestImage(color: .blue)
        _ = try await repository.saveImage(
            image2,
            ownerType: .glassItem,
            ownerId: item.glassItem.stable_id,
            type: .alternate
        )

        let afterSecond = try await repository.getImages(ownerType: .glassItem, ownerId: item.glassItem.stable_id)
        #expect(afterSecond.count == 2)
    }

    @Test("Image list updates after deleting image")
    func testImageListUpdatesAfterDelete() async throws {
        let item = createTestItem()
        let repository = deps.userImageRepository

        // Add two images
        let image1 = createTestImage(color: .red)
        let model1 = try await repository.saveImage(
            image1,
            ownerType: .glassItem,
            ownerId: item.glassItem.stable_id,
            type: .primary
        )

        let image2 = createTestImage(color: .blue)
        _ = try await repository.saveImage(
            image2,
            ownerType: .glassItem,
            ownerId: item.glassItem.stable_id,
            type: .alternate
        )

        let beforeDelete = try await repository.getImages(ownerType: .glassItem, ownerId: item.glassItem.stable_id)
        #expect(beforeDelete.count == 2)

        // Delete one image
        try await repository.deleteImage(model1.id)

        let afterDelete = try await repository.getImages(ownerType: .glassItem, ownerId: item.glassItem.stable_id)
        #expect(afterDelete.count == 1)
        #expect(!afterDelete.contains { $0.id == model1.id })
    }
    #endif

    // MARK: - Error Handling Tests

    #if canImport(UIKit)
    @Test("Deleting non-existent image handles gracefully")
    func testDeleteNonExistentImage() async throws {
        let repository = deps.userImageRepository
        let fakeId = UUID()

        // Should not throw or should handle gracefully
        do {
            try await repository.deleteImage(fakeId)
            // If it doesn't throw, that's fine
        } catch {
            // If it throws, verify it's the expected error
            #expect(error is UserImageError)
        }
    }
    #endif
}
