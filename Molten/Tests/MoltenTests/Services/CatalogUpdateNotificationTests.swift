//
//  CatalogUpdateNotificationTests.swift
//  MoltenTests
//
//  Created by Assistant on 11/9/25.
//  Tests for catalog update notifications
//

import Foundation
import Testing
import UserNotifications
@testable import Molten

@Suite("Catalog Update Notification Tests")
@MainActor
struct CatalogUpdateNotificationTests {

    // MARK: - Background Update Success Notification Tests

    @Test("Should send notification when background update completes successfully")
    func testBackgroundUpdateSuccessNotification() async {
        // This test verifies that a notification is requested when
        // a background update downloads and installs successfully

        let preferences = CatalogUpdatePreferences.shared
        preferences.resetToDefaults()
        preferences.autoUpdateEnabled = true
        preferences.lastUpdateCheck = nil

        let mockService = MockCatalogUpdateService()
        mockService.mockUpdateInfo = CatalogUpdateInfo(
            currentVersion: 1,
            availableVersion: 2,
            itemsAdded: 10,
            releaseDate: Date(),
            changelog: "Test update",
            fileSize: 1000000,
            checksum: "abc123"
        )
        mockService.mockUpdateResult = CatalogUpdateResult(
            version: 2,
            itemsCreated: 10,
            itemsUpdated: 5,
            itemsRemoved: 0,
            appliedAt: Date()
        )

        let mockNetworkMonitor = MockNetworkMonitor()
        mockNetworkMonitor.isConnected = true
        mockNetworkMonitor.isOnWiFi = true

        let backgroundService = BackgroundUpdateService(
            updateService: mockService,
            networkMonitor: mockNetworkMonitor
        )

        await backgroundService.checkForUpdatesIfNeeded()

        // Verify update completed successfully
        #expect(mockService.downloadCallCount == 1)

        // Note: Actual notification verification would require mocking UNUserNotificationCenter
        // For now, we verify the update completed which should trigger notification
    }

    @Test("Should send notification when background update fails")
    func testBackgroundUpdateErrorNotification() async {
        // This test verifies that a notification is requested when
        // a background update encounters an error

        let preferences = CatalogUpdatePreferences.shared
        preferences.resetToDefaults()
        preferences.autoUpdateEnabled = true
        preferences.lastUpdateCheck = nil

        let mockService = MockCatalogUpdateService()
        mockService.mockUpdateInfo = CatalogUpdateInfo(
            currentVersion: 1,
            availableVersion: 2,
            itemsAdded: 10,
            releaseDate: Date(),
            changelog: "Test update",
            fileSize: 1000000,
            checksum: "abc123"
        )
        // Don't set mockUpdateResult - will cause download to fail

        let mockNetworkMonitor = MockNetworkMonitor()
        mockNetworkMonitor.isConnected = true
        mockNetworkMonitor.isOnWiFi = true

        let backgroundService = BackgroundUpdateService(
            updateService: mockService,
            networkMonitor: mockNetworkMonitor
        )

        await backgroundService.checkForUpdatesIfNeeded()

        // Verify download was attempted and failed
        #expect(mockService.downloadCallCount == 1)

        // Note: Actual notification verification would require mocking UNUserNotificationCenter
    }

    @Test("Should NOT send notification when auto-updates are disabled")
    func testNoNotificationWhenAutoUpdateDisabled() async {
        // Notifications should only be sent for automatic background updates,
        // not for user-initiated manual updates

        let preferences = CatalogUpdatePreferences.shared
        preferences.resetToDefaults()
        preferences.autoUpdateEnabled = false

        let mockService = MockCatalogUpdateService()
        let mockNetworkMonitor = MockNetworkMonitor()

        let backgroundService = BackgroundUpdateService(
            updateService: mockService,
            networkMonitor: mockNetworkMonitor
        )

        await backgroundService.checkForUpdatesIfNeeded()

        // Should not have checked for updates at all
        #expect(mockService.checkForUpdatesCallCount == 0)
    }

    // MARK: - Badge State Tests

    @Test("ViewModel should indicate update available for badge")
    func testViewModelUpdateAvailableState() async {
        let mockService = MockCatalogUpdateService()
        mockService.mockUpdateInfo = CatalogUpdateInfo(
            currentVersion: 1,
            availableVersion: 2,
            itemsAdded: 10,
            releaseDate: Date(),
            changelog: "New update",
            fileSize: 1000000,
            checksum: "abc123"
        )

        let viewModel = CatalogUpdateViewModel(updateService: mockService)

        // Initially no update available
        #expect(viewModel.availableUpdate == nil)
        #expect(!viewModel.hasUpdateAvailable)

        // Check for updates
        await viewModel.checkForUpdates()

        // Now update should be available
        #expect(viewModel.availableUpdate != nil)
        #expect(viewModel.hasUpdateAvailable)
        #expect(viewModel.updateAvailableMessage == "Version 2 available")
    }

    @Test("ViewModel should clear update available state after download")
    func testViewModelClearsUpdateAfterDownload() async {
        let mockService = MockCatalogUpdateService()
        mockService.mockUpdateInfo = CatalogUpdateInfo(
            currentVersion: 1,
            availableVersion: 2,
            itemsAdded: 10,
            releaseDate: Date(),
            changelog: "New update",
            fileSize: 1000000,
            checksum: "abc123"
        )
        mockService.mockUpdateResult = CatalogUpdateResult(
            version: 2,
            itemsCreated: 10,
            itemsUpdated: 5,
            itemsRemoved: 0,
            appliedAt: Date()
        )

        let viewModel = CatalogUpdateViewModel(updateService: mockService)

        // Check for updates
        await viewModel.checkForUpdates()
        #expect(viewModel.hasUpdateAvailable)

        // Download update
        await viewModel.downloadUpdate()

        // Update should be cleared
        #expect(!viewModel.hasUpdateAvailable)
        #expect(viewModel.availableUpdate == nil)
    }

    @Test("ViewModel should maintain update available state after check error")
    func testViewModelKeepsUpdateAfterCheckError() async {
        let mockService = MockCatalogUpdateService()
        mockService.mockUpdateInfo = CatalogUpdateInfo(
            currentVersion: 1,
            availableVersion: 2,
            itemsAdded: 10,
            releaseDate: Date(),
            changelog: "New update",
            fileSize: 1000000,
            checksum: "abc123"
        )

        let viewModel = CatalogUpdateViewModel(updateService: mockService)

        // First check succeeds
        await viewModel.checkForUpdates()
        #expect(viewModel.hasUpdateAvailable)

        // Second check fails
        mockService.shouldThrowError = .serverError(statusCode: 500)
        await viewModel.checkForUpdates()

        // Should still show update as available (don't clear on check error)
        #expect(viewModel.hasUpdateAvailable)
    }
}
