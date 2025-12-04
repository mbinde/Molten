//
//  LabelUpdateViewModel.swift
//  Molten
//
//  ViewModel for label database update UI
//

import Foundation
import SwiftUI
import OSLog

/// ViewModel for label database update settings and management
@MainActor
@Observable
class LabelUpdateViewModel {

    // MARK: - Properties

    private var updateService: LabelUpdateService?
    private let preferences = LabelUpdatePreferences.shared
    private let catalogPreferences = CatalogUpdatePreferences.shared  // Shared settings
    private let networkMonitor = NetworkMonitor.shared
    private let log = Logger(subsystem: "Molten", category: "LabelUpdateVM")

    // MARK: - Published State

    var isChecking: Bool = false
    var isDownloading: Bool = false
    var downloadProgress: Double = 0.0
    var availableUpdate: LabelUpdateInfo?
    var lastError: Error?
    var showError: Bool = false

    // MARK: - Computed Properties

    var currentVersion: Int? {
        preferences.currentLabelVersion
    }

    var currentVersionDisplay: String {
        if let version = currentVersion {
            return "v\(version)"
        } else {
            return "Bundled"
        }
    }

    var labelSource: String {
        preferences.labelSource.rawValue
    }

    var lastUpdateCheck: Date? {
        preferences.lastUpdateCheck
    }

    var lastSuccessfulUpdate: Date? {
        preferences.lastSuccessfulUpdate
    }

    /// Auto-update setting (shared with catalog)
    var autoUpdateEnabled: Bool {
        get { catalogPreferences.autoUpdateEnabled }
        set { catalogPreferences.autoUpdateEnabled = newValue }
    }

    /// Download policy (shared with catalog)
    var downloadPolicy: CatalogUpdatePreferences.DownloadPolicy {
        get { catalogPreferences.downloadPolicy }
        set { catalogPreferences.downloadPolicy = newValue }
    }

    /// Update frequency (shared with catalog)
    var updateFrequency: CatalogUpdatePreferences.UpdateFrequency {
        get { catalogPreferences.updateFrequency }
        set { catalogPreferences.updateFrequency = newValue }
    }

    var connectionDescription: String {
        networkMonitor.connectionDescription
    }

    var canDownloadNow: Bool {
        networkMonitor.canDownloadCatalog()
    }

    var updateAvailableMessage: String? {
        guard let update = availableUpdate else { return nil }
        return "v\(update.availableVersion) available"
    }

    var hasUpdateAvailable: Bool {
        availableUpdate != nil || preferences.hasUpdateAvailable
    }

    var isServiceAvailable: Bool {
        updateService != nil
    }

    // MARK: - Initialization

    init(updateService: LabelUpdateService?) {
        self.updateService = updateService
    }

    /// Configure the update service after initialization
    /// Call this when AppDependencies becomes available
    func configure(with service: LabelUpdateService?) {
        self.updateService = service
    }

    // MARK: - Public API

    /// Check for available updates
    func checkForUpdates() async {
        guard let updateService = updateService else {
            log.warning("Label update service not available")
            return
        }

        guard !isChecking else { return }

        isChecking = true
        lastError = nil
        showError = false

        defer { isChecking = false }

        do {
            log.info("Checking for label database updates...")
            availableUpdate = try await updateService.checkForUpdates()

            if availableUpdate != nil {
                log.info("Label update available")
                preferences.hasUpdateAvailable = true
            } else {
                log.info("No label update available")
                preferences.hasUpdateAvailable = false
            }
        } catch {
            log.error("Failed to check for label updates: \(error.localizedDescription)")
            lastError = error
            showError = true
        }
    }

    /// Download and install available update
    func downloadUpdate() async {
        guard let updateService = updateService else {
            log.warning("Label update service not available")
            return
        }

        guard let updateInfo = availableUpdate else {
            log.warning("No label update available to download")
            return
        }

        guard !isDownloading else {
            log.warning("Label download already in progress")
            return
        }

        isDownloading = true
        downloadProgress = 0.0
        lastError = nil
        showError = false

        do {
            log.info("Starting download of label database v\(updateInfo.availableVersion)")

            let result = try await updateService.downloadAndInstallUpdate(
                updateInfo: updateInfo,
                force: false
            )

            log.info("✅ Label update completed successfully")
            log.info("   Layouts: \(result.layoutCount), Products: \(result.productCount), Brands: \(result.brandCount)")

            // Clear available update (we're now up to date)
            availableUpdate = nil
            preferences.hasUpdateAvailable = false

        } catch {
            log.error("Failed to download label update: \(error.localizedDescription)")
            lastError = error
            showError = true
        }

        isDownloading = false
        downloadProgress = 0.0
    }

    /// Force download even if network policy restricts it
    func forceDownloadUpdate() async {
        guard let updateService = updateService else { return }
        guard let updateInfo = availableUpdate else { return }
        guard !isDownloading else { return }

        isDownloading = true
        downloadProgress = 0.0
        lastError = nil
        showError = false

        do {
            _ = try await updateService.downloadAndInstallUpdate(
                updateInfo: updateInfo,
                force: true
            )

            log.info("✅ Forced label update completed successfully")

            availableUpdate = nil
            preferences.hasUpdateAvailable = false

        } catch {
            log.error("Failed to force download label update: \(error.localizedDescription)")
            lastError = error
            showError = true
        }

        isDownloading = false
        downloadProgress = 0.0
    }

    /// Dismiss error alert
    func dismissError() {
        showError = false
        lastError = nil
    }
}
