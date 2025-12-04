//
//  LabelUpdateService.swift
//  Molten
//
//  Service for managing label database updates
//

import Foundation
import OSLog
import Combine

/// Protocol for label update service operations (for dependency injection)
@MainActor
protocol LabelUpdateServiceProtocol: ObservableObject {
    var isChecking: Bool { get }
    var isDownloading: Bool { get }
    var downloadProgress: Double { get }

    func checkForUpdates() async throws -> LabelUpdateInfo?
    func downloadAndInstallUpdate(updateInfo: LabelUpdateInfo, force: Bool) async throws -> LabelUpdateResult
}

/// Service for managing label database updates
@MainActor
class LabelUpdateService: LabelUpdateServiceProtocol {

    // MARK: - Properties

    private let apiClient: LabelAPIClientProtocol
    private let storageService: LabelStorageService
    private let databaseService: LabelDatabaseService
    private let networkMonitor: any NetworkMonitorProtocol
    private let log = Logger(subsystem: "Molten", category: "LabelUpdate")
    private let logger: LoggingService

    @Published private(set) var isChecking: Bool = false
    @Published private(set) var isDownloading: Bool = false
    @Published private(set) var downloadProgress: Double = 0.0

    // MARK: - Initialization

    init(
        apiClient: LabelAPIClientProtocol,
        storageService: LabelStorageService,
        databaseService: LabelDatabaseService,
        networkMonitor: any NetworkMonitorProtocol,
        logger: LoggingService = AppDependencies.shared.loggingService
    ) {
        self.apiClient = apiClient
        self.storageService = storageService
        self.databaseService = databaseService
        self.networkMonitor = networkMonitor
        self.logger = logger
    }

    // MARK: - Public API

    /// Check if label database update is available
    /// - Returns: Update info if available, nil if current
    func checkForUpdates() async throws -> LabelUpdateInfo? {
        guard !isChecking else {
            log.warning("Update check already in progress")
            return nil
        }

        isChecking = true
        defer { isChecking = false }

        log.info("Checking for label database updates...")

        // Update last check time
        LabelUpdatePreferences.shared.lastUpdateCheck = Date()

        do {
            // Get latest version from server
            let latestMetadata = try await apiClient.getLatestVersion()

            // Get current version (nil if pre-versioning)
            let currentVersion = LabelUpdatePreferences.shared.currentLabelVersion

            if let current = currentVersion {
                log.info("Current label DB: v\(current), Latest: v\(latestMetadata.version)")
            } else {
                log.info("Current label DB: unversioned, Latest: v\(latestMetadata.version)")
            }

            // Check if update available
            // If currentVersion is nil (pre-versioning), always update
            if let current = currentVersion, latestMetadata.version <= current {
                log.info("✅ Label database is up to date")
                return nil
            }

            // Check app version compatibility
            let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
            guard latestMetadata.isCompatibleWithApp(version: appVersion) else {
                log.warning("Label DB v\(latestMetadata.version) requires app version \(latestMetadata.minAppVersion)")
                throw LabelUpdateError.incompatibleVersion(
                    required: latestMetadata.minAppVersion,
                    current: appVersion
                )
            }

            // Build update info
            let updateInfo = LabelUpdateInfo(
                currentVersion: currentVersion,
                availableVersion: latestMetadata.version,
                releaseDate: latestMetadata.releaseDate,
                changelog: latestMetadata.changelog,
                fileSize: latestMetadata.fileSize,
                checksum: latestMetadata.checksum
            )

            // Post notification
            NotificationCenter.default.post(
                name: .labelUpdateAvailable,
                object: updateInfo
            )

            return updateInfo

        } catch {
            log.error("Failed to check for label updates: \(error.localizedDescription)")
            logger.error("Label update check failed", context: [
                "operation": "label-update-check",
                "error_type": String(describing: type(of: error))
            ], error: error)
            throw error
        }
    }

    /// Download and install label database update
    /// - Parameters:
    ///   - updateInfo: Update information
    ///   - force: Force download even if network policy restricts it
    /// - Returns: Update result
    func downloadAndInstallUpdate(
        updateInfo: LabelUpdateInfo,
        force: Bool = false
    ) async throws -> LabelUpdateResult {

        guard !isDownloading else {
            log.warning("Download already in progress")
            throw LabelUpdateError.downloadFailed(
                underlying: NSError(domain: "LabelUpdate", code: -1,
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
                let policy = CatalogUpdatePreferences.shared.downloadPolicy
                let canDownload = policy == .wifiAndCellular ||
                                (policy == .wifiOnly && networkMonitor.isOnWiFi)

                guard canDownload else {
                    log.warning("Download blocked by network policy")
                    throw LabelUpdateError.networkPolicyRestricted
                }
            }

            log.info("Starting label database download: v\(updateInfo.availableVersion)")

            // 2. Download database
            let labelData = try await apiClient.downloadDatabase(
                version: updateInfo.availableVersion
            ) { [weak self] progress in
                Task { @MainActor in
                    self?.downloadProgress = progress * 0.5  // First 50% is download
                }
            }

            downloadProgress = 0.5

            // 3. Verify checksum
            guard labelData.verifySHA256Checksum(updateInfo.checksum) else {
                log.error("Checksum mismatch")
                throw LabelUpdateError.checksumMismatch
            }

            log.info("✅ Checksum verified")
            downloadProgress = 0.6

            // 4. Save to temp storage
            let tempFile = try await storageService.saveTempDatabase(
                labelData,
                version: updateInfo.availableVersion
            )

            downloadProgress = 0.7

            // 5. Promote temp to current
            try await storageService.promoteTempToCurrent(tempFile: tempFile)

            downloadProgress = 0.8

            // 6. Hot-swap the database in the service
            let currentURL = await storageService.getCurrentDatabaseURL()
            try databaseService.replaceDatabaseWith(newDatabasePath: currentURL.path)

            downloadProgress = 0.9

            // 7. Update version tracking
            LabelUpdatePreferences.shared.currentLabelVersion = updateInfo.availableVersion
            LabelUpdatePreferences.shared.lastSuccessfulUpdate = Date()
            LabelUpdatePreferences.shared.labelSource = .downloaded
            LabelUpdatePreferences.shared.hasUpdateAvailable = false

            downloadProgress = 1.0

            // 8. Get stats from new database
            let stats = databaseService.getDatabaseStats()

            let result = LabelUpdateResult(
                version: updateInfo.availableVersion,
                layoutCount: stats.layouts,
                productCount: stats.products,
                brandCount: stats.brands,
                appliedAt: Date()
            )

            log.info("✅ Label database updated successfully to v\(updateInfo.availableVersion)")
            log.info("   Layouts: \(result.layoutCount), Products: \(result.productCount), Brands: \(result.brandCount)")

            // Log success
            logger.info("Label database download completed", context: [
                "operation": "label-download",
                "version": updateInfo.availableVersion,
                "layout_count": result.layoutCount,
                "product_count": result.productCount,
                "brand_count": result.brandCount
            ])

            // Post notification
            NotificationCenter.default.post(
                name: .labelUpdateCompleted,
                object: result
            )

            return result

        } catch {
            log.error("Failed to download/install label update: \(error.localizedDescription)")

            logger.error("Label database download failed", context: [
                "operation": "label-download",
                "version": updateInfo.availableVersion,
                "progress": downloadProgress,
                "error_type": String(describing: type(of: error))
            ], error: error)

            // Post failure notification
            NotificationCenter.default.post(
                name: .labelUpdateFailed,
                object: error
            )

            throw error
        }
    }

    /// Perform background update check (called by app lifecycle)
    func performBackgroundUpdateCheck() async {
        guard CatalogUpdatePreferences.shared.autoUpdateEnabled else {
            log.debug("Auto-update disabled, skipping label background check")
            return
        }

        guard LabelUpdatePreferences.shared.shouldCheckForUpdates() else {
            log.debug("Not yet time for label background update check")
            return
        }

        do {
            if let updateInfo = try await checkForUpdates() {
                log.info("Background check found label update: v\(updateInfo.availableVersion)")

                // If this is an initial versioned update (pre-versioning), auto-download
                // Otherwise, follow normal network policy
                let shouldAutoDownload: Bool
                if updateInfo.isInitialVersionedUpdate {
                    // Always download initial versioned update on any network
                    shouldAutoDownload = true
                    log.info("Initial versioned update - auto-downloading")
                } else {
                    // Follow network policy
                    let policy = CatalogUpdatePreferences.shared.downloadPolicy
                    shouldAutoDownload = policy == .wifiAndCellular ||
                                       (policy == .wifiOnly && networkMonitor.isOnWiFi)
                }

                if shouldAutoDownload {
                    log.info("Auto-downloading label update in background")
                    _ = try await downloadAndInstallUpdate(updateInfo: updateInfo, force: updateInfo.isInitialVersionedUpdate)
                }
            }
        } catch {
            // Silent failure for background checks
            log.debug("Background label update check failed: \(error.localizedDescription)")
        }
    }
}
