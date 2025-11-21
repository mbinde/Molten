//
//  CatalogUpdateViewModel.swift
//  Molten
//
//  Created by Assistant on 11/9/25.
//  ViewModel for catalog update UI
//

import Foundation
import SwiftUI
import OSLog

/// ViewModel for catalog update settings and management
@MainActor
@Observable
class CatalogUpdateViewModel {

    // MARK: - Properties

    private let updateService: any CatalogUpdateServiceProtocol
    private let preferences = CatalogUpdatePreferences.shared
    private let networkMonitor = NetworkMonitor.shared
    private let log = Logger(subsystem: "Molten", category: "CatalogUpdateVM")

    // MARK: - Published State

    var isChecking: Bool = false
    var isDownloading: Bool = false
    var downloadProgress: Double = 0.0
    var availableUpdate: CatalogUpdateInfo?
    var lastError: Error?
    var showError: Bool = false

    // MARK: - Computed Properties

    var currentVersion: Int {
        preferences.currentCatalogVersion
    }

    var catalogSource: String {
        preferences.catalogSource.rawValue
    }

    var lastUpdateCheck: Date? {
        preferences.lastUpdateCheck
    }

    var lastSuccessfulUpdate: Date? {
        preferences.lastSuccessfulUpdate
    }

    var autoUpdateEnabled: Bool {
        get { preferences.autoUpdateEnabled }
        set { preferences.autoUpdateEnabled = newValue }
    }

    var downloadPolicy: CatalogUpdatePreferences.DownloadPolicy {
        get { preferences.downloadPolicy }
        set { preferences.downloadPolicy = newValue }
    }

    var updateFrequency: CatalogUpdatePreferences.UpdateFrequency {
        get { preferences.updateFrequency }
        set { preferences.updateFrequency = newValue }
    }

    var connectionDescription: String {
        networkMonitor.connectionDescription
    }

    var canDownloadNow: Bool {
        networkMonitor.canDownloadCatalog()
    }

    var updateAvailableMessage: String? {
        guard let update = availableUpdate else { return nil }
        return "Version \(update.availableVersion) available"
    }

    var hasUpdateAvailable: Bool {
        availableUpdate != nil
    }

    // MARK: - Initialization

    init(updateService: any CatalogUpdateServiceProtocol) {
        self.updateService = updateService
    }

    // MARK: - Public API

    /// Check for available updates
    func checkForUpdates() async {
        guard !isChecking else { return }

        isChecking = true
        lastError = nil
        showError = false

        defer { isChecking = false }

        do {
            log.info("Checking for catalog updates...")
            availableUpdate = try await updateService.checkForUpdates()

            if availableUpdate != nil {
                log.info("Update available")
            } else {
                log.info("No update available")
            }
        } catch {
            log.error("Failed to check for updates: \(error.localizedDescription)")
            lastError = error
            showError = true
        }
    }

    /// Download and install available update
    func downloadUpdate() async {
        guard let updateInfo = availableUpdate else {
            log.warning("No update available to download")
            return
        }

        guard !isDownloading else {
            log.warning("Download already in progress")
            return
        }

        isDownloading = true
        downloadProgress = 0.0
        lastError = nil
        showError = false

        do {
            log.info("Starting download of catalog v\(updateInfo.availableVersion)")

            let result = try await updateService.downloadAndInstallUpdate(
                updateInfo: updateInfo,
                force: false
            )

            log.info("✅ Update completed successfully")
            log.info("   Created: \(result.itemsCreated), Updated: \(result.itemsUpdated)")

            // Clear available update (we're now up to date)
            availableUpdate = nil
            CatalogUpdatePreferences.shared.hasUpdateAvailable = false

        } catch {
            log.error("Failed to download update: \(error.localizedDescription)")
            lastError = error
            showError = true
        }

        isDownloading = false
        downloadProgress = 0.0
    }

    /// Force download even if network policy restricts it
    func forceDownloadUpdate() async {
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

            log.info("✅ Forced update completed successfully")

            availableUpdate = nil
            CatalogUpdatePreferences.shared.hasUpdateAvailable = false

        } catch {
            log.error("Failed to force download update: \(error.localizedDescription)")
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

    /// Reset all preferences to defaults
    func resetPreferences() {
        preferences.resetToDefaults()
    }
}
