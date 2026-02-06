//
//  StockUpdateServiceTests.swift
//  MoltenTests
//
//  Tests for stock database update service
//

import Foundation
import Testing

@testable import Molten

// MARK: - Mock Stock API Client

@MainActor
class MockStockAPIClient: StockAPIClientProtocol {
    var mockVersionMetadata: StockVersionMetadata?
    var mockDatabaseData: Data?
    var shouldThrowError: StockAPIError?

    var getLatestVersionCallCount = 0
    var downloadDatabaseCallCount = 0

    func getLatestVersion() async throws -> StockVersionMetadata {
        getLatestVersionCallCount += 1

        if let error = shouldThrowError {
            throw error
        }

        guard let metadata = mockVersionMetadata else {
            throw StockAPIError.serverError(statusCode: 404)
        }

        return metadata
    }

    func downloadStockDatabase(progressHandler: (@Sendable (Double) -> Void)?) async throws -> Data {
        downloadDatabaseCallCount += 1

        // Simulate progress
        progressHandler?(0.5)
        progressHandler?(1.0)

        if let error = shouldThrowError {
            throw error
        }

        guard let data = mockDatabaseData else {
            throw StockAPIError.downloadFailed("No data")
        }

        return data
    }
}

// MARK: - Mock Stock Database Manager

class MockStockDatabaseManager: StockDatabaseManagerProtocol {
    var _databaseExists = false
    var shouldThrowOnReplace = false
    var replaceCallCount = 0
    var lastReplacedFile: URL?

    var databaseExists: Bool { _databaseExists }

    func initialize() async throws {
        // No-op for tests
    }

    func replaceDatabaseWith(tempFile: URL) async throws {
        replaceCallCount += 1
        lastReplacedFile = tempFile

        if shouldThrowOnReplace {
            throw StockDatabaseError.cannotOpenDatabase("Mock error")
        }

        _databaseExists = true
    }

    nonisolated func performDatabaseOperation<T>(_ operation: (OpaquePointer) throws -> T) throws -> T {
        throw StockDatabaseError.databaseNotInitialized
    }
}

// MARK: - StockUpdateService Tests

@Suite("StockUpdateService Tests")
@MainActor
struct StockUpdateServiceTests {

    @Test("Check for updates returns nil when already up to date")
    func testUpToDate() async throws {
        let mockAPI = MockStockAPIClient()
        mockAPI.mockVersionMetadata = StockVersionMetadata(
            version: 5,
            releaseDate: Date(),
            fileSize: 1000,
            checksum: "abc123"
        )

        // Set current version to match server
        StockUpdatePreferences.shared.currentVersion = 5

        let service = createService(apiClient: mockAPI)
        let result = try await service.checkForUpdates()

        #expect(result == nil, "Should return nil when up to date")
        #expect(mockAPI.getLatestVersionCallCount == 1)

        // Cleanup
        StockUpdatePreferences.shared.currentVersion = 0
    }

    @Test("Check for updates returns metadata when update available")
    func testUpdateAvailable() async throws {
        let mockAPI = MockStockAPIClient()
        let expectedMetadata = StockVersionMetadata(
            version: 10,
            releaseDate: Date(),
            fileSize: 5000,
            checksum: "def456"
        )
        mockAPI.mockVersionMetadata = expectedMetadata

        // Set current version lower than server
        StockUpdatePreferences.shared.currentVersion = 5

        let service = createService(apiClient: mockAPI)
        let result = try await service.checkForUpdates()

        #expect(result != nil, "Should return metadata when update available")
        #expect(result?.version == 10)
        #expect(mockAPI.getLatestVersionCallCount == 1)

        // Cleanup
        StockUpdatePreferences.shared.currentVersion = 0
    }

    @Test("Check for updates returns nil when server returns 404")
    func testNoServerDatabase() async throws {
        let mockAPI = MockStockAPIClient()
        mockAPI.shouldThrowError = .serverError(statusCode: 404)

        let service = createService(apiClient: mockAPI)
        let result = try await service.checkForUpdates()

        #expect(result == nil, "Should return nil for 404 (no database on server)")
    }

    @Test("Check for updates updates lastUpdateCheck")
    func testUpdatesLastCheckTime() async throws {
        let mockAPI = MockStockAPIClient()
        mockAPI.mockVersionMetadata = StockVersionMetadata(
            version: 1,
            releaseDate: Date(),
            fileSize: 100,
            checksum: "abc"
        )

        // Clear any existing check time
        StockUpdatePreferences.shared.lastUpdateCheck = nil

        let service = createService(apiClient: mockAPI)
        _ = try await service.checkForUpdates()

        #expect(StockUpdatePreferences.shared.lastUpdateCheck != nil, "Should set lastUpdateCheck")

        // Cleanup
        StockUpdatePreferences.shared.lastUpdateCheck = nil
        StockUpdatePreferences.shared.currentVersion = 0
    }

    @Test("shouldCheckForUpdates respects 6 hour interval")
    func testCheckInterval() {
        let prefs = StockUpdatePreferences.shared

        // Never checked - should check
        prefs.lastUpdateCheck = nil
        #expect(prefs.shouldCheckForUpdates() == true)

        // Checked just now - should not check
        prefs.lastUpdateCheck = Date()
        #expect(prefs.shouldCheckForUpdates() == false)

        // Checked 5 hours ago - should not check
        prefs.lastUpdateCheck = Date().addingTimeInterval(-5 * 3600)
        #expect(prefs.shouldCheckForUpdates() == false)

        // Checked 7 hours ago - should check
        prefs.lastUpdateCheck = Date().addingTimeInterval(-7 * 3600)
        #expect(prefs.shouldCheckForUpdates() == true)

        // Cleanup
        prefs.lastUpdateCheck = nil
    }

    @Test("hasStockDatabase returns false when version is 0")
    func testHasStockDatabaseFalse() {
        StockUpdatePreferences.shared.currentVersion = 0
        #expect(StockUpdatePreferences.shared.hasStockDatabase == false)
    }

    @Test("hasStockDatabase returns true when version > 0")
    func testHasStockDatabaseTrue() {
        StockUpdatePreferences.shared.currentVersion = 5
        #expect(StockUpdatePreferences.shared.hasStockDatabase == true)

        // Cleanup
        StockUpdatePreferences.shared.currentVersion = 0
    }

    // MARK: - Test Helpers

    func createService(
        apiClient: StockAPIClientProtocol,
        databaseManager: StockDatabaseManagerProtocol? = nil
    ) -> StockUpdateService {
        let mockStorage = MockCatalogStorageService()
        let mockNetwork = MockNetworkMonitor()
        mockNetwork._isConnected = true
        mockNetwork._canDownloadCatalog = true

        return StockUpdateService(
            apiClient: apiClient,
            databaseManager: databaseManager ?? MockStockDatabaseManager(),
            storageService: mockStorage,
            networkMonitor: mockNetwork
        )
    }
}

// MARK: - Mock Catalog Storage Service

@MainActor
class MockCatalogStorageService: CatalogStorageServiceProtocol {
    var saveTempCallCount = 0
    var lastSavedData: Data?

    func saveTempCatalog(_ data: Data, version: Int) async throws -> URL {
        saveTempCallCount += 1
        lastSavedData = data

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_stock_v\(version).sqlite")
        try data.write(to: tempURL)
        return tempURL
    }
}

// MARK: - Mock Network Monitor

@MainActor
class MockNetworkMonitor: NetworkMonitorProtocol {
    var _isConnected = true
    var _isOnWiFi = true
    var _canDownloadCatalog = true

    var isConnected: Bool { _isConnected }
    var isOnWiFi: Bool { _isOnWiFi }

    func canDownloadCatalog() -> Bool { _canDownloadCatalog }
}
