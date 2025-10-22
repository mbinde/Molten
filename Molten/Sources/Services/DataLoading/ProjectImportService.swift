//
//  ProjectImportService.swift
//  Molten
//
//  Service for importing project plans from .molten files (ZIP format)
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif
#if canImport(Darwin)
import Darwin
#endif

#if canImport(UIKit)
/// Service for importing project plans
class ProjectImportService {
    nonisolated(unsafe) private let userImageRepository: UserImageRepository
    nonisolated(unsafe) private let projectPlanRepository: ProjectRepository

    nonisolated init(userImageRepository: UserImageRepository, projectPlanRepository: ProjectRepository) {
        self.userImageRepository = userImageRepository
        self.projectPlanRepository = projectPlanRepository
    }

    /// Import a project plan from a .molten file
    /// - Parameter fileURL: URL to the .molten file
    /// - Returns: The imported ProjectModel
    func importPlan(from fileURL: URL) async throws -> ProjectModel {
        // 1. Create temporary directory for extraction
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MoltenImport-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            // Clean up temp directory
            try? FileManager.default.removeItem(at: tempDir)
        }

        // 2. Unzip the .molten file
        try await unzipFile(at: fileURL, to: tempDir)

        // 3. Read plan.json
        let jsonURL = tempDir.appendingPathComponent("plan.json")
        guard FileManager.default.fileExists(atPath: jsonURL.path) else {
            throw ImportError.invalidPlanFile("Missing plan.json")
        }

        let jsonData = try Data(contentsOf: jsonURL)
        var plan = try decodePlanFromJSON(jsonData)

        // 4. Import images
        let imagesDir = tempDir.appendingPathComponent("images")
        if FileManager.default.fileExists(atPath: imagesDir.path) {
            plan = try await importImages(from: imagesDir, for: plan)
        }

        // 5. Generate new ID to avoid conflicts
        plan = regeneratePlanID(plan)

        // 6. Save to repository
        let createdPlan = try await projectPlanRepository.createPlan(plan)

        return createdPlan
    }

    /// Preview a plan without importing it
    /// - Parameter fileURL: URL to the .molten file
    /// - Returns: Preview information about the plan
    func previewPlan(from fileURL: URL) async throws -> ProjectPlanPreview {
        // Create temporary directory for extraction
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MoltenPreview-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            // Clean up temp directory
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Unzip and read plan.json
        try await unzipFile(at: fileURL, to: tempDir)

        let jsonURL = tempDir.appendingPathComponent("plan.json")
        guard FileManager.default.fileExists(atPath: jsonURL.path) else {
            throw ImportError.invalidPlanFile("Missing plan.json")
        }

        let jsonData = try Data(contentsOf: jsonURL)
        let plan = try decodePlanFromJSON(jsonData)

        // Count images
        let imagesDir = tempDir.appendingPathComponent("images")
        var imageCount = 0
        if FileManager.default.fileExists(atPath: imagesDir.path) {
            let contents = try FileManager.default.contentsOfDirectory(at: imagesDir, includingPropertiesForKeys: nil)
            imageCount = contents.filter { $0.pathExtension == "jpg" }.count
        }

        // Calculate file size
        let fileSize = try FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int64 ?? 0

        return ProjectPlanPreview(
            title: plan.title,
            type: plan.type,
            summary: plan.summary,
            tags: plan.tags,
            coe: plan.coe,
            stepCount: plan.steps.count,
            imageCount: imageCount,
            fileSize: fileSize,
            dateCreated: plan.dateCreated
        )
    }

    // MARK: - Private Helpers

    /// Unzip a file to a destination directory
    /// On iOS, uses NSFileCoordinator to extract ZIP files
    private func unzipFile(at sourceURL: URL, to destinationURL: URL) async throws {
        // Start accessing security-scoped resource if needed
        let didStartAccessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        // Create destination directory
        try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true)

        // Check if sourceURL is already a directory (unzipped)
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: sourceURL.path, isDirectory: &isDirectory),
           isDirectory.boolValue {
            // Source is a directory - just copy contents
            let contents = try FileManager.default.contentsOfDirectory(
                at: sourceURL,
                includingPropertiesForKeys: nil
            )
            for item in contents {
                let destination = destinationURL.appendingPathComponent(item.lastPathComponent)
                try? FileManager.default.removeItem(at: destination)
                try FileManager.default.copyItem(at: item, to: destination)
            }
            return
        }

        // Source is a file - try to extract it using NSFileCoordinator
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let coordinator = NSFileCoordinator()
            var coordinatorError: NSError?
            var extractionError: Error?

            // Use .forUploading which may provide extracted contents
            coordinator.coordinate(readingItemAt: sourceURL, options: .forUploading, error: &coordinatorError) { uploadURL in
                do {
                    // Check if we got a directory (extraction worked)
                    var isDir: ObjCBool = false
                    if FileManager.default.fileExists(atPath: uploadURL.path, isDirectory: &isDir),
                       isDir.boolValue {
                        // Great! We have a directory - copy contents
                        let contents = try FileManager.default.contentsOfDirectory(
                            at: uploadURL,
                            includingPropertiesForKeys: nil
                        )

                        for item in contents {
                            let destination = destinationURL.appendingPathComponent(item.lastPathComponent)
                            if FileManager.default.fileExists(atPath: destination.path) {
                                try? FileManager.default.removeItem(at: destination)
                            }
                            try FileManager.default.copyItem(at: item, to: destination)
                        }
                        print("✅ ZIP extracted successfully to \(destinationURL.path)")
                    } else {
                        // Still a ZIP file - iOS doesn't auto-extract
                        // This is a known limitation on iOS
                        print("⚠️ ZIP extraction requires manual handling on iOS")
                        throw ImportError.failedToUnzip
                    }
                } catch {
                    extractionError = error
                }
            }

            // Check for errors
            if let error = coordinatorError {
                continuation.resume(throwing: error)
            } else if let error = extractionError {
                continuation.resume(throwing: error)
            } else {
                continuation.resume()
            }
        }
    }

    /// Decode plan from JSON data
    private func decodePlanFromJSON(_ data: Data) throws -> ProjectModel {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode(ProjectModel.self, from: data)
        } catch {
            throw ImportError.invalidJSON(error.localizedDescription)
        }
    }

    /// Import images from the images directory
    private func importImages(from imagesDir: URL, for plan: ProjectModel) async throws -> ProjectModel {
        var updatedImages: [ProjectImageModel] = []

        // Get all image files
        let imageFiles = try FileManager.default.contentsOfDirectory(
            at: imagesDir,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "jpg" }

        // Import each image
        for imageFile in imageFiles {
            // Extract original image ID from filename (e.g., "ABC-123.jpg" -> UUID)
            let filenameWithoutExt = imageFile.deletingPathExtension().lastPathComponent
            guard let originalImageID = UUID(uuidString: filenameWithoutExt) else {
                continue
            }

            // Load image data
            guard let imageData = try? Data(contentsOf: imageFile),
                  let image = UIImage(data: imageData) else {
                continue
            }

            // Save to user image repository
            let newImageModel = try await userImageRepository.saveImage(
                image,
                ownerType: .projectPlan,
                ownerId: plan.id.uuidString,
                type: .primary // Import all as primary for now
            )

            // Find the corresponding ProjectImageModel in the plan
            if let originalImageModel = plan.images.first(where: { $0.id == originalImageID }) {
                // Create new ProjectImageModel with new ID
                let updatedImageModel = ProjectImageModel(
                    id: newImageModel.id,
                    projectId: plan.id,
                    projectType: originalImageModel.projectType,
                    fileExtension: originalImageModel.fileExtension,
                    caption: originalImageModel.caption,
                    dateAdded: originalImageModel.dateAdded,
                    order: originalImageModel.order
                )
                updatedImages.append(updatedImageModel)
            }
        }

        // Update plan with new image references
        return ProjectModel(
            id: plan.id,
            title: plan.title,
            type: plan.type,
            dateCreated: plan.dateCreated,
            dateModified: Date(),
            isArchived: plan.isArchived,
            tags: plan.tags,
            coe: plan.coe,
            summary: plan.summary,
            steps: plan.steps,
            estimatedTime: plan.estimatedTime,
            difficultyLevel: plan.difficultyLevel,
            proposedPriceRange: plan.proposedPriceRange,
            images: updatedImages,
            heroImageId: updatedImages.first?.id,
            glassItems: plan.glassItems,
            referenceUrls: plan.referenceUrls,
            timesUsed: 0, // Reset usage tracking for imported plan
            lastUsedDate: nil
        )
    }

    /// Regenerate plan ID and all related IDs to avoid conflicts
    private func regeneratePlanID(_ plan: ProjectModel) -> ProjectModel {
        let newPlanID = UUID()

        // Regenerate step IDs
        let updatedSteps = plan.steps.map { step in
            ProjectStepModel(
                id: UUID(),
                planId: newPlanID,
                order: step.order,
                title: step.title,
                description: step.description,
                estimatedMinutes: step.estimatedMinutes,
                glassItemsNeeded: step.glassItemsNeeded
            )
        }

        // Update image projectIds to match new plan ID
        let updatedImages = plan.images.map { image in
            ProjectImageModel(
                id: image.id,
                projectId: newPlanID,
                projectType: image.projectType,
                fileExtension: image.fileExtension,
                caption: image.caption,
                dateAdded: image.dateAdded,
                order: image.order
            )
        }

        // Reference URLs can keep their IDs as they're just links

        return ProjectModel(
            id: newPlanID,
            title: plan.title,
            type: plan.type,
            dateCreated: Date(), // Set to now
            dateModified: Date(),
            isArchived: false, // Import as active
            tags: plan.tags,
            coe: plan.coe,
            summary: plan.summary,
            steps: updatedSteps,
            estimatedTime: plan.estimatedTime,
            difficultyLevel: plan.difficultyLevel,
            proposedPriceRange: plan.proposedPriceRange,
            images: updatedImages, // Preserve imported images
            heroImageId: updatedImages.first?.id,
            glassItems: plan.glassItems,
            referenceUrls: plan.referenceUrls,
            timesUsed: 0,
            lastUsedDate: nil
        )
    }
}

// MARK: - Preview Model

/// Preview information for a plan before importing
nonisolated struct ProjectPlanPreview {
    let title: String
    let type: ProjectType
    let summary: String?
    let tags: [String]
    let coe: String
    let stepCount: Int
    let imageCount: Int
    let fileSize: Int64
    let dateCreated: Date

    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
}

// MARK: - Import Errors

enum ImportError: LocalizedError {
    case invalidPlanFile(String)
    case invalidJSON(String)
    case failedToUnzip
    case failedToImportImages

    var errorDescription: String? {
        switch self {
        case .invalidPlanFile(let reason):
            return "Invalid plan file: \(reason)"
        case .invalidJSON(let reason):
            return "Could not read plan data: \(reason)"
        case .failedToUnzip:
            return "Failed to extract plan file"
        case .failedToImportImages:
            return "Failed to import plan images"
        }
    }
}
#endif
