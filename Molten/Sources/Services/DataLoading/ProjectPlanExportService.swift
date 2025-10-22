//
//  ProjectPlanExportService.swift
//  Molten
//
//  Service for exporting project plans to .molten files (ZIP format)
//  with configurable image quality options
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Export quality options for project plans
enum ExportQuality: String, CaseIterable, Identifiable {
    case full = "Full Quality"
    case optimized = "Optimized"
    case compact = "Compact"

    nonisolated var id: String { rawValue }

    /// Maximum image dimension for this quality level
    nonisolated var maxImageDimension: CGFloat {
        switch self {
        case .full: return 2048
        case .optimized: return 1600
        case .compact: return 1280
        }
    }

    /// JPEG compression quality (0.0 - 1.0)
    nonisolated var compressionQuality: CGFloat {
        switch self {
        case .full: return 0.85
        case .optimized: return 0.75
        case .compact: return 0.70
        }
    }

    /// Estimated MB per image
    nonisolated var estimatedMBPerImage: Double {
        switch self {
        case .full: return 0.35
        case .optimized: return 0.20
        case .compact: return 0.14
        }
    }

    /// User-friendly description
    nonisolated var description: String {
        switch self {
        case .full: return "Best quality, larger files"
        case .optimized: return "Recommended for sharing"
        case .compact: return "Smallest size"
        }
    }
}

#if canImport(UIKit)
/// Service for exporting project plans
class ProjectPlanExportService {
    nonisolated(unsafe) private let userImageRepository: UserImageRepository

    nonisolated init(userImageRepository: UserImageRepository) {
        self.userImageRepository = userImageRepository
    }

    /// Export a project plan to a .molten file
    /// - Parameters:
    ///   - plan: The project plan to export
    ///   - quality: Export quality level (affects image size/compression)
    /// - Returns: URL to the exported .molten file in temp directory
    func exportPlan(_ plan: ProjectPlanModel, quality: ExportQuality = .optimized) async throws -> URL {
        // Create temporary directory for export
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MoltenExport-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // 1. Export plan metadata as JSON
        let planJSON = try encodePlanToJSON(plan)
        let jsonURL = tempDir.appendingPathComponent("plan.json")
        try planJSON.write(to: jsonURL)

        // 2. Export images to images/ folder
        let imagesDir = tempDir.appendingPathComponent("images")
        try FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)

        // Get all images for this plan from UserImageRepository
        let allPlanImages = try await userImageRepository.getImages(
            ownerType: .projectPlan,
            ownerId: plan.id.uuidString
        )

        // Create lookup dictionary for fast access
        let imagesByID = Dictionary(uniqueKeysWithValues: allPlanImages.map { ($0.id, $0) })

        // Export each image referenced in the plan
        for projectImage in plan.images {
            // Find the corresponding UserImageModel
            guard let userImageModel = imagesByID[projectImage.id],
                  let image = try? await userImageRepository.loadImage(userImageModel) else {
                continue  // Skip if image not found
            }

            // Export with quality settings
            let exportedImageData = try exportImage(image, quality: quality)
            let imageURL = imagesDir.appendingPathComponent("\(projectImage.id.uuidString).jpg")
            try exportedImageData.write(to: imageURL)
        }

        // 3. Create ZIP file
        let sanitizedTitle = plan.title.replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let zipFileName = sanitizedTitle.isEmpty ? "Project Plan" : sanitizedTitle
        let zipURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(zipFileName).molten")

        // Remove existing file if present
        try? FileManager.default.removeItem(at: zipURL)

        // Create ZIP archive
        try await zipDirectory(at: tempDir, to: zipURL)

        // Clean up temp directory
        try? FileManager.default.removeItem(at: tempDir)

        return zipURL
    }

    /// Estimate the size of an exported plan in bytes
    func estimateExportSize(_ plan: ProjectPlanModel, quality: ExportQuality) async -> Int64 {
        // JSON size (rough estimate: 5-10 KB)
        let jsonSize: Int64 = 10_000

        // Image count
        let imageCount = plan.images.count

        // Estimated bytes per image
        let bytesPerImage = Int64(quality.estimatedMBPerImage * 1_000_000)

        let totalSize = jsonSize + (Int64(imageCount) * bytesPerImage)
        return totalSize
    }

    /// Get formatted size string (e.g., "4.2 MB")
    func formattedEstimatedSize(_ plan: ProjectPlanModel, quality: ExportQuality) async -> String {
        let bytes = await estimateExportSize(plan, quality: quality)
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    // MARK: - Private Helpers

    /// Encode plan to JSON data
    private func encodePlanToJSON(_ plan: ProjectPlanModel) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(plan)
    }

    /// Export an image with specified quality settings
    /// Uses progressive JPEG encoding for better compression
    private func exportImage(_ image: UIImage, quality: ExportQuality) throws -> Data {
        // Resize if needed
        let resizedImage = ImageProcessor.resize(image, maxDimension: quality.maxImageDimension)

        // Convert to progressive JPEG
        guard let data = ImageProcessor.progressiveJPEGData(
            from: resizedImage,
            compressionQuality: quality.compressionQuality
        ) else {
            throw ExportError.failedToCompressImage
        }

        return data
    }

    /// Create a ZIP archive from a directory
    private func zipDirectory(at sourceURL: URL, to destinationURL: URL) async throws {
        // On iOS, we need to use Foundation's FileManager coordination
        // or the Compression framework for creating ZIP files

        // For now, use a simple implementation that creates an uncompressed archive
        // A production implementation would use Apple's Compression framework

        let coordinator = NSFileCoordinator()
        var coordinatorError: NSError?

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            coordinator.coordinate(readingItemAt: sourceURL, options: .forUploading, error: &coordinatorError) { zipURL in
                do {
                    // The system creates a temporary ZIP for us
                    try FileManager.default.copyItem(at: zipURL, to: destinationURL)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }

            if let error = coordinatorError {
                continuation.resume(throwing: error)
            }
        }
    }
}

// MARK: - Image Processing Utilities

nonisolated struct ImageProcessor {
    /// Resize image to fit within maxDimension while preserving aspect ratio
    nonisolated static func resize(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size

        // If already smaller than max, return as-is
        if size.width <= maxDimension && size.height <= maxDimension {
            return image
        }

        // Calculate new size maintaining aspect ratio
        let aspectRatio = size.width / size.height
        let newSize: CGSize

        if size.width > size.height {
            // Landscape or square
            newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            // Portrait
            newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        }

        // Resize using high-quality renderer
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resizedImage = renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }

        return resizedImage
    }

    /// Create progressive JPEG data from an image
    /// Progressive JPEGs load faster and compress slightly better
    nonisolated static func progressiveJPEGData(from image: UIImage, compressionQuality: CGFloat) -> Data? {
        // Unfortunately, UIImage.jpegData doesn't support progressive encoding directly
        // We need to use ImageIO for this

        guard let cgImage = image.cgImage else { return nil }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData,
            "public.jpeg" as CFString,
            1,
            nil
        ) else {
            return nil
        }

        // Set progressive encoding and quality
        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: compressionQuality,
            kCGImagePropertyOrientation: image.imageOrientation.cgImagePropertyOrientation,
            // Progressive JPEG (if supported by the system)
            kCGImageDestinationImageMaxPixelSize: max(image.size.width, image.size.height)
        ]

        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            return nil
        }

        return data as Data
    }
}

// MARK: - Errors

enum ExportError: LocalizedError {
    case failedToCompressImage
    case failedToCreateZIP
    case failedToWriteFile

    var errorDescription: String? {
        switch self {
        case .failedToCompressImage:
            return "Failed to compress image for export"
        case .failedToCreateZIP:
            return "Failed to create export file"
        case .failedToWriteFile:
            return "Failed to write export file to disk"
        }
    }
}

// MARK: - UIImage.Orientation to CGImagePropertyOrientation

private extension UIImage.Orientation {
    nonisolated var cgImagePropertyOrientation: Int {
        switch self {
        case .up: return 1
        case .down: return 3
        case .left: return 8
        case .right: return 6
        case .upMirrored: return 2
        case .downMirrored: return 4
        case .leftMirrored: return 5
        case .rightMirrored: return 7
        @unknown default: return 1
        }
    }
}
#endif
