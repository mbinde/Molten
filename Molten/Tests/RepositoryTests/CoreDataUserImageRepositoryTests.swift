//
//  CoreDataUserImageRepositoryTests.swift
//  RepositoryTests
//
//  Core Data integration tests for UserImageRepository
//

import Testing
import Foundation
import CoreData
@testable import Molten

#if canImport(UIKit)
import UIKit

@Suite("UserImageRepository - Core Data Implementation")
struct CoreDataUserImageRepositoryTests {

    // MARK: - Test Setup

    func createTestController() -> PersistenceController {
        return PersistenceController.createTestController()
    }

    func createTestImage(color: UIColor = .red, size: CGSize = CGSize(width: 100, height: 100)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    // MARK: - Save Image Tests

    @Test("Save primary image persists to Core Data")
    func savePrimaryImagePersistsToCoreData() async throws {
        // Given
        let controller = createTestController()
        let repository = CoreDataUserImageRepository(context: controller.container.viewContext)
        let testImage = createTestImage(color: .blue)
        let naturalKey = "bullseye-clear-001"

        // When
        let savedModel = try await repository.saveImage(
            testImage,
            ownerType: .glassItem,
            ownerId: naturalKey,
            type: .primary
        )

        // Then - verify in Core Data
        let context = controller.container.viewContext
        let fetchRequest = UserImage.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", savedModel.id as CVarArg)

        let results = try context.fetch(fetchRequest)
        #expect(results.count == 1)
        #expect(results.first?.ownerType == "glassItem")
        #expect(results.first?.ownerId == naturalKey)
        #expect(results.first?.imageType == "primary")
        #expect(results.first?.imageData != nil)
    }

    @Test("Save image compresses and resizes large images")
    func saveImageCompressesAndResizesLargeImages() async throws {
        // Given
        let controller = createTestController()
        let repository = CoreDataUserImageRepository(context: controller.container.viewContext)
        // Create a large image (over 2048px)
        let largeImage = createTestImage(color: .red, size: CGSize(width: 3000, height: 3000))
        let naturalKey = "bullseye-clear-001"

        // When
        let savedModel = try await repository.saveImage(
            largeImage,
            ownerType: .glassItem,
            ownerId: naturalKey,
            type: .primary
        )

        // Then - load and verify image was resized
        let loadedImage = try await repository.loadImage(savedModel)
        #expect(loadedImage != nil)

        // Should be resized to max 2048px on longest side
        let maxDimension = max(loadedImage!.size.width, loadedImage!.size.height)
        #expect(maxDimension <= 2048)
    }

    @Test("Save primary image demotes existing primary in Core Data")
    func savePrimaryImageDemotesExistingInCoreData() async throws {
        // Given
        let controller = createTestController()
        let repository = CoreDataUserImageRepository(context: controller.container.viewContext)
        let naturalKey = "bullseye-clear-001"
        let firstImage = createTestImage(color: .red)
        let secondImage = createTestImage(color: .blue)

        // When - save first primary
        let firstModel = try await repository.saveImage(
            firstImage,
            ownerType: .glassItem,
            ownerId: naturalKey,
            type: .primary
        )

        // Save second primary (should demote first)
        let secondModel = try await repository.saveImage(
            secondImage,
            ownerType: .glassItem,
            ownerId: naturalKey,
            type: .primary
        )

        // Then - verify in Core Data
        let context = controller.container.viewContext
        let fetchRequest = UserImage.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "ownerId == %@", naturalKey)

        let results = try context.fetch(fetchRequest)
        #expect(results.count == 2)

        // Find each image and verify types
        let firstInDb = results.first { $0.id == firstModel.id }
        let secondInDb = results.first { $0.id == secondModel.id }

        #expect(firstInDb?.imageType == "alternate") // demoted
        #expect(secondInDb?.imageType == "primary")  // new primary
    }

    @Test("Save image stores JPEG data with compression")
    func saveImageStoresJpegDataWithCompression() async throws {
        // Given
        let controller = createTestController()
        let repository = CoreDataUserImageRepository(context: controller.container.viewContext)
        let testImage = createTestImage(color: .green, size: CGSize(width: 500, height: 500))
        let naturalKey = "bullseye-clear-001"

        // When
        let savedModel = try await repository.saveImage(
            testImage,
            ownerType: .glassItem,
            ownerId: naturalKey,
            type: .primary
        )

        // Then - verify JPEG compression in Core Data
        let context = controller.container.viewContext
        let fetchRequest = UserImage.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", savedModel.id as CVarArg)

        let results = try context.fetch(fetchRequest)
        let imageData = results.first?.imageData
        #expect(imageData != nil)

        // Verify it's valid JPEG data
        let loadedImage = UIImage(data: imageData!)
        #expect(loadedImage != nil)
    }

    // MARK: - Get Images Tests

    @Test("Get images queries Core Data correctly")
    func getImagesQueriesCoreDataCorrectly() async throws {
        // Given
        let controller = createTestController()
        let repository = CoreDataUserImageRepository(context: controller.container.viewContext)
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

        // Then - query returns correct subset
        let images = try await repository.getImages(ownerType: .glassItem, ownerId: naturalKey)
        #expect(images.count == 2)
        #expect(images.allSatisfy { $0.ownerId == naturalKey })
    }

    @Test("Get images sorts by type then date")
    func getImagesSortsByTypeThenDate() async throws {
        // Given
        let controller = createTestController()
        let repository = CoreDataUserImageRepository(context: controller.container.viewContext)
        let naturalKey = "bullseye-clear-001"

        // When - save in specific order
        let alternate1 = try await repository.saveImage(
            createTestImage(color: .red),
            ownerType: .glassItem,
            ownerId: naturalKey,
            type: .alternate
        )
        try await Task.sleep(for: .milliseconds(10))

        let primary = try await repository.saveImage(
            createTestImage(color: .blue),
            ownerType: .glassItem,
            ownerId: naturalKey,
            type: .primary
        )
        try await Task.sleep(for: .milliseconds(10))

        let alternate2 = try await repository.saveImage(
            createTestImage(color: .green),
            ownerType: .glassItem,
            ownerId: naturalKey,
            type: .alternate
        )

        // Then - primary should be first, then alternates by date descending
        let images = try await repository.getImages(ownerType: .glassItem, ownerId: naturalKey)
        #expect(images.count == 3)
        #expect(images[0].id == primary.id)  // primary first
        // Alternates sorted by date desc (newest first)
        #expect(images[1].id == alternate2.id)
        #expect(images[2].id == alternate1.id)
    }

    // MARK: - Get Primary Image Tests

    @Test("Get primary image queries Core Data with correct predicate")
    func getPrimaryImageQueriesCoreDataWithCorrectPredicate() async throws {
        // Given
        let controller = createTestController()
        let repository = CoreDataUserImageRepository(context: controller.container.viewContext)
        let naturalKey = "bullseye-clear-001"

        // When
        let savedPrimary = try await repository.saveImage(
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
        let primary = try await repository.getPrimaryImage(ownerType: .glassItem, ownerId: naturalKey)
        #expect(primary?.id == savedPrimary.id)
        #expect(primary?.imageType == .primary)
    }

    // MARK: - Get Standalone Images Tests

    @Test("Get standalone images filters correctly in Core Data")
    func getStandaloneImagesFiltersCorrectlyInCoreData() async throws {
        // Given
        let controller = createTestController()
        let repository = CoreDataUserImageRepository(context: controller.container.viewContext)

        // When - save mix of images
        _ = try await repository.saveImage(
            createTestImage(color: .red),
            ownerType: .glassItem,
            ownerId: "item-1",
            type: .primary
        )
        let standalone1 = try await repository.saveImage(
            createTestImage(color: .blue),
            ownerType: .standalone,
            ownerId: nil,
            type: .primary
        )
        let standalone2 = try await repository.saveImage(
            createTestImage(color: .green),
            ownerType: .standalone,
            ownerId: nil,
            type: .alternate
        )

        // Then
        let standaloneImages = try await repository.getStandaloneImages()
        #expect(standaloneImages.count == 2)

        let ids = standaloneImages.map { $0.id }
        #expect(ids.contains(standalone1.id))
        #expect(ids.contains(standalone2.id))
    }

    // MARK: - Delete Tests

    @Test("Delete image removes from Core Data")
    func deleteImageRemovesFromCoreData() async throws {
        // Given
        let controller = createTestController()
        let repository = CoreDataUserImageRepository(context: controller.container.viewContext)
        let naturalKey = "bullseye-clear-001"

        let savedModel = try await repository.saveImage(
            createTestImage(color: .red),
            ownerType: .glassItem,
            ownerId: naturalKey,
            type: .primary
        )

        // When
        try await repository.deleteImage(savedModel.id)

        // Then - verify removed from Core Data
        let context = controller.container.viewContext
        let fetchRequest = UserImage.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", savedModel.id as CVarArg)

        let results = try context.fetch(fetchRequest)
        #expect(results.isEmpty)
    }

    @Test("Delete all images for owner removes only matching records")
    func deleteAllImagesForOwnerRemovesOnlyMatchingRecords() async throws {
        // Given
        let controller = createTestController()
        let repository = CoreDataUserImageRepository(context: controller.container.viewContext)

        // When - save images for multiple owners
        _ = try await repository.saveImage(
            createTestImage(color: .red),
            ownerType: .glassItem,
            ownerId: "item-1",
            type: .primary
        )
        _ = try await repository.saveImage(
            createTestImage(color: .blue),
            ownerType: .glassItem,
            ownerId: "item-1",
            type: .alternate
        )
        let keepImage = try await repository.saveImage(
            createTestImage(color: .green),
            ownerType: .glassItem,
            ownerId: "item-2",
            type: .primary
        )

        // Delete all for item-1
        try await repository.deleteAllImages(ownerType: .glassItem, ownerId: "item-1")

        // Then - verify Core Data state
        let context = controller.container.viewContext
        let fetchRequest = UserImage.fetchRequest()

        let allResults = try context.fetch(fetchRequest)
        #expect(allResults.count == 1)
        #expect(allResults.first?.id == keepImage.id)
    }

    // MARK: - Update Image Type Tests

    @Test("Update image type persists change to Core Data")
    func updateImageTypePersistsChangeToCoreData() async throws {
        // Given
        let controller = createTestController()
        let repository = CoreDataUserImageRepository(context: controller.container.viewContext)
        let naturalKey = "bullseye-clear-001"

        let savedModel = try await repository.saveImage(
            createTestImage(color: .red),
            ownerType: .glassItem,
            ownerId: naturalKey,
            type: .alternate
        )

        // When
        try await repository.updateImageType(savedModel.id, type: .primary)

        // Then - verify in Core Data
        let context = controller.container.viewContext
        let fetchRequest = UserImage.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", savedModel.id as CVarArg)

        let results = try context.fetch(fetchRequest)
        #expect(results.first?.imageType == "primary")
        #expect(results.first?.dateModified != nil)
    }

    @Test("Update to primary demotes existing primary in Core Data")
    func updateToPrimaryDemotesExistingPrimaryInCoreData() async throws {
        // Given
        let controller = createTestController()
        let repository = CoreDataUserImageRepository(context: controller.container.viewContext)
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

        // Then - verify in Core Data
        let context = controller.container.viewContext
        let fetchRequest = UserImage.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "ownerId == %@", naturalKey)

        let results = try context.fetch(fetchRequest)
        let oldPrimary = results.first { $0.id == existingPrimary.id }
        let newPrimary = results.first { $0.id == alternate.id }

        #expect(oldPrimary?.imageType == "alternate")
        #expect(newPrimary?.imageType == "primary")
    }

    // MARK: - Load Image Tests

    @Test("Load image retrieves from Core Data and decodes correctly")
    func loadImageRetrievesFromCoreDataAndDecodesCorrectly() async throws {
        // Given
        let controller = createTestController()
        let repository = CoreDataUserImageRepository(context: controller.container.viewContext)
        let testImage = createTestImage(color: .red, size: CGSize(width: 200, height: 200))
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

        // Size should be preserved (or resized proportionally)
        #expect(loadedImage!.size.width > 0)
        #expect(loadedImage!.size.height > 0)
    }

    @Test("Load image throws error for non-existent image")
    func loadImageThrowsErrorForNonExistentImage() async throws {
        // Given
        let controller = createTestController()
        let repository = CoreDataUserImageRepository(context: controller.container.viewContext)
        let nonExistentModel = UserImageModel(
            id: UUID(),
            ownerType: .glassItem,
            ownerId: "nonexistent",
            imageType: .primary,
            fileExtension: "jpg"
        )

        // When/Then
        await #expect(throws: UserImageError.imageNotFound) {
            _ = try await repository.loadImage(nonExistentModel)
        }
    }

    // MARK: - Core Data Integration Tests

    @Test("Concurrent saves don't conflict in Core Data")
    func concurrentSavesDontConflictInCoreData() async throws {
        // Given
        let controller = createTestController()
        let repository = CoreDataUserImageRepository(context: controller.container.viewContext)

        // When - save multiple images concurrently
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    let image = self.createTestImage(color: .red)
                    _ = try? await repository.saveImage(
                        image,
                        ownerType: .glassItem,
                        ownerId: "item-\(i)",
                        type: .primary
                    )
                }
            }
        }

        // Then - all images should be saved
        let context = controller.container.viewContext
        let fetchRequest = UserImage.fetchRequest()
        let results = try context.fetch(fetchRequest)
        #expect(results.count == 10)
    }

    @Test("Changes persist across context refreshes")
    func changesPersistAcrossContextRefreshes() async throws {
        // Given
        let controller = createTestController()
        let repository = CoreDataUserImageRepository(context: controller.container.viewContext)
        let naturalKey = "bullseye-clear-001"

        // When - save and then refresh context
        let savedModel = try await repository.saveImage(
            createTestImage(color: .red),
            ownerType: .glassItem,
            ownerId: naturalKey,
            type: .primary
        )

        // Refresh context
        let context = controller.container.viewContext
        context.refreshAllObjects()

        // Then - data still accessible
        let images = try await repository.getImages(ownerType: .glassItem, ownerId: naturalKey)
        #expect(images.count == 1)
        #expect(images.first?.id == savedModel.id)
    }

    @Test("Image data survives save and fetch cycle")
    func imageDataSurvivesSaveAndFetchCycle() async throws {
        // Given
        let controller = createTestController()
        let repository = CoreDataUserImageRepository(context: controller.container.viewContext)
        let testImage = createTestImage(color: .blue, size: CGSize(width: 300, height: 300))
        let naturalKey = "bullseye-clear-001"

        // When - save, then load through repository
        let savedModel = try await repository.saveImage(
            testImage,
            ownerType: .glassItem,
            ownerId: naturalKey,
            type: .primary
        )

        let loadedImage = try await repository.loadImage(savedModel)

        // Then - image should be intact
        #expect(loadedImage != nil)

        // Verify we can convert back to data (complete round-trip)
        let reloadedData = loadedImage!.jpegData(compressionQuality: 0.85)
        #expect(reloadedData != nil)
    }
}
#endif
