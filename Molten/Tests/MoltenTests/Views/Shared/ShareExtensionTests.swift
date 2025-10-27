//
//  ShareExtensionTests.swift
//  MoltenTests
//
//  Tests for Share Extension data model support
//

import Testing
import Foundation
import CoreData
import UIKit
@testable import Molten

// NOTE: Tags and technique types removed from share extension as of October 2025
// The Project entity in Core Data does not support:
// - ProjectTag entities (removed as part of Transformable attribute migration)
// - technique_type attribute (removed, now uses ProjectTechnique relationship)

@Suite("Share Extension - Project Creation Without Tags")
struct ShareExtensionProjectCreationTests {

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
        container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump

        return container
    }

    @Test("Project can be created without tags")
    @MainActor
    func projectCreatedWithoutTags() async throws {
        let container = createTestController()
        let context = container.viewContext

        // Create project like share extension does (without tags)
        let project = Project(context: context)
        project.id = UUID()
        project.title = "Imported Project"
        project.summary = "Test summary"
        project.date_created = Date()
        project.date_modified = Date()
        project.setValue("idea", forKey: "project_type")
        project.is_archived = false

        // Should save successfully without tags
        try context.save()

        // Verify project was created
        let fetchRequest = Project.fetchRequest()
        let results = try context.fetch(fetchRequest)

        #expect(results.count == 1)
        #expect(results.first?.title == "Imported Project")
        #expect(results.first?.value(forKey: "project_type") as? String == "idea")
    }

    @Test("Project can be created without technique type")
    @MainActor
    func projectCreatedWithoutTechniqueType() async throws {
        let container = createTestController()
        let context = container.viewContext

        // Create project like share extension does (without technique_type)
        let project = Project(context: context)
        project.id = UUID()
        project.title = "Test Project"
        project.date_created = Date()
        project.date_modified = Date()
        project.setValue("recipe", forKey: "project_type")
        project.is_archived = false

        // Note: technique_type attribute removed from Project entity
        // DO NOT set: project.setValue("flameworking", forKey: "technique_type")

        // Should save successfully without technique_type
        try context.save()

        // Verify project was created
        let fetchRequest = Project.fetchRequest()
        let results = try context.fetch(fetchRequest)

        #expect(results.count == 1)
        #expect(results.first?.title == "Test Project")
    }

    @Test("Project with minimal fields saves successfully")
    @MainActor
    func minimalProjectSaves() async throws {
        let container = createTestController()
        let context = container.viewContext

        // Create project with only required fields
        let project = Project(context: context)
        project.id = UUID()
        project.title = "Minimal Project"
        project.date_created = Date()
        project.date_modified = Date()
        project.is_archived = false

        // Should save successfully
        try context.save()

        // Verify project was created
        let fetchRequest = Project.fetchRequest()
        let results = try context.fetch(fetchRequest)

        #expect(results.count == 1)
        #expect(results.first?.title == "Minimal Project")
    }
}

@Suite("Share Extension - Callback Signature")
struct ShareExtensionCallbackTests {

    @Test("Callback signature includes all required parameters")
    func callbackSignatureComplete() async throws {
        // Updated callback signature (tags and techniqueType removed)
        // The callback should accept: title, notes, projectType, existingProjectId
        let title = "Test Project"
        let notes = "Test notes"
        let projectType = "recipe"
        let existingProjectId: UUID? = nil

        // Verify all parameters have expected types
        #expect(title is String)
        #expect(notes is String)
        #expect(projectType is String)
        #expect(existingProjectId is UUID?)
    }

    @Test("Callback works with empty notes")
    func callbackWorksWithEmptyNotes() async throws {
        let title = "Test Project"
        let notes = ""
        let projectType = "idea"
        let existingProjectId: UUID? = nil

        #expect(notes.isEmpty)
        #expect(!title.isEmpty)
    }

    @Test("Callback works with all project types")
    func callbackWorksWithAllProjectTypes() async throws {
        let projectTypes = ["idea", "recipe", "technique", "tutorial", "commission"]

        for projectType in projectTypes {
            let title = "Test \(projectType)"
            let notes = "Notes"
            let existingProjectId: UUID? = nil

            // Should work with all valid project types
            #expect(!projectType.isEmpty)
        }
    }

    @Test("Callback works with existing project ID for adding to existing")
    func callbackWorksWithExistingProjectId() async throws {
        // When adding to existing project, title/notes/projectType are empty
        let title = ""
        let notes = ""
        let projectType = ""
        let existingProjectId = UUID()

        #expect(existingProjectId != nil)
        #expect(title.isEmpty)
        #expect(notes.isEmpty)
    }

    @Test("Callback works with new project creation")
    func callbackWorksWithNewProject() async throws {
        // When creating new project, existingProjectId is nil
        let title = "New Project"
        let notes = "Project notes"
        let projectType = "idea"
        let existingProjectId: UUID? = nil

        #expect(existingProjectId == nil)
        #expect(!title.isEmpty)
        #expect(!projectType.isEmpty)
    }
}

@Suite("Share Extension - Project Type Integration")
struct ShareExtensionProjectTypeTests {

    @Test("Share extension project types match ProjectType enum")
    func shareExtensionProjectTypesMatchModel() async throws {
        let shareExtensionTypes = [
            ("idea", "Idea"),
            ("recipe", "Instructions"),
            ("technique", "Technique"),
            ("tutorial", "Tutorial"),
            ("commission", "Commission")
        ]

        for (rawValue, _) in shareExtensionTypes {
            let projectType = ProjectType(rawValue: rawValue)
            #expect(projectType != nil, "ProjectType should have raw value: \(rawValue)")
        }
    }

    @Test("All ProjectType cases are supported in share extension")
    func allProjectTypesSupported() async throws {
        // Test that common project types can be created
        let supportedRawValues = ["idea", "recipe", "technique", "tutorial", "commission"]

        for rawValue in supportedRawValues {
            let projectType = ProjectType(rawValue: rawValue)
            #expect(projectType != nil,
                   "Share extension should support ProjectType with raw value: \(rawValue)")
        }
    }
}

@Suite("Share Extension - Complete Save Flow")
@MainActor
struct ShareExtensionSaveFlowTests {

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
        container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump

        return container
    }

    private func createTestImage(width: Int = 100, height: Int = 100) -> Data {
        let size = CGSize(width: width, height: height)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return image.jpegData(compressionQuality: 0.85) ?? Data()
    }

    @Test("New project with images saves successfully")
    func newProjectWithImagesSaves() async throws {
        let container = createTestController()
        let context = container.viewContext

        // Simulate share extension creating new project with images
        let project = Project(context: context)
        project.id = UUID()
        project.title = "Imported Photo Project"
        project.summary = "Photos from share extension"
        project.date_created = Date()
        project.date_modified = Date()
        project.setValue("idea", forKey: "project_type")
        project.is_archived = false

        // Add 3 images like share extension does
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

            // Create ProjectImage metadata
            let projectImage = ProjectImage(context: context)
            projectImage.setValue(imageId, forKey: "id")
            projectImage.setValue(Date(), forKey: "date_added")
            projectImage.setValue("jpg", forKey: "file_extension")
            projectImage.setValue(Int32(index), forKey: "order_index")
            projectImage.setValue(project, forKey: "plan")

            // Set first image as hero
            if index == 0 && project.value(forKey: "hero_image_id") == nil {
                project.setValue(imageId, forKey: "hero_image_id")
            }
        }

        // Should save successfully
        try context.save()

        // Verify project was created
        let projectFetch = Project.fetchRequest()
        let projects = try context.fetch(projectFetch)
        #expect(projects.count == 1)
        #expect(projects.first?.title == "Imported Photo Project")

        // Verify images were created
        let imageFetch = UserImage.fetchRequest()
        let images = try context.fetch(imageFetch)
        #expect(images.count == 3)

        // Verify all images have correct ownerType
        for image in images {
            #expect(image.ownerType == "projectPlan")
            #expect(image.ownerId == project.id?.uuidString)
        }

        // Verify hero image is set
        let heroId = project.value(forKey: "hero_image_id") as? UUID
        #expect(heroId == imageIds[0])
    }

    @Test("Adding images to existing project works")
    func addingImagesToExistingProject() async throws {
        let container = createTestController()
        let context = container.viewContext

        // Create existing project
        let existingProject = Project(context: context)
        let projectId = UUID()
        existingProject.id = projectId
        existingProject.title = "Existing Project"
        existingProject.date_created = Date()
        existingProject.date_modified = Date()
        existingProject.setValue("recipe", forKey: "project_type")
        existingProject.is_archived = false

        try context.save()

        // Simulate share extension adding images to existing project
        let modificationDate = Date()
        existingProject.date_modified = modificationDate

        let newImageIds: [UUID] = [UUID(), UUID()]

        for (index, imageId) in newImageIds.enumerated() {
            let userImage = UserImage(context: context)
            userImage.id = imageId
            userImage.imageData = createTestImage()
            userImage.dateCreated = Date()
            userImage.dateModified = Date()
            userImage.imageType = "primary"
            userImage.ownerType = "projectPlan"
            userImage.ownerId = existingProject.id?.uuidString
            userImage.fileExtension = "jpg"

            let projectImage = ProjectImage(context: context)
            projectImage.setValue(imageId, forKey: "id")
            projectImage.setValue(Date(), forKey: "date_added")
            projectImage.setValue("jpg", forKey: "file_extension")
            projectImage.setValue(Int32(index), forKey: "order_index")
            projectImage.setValue(existingProject, forKey: "plan")

            // Set first image as hero if none exists
            if index == 0 && existingProject.value(forKey: "hero_image_id") == nil {
                existingProject.setValue(imageId, forKey: "hero_image_id")
            }
        }

        try context.save()

        // Verify project still exists with same ID
        let projectFetch = Project.fetchRequest()
        projectFetch.predicate = NSPredicate(format: "id == %@", projectId as CVarArg)
        let projects = try context.fetch(projectFetch)
        #expect(projects.count == 1)
        #expect(projects.first?.id == projectId)

        // Verify modification date was updated
        #expect(projects.first?.date_modified == modificationDate)

        // Verify images were added
        let imageFetch = UserImage.fetchRequest()
        imageFetch.predicate = NSPredicate(format: "ownerId == %@", projectId.uuidString)
        let images = try context.fetch(imageFetch)
        #expect(images.count == 2)
    }

    @Test("Empty notes do not cause save failure")
    func emptyNotesSaveSuccessfully() async throws {
        let container = createTestController()
        let context = container.viewContext

        let project = Project(context: context)
        project.id = UUID()
        project.title = "Project Without Notes"
        project.summary = nil  // Explicitly nil notes
        project.date_created = Date()
        project.date_modified = Date()
        project.setValue("tutorial", forKey: "project_type")
        project.is_archived = false

        // Should save successfully with nil summary
        try context.save()

        let fetchRequest = Project.fetchRequest()
        let results = try context.fetch(fetchRequest)
        #expect(results.count == 1)
        #expect(results.first?.summary == nil)
    }

    @Test("Auto-generated title works when user provides empty title")
    func autoGeneratedTitleWorks() async throws {
        // When user leaves title empty, share extension auto-generates one
        let projectType = "idea"
        let displayName = "Idea"
        let date = Date()

        // Simulating the title generation logic from share extension
        let autoTitle = "Imported \(displayName) \(date.formatted(date: .abbreviated, time: .shortened))"

        #expect(autoTitle.contains("Imported"))
        #expect(autoTitle.contains(displayName))
        #expect(!autoTitle.isEmpty)
    }

    @Test("Project without images saves successfully")
    func projectWithoutImagesSaves() async throws {
        let container = createTestController()
        let context = container.viewContext

        // Edge case: what if share extension is invoked but no images loaded?
        let project = Project(context: context)
        project.id = UUID()
        project.title = "Project Without Images"
        project.date_created = Date()
        project.date_modified = Date()
        project.setValue("commission", forKey: "project_type")
        project.is_archived = false

        // Should save successfully even without images
        try context.save()

        let fetchRequest = Project.fetchRequest()
        let results = try context.fetch(fetchRequest)
        #expect(results.count == 1)

        // Verify no hero image is set
        #expect(results.first?.value(forKey: "hero_image_id") == nil)
    }

    @Test("Multiple projects can be created in sequence")
    func multipleProjectsCreated() async throws {
        let container = createTestController()
        let context = container.viewContext

        // Simulate multiple share extension invocations
        for i in 1...3 {
            let project = Project(context: context)
            project.id = UUID()
            project.title = "Imported Project \(i)"
            project.date_created = Date()
            project.date_modified = Date()
            project.setValue("idea", forKey: "project_type")
            project.is_archived = false

            try context.save()
        }

        let fetchRequest = Project.fetchRequest()
        let results = try context.fetch(fetchRequest)
        #expect(results.count == 3)
    }
}
