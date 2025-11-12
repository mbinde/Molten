//
//  ImageDownloadService.swift
//  Molten
//
//  Created by Assistant on 11/11/25.
//  Service for downloading and caching product images from CDN
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Service for downloading product images from images.molten.glass and caching locally
/// This is a utility service with static methods - does not need MainActor isolation
final class ImageDownloadService: Sendable {

    // MARK: - Configuration

    /// Base URL for image CDN
    // Images served as static assets from Cloudflare Pages
    nonisolated(unsafe) private static let imageBaseURL = "https://www.moltenglass.app/images"

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

    /// Attempts to load a product image from cache or download from CDN
    /// - Parameters:
    ///   - itemCode: The item code (e.g., "650001" or "BB-650001")
    ///   - manufacturer: The manufacturer abbreviation (e.g., "BB", "CiM")
    ///   - exactFilename: If provided, try this exact filename first (from catalog's image_path field)
    ///   - useThumbnail: If true, automatically try thumbnail version (_thumb.jpg) first (default: true)
    /// - Returns: UIImage if found/downloaded, nil otherwise
    nonisolated static func loadImage(itemCode: String, manufacturer: String?, exactFilename: String? = nil, useThumbnail: Bool = true) async -> UIImage? {
        guard let manufacturer = manufacturer, !manufacturer.isEmpty else {
            return nil
        }

        // Check if we have permission to use product-specific images for this manufacturer
        guard GlassManufacturers.hasProductImagePermission(for: manufacturer) else {
            print("⚠️ [ImageDownloadService] No image permission for manufacturer: \(manufacturer)")
            return nil
        }

        // PRIORITY 1: If exact filename provided (from catalog image_path), try it first
        if let filename = exactFilename, !filename.isEmpty {
            // Convert to thumbnail version if requested
            let targetFilename = useThumbnail ? thumbnailFilename(from: filename) : filename
            print("📸 [ImageDownloadService] Trying exact filename: \(targetFilename)\(useThumbnail ? " (thumbnail)" : "")")

            // First check local cache
            if let cachedImage = await loadFromCache(filename: targetFilename) {
                print("✅ [ImageDownloadService] Found in cache: \(targetFilename)")
                return cachedImage
            }

            // If not cached, try to download
            if let downloadedImage = await downloadImage(filename: targetFilename) {
                print("✅ [ImageDownloadService] Downloaded from CDN: \(targetFilename)")
                // Save to cache for next time
                await saveToCache(image: downloadedImage, filename: targetFilename)
                return downloadedImage
            }

            print("❌ [ImageDownloadService] Failed to load: \(targetFilename)")

            // If thumbnail failed and we were looking for thumbnail, try full-size as fallback
            if useThumbnail && targetFilename != filename {
                print("📸 [ImageDownloadService] Thumbnail failed, trying full-size: \(filename)")

                if let cachedImage = await loadFromCache(filename: filename) {
                    print("✅ [ImageDownloadService] Found full-size in cache: \(filename)")
                    return cachedImage
                }

                if let downloadedImage = await downloadImage(filename: filename) {
                    print("✅ [ImageDownloadService] Downloaded full-size from CDN: \(filename)")
                    await saveToCache(image: downloadedImage, filename: filename)
                    return downloadedImage
                }
            }

            // If exact filename failed, fall through to variation logic below
        }

        // PRIORITY 2: Try variations if no exact filename or exact filename failed
        // Sanitize filename (replace slashes with dashes)
        let sanitizedCode = itemCode.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: "\\", with: "-")
        let sanitizedManufacturer = manufacturer.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: "\\", with: "-")

        // Try multiple case variations (matching ImageHelpers.swift logic)
        let manufacturerVariations = [
            sanitizedManufacturer.uppercased(),  // Try uppercase first (most common)
            sanitizedManufacturer.lowercased(),  // Then lowercase
            sanitizedManufacturer.capitalized,   // Then capitalized
            sanitizedManufacturer                // Finally original case
        ]

        // Common image extensions to try
        let extensions = ["webp", "jpg", "jpeg", "png", "PNG", "JPG", "JPEG", "WEBP"]

        // Try with manufacturer prefix variations
        for mfrVariation in manufacturerVariations {
            for ext in extensions {
                // Check if itemCode already starts with manufacturer prefix to avoid duplication
                let imageName: String
                if sanitizedCode.uppercased().hasPrefix("\(mfrVariation.uppercased())-") {
                    // ItemCode already includes manufacturer prefix, use as-is
                    imageName = sanitizedCode
                } else {
                    // Add manufacturer prefix
                    imageName = "\(mfrVariation)-\(sanitizedCode)"
                }

                let filenameWithExt = "\(imageName).\(ext)"

                // First check local cache
                if let cachedImage = await loadFromCache(filename: filenameWithExt) {
                    return cachedImage
                }

                // If not cached, try to download
                if let downloadedImage = await downloadImage(filename: filenameWithExt) {
                    // Save to cache for next time
                    await saveToCache(image: downloadedImage, filename: filenameWithExt)
                    return downloadedImage
                }
            }
        }

        // Fallback: try without manufacturer prefix (for backward compatibility)
        for ext in extensions {
            let filenameWithExt = "\(sanitizedCode).\(ext)"

            // First check local cache
            if let cachedImage = await loadFromCache(filename: filenameWithExt) {
                return cachedImage
            }

            // If not cached, try to download
            if let downloadedImage = await downloadImage(filename: filenameWithExt) {
                // Save to cache for next time
                await saveToCache(image: downloadedImage, filename: filenameWithExt)
                return downloadedImage
            }
        }

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
            print("❌ [ImageDownloadService] Failed to clear cache: \(error)")
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
            print("❌ [ImageDownloadService] Failed to calculate cache size: \(error)")
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

    /// Downloads image from CDN
    private nonisolated static func downloadImage(filename: String) async -> UIImage? {
        let urlString = "\(imageBaseURL)/\(filename)"
        guard let url = URL(string: urlString) else {
            print("❌ [ImageDownloadService] Invalid URL: \(urlString)")
            return nil
        }

//        print("🌐 [ImageDownloadService] Fetching: \(urlString)")

        do {
            let (data, response) = try await urlSession.data(from: url)

            // Check for successful response
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }

            // Convert data to UIImage
            guard let image = UIImage(data: data) else {
                return nil
            }

            return image
        } catch {
            // Silently fail for missing images (expected for many items)
            // Only log unexpected errors
            if (error as? URLError)?.code != .fileDoesNotExist &&
               (error as? URLError)?.code != .cancelled {
                print("⚠️ [ImageDownloadService] Failed to download \(filename): \(error)")
            }
            return nil
        }
    }

    /// Saves image to local cache
    private nonisolated static func saveToCache(image: UIImage, filename: String) async {
        guard let cacheDir = cacheDirectory else {
            return
        }

        let fileURL = cacheDir.appendingPathComponent(filename)

        // Determine format based on extension
        let ext = (filename as NSString).pathExtension.lowercased()
        let data: Data?

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
        } catch {
            print("❌ [ImageDownloadService] Failed to save to cache: \(error)")
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
}
