//
//  ProjectImportServiceTests.swift
//  MoltenTests
//
//  Tests for project import functionality
//

import Testing
import Foundation
#if canImport(UIKit)
import UIKit
#endif
@testable import Molten

@Suite("Project Import Service Tests")
struct ProjectImportServiceTests {

    #if canImport(UIKit)
    @Test("Import service can preview a plan file")
    func testPreviewPlan() async throws {
        // Arrange
        let mockImageRepo = MockUserImageRepository()
        let mockPlanRepo = MockProjectRepository()
        let exportService = ProjectExportService(userImageRepository: mockImageRepo)
        let importService = ProjectImportService(
            userImageRepository: mockImageRepo,
            projectPlanRepository: mockPlanRepo
        )

        // Create a plan with some content
        let originalPlan = ProjectModel(
            title: "Test Tutorial",
            type: .tutorial,
            coe: "104",
            summary: "A plan for testing preview",
            steps: [
                ProjectStepModel(
                    projectId: UUID(),
                    order: 0,
                    title: "Step 1"
                ),
                ProjectStepModel(
                    projectId: UUID(),
                    order: 1,
                    title: "Step 2"
                )
            ]
        )

        // Export it
        let exportURL = try await exportService.exportPlan(originalPlan, quality: .optimized, skipCompression: true)

        // Act - Preview the exported file
        let preview = try await importService.previewPlan(from: exportURL)

        // Assert
        #expect(preview.title == "Test Tutorial", "Preview should have correct title")
        #expect(preview.type == .tutorial, "Preview should have correct type")
        #expect(preview.summary == "A plan for testing preview", "Preview should have correct summary")
        #expect(preview.stepCount == 2, "Preview should show 2 steps")
        #expect(preview.imageCount == 0, "Preview should show 0 images")
        #expect(preview.fileSize > 0, "Preview should report file size")

        // Cleanup
        try? FileManager.default.removeItem(at: exportURL)
    }

    @Test("Import service can import a plan file")
    func testImportPlan() async throws {
        // Arrange
        let mockImageRepo = MockUserImageRepository()
        let mockPlanRepo = MockProjectRepository()
        let exportService = ProjectExportService(userImageRepository: mockImageRepo)
        let importService = ProjectImportService(
            userImageRepository: mockImageRepo,
            projectPlanRepository: mockPlanRepo
        )

        let originalPlan = ProjectModel(
            title: "Import Test Plan",
            type: .recipe,
            coe: "96",
            summary: "Testing import functionality",
            difficultyLevel: .intermediate
        )

        // Export it
        let exportURL = try await exportService.exportPlan(originalPlan, quality: .optimized, skipCompression: true)

        // Act - Import the exported file
        let importedPlan = try await importService.importPlan(from: exportURL)

        // Assert - Plan data should be preserved
        #expect(importedPlan.title == originalPlan.title, "Title should be preserved")
        #expect(importedPlan.type == originalPlan.type, "Type should be preserved")
        #expect(importedPlan.coe == originalPlan.coe, "COE should be preserved")
        #expect(importedPlan.summary == originalPlan.summary, "Summary should be preserved")
        #expect(importedPlan.difficultyLevel == originalPlan.difficultyLevel, "Difficulty should be preserved")

        // Assert - IDs should be different (to avoid conflicts)
        #expect(importedPlan.id != originalPlan.id, "Imported plan should have new ID")

        // Assert - Plan should be in repository
        let storedPlan = try await mockPlanRepo.getProject(id: importedPlan.id)
        #expect(storedPlan != nil, "Plan should be saved in repository")

        // Cleanup
        try? FileManager.default.removeItem(at: exportURL)
    }

    @Test("Import preserves all plan steps")
    func testImportPreservesSteps() async throws {
        // Arrange
        let mockImageRepo = MockUserImageRepository()
        let mockPlanRepo = MockProjectRepository()
        let exportService = ProjectExportService(userImageRepository: mockImageRepo)
        let importService = ProjectImportService(
            userImageRepository: mockImageRepo,
            projectPlanRepository: mockPlanRepo
        )

        let step1 = ProjectStepModel(
            projectId: UUID(),
            order: 0,
            title: "First Step",
            description: "Do this first"
        )

        let step2 = ProjectStepModel(
            projectId: UUID(),
            order: 1,
            title: "Second Step",
            description: "Then do this"
        )

        let originalPlan = ProjectModel(
            title: "Step Test",
            type: .recipe,
            coe: "any",
            steps: [step1, step2]
        )

        // Export and import
        let exportURL = try await exportService.exportPlan(originalPlan, quality: .optimized, skipCompression: true)
        let importedPlan = try await importService.importPlan(from: exportURL)

        // Assert
        #expect(importedPlan.steps.count == 2, "Should import all steps")
        #expect(importedPlan.steps[0].title == "First Step", "First step title preserved")
        #expect(importedPlan.steps[0].description == "Do this first", "First step description preserved")
        #expect(importedPlan.steps[1].title == "Second Step", "Second step title preserved")
        #expect(importedPlan.steps[1].description == "Then do this", "Second step description preserved")
        #expect(importedPlan.steps[0].order == 0, "Step order preserved")
        #expect(importedPlan.steps[1].order == 1, "Step order preserved")

        // Step IDs should be different
        #expect(importedPlan.steps[0].id != step1.id, "Step IDs should be regenerated")
        #expect(importedPlan.steps[1].id != step2.id, "Step IDs should be regenerated")

        // Cleanup
        try? FileManager.default.removeItem(at: exportURL)
    }

    @Test("Import preserves reference URLs")
    func testImportPreservesReferenceURLs() async throws {
        // Arrange
        let mockImageRepo = MockUserImageRepository()
        let mockPlanRepo = MockProjectRepository()
        let exportService = ProjectExportService(userImageRepository: mockImageRepo)
        let importService = ProjectImportService(
            userImageRepository: mockImageRepo,
            projectPlanRepository: mockPlanRepo
        )

        let url1 = ProjectReferenceUrl(
            url: "https://example.com/tutorial1",
            title: "Tutorial 1",
            description: "First tutorial"
        )

        let url2 = ProjectReferenceUrl(
            url: "https://example.com/tutorial2",
            title: "Tutorial 2"
        )

        let originalPlan = ProjectModel(
            title: "URL Test",
            type: .tutorial,
            coe: "any",
            referenceUrls: [url1, url2]
        )

        // Export and import
        let exportURL = try await exportService.exportPlan(originalPlan, quality: .optimized, skipCompression: true)
        let importedPlan = try await importService.importPlan(from: exportURL)

        // Assert
        #expect(importedPlan.referenceUrls.count == 2, "Should import all URLs")
        #expect(importedPlan.referenceUrls[0].url == url1.url, "URL preserved")
        #expect(importedPlan.referenceUrls[0].title == url1.title, "URL title preserved")
        #expect(importedPlan.referenceUrls[0].description == url1.description, "URL description preserved")
        #expect(importedPlan.referenceUrls[1].url == url2.url, "Second URL preserved")

        // Cleanup
        try? FileManager.default.removeItem(at: exportURL)
    }

    @Test("Import preserves glass items")
    func testImportPreservesGlassItems() async throws {
        // Arrange
        let mockImageRepo = MockUserImageRepository()
        let mockPlanRepo = MockProjectRepository()
        let exportService = ProjectExportService(userImageRepository: mockImageRepo)
        let importService = ProjectImportService(
            userImageRepository: mockImageRepo,
            projectPlanRepository: mockPlanRepo
        )

        let glass1 = ProjectGlassItem(
            naturalKey: "bullseye-clear-001",
            quantity: 2,
            unit: "rods",
            notes: "For base layer"
        )

        let glass2 = ProjectGlassItem(
            freeformDescription: "Any dark transparent",
            quantity: 1,
            unit: "rods"
        )

        let originalPlan = ProjectModel(
            title: "Glass Test",
            type: .recipe,
            coe: "104",
            glassItems: [glass1, glass2]
        )

        // Export and import
        let exportURL = try await exportService.exportPlan(originalPlan, quality: .optimized, skipCompression: true)
        let importedPlan = try await importService.importPlan(from: exportURL)

        // Assert
        #expect(importedPlan.glassItems.count == 2, "Should import all glass items")

        // First glass item (catalog item)
        #expect(importedPlan.glassItems[0].naturalKey == "bullseye-clear-001", "Natural key preserved")
        #expect(importedPlan.glassItems[0].quantity == 2, "Quantity preserved")
        #expect(importedPlan.glassItems[0].unit == "rods", "Unit preserved")
        #expect(importedPlan.glassItems[0].notes == "For base layer", "Notes preserved")

        // Second glass item (free-form)
        #expect(importedPlan.glassItems[1].freeformDescription == "Any dark transparent", "Free-form description preserved")
        #expect(importedPlan.glassItems[1].quantity == 1, "Quantity preserved")

        // Cleanup
        try? FileManager.default.removeItem(at: exportURL)
    }

    @Test("Import handles images correctly")
    func testImportWithImages() async throws {
        // Arrange
        let mockImageRepo = MockUserImageRepository()
        let mockPlanRepo = MockProjectRepository()

        // Create a test image and add to repository
        let planId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let testImage = createTestImage(size: CGSize(width: 800, height: 600))
        let imageModel = try await mockImageRepo.saveImage(
            testImage,
            ownerType: .projectPlan,
            ownerId: planId.uuidString,
            type: .primary
        )

        let originalPlan = ProjectModel(
            id: planId,
            title: "Plan With Image",
            type: .recipe,
            coe: "104",
            images: [ProjectImageModel(
                id: imageModel.id,
                projectId: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                projectCategory: .plan,
                fileExtension: "jpg"
            )]
        )

        let exportService = ProjectExportService(userImageRepository: mockImageRepo)
        let importService = ProjectImportService(
            userImageRepository: mockImageRepo,
            projectPlanRepository: mockPlanRepo
        )

        // Export and import
        let exportURL = try await exportService.exportPlan(originalPlan, quality: .optimized, skipCompression: true)
        let importedPlan = try await importService.importPlan(from: exportURL)

        // Assert
        #expect(importedPlan.images.count > 0, "Should import images")

        // Image ID should be different (new image created)
        if !importedPlan.images.isEmpty {
            #expect(importedPlan.images[0].id != imageModel.id, "Image should have new ID")
        }

        // Cleanup
        try? FileManager.default.removeItem(at: exportURL)
    }

    @Test("Import resets usage tracking")
    func testImportResetsUsageTracking() async throws {
        // Arrange
        let mockImageRepo = MockUserImageRepository()
        let mockPlanRepo = MockProjectRepository()
        let exportService = ProjectExportService(userImageRepository: mockImageRepo)
        let importService = ProjectImportService(
            userImageRepository: mockImageRepo,
            projectPlanRepository: mockPlanRepo
        )

        // Create plan with usage data
        let originalPlan = ProjectModel(
            title: "Used Plan",
            type: .recipe,
            coe: "any",
            timesUsed: 5,
            lastUsedDate: Date()
        )

        // Export and import
        let exportURL = try await exportService.exportPlan(originalPlan, quality: .optimized, skipCompression: true)
        let importedPlan = try await importService.importPlan(from: exportURL)

        // Assert - Usage should be reset
        #expect(importedPlan.timesUsed == 0, "Usage count should be reset")
        #expect(importedPlan.lastUsedDate == nil, "Last used date should be nil")

        // Cleanup
        try? FileManager.default.removeItem(at: exportURL)
    }

    @Test("Import fails gracefully with invalid file")
    func testImportInvalidFile() async throws {
        // Arrange
        let mockImageRepo = MockUserImageRepository()
        let mockPlanRepo = MockProjectRepository()
        let importService = ProjectImportService(
            userImageRepository: mockImageRepo,
            projectPlanRepository: mockPlanRepo
        )

        // Create an invalid file (just random data)
        let invalidURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("invalid.molten")
        try "Not a valid plan file".write(to: invalidURL, atomically: true, encoding: .utf8)

        // Act & Assert - Should throw error
        do {
            _ = try await importService.importPlan(from: invalidURL)
            Issue.record("Should have thrown an error for invalid file")
        } catch {
            // Expected to throw
            #expect(error is ImportError, "Should throw ImportError")
        }

        // Cleanup
        try? FileManager.default.removeItem(at: invalidURL)
    }

    @Test("Round-trip export/import preserves data")
    func testRoundTripExportImport() async throws {
        // Arrange
        let mockImageRepo = MockUserImageRepository()
        let mockPlanRepo = MockProjectRepository()
        let exportService = ProjectExportService(userImageRepository: mockImageRepo)
        let importService = ProjectImportService(
            userImageRepository: mockImageRepo,
            projectPlanRepository: mockPlanRepo
        )

        // Create a comprehensive plan
        let originalPlan = ProjectModel(
            title: "Round-Trip Test",
            type: .recipe,
            coe: "104",
            summary: "Testing full round-trip",
            steps: [
                ProjectStepModel(projectId: UUID(), order: 0, title: "Step 1")
            ],
            difficultyLevel: .advanced,
            proposedPriceRange: PriceRange(min: 50, max: 100),
            glassItems: [
                ProjectGlassItem(naturalKey: "test-glass", quantity: 1, unit: "rods")
            ],
            referenceUrls: [
                ProjectReferenceUrl(url: "https://example.com", title: "Test")
            ]
        )

        // Act - Export then import
        let exportURL = try await exportService.exportPlan(originalPlan, quality: .optimized, skipCompression: true)
        let importedPlan = try await importService.importPlan(from: exportURL)

        // Assert - All data preserved
        #expect(importedPlan.title == originalPlan.title)
        #expect(importedPlan.type == originalPlan.type)
        #expect(importedPlan.coe == originalPlan.coe)
        #expect(importedPlan.summary == originalPlan.summary)
        #expect(importedPlan.steps.count == originalPlan.steps.count)
        #expect(importedPlan.difficultyLevel == originalPlan.difficultyLevel)
        #expect(importedPlan.proposedPriceRange?.min == originalPlan.proposedPriceRange?.min)
        #expect(importedPlan.proposedPriceRange?.max == originalPlan.proposedPriceRange?.max)
        #expect(importedPlan.glassItems.count == originalPlan.glassItems.count)
        #expect(importedPlan.referenceUrls.count == originalPlan.referenceUrls.count)

        // Cleanup
        try? FileManager.default.removeItem(at: exportURL)
    }

    // MARK: - Helper Methods

    private func createTestImage(size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
    #endif
}
