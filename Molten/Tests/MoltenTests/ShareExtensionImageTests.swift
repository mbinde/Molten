//
//  ShareExtensionImageTests.swift
//  MoltenTests
//
//  Tests for share extension image handling behavior
//

import Testing
import Foundation
import CoreData
@testable import Molten

@Suite("Share Extension - Image Handling")
@MainActor
struct ShareExtensionImageTests {

    // MARK: - Helper Methods

    private func createTestController() -> NSPersistentContainer {
        let container = NSPersistentContainer(name: "Molten")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]

        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Failed to load test store: \(error)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        return container
    }

    private func createTestImage(width: Int = 100, height: Int = 100) -> Data {
        // Create a simple 1x1 JPEG for testing
        let size = CGSize(width: width, height: height)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return image.jpegData(compressionQuality: 0.85) ?? Data()
    }

    // MARK: - New Project Tests

    @Test("New project sets first image as hero image")
    func newProjectSetsFirstImageAsHero() async throws {
        let container = createTestController()
        let context = container.viewContext

        // Create a new project
        let project = Project(context: context)
        project.id = UUID()
        project.title = "Test Project"
        project.date_created = Date()
        project.date_modified = Date()
        project.setValue("idea", forKey: "project_type")
        project.is_archived = false

        // Simulate adding 3 images like share extension does
        let imageIds: [UUID] = [UUID(), UUID(), UUID()]

        for (index, imageId) in imageIds.enumerated() {
            // Create UserImage
            let userImage = UserImage(context: context)
            userImage.id = imageId
            userImage.imageData = createTestImage()
            userImage.dateCreated = Date()
            userImage.dateModified = Date()
            userImage.imageType = "primary"
            userImage.ownerType = "projectPlan"
            userImage.ownerId = project.id?.uuidString
            userImage.fileExtension = "jpg"

            // Create ProjectImage
            let projectImage = ProjectImage(context: context)
            projectImage.setValue(imageId, forKey: "id")
            projectImage.setValue(Date(), forKey: "date_added")
            projectImage.setValue("jpg", forKey: "file_extension")
            projectImage.setValue(Int32(index), forKey: "order_index")
            projectImage.setValue(project, forKey: "plan")

            // Set first image as hero image ONLY if project doesn't already have one
            if index == 0 && project.value(forKey: "hero_image_id") == nil {
                project.setValue(imageId, forKey: "hero_image_id")
            }
        }

        try context.save()

        // Verify first image is hero
        let heroImageId = project.value(forKey: "hero_image_id") as? UUID
        #expect(heroImageId == imageIds[0])
        #expect(heroImageId != imageIds[1])
        #expect(heroImageId != imageIds[2])
    }

    @Test("New project with single image sets it as hero")
    func newProjectWithSingleImageSetsHero() async throws {
        let container = createTestController()
        let context = container.viewContext

        // Create a new project
        let project = Project(context: context)
        project.id = UUID()
        project.title = "Test Project"
        project.date_created = Date()
        project.date_modified = Date()
        project.setValue("idea", forKey: "project_type")
        project.is_archived = false

        // Add single image
        let imageId = UUID()
        let userImage = UserImage(context: context)
        userImage.id = imageId
        userImage.imageData = createTestImage()
        userImage.dateCreated = Date()
        userImage.dateModified = Date()
        userImage.imageType = "primary"
        userImage.ownerType = "projectPlan"
        userImage.ownerId = project.id?.uuidString
        userImage.fileExtension = "jpg"

        let projectImage = ProjectImage(context: context)
        projectImage.setValue(imageId, forKey: "id")
        projectImage.setValue(Date(), forKey: "date_added")
        projectImage.setValue("jpg", forKey: "file_extension")
        projectImage.setValue(Int32(0), forKey: "order_index")
        projectImage.setValue(project, forKey: "plan")

        // Set as hero (first and only image)
        if project.value(forKey: "hero_image_id") == nil {
            project.setValue(imageId, forKey: "hero_image_id")
        }

        try context.save()

        // Verify image is hero
        let heroImageId = project.value(forKey: "hero_image_id") as? UUID
        #expect(heroImageId == imageId)
    }

    // MARK: - Existing Project Tests

    @Test("Adding images to existing project preserves original hero image")
    func existingProjectPreservesHeroImage() async throws {
        let container = createTestController()
        let context = container.viewContext

        // Create existing project with hero image already set
        let project = Project(context: context)
        project.id = UUID()
        project.title = "Existing Project"
        project.date_created = Date()
        project.date_modified = Date()
        project.setValue("idea", forKey: "project_type")
        project.is_archived = false

        // Add original image and set as hero
        let originalImageId = UUID()
        let originalImage = UserImage(context: context)
        originalImage.id = originalImageId
        originalImage.imageData = createTestImage()
        originalImage.dateCreated = Date()
        originalImage.dateModified = Date()
        originalImage.imageType = "primary"
        originalImage.ownerType = "projectPlan"
        originalImage.ownerId = project.id?.uuidString
        originalImage.fileExtension = "jpg"

        let originalProjectImage = ProjectImage(context: context)
        originalProjectImage.setValue(originalImageId, forKey: "id")
        originalProjectImage.setValue(Date(), forKey: "date_added")
        originalProjectImage.setValue("jpg", forKey: "file_extension")
        originalProjectImage.setValue(Int32(0), forKey: "order_index")
        originalProjectImage.setValue(project, forKey: "plan")

        project.setValue(originalImageId, forKey: "hero_image_id")

        try context.save()

        // Verify original hero is set
        let heroBeforeAdd = project.value(forKey: "hero_image_id") as? UUID
        #expect(heroBeforeAdd == originalImageId)

        // Now add new images via share extension (simulating adding to existing project)
        let newImageIds: [UUID] = [UUID(), UUID()]

        for (index, imageId) in newImageIds.enumerated() {
            let userImage = UserImage(context: context)
            userImage.id = imageId
            userImage.imageData = createTestImage()
            userImage.dateCreated = Date()
            userImage.dateModified = Date()
            userImage.imageType = "primary"
            userImage.ownerType = "projectPlan"
            userImage.ownerId = project.id?.uuidString
            userImage.fileExtension = "jpg"

            let projectImage = ProjectImage(context: context)
            projectImage.setValue(imageId, forKey: "id")
            projectImage.setValue(Date(), forKey: "date_added")
            projectImage.setValue("jpg", forKey: "file_extension")
            projectImage.setValue(Int32(index + 1), forKey: "order_index") // Start at index 1 since 0 is original
            projectImage.setValue(project, forKey: "plan")

            // CRITICAL: Should NOT set as hero if project already has one
            if index == 0 && project.value(forKey: "hero_image_id") == nil {
                project.setValue(imageId, forKey: "hero_image_id")
            }
        }

        try context.save()

        // Verify original hero is STILL set (not overridden)
        let heroAfterAdd = project.value(forKey: "hero_image_id") as? UUID
        #expect(heroAfterAdd == originalImageId)
        #expect(heroAfterAdd != newImageIds[0])
        #expect(heroAfterAdd != newImageIds[1])
    }

    @Test("Existing project without hero image gets hero from first new image")
    func existingProjectWithoutHeroGetsNewHero() async throws {
        let container = createTestController()
        let context = container.viewContext

        // Create existing project WITHOUT hero image
        let project = Project(context: context)
        project.id = UUID()
        project.title = "Project Without Hero"
        project.date_created = Date()
        project.date_modified = Date()
        project.setValue("idea", forKey: "project_type")
        project.is_archived = false
        // Explicitly no hero_image_id set

        try context.save()

        // Verify no hero initially
        let heroBeforeAdd = project.value(forKey: "hero_image_id") as? UUID
        #expect(heroBeforeAdd == nil)

        // Add images via share extension
        let newImageIds: [UUID] = [UUID(), UUID()]

        for (index, imageId) in newImageIds.enumerated() {
            let userImage = UserImage(context: context)
            userImage.id = imageId
            userImage.imageData = createTestImage()
            userImage.dateCreated = Date()
            userImage.dateModified = Date()
            userImage.imageType = "primary"
            userImage.ownerType = "projectPlan"
            userImage.ownerId = project.id?.uuidString
            userImage.fileExtension = "jpg"

            let projectImage = ProjectImage(context: context)
            projectImage.setValue(imageId, forKey: "id")
            projectImage.setValue(Date(), forKey: "date_added")
            projectImage.setValue("jpg", forKey: "file_extension")
            projectImage.setValue(Int32(index), forKey: "order_index")
            projectImage.setValue(project, forKey: "plan")

            // Set first image as hero ONLY if project doesn't already have one
            if index == 0 && project.value(forKey: "hero_image_id") == nil {
                project.setValue(imageId, forKey: "hero_image_id")
            }
        }

        try context.save()

        // Verify first new image became hero
        let heroAfterAdd = project.value(forKey: "hero_image_id") as? UUID
        #expect(heroAfterAdd == newImageIds[0])
        #expect(heroAfterAdd != newImageIds[1])
    }

    @Test("Adding single image to existing project preserves original hero")
    func addingSingleImagePreservesHero() async throws {
        let container = createTestController()
        let context = container.viewContext

        // Create existing project with hero
        let project = Project(context: context)
        project.id = UUID()
        project.title = "Existing Project"
        project.date_created = Date()
        project.date_modified = Date()
        project.setValue("idea", forKey: "project_type")
        project.is_archived = false

        let originalHeroId = UUID()
        project.setValue(originalHeroId, forKey: "hero_image_id")

        try context.save()

        // Add single new image
        let newImageId = UUID()
        let userImage = UserImage(context: context)
        userImage.id = newImageId
        userImage.imageData = createTestImage()
        userImage.dateCreated = Date()
        userImage.dateModified = Date()
        userImage.imageType = "primary"
        userImage.ownerType = "projectPlan"
        userImage.ownerId = project.id?.uuidString
        userImage.fileExtension = "jpg"

        let projectImage = ProjectImage(context: context)
        projectImage.setValue(newImageId, forKey: "id")
        projectImage.setValue(Date(), forKey: "date_added")
        projectImage.setValue("jpg", forKey: "file_extension")
        projectImage.setValue(Int32(1), forKey: "order_index")
        projectImage.setValue(project, forKey: "plan")

        // Should NOT override existing hero
        if project.value(forKey: "hero_image_id") == nil {
            project.setValue(newImageId, forKey: "hero_image_id")
        }

        try context.save()

        // Verify original hero preserved
        let heroAfterAdd = project.value(forKey: "hero_image_id") as? UUID
        #expect(heroAfterAdd == originalHeroId)
        #expect(heroAfterAdd != newImageId)
    }

    // MARK: - Edge Cases

    @Test("Adding multiple images in sequence preserves hero")
    func multipleAdditionsPreserveHero() async throws {
        let container = createTestController()
        let context = container.viewContext

        // Create project with initial hero
        let project = Project(context: context)
        project.id = UUID()
        project.title = "Test Project"
        project.date_created = Date()
        project.date_modified = Date()
        project.setValue("idea", forKey: "project_type")
        project.is_archived = false

        let originalHeroId = UUID()
        project.setValue(originalHeroId, forKey: "hero_image_id")

        try context.save()

        // Add first batch of images
        let batch1Ids: [UUID] = [UUID(), UUID()]
        for (index, imageId) in batch1Ids.enumerated() {
            let userImage = UserImage(context: context)
            userImage.id = imageId
            userImage.imageData = createTestImage()
            userImage.dateCreated = Date()
            userImage.dateModified = Date()
            userImage.imageType = "primary"
            userImage.ownerType = "projectPlan"
            userImage.ownerId = project.id?.uuidString
            userImage.fileExtension = "jpg"

            // Should not override hero
            if index == 0 && project.value(forKey: "hero_image_id") == nil {
                project.setValue(imageId, forKey: "hero_image_id")
            }
        }

        try context.save()

        // Verify hero unchanged after first batch
        let heroAfterBatch1 = project.value(forKey: "hero_image_id") as? UUID
        #expect(heroAfterBatch1 == originalHeroId)

        // Add second batch of images
        let batch2Ids: [UUID] = [UUID(), UUID()]
        for (index, imageId) in batch2Ids.enumerated() {
            let userImage = UserImage(context: context)
            userImage.id = imageId
            userImage.imageData = createTestImage()
            userImage.dateCreated = Date()
            userImage.dateModified = Date()
            userImage.imageType = "primary"
            userImage.ownerType = "projectPlan"
            userImage.ownerId = project.id?.uuidString
            userImage.fileExtension = "jpg"

            // Should not override hero
            if index == 0 && project.value(forKey: "hero_image_id") == nil {
                project.setValue(imageId, forKey: "hero_image_id")
            }
        }

        try context.save()

        // Verify hero STILL unchanged after second batch
        let heroAfterBatch2 = project.value(forKey: "hero_image_id") as? UUID
        #expect(heroAfterBatch2 == originalHeroId)
        #expect(!batch1Ids.contains(heroAfterBatch2 ?? UUID()))
        #expect(!batch2Ids.contains(heroAfterBatch2 ?? UUID()))
    }

    @Test("Empty project receives hero from first image addition")
    func emptyProjectReceivesHero() async throws {
        let container = createTestController()
        let context = container.viewContext

        // Create completely empty project
        let project = Project(context: context)
        project.id = UUID()
        project.title = "Empty Project"
        project.date_created = Date()
        project.date_modified = Date()
        project.setValue("idea", forKey: "project_type")
        project.is_archived = false

        try context.save()

        // Verify no hero
        #expect(project.value(forKey: "hero_image_id") == nil)

        // Add first image
        let firstImageId = UUID()
        let userImage = UserImage(context: context)
        userImage.id = firstImageId
        userImage.imageData = createTestImage()
        userImage.dateCreated = Date()
        userImage.dateModified = Date()
        userImage.imageType = "primary"
        userImage.ownerType = "projectPlan"
        userImage.ownerId = project.id?.uuidString
        userImage.fileExtension = "jpg"

        // Set as hero since none exists
        if project.value(forKey: "hero_image_id") == nil {
            project.setValue(firstImageId, forKey: "hero_image_id")
        }

        try context.save()

        // Verify first image is now hero
        let heroId = project.value(forKey: "hero_image_id") as? UUID
        #expect(heroId == firstImageId)

        // Add second image
        let secondImageId = UUID()
        let userImage2 = UserImage(context: context)
        userImage2.id = secondImageId
        userImage2.imageData = createTestImage()
        userImage2.dateCreated = Date()
        userImage2.dateModified = Date()
        userImage2.imageType = "primary"
        userImage2.ownerType = "projectPlan"
        userImage2.ownerId = project.id?.uuidString
        userImage2.fileExtension = "jpg"

        // Should NOT override existing hero
        if project.value(forKey: "hero_image_id") == nil {
            project.setValue(secondImageId, forKey: "hero_image_id")
        }

        try context.save()

        // Verify hero unchanged (still first image)
        let finalHeroId = project.value(forKey: "hero_image_id") as? UUID
        #expect(finalHeroId == firstImageId)
        #expect(finalHeroId != secondImageId)
    }
}
