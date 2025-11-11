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
@MainActor
final class ImageDownloadService: Sendable {

    // MARK: - Configuration

    /// Base URL for image CDN
    // Using GitHub raw URLs temporarily while Cloudflare deployment is set up
    private static let imageBaseURL = "https://raw.githubusercontent.com/mbinde/molten-data/main/images/product-images"

    /// Local cache directory for downloaded images
    private static let cacheDirectory: URL? = {
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
    private static let urlSession: URLSession = {
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
    ///   - itemCode: The item code (e.g., "650001")
    ///   - manufacturer: The manufacturer abbreviation (e.g., "BB")
    /// - Returns: UIImage if found/downloaded, nil otherwise
    nonisolated static func loadImage(itemCode: String, manufacturer: String?) async -> UIImage? {
        guard let manufacturer = manufacturer, !manufacturer.isEmpty else {
            return nil
        }

        // Build filename: MANUFACTURER-CODE (e.g., "BB-650001")
        let filename = "\(manufacturer.uppercased())-\(itemCode)"

        // Try common extensions
        let extensions = ["webp", "jpg", "jpeg", "png"]
        for ext in extensions {
            let filenameWithExt = "\(filename).\(ext)"

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
            return nil
        }

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
}
