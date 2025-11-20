//
//  ImageSyncService.swift
//  Molten
//
//  Service for managing network-aware image synchronization
//  Handles when to download images based on network conditions and user preferences
//

import Foundation
import Network
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Manages image synchronization with network awareness
actor ImageSyncService {

    // MARK: - Network Monitoring

    private let monitor = NWPathMonitor()
    private var currentNetworkStatus: NetworkStatus = .unknown

    enum NetworkStatus {
        case wifi
        case cellular
        case offline
        case unknown
    }

    // MARK: - User Preferences

    /// Whether to download images over cellular (default: false)
    var allowCellularDownloads: Bool {
        get { UserDefaults.standard.bool(forKey: "allowCellularImageDownloads") }
        set { UserDefaults.standard.set(newValue, forKey: "allowCellularImageDownloads") }
    }

    // MARK: - Sync State

    /// Last time we checked the manifest for updates
    private var lastManifestCheck: Date? {
        get { UserDefaults.standard.object(forKey: "lastImageManifestCheck") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "lastImageManifestCheck") }
    }

    /// How often to check for image updates (default: 24 hours)
    private let manifestCheckInterval: TimeInterval = 24 * 60 * 60

    // MARK: - Initialization

    init() {
        // Start network monitoring on a background queue
        // Note: pathUpdateHandler captures self weakly to avoid retain cycles
        monitor.pathUpdateHandler = { [weak self] path in
            Task {
                await self?.updateNetworkStatus(path: path)
            }
        }
        monitor.start(queue: DispatchQueue.global(qos: .background))
    }

    private func updateNetworkStatus(path: NWPath) {
        if path.status == .satisfied {
            if path.usesInterfaceType(.wifi) {
                currentNetworkStatus = .wifi
            } else if path.usesInterfaceType(.cellular) {
                currentNetworkStatus = .cellular
            } else {
                currentNetworkStatus = .wifi // Assume WiFi for wired connections
            }
        } else {
            currentNetworkStatus = .offline
        }
    }

    // MARK: - Public API

    /// Should we download images given current network conditions?
    func shouldDownloadImages() -> Bool {
        switch currentNetworkStatus {
        case .wifi:
            return true
        case .cellular:
            return allowCellularDownloads
        case .offline, .unknown:
            return false
        }
    }

    /// Should we check for image updates?
    /// Checks if enough time has passed since last manifest check
    func shouldCheckForUpdates() -> Bool {
        guard let lastCheck = lastManifestCheck else {
            return true // Never checked before
        }

        let timeSinceLastCheck = Date().timeIntervalSince(lastCheck)
        return timeSinceLastCheck >= manifestCheckInterval
    }

    // MARK: - Catalog Update Workflow

    /// Called when downloading a new catalog
    /// Downloads thumbnails for new/changed items, respecting network conditions
    func syncThumbnailsAfterCatalogUpdate(catalogItems: [GlassItemModel]) async throws {
        guard shouldDownloadImages() else {
            return
        }

        // Step 1: Fetch the manifest to get current ETags
        let manifest = try await ImageDownloadService.fetchManifest()
        lastManifestCheck = Date()

        var downloadCount = 0
        var skipCount = 0

        // Step 2: Check each catalog item
        for item in catalogItems {
            // Only process items with an image path from the catalog
            guard let imagePath = item.image_path, !imagePath.isEmpty else {
                continue
            }

            // Convert to thumbnail filename
            let thumbFilename = thumbnailFilename(from: imagePath)

            // Find this image in the manifest
            guard let manifestEntry = manifest.images.first(where: { $0.filename == thumbFilename }) else {
                continue
            }

            // Check if we need to download
            if ImageDownloadService.isCacheValid(for: thumbFilename, expectedETag: manifestEntry.etag) {
                skipCount += 1
                continue
            }

            // Download the thumbnail
            if let _ = await ImageDownloadService.loadImage(
                manufacturer: item.manufacturer,
                exactFilename: imagePath,
                exactThumbnailFilename: thumbFilename,
                useThumbnail: true
            ) {
                downloadCount += 1

                // Rate limit: pause briefly between downloads to be nice to the network
                if downloadCount % 10 == 0 {
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
                }
            }
        }
    }

    // MARK: - On-Demand Workflow

    /// Called when viewing an item detail
    /// Downloads full-size image if needed, WiFi only
    func loadImageForViewing(itemCode: String, manufacturer: String?, imagePath: String?) async -> PlatformImage? {
        // First try to load from cache (always fast)
        if let cached = await ImageDownloadService.loadImage(
            manufacturer: manufacturer,
            exactFilename: imagePath,
            useThumbnail: false
        ) {
            return cached
        }

        // If not cached, only download on WiFi
        guard currentNetworkStatus == .wifi else {
            return nil
        }

        // Download full-size image
        return await ImageDownloadService.loadImage(
            manufacturer: manufacturer,
            exactFilename: imagePath,
            useThumbnail: false
        )
    }

    // MARK: - Background Refresh

    /// Performs a background check for updated images
    /// Should be called periodically (e.g., daily background task)
    func performBackgroundImageRefresh() async throws {
        // Only on WiFi for background tasks
        guard currentNetworkStatus == .wifi else {
            return
        }

        // Check if we need to refresh
        guard shouldCheckForUpdates() else {
            return
        }

        // Fetch current manifest
        let manifest = try await ImageDownloadService.fetchManifest()
        lastManifestCheck = Date()

        // Find images that need updating
        var needsUpdate: [(filename: String, etag: String)] = []

        for imageEntry in manifest.images {
            if !ImageDownloadService.isCacheValid(for: imageEntry.filename, expectedETag: imageEntry.etag) {
                needsUpdate.append((imageEntry.filename, imageEntry.etag))
            }
        }

        // Download updated images (thumbnails only for background refresh)
        for (index, update) in needsUpdate.enumerated() {
            // Only update thumbnails in background
            guard update.filename.contains("_thumb") else {
                continue
            }

            // Extract item code and manufacturer from filename
            // This is a simple heuristic - adjust based on your naming convention
            let filenameWithoutExt = (update.filename as NSString).deletingPathExtension
            let parts = filenameWithoutExt.components(separatedBy: "-")

            if parts.count >= 2 {
                let manufacturer = parts[0]
                let itemCode = parts[1...].joined(separator: "-").replacingOccurrences(of: "_thumb", with: "")

                _ = await ImageDownloadService.loadImage(
                    manufacturer: manufacturer,
                    exactFilename: update.filename,
                    useThumbnail: true
                )

                // Rate limit
                if index % 10 == 0 {
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
                }
            }
        }
    }

    // MARK: - Helpers

    private func thumbnailFilename(from filename: String) -> String {
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
