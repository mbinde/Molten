//
//  CatalogUpdateViewModelTests.swift
//  MoltenTests
//
//  Created by Assistant on 11/9/25.
//  Tests for catalog update view model
//

import Foundation
import Testing
import Combine

@testable import Molten

@Suite("CatalogUpdateViewModel Tests", .serialized)
@MainActor
struct CatalogUpdateViewModelTests {

    // MARK: - Test Helpers

    func createMockUpdateService() -> MockCatalogUpdateService {
        return MockCatalogUpdateService()
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

    // MARK: - Initialization Tests

    @Test("ViewModel initializes with default state")
    func testInitialization() {
        let mockService = createMockUpdateService()
        let viewModel = CatalogUpdateViewModel(updateService: mockService)

        #expect(!viewModel.isChecking)
        #expect(!viewModel.isDownloading)
        #expect(viewModel.downloadProgress == 0.0)
        #expect(viewModel.availableUpdate == nil)
        #expect(viewModel.lastError == nil)
        #expect(!viewModel.showError)
    }

    // MARK: - Computed Properties Tests

    @Test("Current version returns preferences value")
    func testCurrentVersion() {
        let mockService = createMockUpdateService()
        let viewModel = CatalogUpdateViewModel(updateService: mockService)

        CatalogUpdatePreferences.shared.currentCatalogVersion = 5

        #expect(viewModel.currentVersion == 5)
    }

    @Test("Catalog source returns preferences value")
    func testCatalogSource() {
        let mockService = createMockUpdateService()
        let viewModel = CatalogUpdateViewModel(updateService: mockService)

        CatalogUpdatePreferences.shared.catalogSource = .downloaded

        #expect(viewModel.catalogSource == "Downloaded")
    }

    @Test("Auto update enabled reads and writes to preferences")
    func testAutoUpdateEnabled() {
        // Start with clean state
        CatalogUpdatePreferences.shared.resetToDefaults()

        let mockService = createMockUpdateService()
        let viewModel = CatalogUpdateViewModel(updateService: mockService)

        // Test write-through to preferences
        viewModel.autoUpdateEnabled = true
        #expect(CatalogUpdatePreferences.shared.autoUpdateEnabled == true)

        viewModel.autoUpdateEnabled = false
        #expect(CatalogUpdatePreferences.shared.autoUpdateEnabled == false)
    }

    @Test("Download policy reads and writes to preferences")
    func testDownloadPolicy() {
        // Start with clean state
        CatalogUpdatePreferences.shared.resetToDefaults()

        let mockService = createMockUpdateService()
        let viewModel = CatalogUpdateViewModel(updateService: mockService)

        viewModel.downloadPolicy = .wifiOnly
        #expect(CatalogUpdatePreferences.shared.downloadPolicy == .wifiOnly)

        viewModel.downloadPolicy = .wifiAndCellular
        #expect(CatalogUpdatePreferences.shared.downloadPolicy == .wifiAndCellular)
    }

    @Test("Update frequency reads and writes to preferences")
    func testUpdateFrequency() {
        // Start with clean state
        CatalogUpdatePreferences.shared.resetToDefaults()

        let mockService = createMockUpdateService()
        let viewModel = CatalogUpdateViewModel(updateService: mockService)

        viewModel.updateFrequency = .daily
        #expect(CatalogUpdatePreferences.shared.updateFrequency == .daily)

        viewModel.updateFrequency = .weekly
        #expect(CatalogUpdatePreferences.shared.updateFrequency == .weekly)
    }

    @Test("Update available message shows correct text")
    func testUpdateAvailableMessage() {
        let mockService = createMockUpdateService()
        let viewModel = CatalogUpdateViewModel(updateService: mockService)

        // No update available
        #expect(viewModel.updateAvailableMessage == nil)

        // Update available
        viewModel.availableUpdate = createTestUpdateInfo(version: 3)
        #expect(viewModel.updateAvailableMessage?.contains("3") == true)
    }

    // MARK: - Check For Updates Tests

    @Test("Check for updates sets isChecking flag")
    func testCheckForUpdatesSetsFlag() async {
        let mockService = createMockUpdateService()
        mockService.shouldDelayResponse = true
        let viewModel = CatalogUpdateViewModel(updateService: mockService)

        // Start check in background
        let checkTask = Task {
            await viewModel.checkForUpdates()
        }

        // Give it a moment to start
        try? await Task.sleep(for: .milliseconds(50))

        // Should be checking
        #expect(viewModel.isChecking)

        // Wait for completion
        await checkTask.value

        // Should no longer be checking
        #expect(!viewModel.isChecking)
    }

    @Test("Check for updates stores available update")
    func testCheckForUpdatesStoresUpdate() async {
        let mockService = createMockUpdateService()
        let updateInfo = createTestUpdateInfo()
        mockService.mockUpdateInfo = updateInfo

        let viewModel = CatalogUpdateViewModel(updateService: mockService)

        await viewModel.checkForUpdates()

        #expect(viewModel.availableUpdate != nil)
        #expect(viewModel.availableUpdate?.availableVersion == updateInfo.availableVersion)
    }

    @Test("Check for updates clears update when none available")
    func testCheckForUpdatesClearsWhenNoneAvailable() async {
        let mockService = createMockUpdateService()
        mockService.mockUpdateInfo = nil  // No update available

        let viewModel = CatalogUpdateViewModel(updateService: mockService)
        viewModel.availableUpdate = createTestUpdateInfo()  // Set initial update

        await viewModel.checkForUpdates()

        #expect(viewModel.availableUpdate == nil)
    }

    @Test("Check for updates handles errors")
    func testCheckForUpdatesHandlesErrors() async {
        let mockService = createMockUpdateService()
        mockService.shouldThrowError = .serverError(statusCode: 500)

        let viewModel = CatalogUpdateViewModel(updateService: mockService)

        await viewModel.checkForUpdates()

        #expect(viewModel.lastError != nil)
        #expect(viewModel.showError)
    }

    @Test("Check for updates clears previous errors")
    func testCheckForUpdatesClearsPreviousErrors() async {
        let mockService = createMockUpdateService()
        let viewModel = CatalogUpdateViewModel(updateService: mockService)

        // Set previous error
        viewModel.lastError = CatalogUpdateError.networkPolicyRestricted
        viewModel.showError = true

        // Successful check should clear error
        await viewModel.checkForUpdates()

        // Error should be cleared even if no update found
        #expect(viewModel.lastError == nil)
        #expect(!viewModel.showError)
    }

    @Test("Check for updates prevents concurrent checks")
    func testCheckForUpdatesPreventsConcurrentChecks() async {
        let mockService = createMockUpdateService()
        mockService.shouldDelayResponse = true

        let viewModel = CatalogUpdateViewModel(updateService: mockService)

        // Start first check
        let task1 = Task {
            await viewModel.checkForUpdates()
        }

        // Try to start second check immediately
        try? await Task.sleep(for: .milliseconds(50))
        let task2 = Task {
            await viewModel.checkForUpdates()
        }

        await task1.value
        await task2.value

        // Service should only be called once
        #expect(mockService.checkForUpdatesCallCount == 1)
    }

    // MARK: - Download Update Tests

    @Test("Download update requires available update")
    func testDownloadUpdateRequiresAvailableUpdate() async {
        let mockService = createMockUpdateService()
        let viewModel = CatalogUpdateViewModel(updateService: mockService)

        // No available update
        viewModel.availableUpdate = nil

        await viewModel.downloadUpdate()

        // Should not call service
        #expect(mockService.downloadCallCount == 0)
    }

    @Test("Download update sets isDownloading flag")
    func testDownloadUpdateSetsFlag() async {
        let mockService = createMockUpdateService()
        mockService.shouldDelayResponse = true

        let viewModel = CatalogUpdateViewModel(updateService: mockService)
        viewModel.availableUpdate = createTestUpdateInfo()

        // Start download in background
        let downloadTask = Task {
            await viewModel.downloadUpdate()
        }

        // Give it a moment to start
        try? await Task.sleep(for: .milliseconds(50))

        // Should be downloading
        #expect(viewModel.isDownloading)

        // Wait for completion
        await downloadTask.value

        // Should no longer be downloading
        #expect(!viewModel.isDownloading)
    }

    @Test("Download update clears available update on success")
    func testDownloadUpdateClearsUpdateOnSuccess() async {
        let mockService = createMockUpdateService()
        mockService.mockUpdateResult = CatalogUpdateResult(
            version: 2,
            itemsCreated: 10,
            itemsUpdated: 5,
            itemsRemoved: 0,
            appliedAt: Date()
        )

        let viewModel = CatalogUpdateViewModel(updateService: mockService)
        viewModel.availableUpdate = createTestUpdateInfo()

        await viewModel.downloadUpdate()

        // Update should be cleared after successful download
        #expect(viewModel.availableUpdate == nil)
    }

    @Test("Download update handles errors")
    func testDownloadUpdateHandlesErrors() async {
        let mockService = createMockUpdateService()
        mockService.shouldThrowError = .checksumMismatch

        let viewModel = CatalogUpdateViewModel(updateService: mockService)
        viewModel.availableUpdate = createTestUpdateInfo()

        await viewModel.downloadUpdate()

        #expect(viewModel.lastError != nil)
        #expect(viewModel.showError)
        #expect(!viewModel.isDownloading)
    }

    @Test("Download update prevents concurrent downloads")
    func testDownloadUpdatePreventsConcurrentDownloads() async {
        let mockService = createMockUpdateService()
        mockService.shouldDelayResponse = true

        let viewModel = CatalogUpdateViewModel(updateService: mockService)
        viewModel.availableUpdate = createTestUpdateInfo()

        // Start first download
        let task1 = Task {
            await viewModel.downloadUpdate()
        }

        // Try to start second download immediately
        try? await Task.sleep(for: .milliseconds(50))
        let task2 = Task {
            await viewModel.downloadUpdate()
        }

        await task1.value
        await task2.value

        // Service should only be called once
        #expect(mockService.downloadCallCount == 1)
    }

    // MARK: - Force Download Tests

    @Test("Force download bypasses network policy")
    func testForceDownloadBypassesPolicy() async {
        let mockService = createMockUpdateService()
        mockService.mockUpdateResult = CatalogUpdateResult(
            version: 2,
            itemsCreated: 10,
            itemsUpdated: 5,
            itemsRemoved: 0,
            appliedAt: Date()
        )

        let viewModel = CatalogUpdateViewModel(updateService: mockService)
        viewModel.availableUpdate = createTestUpdateInfo()

        await viewModel.forceDownloadUpdate()

        // Should have been called with force = true
        #expect(mockService.downloadCallCount == 1)
        #expect(mockService.lastForceFlag == true)
    }

    @Test("Force download clears update on success")
    func testForceDownloadClearsUpdateOnSuccess() async {
        let mockService = createMockUpdateService()
        mockService.mockUpdateResult = CatalogUpdateResult(
            version: 2,
            itemsCreated: 10,
            itemsUpdated: 5,
            itemsRemoved: 0,
            appliedAt: Date()
        )

        let viewModel = CatalogUpdateViewModel(updateService: mockService)
        viewModel.availableUpdate = createTestUpdateInfo()

        await viewModel.forceDownloadUpdate()

        #expect(viewModel.availableUpdate == nil)
    }

    // MARK: - Error Handling Tests

    @Test("Dismiss error clears error state")
    func testDismissError() {
        let mockService = createMockUpdateService()
        let viewModel = CatalogUpdateViewModel(updateService: mockService)

        // Set error state
        viewModel.lastError = CatalogUpdateError.networkPolicyRestricted
        viewModel.showError = true

        // Dismiss error
        viewModel.dismissError()

        #expect(viewModel.lastError == nil)
        #expect(!viewModel.showError)
    }

    // MARK: - Reset Preferences Tests

    @Test("Reset preferences calls preferences reset")
    func testResetPreferences() {
        let mockService = createMockUpdateService()
        let viewModel = CatalogUpdateViewModel(updateService: mockService)

        // First reset to ensure we start from a clean state
        CatalogUpdatePreferences.shared.resetToDefaults()

        // Verify initial state is defaults
        #expect(CatalogUpdatePreferences.shared.autoUpdateEnabled == false)
        #expect(CatalogUpdatePreferences.shared.downloadPolicy == .wifiOnly)

        // Modify preferences to different values
        CatalogUpdatePreferences.shared.autoUpdateEnabled = true  // Change to true
        CatalogUpdatePreferences.shared.downloadPolicy = .manual

        // Verify modifications
        #expect(CatalogUpdatePreferences.shared.autoUpdateEnabled == true)
        #expect(CatalogUpdatePreferences.shared.downloadPolicy == .manual)

        // Reset
        viewModel.resetPreferences()

        // Should be back to defaults
        #expect(CatalogUpdatePreferences.shared.autoUpdateEnabled == false)
        #expect(CatalogUpdatePreferences.shared.downloadPolicy == .wifiOnly)
    }
}
