//
//  BackgroundUpdateService.swift
//  Molten
//
//  Created by Assistant on 11/9/25.
//  Background catalog update checking and downloading
//

import Foundation
import OSLog
import UserNotifications

private let log = Logger(subsystem: "com.molten", category: "BackgroundUpdateService")

/// Service for handling automatic catalog updates in the background
@MainActor
final class BackgroundUpdateService {
    private let updateService: any CatalogUpdateServiceProtocol
    private let networkMonitor: any NetworkMonitorProtocol

    init(
        updateService: any CatalogUpdateServiceProtocol,
        networkMonitor: any NetworkMonitorProtocol
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
            return
        }

        // Check network connectivity (with retry for network monitor initialization)
        // NWPathMonitor needs a moment to determine actual network status
        var isConnected = networkMonitor.isConnected
        if !isConnected {
            log.debug("📡 Network not ready, waiting 2 seconds for monitor to stabilize...")
            try? await Task.sleep(for: .seconds(2))
            isConnected = networkMonitor.isConnected
        }

        guard isConnected else {
            log.debug("📡 No network connection, skipping update check")
            return
        }

        // Update timestamp before check (so we don't retry immediately on error)
        preferences.lastUpdateCheck = Date()

        do {
            // Check for available updates
            guard let updateInfo = try await updateService.checkForUpdates() else {
                return
            }

            // Mark update as available for badge display
            preferences.hasUpdateAvailable = true

            // Check if we should auto-download
            guard shouldAutoDownload() else {
                return
            }

            // Download and install the update
            let result = try await updateService.downloadAndInstallUpdate(
                updateInfo: updateInfo,
                force: false  // Respect network policy
            )

            // Clear update available badge
            preferences.hasUpdateAvailable = false

            // Send success notification
            await sendNotification(
                title: "Catalog Updated",
                body: "Version \(result.version) installed successfully. \(result.itemsCreated) new items added."
            )

        } catch {
            log.error("❌ Background update failed: \(error.localizedDescription)")

            // Send error notification
            await sendNotification(
                title: "Catalog Update Failed",
                body: "Unable to update catalog. Please try again later."
            )

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

        // Use the interval from the updateFrequency preference
        let interval = preferences.updateFrequency.checkInterval
        let timeSinceLastCheck = Date().timeIntervalSince(lastCheck)
        return timeSinceLastCheck >= interval
    }

    /// Check if we should auto-download based on network policy
    private func shouldAutoDownload() -> Bool {
        // Use the existing canDownloadCatalog() method which already checks policy
        return networkMonitor.canDownloadCatalog()
    }

    /// Send a local notification
    private func sendNotification(title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil  // Deliver immediately
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            log.debug("📬 Notification sent: \(title)")
        } catch {
            log.error("Failed to send notification: \(error.localizedDescription)")
        }
    }
}
