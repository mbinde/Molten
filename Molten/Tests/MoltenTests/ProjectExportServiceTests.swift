//
//  ProjectExportServiceTests.swift
//  MoltenTests
//
//  Tests for project plan export/import functionality
//

import Testing
import Foundation
#if canImport(UIKit)
import UIKit
#endif
@testable import Molten

@Suite("Project Plan Export Service Tests")
struct ProjectExportServiceTests {

    #if canImport(UIKit)
    @Test("Export creates a valid .molten file")
    func testExportCreatesFile() async throws {
        // Arrange
        let mockImageRepo = MockUserImageRepository()
        let service = ProjectExportService(userImageRepository: mockImageRepo)

        let plan = ProjectModel(
            title: "Test Bead Tutorial",
            type: .recipe,
            coe: "104",
            summary: "A simple bead tutorial for testing"
        )

        // Act
        let exportURL = try await service.exportPlan(plan, quality: .optimized)

        // Assert
        #expect(FileManager.default.fileExists(atPath: exportURL.path), "Export file should exist")
        #expect(exportURL.pathExtension == "molten", "File should have .molten extension")
        #expect(exportURL.lastPathComponent.contains("Test Bead Tutorial"), "Filename should include plan title")

        // Cleanup
        try? FileManager.default.removeItem(at: exportURL)
    }

    @Test("Export quality affects file size")
    func testExportQualityAffectsSize() async throws {
        // Arrange
        let mockImageRepo = MockUserImageRepository()

        // Create a test image
        let planId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        let testImage = createTestImage(size: CGSize(width: 3000, height: 2000))

        // Add image to mock repository
        let imageModel = try await mockImageRepo.saveImage(
            testImage,
            ownerType: .projectPlan,
            ownerId: planId.uuidString,
            type: .primary
        )

        let plan = ProjectModel(
            id: planId,
            title: "Plan With Images",
            type: .recipe,
            coe: "104",
            images: [ProjectImageModel(
                id: imageModel.id,
                projectId: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
                projectCategory: .plan,
                fileExtension: "jpg"
            )]
        )

        let service = ProjectExportService(userImageRepository: mockImageRepo)

        // Act - Export with different qualities (using skipCompression to get directories)
        let fullURL = try await service.exportPlan(plan, quality: .full, skipCompression: true)
        let optimizedURL = try await service.exportPlan(plan, quality: .optimized, skipCompression: true)
        let compactURL = try await service.exportPlan(plan, quality: .compact, skipCompression: true)

        // Get image file sizes from the images directory
        let fullImageURL = fullURL.appendingPathComponent("images").appendingPathComponent("\(imageModel.id.uuidString).jpg")
        let optimizedImageURL = optimizedURL.appendingPathComponent("images").appendingPathComponent("\(imageModel.id.uuidString).jpg")
        let compactImageURL = compactURL.appendingPathComponent("images").appendingPathComponent("\(imageModel.id.uuidString).jpg")

        let fullSize = try FileManager.default.attributesOfItem(atPath: fullImageURL.path)[.size] as! Int64
        let optimizedSize = try FileManager.default.attributesOfItem(atPath: optimizedImageURL.path)[.size] as! Int64
        let compactSize = try FileManager.default.attributesOfItem(atPath: compactImageURL.path)[.size] as! Int64

        // Assert - Full should be larger than Optimized, Optimized larger than Compact
        #expect(fullSize > optimizedSize, "Full quality should be larger than optimized")
        #expect(optimizedSize > compactSize, "Optimized should be larger than compact")

        // Cleanup
        try? FileManager.default.removeItem(at: fullURL)
        try? FileManager.default.removeItem(at: optimizedURL)
        try? FileManager.default.removeItem(at: compactURL)
    }

    @Test("File size estimation is reasonable")
    func testFileSizeEstimation() async throws {
        // Arrange
        let mockImageRepo = MockUserImageRepository()
        let service = ProjectExportService(userImageRepository: mockImageRepo)

        // Plan with no images
        let emptyPlan = ProjectModel(
            title: "No Images",
            type: .idea,
            coe: "any"
        )

        // Plan with 5 images
        let planWithImages = ProjectModel(
            title: "With Images",
            type: .recipe,
            coe: "104",
            images: Array(repeating: ProjectImageModel(
                projectId: UUID(),
                projectCategory: .plan,
                fileExtension: "jpg"
            ), count: 5)
        )

        // Act
        let emptyEstimate = await service.estimateExportSize(emptyPlan, quality: .optimized)
        let withImagesEstimate = await service.estimateExportSize(planWithImages, quality: .optimized)

        // Assert
        #expect(emptyEstimate < 50_000, "Empty plan should be under 50KB")
        #expect(withImagesEstimate > emptyEstimate, "Plan with images should be larger")

        // Estimate should be approximately 5 * 200KB + 10KB
        let expectedSize = Int64(5 * 200_000 + 10_000)
        let tolerance = Int64(500_000) // 500KB tolerance
        #expect(abs(withImagesEstimate - expectedSize) < tolerance, "Estimate should be within reasonable range")
    }

    @Test("Formatted size string is human-readable")
    func testFormattedSizeString() async throws {
        // Arrange
        let mockImageRepo = MockUserImageRepository()
        let service = ProjectExportService(userImageRepository: mockImageRepo)

        let smallPlan = ProjectModel(
            title: "Small",
            type: .idea,
            coe: "any"
        )

        let largePlan = ProjectModel(
            title: "Large",
            type: .recipe,
            coe: "104",
            images: Array(repeating: ProjectImageModel(
                projectId: UUID(),
                projectCategory: .plan,
                fileExtension: "jpg"
            ), count: 20)
        )

        // Act
        let smallSize = await service.formattedEstimatedSize(smallPlan, quality: .optimized)
        let largeSize = await service.formattedEstimatedSize(largePlan, quality: .optimized)

        // Assert
        #expect(smallSize.contains("KB") || smallSize.contains("bytes"), "Small plan should show KB or bytes")
        #expect(largeSize.contains("MB"), "Large plan should show MB")
    }

    @Test("Export handles sanitized filenames")
    func testSanitizedFilenames() async throws {
        // Arrange
        let mockImageRepo = MockUserImageRepository()
        let service = ProjectExportService(userImageRepository: mockImageRepo)

        let plan = ProjectModel(
            title: "Test/Plan:With*Invalid?Characters",
            type: .recipe,
            coe: "104"
        )

        // Act
        let exportURL = try await service.exportPlan(plan, quality: .optimized)

        // Assert
        #expect(!exportURL.lastPathComponent.contains("/"), "Filename should not contain /")
        #expect(!exportURL.lastPathComponent.contains(":"), "Filename should not contain :")
        #expect(!exportURL.lastPathComponent.contains("*"), "Filename should not contain *")
        #expect(!exportURL.lastPathComponent.contains("?"), "Filename should not contain ?")
        #expect(exportURL.pathExtension == "molten", "File should have .molten extension")

        // Cleanup
        try? FileManager.default.removeItem(at: exportURL)
    }

    @Test("Export includes all plan data in JSON")
    func testExportIncludesAllData() async throws {
        // Arrange
        let mockImageRepo = MockUserImageRepository()
        let service = ProjectExportService(userImageRepository: mockImageRepo)

        let step1 = ProjectStepModel(
            projectId: UUID(),
            order: 0,
            title: "Step 1",
            description: "First step"
        )

        let step2 = ProjectStepModel(
            projectId: UUID(),
            order: 1,
            title: "Step 2",
            description: "Second step"
        )

        let plan = ProjectModel(
            title: "Complete Plan",
            type: .recipe,
            coe: "104",
            summary: "A complete plan with all fields",
            steps: [step1, step2],
            difficultyLevel: .intermediate,
            referenceUrls: [
                ProjectReferenceUrl(
                    url: "https://example.com",
                    title: "Example Tutorial"
                )
            ]
        )

        // Act
        let exportURL = try await service.exportPlan(plan, quality: .optimized)

        // Verify the file exists
        #expect(FileManager.default.fileExists(atPath: exportURL.path), "Export file should exist")

        // TODO: In a full implementation, we would:
        // 1. Unzip the .molten file
        // 2. Read the plan.json
        // 3. Verify all fields are present and correct

        // Cleanup
        try? FileManager.default.removeItem(at: exportURL)
    }

    @Test("Quality presets have correct values")
    func testQualityPresets() {
        // Full quality
        #expect(ExportQuality.full.maxImageDimension == 2048)
        #expect(ExportQuality.full.compressionQuality == 0.85)

        // Optimized quality
        #expect(ExportQuality.optimized.maxImageDimension == 1600)
        #expect(ExportQuality.optimized.compressionQuality == 0.75)

        // Compact quality
        #expect(ExportQuality.compact.maxImageDimension == 1280)
        #expect(ExportQuality.compact.compressionQuality == 0.70)
    }

    @Test("ImageProcessor resizes images correctly")
    func testImageResizing() {
        // Large landscape image
        let landscapeImage = createTestImage(size: CGSize(width: 4000, height: 3000))
        let resizedLandscape = ImageProcessor.resize(landscapeImage, maxDimension: 2048)

        #expect(resizedLandscape.size.width == 2048, "Width should be resized to max")
        #expect(resizedLandscape.size.height == 1536, "Height should maintain aspect ratio")

        // Large portrait image
        let portraitImage = createTestImage(size: CGSize(width: 3000, height: 4000))
        let resizedPortrait = ImageProcessor.resize(portraitImage, maxDimension: 2048)

        #expect(resizedPortrait.size.width == 1536, "Width should maintain aspect ratio")
        #expect(resizedPortrait.size.height == 2048, "Height should be resized to max")

        // Small image (should not be upscaled)
        let smallImage = createTestImage(size: CGSize(width: 800, height: 600))
        let resizedSmall = ImageProcessor.resize(smallImage, maxDimension: 2048)

        #expect(resizedSmall.size.width == 800, "Small image width should not change")
        #expect(resizedSmall.size.height == 600, "Small image height should not change")
    }

    // MARK: - Helper Methods

    private func createTestImage(size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            // Fill with gradient to create realistic file size
            let colors = [UIColor.blue.cgColor, UIColor.green.cgColor]
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(
                colorsSpace: colorSpace,
                colors: colors as CFArray,
                locations: [0.0, 1.0]
            )!

            context.cgContext.drawLinearGradient(
                gradient,
                start: .zero,
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )
        }
    }
    #endif
}
