//
//  StockUpdateService.swift
//  Molten
//
//  Service for managing stock database updates.
//  Orchestrates version checks and database downloads.
//

import Combine
import Foundation
import OSLog

// MARK: - Protocol

/// Protocol for stock update service operations
@MainActor
protocol StockUpdateServiceProtocol {
    var isChecking: Bool { get }
    var isDownloading: Bool { get }
    var downloadProgress: Double { get }

    func checkForUpdates() async throws -> StockVersionMetadata?
    func downloadAndInstallUpdate(metadata: StockVersionMetadata) async throws
    func checkForUpdatesIfNeeded() async
}

// MARK: - Implementation

/// Service for managing stock database updates
@MainActor
class StockUpdateService: StockUpdateServiceProtocol, ObservableObject {

    // MARK: - Properties

    private let apiClient: StockAPIClientProtocol
    private let databaseManager: StockDatabaseManagerProtocol
    private let storageService: CatalogStorageServiceProtocol  // Reuse for temp file handling
    private let networkMonitor: any NetworkMonitorProtocol
    private let log = Logger(subsystem: "Molten", category: "StockUpdate")

    @Published private(set) var isChecking: Bool = false
    @Published private(set) var isDownloading: Bool = false
    @Published private(set) var downloadProgress: Double = 0.0

    // MARK: - Initialization

    init(
        apiClient: StockAPIClientProtocol,
        databaseManager: StockDatabaseManagerProtocol = StockDatabaseManager.shared,
        storageService: CatalogStorageServiceProtocol,
        networkMonitor: any NetworkMonitorProtocol
    ) {
        self.apiClient = apiClient
        self.databaseManager = databaseManager
        self.storageService = storageService
        self.networkMonitor = networkMonitor
    }

    // MARK: - Public API

    /// Check if stock database update is available
    /// - Returns: Version metadata if update available, nil if current or no update
    func checkForUpdates() async throws -> StockVersionMetadata? {
        guard !isChecking else {
            log.warning("Stock update check already in progress")
            return nil
        }

        isChecking = true
        defer { isChecking = false }

        log.info("Checking for stock database updates...")

        // Update last check time
        StockUpdatePreferences.shared.lastUpdateCheck = Date()

        do {
            // Get latest version from server
            let latestMetadata = try await apiClient.getLatestVersion()

            // Get current version
            let currentVersion = StockUpdatePreferences.shared.currentVersion

            log.info("Stock DB - Current: v\(currentVersion), Latest: v\(latestMetadata.version)")

            // Check if update available
            guard latestMetadata.version > currentVersion else {
                log.info("Stock database is up to date")
                return nil
            }

            log.info("Stock database update available: v\(latestMetadata.version)")
            return latestMetadata

        } catch let error as StockAPIError where error == .serverError(statusCode: 404) {
            // No stock database available yet - this is OK
            log.info("No stock database available on server yet")
            return nil
        } catch {
            log.error("Failed to check for stock updates: \(error.localizedDescription)")
            throw error
        }
    }

    /// Download and install stock database update
    /// - Parameter metadata: Version metadata for the update
    func downloadAndInstallUpdate(metadata: StockVersionMetadata) async throws {
        guard !isDownloading else {
            log.warning("Stock download already in progress")
            return
        }

        isDownloading = true
        downloadProgress = 0.0

        defer {
            isDownloading = false
            downloadProgress = 0.0
        }

        do {
            log.info("Starting stock database download: v\(metadata.version)")

            // 1. Download database
            let databaseData = try await apiClient.downloadStockDatabase { [weak self] progress in
                Task { @MainActor in
                    self?.downloadProgress = progress * 0.5  // First 50% is download
                }
            }

            downloadProgress = 0.5

            // 2. Verify checksum
            guard databaseData.verifySHA256Checksum(metadata.checksum) else {
                log.error("Stock database checksum mismatch")
                throw StockAPIError.checksumMismatch
            }

            log.info("Stock database checksum verified")
            downloadProgress = 0.6

            // 3. Save to temp file
            let tempFile = try await saveTempDatabase(databaseData, version: metadata.version)

            downloadProgress = 0.7

            // 4. Replace database
            log.info("Replacing stock database...")
            try await databaseManager.replaceDatabaseWith(tempFile: tempFile)

            downloadProgress = 0.9

            // 5. Update preferences
            StockUpdatePreferences.shared.currentVersion = metadata.version
            StockUpdatePreferences.shared.lastSuccessfulUpdate = Date()

            downloadProgress = 1.0

            log.info("Stock database updated successfully to v\(metadata.version)")

        } catch {
            log.error("Failed to download/install stock update: \(error.localizedDescription)")
            throw error
        }
    }

    /// Check for updates if conditions are met (called by BackgroundUpdateService)
    func checkForUpdatesIfNeeded() async {
        // Check if enough time has passed since last check (6 hours)
        guard StockUpdatePreferences.shared.shouldCheckForUpdates() else {
            log.debug("Not yet time for stock update check")
            return
        }

        // Check network connectivity
        guard networkMonitor.isConnected else {
            log.debug("No network connection, skipping stock update check")
            return
        }

        do {
            if let metadata = try await checkForUpdates() {
                // Check if we can auto-download (use same policy as catalog)
                if networkMonitor.canDownloadCatalog() {
                    log.info("Auto-downloading stock database update")
                    try await downloadAndInstallUpdate(metadata: metadata)
                }
            }
        } catch {
            // Silent failure for background checks
            log.debug("Background stock update check failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Helpers

    /// Save database data to a temp file
    private func saveTempDatabase(_ data: Data, version: Int) async throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("stock_v\(version).sqlite")

        // Remove existing temp file if present
        if FileManager.default.fileExists(atPath: tempFile.path) {
            try FileManager.default.removeItem(at: tempFile)
        }

        try data.write(to: tempFile)
        return tempFile
    }
}
