//
//  MockCatalogUpdateHelpers.swift
//  MoltenTests
//
//  Created by Assistant on 11/9/25.
//  Shared mocks for catalog update testing
//

import Foundation
import Combine
@testable import Molten

// MARK: - Mock Catalog Update Service

@MainActor
class MockCatalogUpdateService: CatalogUpdateServiceProtocol {
    @Published var isChecking: Bool = false
    @Published var isDownloading: Bool = false
    @Published var downloadProgress: Double = 0.0

    var mockUpdateInfo: CatalogUpdateInfo?
    var mockUpdateResult: CatalogUpdateResult?
    var shouldThrowError: CatalogUpdateError?
    var shouldDelayResponse: Bool = false

    var checkForUpdatesCallCount = 0
    var downloadCallCount = 0
    var lastForceFlag: Bool?

    func checkForUpdates() async throws -> CatalogUpdateInfo? {
        checkForUpdatesCallCount += 1
        isChecking = true
        defer { isChecking = false }

        if shouldDelayResponse {
            try await Task.sleep(for: .milliseconds(200))
        }

        if let error = shouldThrowError {
            throw error
        }

        return mockUpdateInfo
    }

    func downloadAndInstallUpdate(
        updateInfo: CatalogUpdateInfo,
        force: Bool = false
    ) async throws -> CatalogUpdateResult {
        downloadCallCount += 1
        lastForceFlag = force

        isDownloading = true
        downloadProgress = 0.0

        defer {
            isDownloading = false
            downloadProgress = 0.0
        }

        if shouldDelayResponse {
            try await Task.sleep(for: .milliseconds(200))
        }

        if let error = shouldThrowError {
            throw error
        }

        guard let result = mockUpdateResult else {
            throw CatalogUpdateError.downloadFailed(
                underlying: NSError(domain: "MockService", code: -1,
                                  userInfo: [NSLocalizedDescriptionKey: "No mock result set"])
            )
        }

        return result
    }
}

// MARK: - Mock Network Monitor

@MainActor
class MockNetworkMonitor: NetworkMonitorProtocol {
    @Published var isConnected: Bool = true
    @Published var isOnWiFi: Bool = true
    @Published var isExpensive: Bool = false
    @Published var isConstrained: Bool = false

    var connectionDescription: String {
        guard isConnected else { return "No connection" }
        return isOnWiFi ? "WiFi" : "Cellular"
    }

    func canDownloadCatalog() -> Bool {
        guard isConnected else { return false }
        let policy = CatalogUpdatePreferences.shared.downloadPolicy
        return policy.allowsDownload(isOnWiFi: isOnWiFi)
    }
}
