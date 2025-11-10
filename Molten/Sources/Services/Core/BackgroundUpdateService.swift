//
//  BackgroundUpdateService.swift
//  Molten
//
//  Created by Assistant on 11/9/25.
//  Background catalog update checking and downloading
//

import Foundation
import OSLog

private let log = Logger(subsystem: "com.molten", category: "BackgroundUpdateService")

/// Service for handling automatic catalog updates in the background
@MainActor
final class BackgroundUpdateService {
    private let updateService: CatalogUpdateServiceProtocol
    private let networkMonitor: NetworkMonitorProtocol

    init(
        updateService: CatalogUpdateServiceProtocol,
        networkMonitor: NetworkMonitorProtocol = NetworkMonitor()
    ) {
        self.updateService = updateService
        self.networkMonitor = networkMonitor
    }

    /// Check for updates if conditions are met, and optionally download
    func checkForUpdatesIfNeeded() async {
        let preferences = CatalogUpdatePreferences.shared

        // Check if auto-updates are enabled
        guard preferences.autoUpdateEnabled else {
            log.debug("🔕 Auto-updates disabled, skipping background check")
            return
        }

        // Check if enough time has passed since last check
        guard shouldCheckForUpdates() else {
            log.debug("⏰ Not enough time has passed since last update check")
            return
        }

        // Check network connectivity
        guard networkMonitor.checkConnection() else {
            log.debug("📡 No network connection, skipping update check")
            return
        }

        log.info("🔍 Starting background update check")

        // Update timestamp before check (so we don't retry immediately on error)
        preferences.lastUpdateCheck = Date()

        do {
            // Check for available updates
            guard let updateInfo = try await updateService.checkForUpdates() else {
                log.info("✅ No catalog updates available")
                return
            }

            log.info("📦 Update available: v\(updateInfo.availableVersion)")

            // Check if we should auto-download
            guard shouldAutoDownload() else {
                log.info("⏸️ Auto-download conditions not met (network policy)")
                return
            }

            // Download and install the update
            log.info("⬇️ Auto-downloading catalog update")
            let result = try await updateService.downloadAndInstallUpdate(
                updateInfo: updateInfo,
                force: false  // Respect network policy
            )

            log.info("✅ Background update completed: v\(result.version), +\(result.itemsCreated) items created, ~\(result.itemsUpdated) items updated")

        } catch {
            log.error("❌ Background update failed: \(error.localizedDescription)")
            // Don't throw - background updates should fail gracefully
        }
    }

    // MARK: - Private Helpers

    /// Check if enough time has passed to check for updates
    private func shouldCheckForUpdates() -> Bool {
        let preferences = CatalogUpdatePreferences.shared

        guard let lastCheck = preferences.lastUpdateCheck else {
            // Never checked before
            return true
        }

        let interval: TimeInterval
        switch preferences.updateFrequency {
        case .daily:
            interval = 24 * 3600  // 24 hours
        case .weekly:
            interval = 7 * 24 * 3600  // 7 days
        case .monthly:
            interval = 30 * 24 * 3600  // 30 days
        case .manual:
            // Manual mode shouldn't trigger background checks
            return false
        }

        let timeSinceLastCheck = Date().timeIntervalSince(lastCheck)
        return timeSinceLastCheck >= interval
    }

    /// Check if we should auto-download based on network policy
    private func shouldAutoDownload() -> Bool {
        let preferences = CatalogUpdatePreferences.shared

        switch preferences.downloadPolicy {
        case .manual:
            // Manual policy means user must initiate download
            return false

        case .wifiOnly:
            // Only download on WiFi (non-expensive connection)
            return !networkMonitor.checkIsExpensive()

        case .wifiAndCellular:
            // Download on any connection
            return true
        }
    }
}
