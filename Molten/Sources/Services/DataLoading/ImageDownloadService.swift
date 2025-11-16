//
//  ImageDownloadService.swift
//  Molten
//
//  Created by Assistant on 11/11/25.
//  Service for downloading and caching product images from CDN
//

import Foundation
import UIKit

// MARK: - Manifest Types

/// Image manifest response from R2 API
@preconcurrency struct ImageManifest: Codable, Sendable {
    let version: String
    let generatedAt: String
    let images: [ImageEntry]
    let totalCount: Int
    let totalSize: Int
}

/// Individual image entry in manifest
@preconcurrency struct ImageEntry: Codable, Sendable {
    let filename: String
    let etag: String
    let size: Int
    let lastModified: String
}

/// Service for downloading product images from images.molten.glass and caching locally
/// This is a utility service with static methods - does not need MainActor isolation
final class ImageDownloadService: Sendable {

    // MARK: - Configuration

    /// Base URL for image API (R2-backed)
    // Images served from Cloudflare R2 via API with checksum validation
    nonisolated(unsafe) private static let imageBaseURL = "https://www.moltenglass.app/api/v1/images"

    /// URL for image manifest (contains all images with their ETags)
    nonisolated(unsafe) private static let manifestURL = "https://www.moltenglass.app/api/v1/images/manifest"

    /// Local cache directory for downloaded images
    /// Marked nonisolated(unsafe) because it's computed once at class load and never changes
    nonisolated(unsafe) private static let cacheDirectory: URL? = {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let cacheDir = appSupport.appendingPathComponent("DownloadedImages", isDirectory: true)

        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: cacheDir.path) {
            try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true, attributes: nil)
        }

        return cacheDir
    }()

    /// URL session for downloading images
    /// Marked nonisolated(unsafe) because URLSession is thread-safe and this is read-only
    nonisolated(unsafe) private static let urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10 // 10 second timeout
        config.timeoutIntervalForResource = 30 // 30 second total timeout
        config.requestCachePolicy = .returnCacheDataElseLoad // Use cache when available
        config.urlCache = URLCache(memoryCapacity: 50 * 1024 * 1024, diskCapacity: 100 * 1024 * 1024) // 50MB memory, 100MB disk
        return URLSession(configuration: config)
    }()

    // MARK: - Public API

    /// Fetches the image manifest from R2 API
    /// - Returns: ImageManifest containing all available images with their ETags
    static func fetchManifest() async throws -> ImageManifest {
        guard let url = URL(string: manifestURL) else {
            throw URLError(.badURL)
        }

        let (data, response) = try await urlSession.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let manifest = try JSONDecoder().decode(ImageManifest.self, from: data)
        return manifest
    }

    /// Attempts to load a product image from cache or download from CDN
    /// - Parameters:
    ///   - itemCode: The item code (e.g., "650001" or "BB-650001")
    ///   - manufacturer: The manufacturer abbreviation (e.g., "BB", "CiM")
    ///   - exactFilename: If provided, try this exact filename first (from catalog's image_path field)
    ///   - exactThumbnailFilename: If provided, use this as the thumbnail filename (from catalog's image_thumb_path field)
    ///   - useThumbnail: If true, try thumbnail version first (default: true)
    /// - Returns: UIImage if found/downloaded, nil otherwise
    nonisolated static func loadImage(itemCode: String, manufacturer: String?, exactFilename: String? = nil, exactThumbnailFilename: String? = nil, useThumbnail: Bool = true) async -> UIImage? {
        guard let manufacturer = manufacturer, !manufacturer.isEmpty else {
            return nil
        }

        // Check if we have permission to use product-specific images for this manufacturer
        guard GlassManufacturers.hasProductImagePermission(for: manufacturer) else {
            return nil
        }

        // PRIORITY 1: If exact thumbnail filename provided (from catalog image_thumb_path), try it first
        if useThumbnail, let thumbnailFilename = exactThumbnailFilename, !thumbnailFilename.isEmpty {
            // First check local cache
            if let cachedImage = await loadFromCache(filename: thumbnailFilename) {
                return cachedImage
            }

            // If not cached, try to download
            if let result = await downloadImage(filename: thumbnailFilename) {
                await saveToCache(image: result.image, filename: thumbnailFilename, etag: result.etag)
                return result.image
            }

            // Fall through to try full-size image
        }

        // PRIORITY 2: If exact filename provided (from catalog image_path), try it
        if let filename = exactFilename, !filename.isEmpty {
            // First check local cache
            if let cachedImage = await loadFromCache(filename: filename) {
                return cachedImage
            }

            // If not cached, try to download
            if let result = await downloadImage(filename: filename) {
                await saveToCache(image: result.image, filename: filename, etag: result.etag)
                return result.image
            }
        }

        // No exact filename provided or download failed - return nil
        // The caller (ProductImageView) will fall back to bundled images or manufacturer default
        return nil
    }

    /// Clears cached image for a specific item
    /// - Parameters:
    ///   - itemCode: The item code
    ///   - manufacturer: The manufacturer abbreviation
    nonisolated static func clearCache(itemCode: String, manufacturer: String?) {
        guard let manufacturer = manufacturer,
              let cacheDir = cacheDirectory else {
            return
        }

        let filename = "\(manufacturer.uppercased())-\(itemCode)"
        let extensions = ["webp", "jpg", "jpeg", "png"]

        for ext in extensions {
            let fileURL = cacheDir.appendingPathComponent("\(filename).\(ext)")
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    /// Clears all cached images
    nonisolated static func clearAllCache() {
        guard let cacheDir = cacheDirectory else {
            return
        }

        do {
            let files = try FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil)
            for file in files {
                try? FileManager.default.removeItem(at: file)
            }
        } catch {
            // Silent failure - not critical
        }
    }

    /// Returns the size of the image cache in bytes
    nonisolated static func getCacheSize() -> Int64 {
        guard let cacheDir = cacheDirectory else {
            return 0
        }

        var totalSize: Int64 = 0

        do {
            let files = try FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: [.fileSizeKey])
            for file in files {
                if let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += Int64(size)
                }
            }
        } catch {
            // Silent failure - return 0
        }

        return totalSize
    }

    // MARK: - Private Helpers

    /// Loads image from local cache
    private nonisolated static func loadFromCache(filename: String) async -> UIImage? {
        guard let cacheDir = cacheDirectory else {
            return nil
        }

        let fileURL = cacheDir.appendingPathComponent(filename)

        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            return nil
        }

        return image
    }

    /// Downloads image from CDN and returns both the image and its ETag for checksum validation
    /// - Returns: Tuple of (UIImage, ETag) if successful, nil otherwise
    private nonisolated static func downloadImage(filename: String) async -> (image: UIImage, etag: String)? {
        let urlString = "\(imageBaseURL)/\(filename)"
        guard let url = URL(string: urlString) else {
            return nil
        }

        do {
            let (data, response) = try await urlSession.data(from: url)

            // Check for successful response
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }

            // Extract ETag from response headers (for checksum validation)
            let etag = httpResponse.value(forHTTPHeaderField: "ETag") ?? ""

            // Convert data to UIImage
            guard let image = UIImage(data: data) else {
                return nil
            }

            return (image: image, etag: etag)
        } catch {
            // Silently fail for missing images (expected for many items)
            return nil
        }
    }

    /// Saves image to local cache along with its ETag for checksum validation
    /// - Parameters:
    ///   - image: The image to save
    ///   - filename: The filename to save as
    ///   - etag: Optional ETag from server for checksum validation
    private nonisolated static func saveToCache(image: UIImage, filename: String, etag: String? = nil) async {
        guard let cacheDir = cacheDirectory else {
            return
        }

        let fileURL = cacheDir.appendingPathComponent(filename)

        // Determine format based on extension
        let ext = (filename as NSString).pathExtension.lowercased()
        let data: Data?

        // Convert UIImage to Data using appropriate format
        switch ext {
        case "png":
            data = image.pngData()
        case "jpg", "jpeg":
            data = image.jpegData(compressionQuality: 0.9)
        case "webp":
            // For webp, save as JPEG (iOS doesn't have native webp encoding)
            data = image.jpegData(compressionQuality: 0.9)
        default:
            data = image.jpegData(compressionQuality: 0.9)
        }

        guard let imageData = data else {
            return
        }

        do {
            try imageData.write(to: fileURL, options: .atomic)

            // Store ETag alongside the image for future checksum validation
            if let etag = etag, !etag.isEmpty {
                storeETag(etag, for: filename)
            }
        } catch {
            // Silent failure - cache write is not critical
        }
    }

    /// Converts a filename to its thumbnail version by inserting _thumb before the extension
    /// - Parameter filename: Original filename (e.g., "1ErCJw.jpg")
    /// - Returns: Thumbnail filename (e.g., "1ErCJw_thumb.jpg")
    private nonisolated static func thumbnailFilename(from filename: String) -> String {
        let nsFilename = filename as NSString
        let ext = nsFilename.pathExtension
        let nameWithoutExt = nsFilename.deletingPathExtension

        if ext.isEmpty {
            return "\(nameWithoutExt)_thumb"
        } else {
            return "\(nameWithoutExt)_thumb.\(ext)"
        }
    }

    // MARK: - ETag Storage (for checksum validation)

    /// Returns the path for storing an image's ETag
    private nonisolated static func etagPath(for filename: String) -> URL? {
        guard let cacheDir = cacheDirectory else {
            return nil
        }
        return cacheDir.appendingPathComponent("\(filename).etag")
    }

    /// Stores the ETag for a cached image
    private nonisolated static func storeETag(_ etag: String, for filename: String) {
        guard let path = etagPath(for: filename) else {
            return
        }

        do {
            try etag.write(to: path, atomically: true, encoding: .utf8)
        } catch {
            // Silent failure - ETag storage is not critical
        }
    }

    /// Retrieves the stored ETag for a cached image
    private nonisolated static func getStoredETag(for filename: String) -> String? {
        guard let path = etagPath(for: filename),
              FileManager.default.fileExists(atPath: path.path) else {
            return nil
        }

        return try? String(contentsOf: path, encoding: .utf8)
    }

    /// Checks if a cached image matches the expected ETag
    /// - Parameters:
    ///   - filename: The image filename
    ///   - expectedETag: The ETag from R2 manifest
    /// - Returns: true if cached image exists and ETags match
    nonisolated static func isCacheValid(for filename: String, expectedETag: String) -> Bool {
        // Check if image file exists
        guard let cacheDir = cacheDirectory else {
            return false
        }

        let imageURL = cacheDir.appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: imageURL.path) else {
            return false
        }

        // Check if stored ETag matches expected
        guard let storedETag = getStoredETag(for: filename) else {
            return false
        }

        return storedETag == expectedETag
    }
}
