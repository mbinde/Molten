//
//  BackgroundUpdateServiceTests.swift
//  MoltenTests
//
//  Created by Assistant on 11/9/25.
//  Tests for background update service
//

import Foundation
import Testing

@testable import Molten

@Suite("BackgroundUpdateService Tests", .serialized)
@MainActor
struct BackgroundUpdateServiceTests {

    // MARK: - Test Helpers

    func createMockUpdateService() -> MockCatalogUpdateService {
        return MockCatalogUpdateService()
    }

    func createMockNetworkMonitor() -> MockNetworkMonitor {
        let monitor = MockNetworkMonitor()
        monitor.isConnected = true
        monitor.isOnWiFi = true
        return monitor
    }

    func createTestUpdateInfo(version: Int = 2) -> CatalogUpdateInfo {
        return CatalogUpdateInfo(
            currentVersion: 1,
            availableVersion: version,
            itemsAdded: 15,
            releaseDate: Date(),
            changelog: "Test changelog",
            fileSize: 3_145_728,
            checksum: "sha256:test"
        )
    }

    // MARK: - Auto-Update Enabled Tests

    @Test("Background update does nothing when auto-update is disabled")
    func testBackgroundUpdateDisabled() async {
        // Reset preferences to ensure clean state
        CatalogUpdatePreferences.shared.resetToDefaults()
        CatalogUpdatePreferences.shared.autoUpdateEnabled = false

        let mockService = createMockUpdateService()
        let mockNetworkMonitor = createMockNetworkMonitor()
        let backgroundService = BackgroundUpdateService(
            updateService: mockService,
            networkMonitor: mockNetworkMonitor
        )

        await backgroundService.checkForUpdatesIfNeeded()

        // Should not have called update service
        #expect(mockService.checkForUpdatesCallCount == 0)
    }

    @Test("Background update checks when auto-update is enabled")
    func testBackgroundUpdateEnabled() async {
        CatalogUpdatePreferences.shared.resetToDefaults()
        CatalogUpdatePreferences.shared.autoUpdateEnabled = true
        CatalogUpdatePreferences.shared.lastUpdateCheck = nil  // Force check

        let mockService = createMockUpdateService()
        let mockNetworkMonitor = createMockNetworkMonitor()
        let backgroundService = BackgroundUpdateService(
            updateService: mockService,
            networkMonitor: mockNetworkMonitor
        )

        await backgroundService.checkForUpdatesIfNeeded()

        // Should have called update service
        #expect(mockService.checkForUpdatesCallCount == 1)
    }

    // MARK: - Update Frequency Tests

    @Test("Background update respects daily frequency")
    func testBackgroundUpdateDailyFrequency() async {
        CatalogUpdatePreferences.shared.resetToDefaults()
        CatalogUpdatePreferences.shared.autoUpdateEnabled = true
        CatalogUpdatePreferences.shared.updateFrequency = .daily

        // Set last check to 1 hour ago (should NOT check again)
        let oneHourAgo = Date().addingTimeInterval(-3600)
        CatalogUpdatePreferences.shared.lastUpdateCheck = oneHourAgo

        let mockService = createMockUpdateService()
        let mockNetworkMonitor = createMockNetworkMonitor()
        let backgroundService = BackgroundUpdateService(
            updateService: mockService,
            networkMonitor: mockNetworkMonitor
        )

        await backgroundService.checkForUpdatesIfNeeded()

        // Should not have checked (too soon)
        #expect(mockService.checkForUpdatesCallCount == 0)
    }

    @Test("Background update checks when daily interval has passed")
    func testBackgroundUpdateDailyIntervalPassed() async {
        CatalogUpdatePreferences.shared.resetToDefaults()
        CatalogUpdatePreferences.shared.autoUpdateEnabled = true
        CatalogUpdatePreferences.shared.updateFrequency = .daily

        // Set last check to 25 hours ago (should check again)
        let twentyFiveHoursAgo = Date().addingTimeInterval(-25 * 3600)
        CatalogUpdatePreferences.shared.lastUpdateCheck = twentyFiveHoursAgo

        let mockService = createMockUpdateService()
        let mockNetworkMonitor = createMockNetworkMonitor()
        let backgroundService = BackgroundUpdateService(
            updateService: mockService,
            networkMonitor: mockNetworkMonitor
        )

        await backgroundService.checkForUpdatesIfNeeded()

        // Should have checked (enough time passed)
        #expect(mockService.checkForUpdatesCallCount == 1)
    }

    @Test("Background update respects weekly frequency")
    func testBackgroundUpdateWeeklyFrequency() async {
        CatalogUpdatePreferences.shared.resetToDefaults()
        CatalogUpdatePreferences.shared.autoUpdateEnabled = true
        CatalogUpdatePreferences.shared.updateFrequency = .weekly

        // Set last check to 3 days ago (should NOT check again)
        let threeDaysAgo = Date().addingTimeInterval(-3 * 24 * 3600)
        CatalogUpdatePreferences.shared.lastUpdateCheck = threeDaysAgo

        let mockService = createMockUpdateService()
        let mockNetworkMonitor = createMockNetworkMonitor()
        let backgroundService = BackgroundUpdateService(
            updateService: mockService,
            networkMonitor: mockNetworkMonitor
        )

        await backgroundService.checkForUpdatesIfNeeded()

        // Should not have checked (too soon)
        #expect(mockService.checkForUpdatesCallCount == 0)
    }

    @Test("Background update checks when weekly interval has passed")
    func testBackgroundUpdateWeeklyIntervalPassed() async {
        CatalogUpdatePreferences.shared.resetToDefaults()
        CatalogUpdatePreferences.shared.autoUpdateEnabled = true
        CatalogUpdatePreferences.shared.updateFrequency = .weekly

        // Set last check to 8 days ago (should check again)
        let eightDaysAgo = Date().addingTimeInterval(-8 * 24 * 3600)
        CatalogUpdatePreferences.shared.lastUpdateCheck = eightDaysAgo

        let mockService = createMockUpdateService()
        let mockNetworkMonitor = createMockNetworkMonitor()
        let backgroundService = BackgroundUpdateService(
            updateService: mockService,
            networkMonitor: mockNetworkMonitor
        )

        await backgroundService.checkForUpdatesIfNeeded()

        // Should have checked (enough time passed)
        #expect(mockService.checkForUpdatesCallCount == 1)
    }

    @Test("Background update respects monthly frequency")
    func testBackgroundUpdateMonthlyFrequency() async {
        CatalogUpdatePreferences.shared.resetToDefaults()
        CatalogUpdatePreferences.shared.autoUpdateEnabled = true
        CatalogUpdatePreferences.shared.updateFrequency = .monthly

        // Set last check to 15 days ago (should NOT check again)
        let fifteenDaysAgo = Date().addingTimeInterval(-15 * 24 * 3600)
        CatalogUpdatePreferences.shared.lastUpdateCheck = fifteenDaysAgo

        let mockService = createMockUpdateService()
        let mockNetworkMonitor = createMockNetworkMonitor()
        let backgroundService = BackgroundUpdateService(
            updateService: mockService,
            networkMonitor: mockNetworkMonitor
        )

        await backgroundService.checkForUpdatesIfNeeded()

        // Should not have checked (too soon)
        #expect(mockService.checkForUpdatesCallCount == 0)
    }

    @Test("Background update checks when monthly interval has passed")
    func testBackgroundUpdateMonthlyIntervalPassed() async {
        CatalogUpdatePreferences.shared.resetToDefaults()
        CatalogUpdatePreferences.shared.autoUpdateEnabled = true
        CatalogUpdatePreferences.shared.updateFrequency = .monthly

        // Set last check to 31 days ago (should check again)
        let thirtyOneDaysAgo = Date().addingTimeInterval(-31 * 24 * 3600)
        CatalogUpdatePreferences.shared.lastUpdateCheck = thirtyOneDaysAgo

        let mockService = createMockUpdateService()
        let mockNetworkMonitor = createMockNetworkMonitor()
        let backgroundService = BackgroundUpdateService(
            updateService: mockService,
            networkMonitor: mockNetworkMonitor
        )

        await backgroundService.checkForUpdatesIfNeeded()

        // Should have checked (enough time passed)
        #expect(mockService.checkForUpdatesCallCount == 1)
    }

    // MARK: - Update Check Result Tests

    @Test("Background update updates lastUpdateCheck timestamp")
    func testBackgroundUpdateUpdatesTimestamp() async {
        CatalogUpdatePreferences.shared.resetToDefaults()
        CatalogUpdatePreferences.shared.autoUpdateEnabled = true
        CatalogUpdatePreferences.shared.lastUpdateCheck = nil

        let mockService = createMockUpdateService()
        let mockNetworkMonitor = createMockNetworkMonitor()
        let backgroundService = BackgroundUpdateService(
            updateService: mockService,
            networkMonitor: mockNetworkMonitor
        )

        let beforeCheck = Date()
        await backgroundService.checkForUpdatesIfNeeded()
        let afterCheck = Date()

        // Should have updated timestamp
        let lastCheck = CatalogUpdatePreferences.shared.lastUpdateCheck
        #expect(lastCheck != nil)
        #expect(lastCheck! >= beforeCheck)
        #expect(lastCheck! <= afterCheck)
    }

    @Test("Background update does nothing when no update available")
    func testBackgroundUpdateNoUpdateAvailable() async {
        CatalogUpdatePreferences.shared.resetToDefaults()
        CatalogUpdatePreferences.shared.autoUpdateEnabled = true
        CatalogUpdatePreferences.shared.lastUpdateCheck = nil

        let mockService = createMockUpdateService()
        mockService.mockUpdateInfo = nil  // No update available

        let mockNetworkMonitor = createMockNetworkMonitor()
        let backgroundService = BackgroundUpdateService(
            updateService: mockService,
            networkMonitor: mockNetworkMonitor
        )

        await backgroundService.checkForUpdatesIfNeeded()

        // Should have checked but not downloaded
        #expect(mockService.checkForUpdatesCallCount == 1)
        #expect(mockService.downloadCallCount == 0)
    }

    @Test("Background update auto-downloads when update available and wifi-only policy met")
    func testBackgroundUpdateAutoDownloadsOnWifi() async {
        CatalogUpdatePreferences.shared.resetToDefaults()
        CatalogUpdatePreferences.shared.autoUpdateEnabled = true
        CatalogUpdatePreferences.shared.downloadPolicy = .wifiOnly
        CatalogUpdatePreferences.shared.lastUpdateCheck = nil

        let mockService = createMockUpdateService()
        mockService.mockUpdateInfo = createTestUpdateInfo()
        mockService.mockUpdateResult = CatalogUpdateResult(
            version: 2,
            itemsCreated: 10,
            itemsUpdated: 5,
            itemsRemoved: 0,
            appliedAt: Date()
        )

        // Mock network monitor to report WiFi
        let mockNetworkMonitor = MockNetworkMonitor()
        mockNetworkMonitor.isConnected = true
        mockNetworkMonitor.isOnWiFi = true

        let backgroundService = BackgroundUpdateService(
            updateService: mockService,
            networkMonitor: mockNetworkMonitor
        )

        await backgroundService.checkForUpdatesIfNeeded()

        // Should have checked and downloaded
        #expect(mockService.checkForUpdatesCallCount == 1)
        #expect(mockService.downloadCallCount == 1)
    }

    @Test("Background update skips download when on cellular and wifi-only policy")
    func testBackgroundUpdateSkipsDownloadOnCellular() async {
        CatalogUpdatePreferences.shared.resetToDefaults()
        CatalogUpdatePreferences.shared.autoUpdateEnabled = true
        CatalogUpdatePreferences.shared.downloadPolicy = .wifiOnly
        CatalogUpdatePreferences.shared.lastUpdateCheck = nil

        let mockService = createMockUpdateService()
        mockService.mockUpdateInfo = createTestUpdateInfo()

        // Mock network monitor to report cellular
        let mockNetworkMonitor = MockNetworkMonitor()
        mockNetworkMonitor.isConnected = true
        mockNetworkMonitor.isOnWiFi = false  // Cellular

        let backgroundService = BackgroundUpdateService(
            updateService: mockService,
            networkMonitor: mockNetworkMonitor
        )

        await backgroundService.checkForUpdatesIfNeeded()

        // Should have checked but NOT downloaded
        #expect(mockService.checkForUpdatesCallCount == 1)
        #expect(mockService.downloadCallCount == 0)
    }

    @Test("Background update downloads on cellular when policy allows")
    func testBackgroundUpdateDownloadsOnCellularWhenAllowed() async {
        CatalogUpdatePreferences.shared.resetToDefaults()
        CatalogUpdatePreferences.shared.autoUpdateEnabled = true
        CatalogUpdatePreferences.shared.downloadPolicy = .wifiAndCellular
        CatalogUpdatePreferences.shared.lastUpdateCheck = nil

        let mockService = createMockUpdateService()
        mockService.mockUpdateInfo = createTestUpdateInfo()
        mockService.mockUpdateResult = CatalogUpdateResult(
            version: 2,
            itemsCreated: 10,
            itemsUpdated: 5,
            itemsRemoved: 0,
            appliedAt: Date()
        )

        // Mock network monitor to report cellular
        let mockNetworkMonitor = MockNetworkMonitor()
        mockNetworkMonitor.isConnected = true
        mockNetworkMonitor.isOnWiFi = false  // Cellular

        let backgroundService = BackgroundUpdateService(
            updateService: mockService,
            networkMonitor: mockNetworkMonitor
        )

        await backgroundService.checkForUpdatesIfNeeded()

        // Should have checked and downloaded
        #expect(mockService.checkForUpdatesCallCount == 1)
        #expect(mockService.downloadCallCount == 1)
    }

    @Test("Background update skips check when no network")
    func testBackgroundUpdateSkipsCheckWhenNoNetwork() async {
        CatalogUpdatePreferences.shared.resetToDefaults()
        CatalogUpdatePreferences.shared.autoUpdateEnabled = true
        CatalogUpdatePreferences.shared.lastUpdateCheck = nil

        let mockService = createMockUpdateService()

        // Mock network monitor to report no connection
        let mockNetworkMonitor = MockNetworkMonitor()
        mockNetworkMonitor.isConnected = false

        let backgroundService = BackgroundUpdateService(
            updateService: mockService,
            networkMonitor: mockNetworkMonitor
        )

        await backgroundService.checkForUpdatesIfNeeded()

        // Should NOT have checked (no network)
        #expect(mockService.checkForUpdatesCallCount == 0)
    }

    // MARK: - Error Handling Tests

    @Test("Background update handles check errors gracefully")
    func testBackgroundUpdateHandlesCheckError() async {
        CatalogUpdatePreferences.shared.resetToDefaults()
        CatalogUpdatePreferences.shared.autoUpdateEnabled = true
        CatalogUpdatePreferences.shared.lastUpdateCheck = nil

        let mockService = createMockUpdateService()
        mockService.shouldThrowError = .serverError(statusCode: 500)

        let mockNetworkMonitor = createMockNetworkMonitor()
        let backgroundService = BackgroundUpdateService(
            updateService: mockService,
            networkMonitor: mockNetworkMonitor
        )

        // Should not crash
        await backgroundService.checkForUpdatesIfNeeded()

        // Should have attempted check
        #expect(mockService.checkForUpdatesCallCount == 1)
        // Should have updated timestamp despite error
        #expect(CatalogUpdatePreferences.shared.lastUpdateCheck != nil)
    }

    @Test("Background update handles download errors gracefully")
    func testBackgroundUpdateHandlesDownloadError() async {
        CatalogUpdatePreferences.shared.resetToDefaults()
        CatalogUpdatePreferences.shared.autoUpdateEnabled = true
        CatalogUpdatePreferences.shared.downloadPolicy = .wifiOnly
        CatalogUpdatePreferences.shared.lastUpdateCheck = nil

        let mockService = createMockUpdateService()
        mockService.mockUpdateInfo = createTestUpdateInfo()
        // Don't set mockUpdateResult - download will fail with missing result error
        // (can't use shouldThrowError as it affects checkForUpdates too)

        let mockNetworkMonitor = MockNetworkMonitor()
        mockNetworkMonitor.isConnected = true
        mockNetworkMonitor.isOnWiFi = true  // Must be on WiFi for wifiOnly policy
        mockNetworkMonitor.isExpensive = false

        let backgroundService = BackgroundUpdateService(
            updateService: mockService,
            networkMonitor: mockNetworkMonitor
        )

        // Should not crash
        await backgroundService.checkForUpdatesIfNeeded()

        // Should have attempted both check and download
        #expect(mockService.checkForUpdatesCallCount == 1)
        #expect(mockService.downloadCallCount == 1)
    }
}
