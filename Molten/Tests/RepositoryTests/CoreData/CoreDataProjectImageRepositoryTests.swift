//
//  CoreDataProjectImageRepositoryTests.swift
//  RepositoryTests
//
//  Tests for CoreDataProjectImageRepository - manages project image metadata
//

import Testing
import Foundation
import CoreData
@testable import Molten

@Suite("Core Data ProjectImage Repository Tests")
@MainActor
struct CoreDataProjectImageRepositoryTests {

    // MARK: - Create Tests

    @Test("Should create image metadata for plan")
    func testCreateImageMetadataForPlan() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)
        let projectId = try await createTestProject(in: controller)

        let metadata = ProjectImageModel(
            projectId: projectId,
            projectCategory: .plan,
            fileExtension: "jpg",
            caption: "Test image",
            order: 0
        )

        // Test
        let created = try await repository.createImageMetadata(metadata)

        // Verify
        #expect(created.projectId == projectId)
        #expect(created.caption == "Test image")
        #expect(created.fileExtension == "jpg")
    }

    @Test("Should create image metadata for log")
    func testCreateImageMetadataForLog() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)
        let logId = try await createTestLogbook(in: controller)

        let metadata = ProjectImageModel(
            projectId: logId,
            projectCategory: .log,
            fileExtension: "png",
            caption: "Log image",
            order: 0
        )

        // Test
        let created = try await repository.createImageMetadata(metadata)

        // Verify
        #expect(created.projectId == logId)
        #expect(created.projectCategory == .log)
    }

    // MARK: - Read Tests

    @Test("Should get images for project")
    func testGetImagesForProject() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)
        let projectId = try await createTestProject(in: controller)

        let metadata1 = ProjectImageModel(
            projectId: projectId,
            projectCategory: .plan,
            fileExtension: "jpg",
            order: 0
        )
        let metadata2 = ProjectImageModel(
            projectId: projectId,
            projectCategory: .plan,
            fileExtension: "png",
            order: 1
        )

        _ = try await repository.createImageMetadata(metadata1)
        _ = try await repository.createImageMetadata(metadata2)

        // Test
        let images = try await repository.getImages(for: projectId, type: .plan)

        // Verify
        #expect(images.count == 2)
    }

    @Test("Should preserve image order")
    func testPreserveImageOrder() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)
        let projectId = try await createTestProject(in: controller)

        _ = try await repository.createImageMetadata(ProjectImageModel(
            projectId: projectId,
            projectCategory: .plan,
            fileExtension: "jpg",
            caption: "Second",
            order: 1
        ))
        _ = try await repository.createImageMetadata(ProjectImageModel(
            projectId: projectId,
            projectCategory: .plan,
            fileExtension: "jpg",
            caption: "First",
            order: 0
        ))

        // Test
        let images = try await repository.getImages(for: projectId, type: .plan)

        // Verify - should be ordered by order_index
        #expect(images.count == 2)
        #expect(images[0].caption == "First")
        #expect(images[1].caption == "Second")
    }

    // MARK: - Update Tests

    @Test("Should update image metadata")
    func testUpdateImageMetadata() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)
        let projectId = try await createTestProject(in: controller)

        let original = ProjectImageModel(
            projectId: projectId,
            projectCategory: .plan,
            fileExtension: "jpg",
            caption: "Original caption",
            order: 0
        )
        let created = try await repository.createImageMetadata(original)

        // Test
        let updated = ProjectImageModel(
            id: created.id,
            projectId: projectId,
            projectCategory: .plan,
            fileExtension: "jpg",
            caption: "Updated caption",
            order: 0
        )
        try await repository.updateImageMetadata(updated)

        // Verify
        let images = try await repository.getImages(for: projectId, type: .plan)
        #expect(images.count == 1)
        #expect(images[0].caption == "Updated caption")
    }

    @Test("Should reorder images")
    func testReorderImages() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)
        let projectId = try await createTestProject(in: controller)

        let img1 = try await repository.createImageMetadata(ProjectImageModel(
            projectId: projectId,
            projectCategory: .plan,
            fileExtension: "jpg",
            caption: "First",
            order: 0
        ))
        let img2 = try await repository.createImageMetadata(ProjectImageModel(
            projectId: projectId,
            projectCategory: .plan,
            fileExtension: "jpg",
            caption: "Second",
            order: 1
        ))
        let img3 = try await repository.createImageMetadata(ProjectImageModel(
            projectId: projectId,
            projectCategory: .plan,
            fileExtension: "jpg",
            caption: "Third",
            order: 2
        ))

        // Test - Reorder to: img3, img1, img2
        try await repository.reorderImages(
            projectId: projectId,
            type: .plan,
            imageIds: [img3.id, img1.id, img2.id]
        )

        // Verify
        let images = try await repository.getImages(for: projectId, type: .plan)
        #expect(images.count == 3)
        #expect(images[0].caption == "Third")
        #expect(images[1].caption == "First")
        #expect(images[2].caption == "Second")
    }

    @Test("Should throw error when updating non-existent image")
    func testUpdateNonExistentImage() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)
        let projectId = try await createTestProject(in: controller)

        let metadata = ProjectImageModel(
            projectId: projectId,
            projectCategory: .plan,
            fileExtension: "jpg",
            order: 0
        )

        // Test & Verify
        do {
            try await repository.updateImageMetadata(metadata)
            Issue.record("Expected error for updating non-existent image")
        } catch {
            // Expected error
        }
    }

    // MARK: - Delete Tests

    @Test("Should delete image metadata")
    func testDeleteImageMetadata() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)
        let projectId = try await createTestProject(in: controller)

        let metadata = ProjectImageModel(
            projectId: projectId,
            projectCategory: .plan,
            fileExtension: "jpg",
            order: 0
        )
        let created = try await repository.createImageMetadata(metadata)

        // Test
        try await repository.deleteImageMetadata(id: created.id)

        // Verify
        let images = try await repository.getImages(for: projectId, type: .plan)
        #expect(images.isEmpty)
    }

    @Test("Should throw error when deleting non-existent image")
    func testDeleteNonExistentImage() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        // Test & Verify
        do {
            try await repository.deleteImageMetadata(id: UUID())
            Issue.record("Expected error for deleting non-existent image")
        } catch {
            // Expected error
        }
    }

    // MARK: - Helper Methods

    private func createTestRepository(controller: PersistenceController) -> CoreDataProjectImageRepository {
        return CoreDataProjectImageRepository(context: controller.container.viewContext)
    }

    private func createTestProject(in controller: PersistenceController) async throws -> UUID {
        let projectId = UUID()
        try await controller.container.viewContext.perform {
            let project = Project(context: controller.container.viewContext)
            project.id = projectId
            project.title = "Test Project"
            project.date_created = Date()
            project.date_modified = Date()

            try controller.container.viewContext.save()
        }
        return projectId
    }

    private func createTestLogbook(in controller: PersistenceController) async throws -> UUID {
        let logId = UUID()
        try await controller.container.viewContext.perform {
            let logbook = Logbook(context: controller.container.viewContext)
            logbook.id = logId
            logbook.title = "Test Log"
            logbook.date_created = Date()
            logbook.date_modified = Date()

            try controller.container.viewContext.save()
        }
        return logId
    }
}
