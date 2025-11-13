//
//  CatalogUpdateService.swift
//  Molten
//
//  Created by Assistant on 11/9/25.
//  Service for managing catalog updates
//

import Foundation
import OSLog
import Combine

/// Protocol for catalog update service operations (for dependency injection)
@MainActor
protocol CatalogUpdateServiceProtocol: ObservableObject {
    var isChecking: Bool { get }
    var isDownloading: Bool { get }
    var downloadProgress: Double { get }

    func checkForUpdates() async throws -> CatalogUpdateInfo?
    func downloadAndInstallUpdate(updateInfo: CatalogUpdateInfo, force: Bool) async throws -> CatalogUpdateResult
}

/// Service for managing catalog updates
@MainActor
class CatalogUpdateService: CatalogUpdateServiceProtocol {

    // MARK: - Properties

    private let apiClient: CatalogAPIClientProtocol
    private let storageService: CatalogStorageServiceProtocol
    private let databaseManager: CatalogDatabaseManager
    private let networkMonitor: NetworkMonitorProtocol
    private let log = Logger(subsystem: "Molten", category: "CatalogUpdate")

    @Published private(set) var isChecking: Bool = false
    @Published private(set) var isDownloading: Bool = false
    @Published private(set) var downloadProgress: Double = 0.0

    // MARK: - Initialization

    init(
        apiClient: CatalogAPIClientProtocol,
        storageService: CatalogStorageServiceProtocol,
        databaseManager: CatalogDatabaseManager = .shared,
        networkMonitor: NetworkMonitorProtocol
    ) {
        self.apiClient = apiClient
        self.storageService = storageService
        self.databaseManager = databaseManager
        self.networkMonitor = networkMonitor
    }

    // MARK: - Public API

    /// Check if catalog update is available
    /// - Returns: Update info if available, nil if current
    func checkForUpdates() async throws -> CatalogUpdateInfo? {
        guard !isChecking else {
            log.warning("Update check already in progress")
            return nil
        }

        isChecking = true
        defer { isChecking = false }

        log.info("Checking for catalog updates...")

        do {
            // Get latest version from server
            let latestMetadata = try await apiClient.getLatestVersion()

            // Update last check time
            CatalogUpdatePreferences.shared.lastUpdateCheck = Date()

            // Get current version
            let currentVersion = CatalogUpdatePreferences.shared.currentCatalogVersion

            log.info("Current: v\(currentVersion), Latest: v\(latestMetadata.version)")

            // Check if update available
            guard latestMetadata.version > currentVersion else {
                log.info("✅ Catalog is up to date")
                return nil
            }

            // Check app version compatibility
            let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
            guard latestMetadata.isCompatibleWithApp(version: appVersion) else {
                log.warning("Catalog v\(latestMetadata.version) requires app version \(latestMetadata.minAppVersion)")
                throw CatalogUpdateError.incompatibleVersion(
                    required: latestMetadata.minAppVersion,
                    current: appVersion
                )
            }

            // Build update info
            let updateInfo = CatalogUpdateInfo(
                currentVersion: currentVersion,
                availableVersion: latestMetadata.version,
                itemsAdded: 0,  // We don't know this until we download
                releaseDate: latestMetadata.releaseDate,
                changelog: latestMetadata.changelog,
                fileSize: latestMetadata.fileSize,
                checksum: latestMetadata.checksum
            )

            log.info("📦 Update available: v\(currentVersion) → v\(updateInfo.availableVersion)")

            // Post notification
            NotificationCenter.default.post(
                name: .catalogUpdateAvailable,
                object: updateInfo
            )

            return updateInfo

        } catch {
            log.error("Failed to check for updates: \(error.localizedDescription)")
            throw error
        }
    }

    /// Download and install catalog update
    /// - Parameters:
    ///   - updateInfo: Update information
    ///   - force: Force download even if network policy restricts it
    /// - Returns: Update result
    func downloadAndInstallUpdate(
        updateInfo: CatalogUpdateInfo,
        force: Bool = false
    ) async throws -> CatalogUpdateResult {

        guard !isDownloading else {
            log.warning("Download already in progress")
            throw CatalogUpdateError.downloadFailed(
                underlying: NSError(domain: "CatalogUpdate", code: -1,
                                  userInfo: [NSLocalizedDescriptionKey: "Download already in progress"])
            )
        }

        isDownloading = true
        downloadProgress = 0.0

        defer {
            isDownloading = false
            downloadProgress = 0.0
        }

        do {
            // 1. Check network policy
            if !force {
                guard networkMonitor.canDownloadCatalog() else {
                    log.warning("Download blocked by network policy")
                    throw CatalogUpdateError.networkPolicyRestricted
                }
            }

            log.info("Starting catalog download: v\(updateInfo.availableVersion)")

            // 2. Download catalog
            let catalogData = try await apiClient.downloadFullCatalog(
                version: updateInfo.availableVersion
            ) { [weak self] progress in
                Task { @MainActor in
                    self?.downloadProgress = progress * 0.5  // First 50% is download
                }
            }

            downloadProgress = 0.5

            // 3. Verify checksum
            guard catalogData.verifySHA256Checksum(updateInfo.checksum) else {
                log.error("Checksum mismatch")
                throw CatalogUpdateError.checksumMismatch
            }

            log.info("✅ Checksum verified")
            downloadProgress = 0.6

            // 4. Save to temp storage
            let tempFile = try await storageService.saveTempCatalog(
                catalogData,
                version: updateInfo.availableVersion
            )

            downloadProgress = 0.7

            // 5. Replace database with downloaded version
            log.info("Replacing catalog database...")

            try await databaseManager.replaceDatabaseWith(tempFile: tempFile)

            downloadProgress = 0.9

            // 6. Update version tracking
            CatalogUpdatePreferences.shared.currentCatalogVersion = updateInfo.availableVersion
            CatalogUpdatePreferences.shared.lastSuccessfulUpdate = Date()
            CatalogUpdatePreferences.shared.catalogSource = .downloaded

            downloadProgress = 1.0

            // 7. Get item count from new database
            let repository = SQLiteGlassItemRepository()
            let items = try await repository.fetchItems(matching: nil)

            let result = CatalogUpdateResult(
                version: updateInfo.availableVersion,
                itemsCreated: items.count,  // Total item count (can't differentiate created vs updated for full DB replacement)
                itemsUpdated: 0,
                itemsRemoved: 0,
                appliedAt: Date()
            )

            log.info("✅ Catalog updated successfully to v\(updateInfo.availableVersion)")
            log.info("   Created: \(result.itemsCreated), Updated: \(result.itemsUpdated)")

            // Post notification
            NotificationCenter.default.post(
                name: .catalogUpdateCompleted,
                object: result
            )

            return result

        } catch {
            log.error("Failed to download/install update: \(error.localizedDescription)")

            // Post failure notification
            NotificationCenter.default.post(
                name: .catalogUpdateFailed,
                object: error
            )

            throw error
        }
    }

    /// Perform background update check (called by app lifecycle)
    func performBackgroundUpdateCheck() async {
        guard CatalogUpdatePreferences.shared.autoUpdateEnabled else {
            log.debug("Auto-update disabled, skipping background check")
            return
        }

        guard CatalogUpdatePreferences.shared.shouldCheckForUpdates() else {
            log.debug("Not yet time for background update check")
            return
        }

        do {
            if let updateInfo = try await checkForUpdates() {
                log.info("Background check found update: v\(updateInfo.availableVersion)")

                // If auto-update enabled and network allows, download automatically
                let policy = CatalogUpdatePreferences.shared.downloadPolicy
                let canDownload = policy == .wifiAndCellular ||
                                (policy == .wifiOnly && networkMonitor.isOnWiFi)

                if canDownload {
                    log.info("Auto-downloading update in background")
                    _ = try await downloadAndInstallUpdate(updateInfo: updateInfo)
                }
            }
        } catch {
            // Silent failure for background checks
            log.debug("Background update check failed: \(error.localizedDescription)")
        }
    }
}
