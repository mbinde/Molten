//
//  CoreDataProjectImageRepositoryTests.swift
//  Molten
//
//  Tests for CoreDataProjectImageRepository
//

import Testing
import Foundation
@preconcurrency import CoreData
@testable import Molten

/// Tests for CoreDataProjectImageRepository using isolated Core Data stack
@Suite("CoreDataProjectImageRepository Tests")
@MainActor
struct CoreDataProjectImageRepositoryTests {

    // MARK: - Test Setup

    let repository: ProjectImageRepository
    let projectRepository: ProjectRepository
    let logbookRepository: LogbookRepository

    init() async throws {
        // Configure factory for testing with Core Data
        RepositoryFactory.configureForTestingWithCoreData()

        // Create repositories using factory
        repository = RepositoryFactory.createProjectImageRepository()
        projectRepository = RepositoryFactory.createProjectRepository()
        logbookRepository = RepositoryFactory.createLogbookRepository()
    }

    // MARK: - Create Tests

    @Test("Create image metadata for plan")
    func testCreateImageMetadataForPlan() async throws {
        // Create a plan first
        let plan = ProjectModel(
            id: UUID(),
            title: "Test Plan",
            type: .recipe,
            dateCreated: Date(),
            dateModified: Date(),
            isArchived: false,
            tags: [],
            coe: "96",
            summary: nil,
            steps: [],
            estimatedTime: nil,
            difficultyLevel: nil,
            proposedPriceRange: nil,
            images: [],
            heroImageId: nil,
            glassItems: [],
            referenceUrls: [],
            timesUsed: 0,
            lastUsedDate: nil
        )
        _ = try await projectRepository.createProject(plan)

        // Create image metadata
        let imageId = UUID()
        let metadata = ProjectImageModel(
            id: imageId,
            projectId: plan.id,
            projectCategory: .plan,
            fileExtension: "jpg",
            caption: "Test image",
            order: 0
        )

        let created = try await repository.createImageMetadata(metadata)

        #expect(created.id == imageId)
        #expect(created.projectId == plan.id)
        #expect(created.projectType == .plan)
        #expect(created.caption == "Test image")
    }

    @Test("Create image metadata for log")
    func testCreateImageMetadataForLog() async throws {
        // Create a log first
        let log = LogbookModel(
            id: UUID(),
            title: "Test Log",
            dateCreated: Date(),
            dateModified: Date(),
            projectDate: Date(),
            basedOnProjectId: nil,
            tags: [],
            coe: "96",
            notes: nil,
            techniquesUsed: nil,
            hoursSpent: nil,
            images: [],
            heroImageId: nil,
            glassItems: [],
            pricePoint: nil,
            saleDate: nil,
            buyerInfo: nil,
            status: .completed,
            inventoryDeductionRecorded: false
        )
        _ = try await logbookRepository.createLog(log)

        // Create image metadata
        let imageId = UUID()
        let metadata = ProjectImageModel(
            id: imageId,
            projectId: log.id,
            projectCategory: .log,
            fileExtension: "jpg",
            caption: "Test log image",
            order: 0
        )

        let created = try await repository.createImageMetadata(metadata)

        #expect(created.id == imageId)
        #expect(created.projectId == log.id)
        #expect(created.projectType == .log)
        #expect(created.caption == "Test log image")
    }

    // MARK: - Read Tests

    @Test("Get images for plan")
    func testGetImagesForPlan() async throws {
        // Create a plan
        let plan = ProjectModel(
            id: UUID(),
            title: "Test Plan",
            type: .recipe,
            dateCreated: Date(),
            dateModified: Date(),
            isArchived: false,
            tags: [],
            coe: "96",
            summary: nil,
            steps: [],
            estimatedTime: nil,
            difficultyLevel: nil,
            proposedPriceRange: nil,
            images: [],
            heroImageId: nil,
            glassItems: [],
            referenceUrls: [],
            timesUsed: 0,
            lastUsedDate: nil
        )
        _ = try await projectRepository.createProject(plan)

        // Create multiple image metadata records
        let image1 = ProjectImageModel(
            id: UUID(),
            projectId: plan.id,
            projectCategory: .plan,
            fileExtension: "jpg",
            caption: "First image",
            order: 0
        )
        let image2 = ProjectImageModel(
            id: UUID(),
            projectId: plan.id,
            projectCategory: .plan,
            fileExtension: "png",
            caption: "Second image",
            order: 1
        )

        _ = try await repository.createImageMetadata(image1)
        _ = try await repository.createImageMetadata(image2)

        // Fetch images
        let images = try await repository.getImages(for: plan.id, type: .plan)

        #expect(images.count == 2)
        #expect(images[0].order == 0)
        #expect(images[1].order == 1)
        #expect(images[0].caption == "First image")
        #expect(images[1].caption == "Second image")
    }

    @Test("Get images returns empty array when no images exist")
    func testGetImagesReturnsEmptyWhenNone() async throws {
        let projectId = UUID()
        let images = try await repository.getImages(for: projectId, type: .plan)
        #expect(images.isEmpty)
    }

    // MARK: - Update Tests

    @Test("Update image metadata")
    func testUpdateImageMetadata() async throws {
        // Create a plan
        let plan = ProjectModel(
            id: UUID(),
            title: "Test Plan",
            type: .recipe,
            dateCreated: Date(),
            dateModified: Date(),
            isArchived: false,
            tags: [],
            coe: "96",
            summary: nil,
            steps: [],
            estimatedTime: nil,
            difficultyLevel: nil,
            proposedPriceRange: nil,
            images: [],
            heroImageId: nil,
            glassItems: [],
            referenceUrls: [],
            timesUsed: 0,
            lastUsedDate: nil
        )
        _ = try await projectRepository.createProject(plan)

        // Create image metadata
        let imageId = UUID()
        let original = ProjectImageModel(
            id: imageId,
            projectId: plan.id,
            projectCategory: .plan,
            fileExtension: "jpg",
            caption: "Original caption",
            order: 0
        )
        _ = try await repository.createImageMetadata(original)

        // Update the caption
        let updated = ProjectImageModel(
            id: imageId,
            projectId: plan.id,
            projectCategory: .plan,
            fileExtension: "jpg",
            caption: "Updated caption",
            order: 0
        )
        try await repository.updateImageMetadata(updated)

        // Verify update
        let images = try await repository.getImages(for: plan.id, type: .plan)
        #expect(images.count == 1)
        #expect(images[0].caption == "Updated caption")
    }

    @Test("Reorder images")
    func testReorderImages() async throws {
        // Create a plan
        let plan = ProjectModel(
            id: UUID(),
            title: "Test Plan",
            type: .recipe,
            dateCreated: Date(),
            dateModified: Date(),
            isArchived: false,
            tags: [],
            coe: "96",
            summary: nil,
            steps: [],
            estimatedTime: nil,
            difficultyLevel: nil,
            proposedPriceRange: nil,
            images: [],
            heroImageId: nil,
            glassItems: [],
            referenceUrls: [],
            timesUsed: 0,
            lastUsedDate: nil
        )
        _ = try await projectRepository.createProject(plan)

        // Create three images
        let id1 = UUID()
        let id2 = UUID()
        let id3 = UUID()

        _ = try await repository.createImageMetadata(ProjectImageModel(
            id: id1,
            projectId: plan.id,
            projectCategory: .plan,
            fileExtension: "jpg",
            caption: "First",
            order: 0
        ))
        _ = try await repository.createImageMetadata(ProjectImageModel(
            id: id2,
            projectId: plan.id,
            projectCategory: .plan,
            fileExtension: "jpg",
            caption: "Second",
            order: 1
        ))
        _ = try await repository.createImageMetadata(ProjectImageModel(
            id: id3,
            projectId: plan.id,
            projectCategory: .plan,
            fileExtension: "jpg",
            caption: "Third",
            order: 2
        ))

        // Reorder: reverse the order
        try await repository.reorderImages(projectId: plan.id, type: .plan, imageIds: [id3, id2, id1])

        // Verify new order
        let images = try await repository.getImages(for: plan.id, type: .plan)
        #expect(images.count == 3)
        #expect(images[0].id == id3)
        #expect(images[1].id == id2)
        #expect(images[2].id == id1)
    }

    // MARK: - Delete Tests

    @Test("Delete image metadata")
    func testDeleteImageMetadata() async throws {
        // Create a plan
        let plan = ProjectModel(
            id: UUID(),
            title: "Test Plan",
            type: .recipe,
            dateCreated: Date(),
            dateModified: Date(),
            isArchived: false,
            tags: [],
            coe: "96",
            summary: nil,
            steps: [],
            estimatedTime: nil,
            difficultyLevel: nil,
            proposedPriceRange: nil,
            images: [],
            heroImageId: nil,
            glassItems: [],
            referenceUrls: [],
            timesUsed: 0,
            lastUsedDate: nil
        )
        _ = try await projectRepository.createProject(plan)

        // Create image metadata
        let imageId = UUID()
        let metadata = ProjectImageModel(
            id: imageId,
            projectId: plan.id,
            projectCategory: .plan,
            fileExtension: "jpg",
            caption: "Test image",
            order: 0
        )
        _ = try await repository.createImageMetadata(metadata)

        // Verify it exists
        var images = try await repository.getImages(for: plan.id, type: .plan)
        #expect(images.count == 1)

        // Delete it
        try await repository.deleteImageMetadata(id: imageId)

        // Verify it's gone
        images = try await repository.getImages(for: plan.id, type: .plan)
        #expect(images.isEmpty)
    }

    // MARK: - Integration Tests

    @Test("Image metadata persists with plan")
    func testImageMetadataPersistsWithPlan() async throws {
        // Create a plan
        let plan = ProjectModel(
            id: UUID(),
            title: "Test Plan",
            type: .recipe,
            dateCreated: Date(),
            dateModified: Date(),
            isArchived: false,
            tags: [],
            coe: "96",
            summary: nil,
            steps: [],
            estimatedTime: nil,
            difficultyLevel: nil,
            proposedPriceRange: nil,
            images: [],
            heroImageId: nil,
            glassItems: [],
            referenceUrls: [],
            timesUsed: 0,
            lastUsedDate: nil
        )
        _ = try await projectRepository.createProject(plan)

        // Create image metadata
        let imageId = UUID()
        let metadata = ProjectImageModel(
            id: imageId,
            projectId: plan.id,
            projectCategory: .plan,
            fileExtension: "jpg",
            caption: "Test image",
            order: 0
        )
        _ = try await repository.createImageMetadata(metadata)

        // Fetch the plan
        let fetchedPlan = try await projectRepository.getProject(id: plan.id)

        #expect(fetchedPlan != nil)
        #expect(fetchedPlan!.images.count == 1)
        #expect(fetchedPlan!.images[0].id == imageId)
        #expect(fetchedPlan!.images[0].caption == "Test image")
    }
}
