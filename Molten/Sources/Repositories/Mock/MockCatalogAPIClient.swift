//
//  MockCatalogAPIClient.swift
//  Molten
//
//  Created by Assistant on 11/9/25.
//  Mock API client for testing catalog updates
//

import Foundation

/// Mock implementation of catalog API client for testing
@MainActor
class MockCatalogAPIClient {

    // MARK: - Mock State

    var latestVersion: CatalogVersionMetadata?
    var catalogData: Data?
    var shouldThrowError: CatalogUpdateError?
    var downloadDelay: TimeInterval = 0.1
    var progressUpdates: [Double] = []

    // MARK: - Tracking

    private(set) var getLatestVersionCallCount = 0
    private(set) var downloadFullCatalogCallCount = 0
    private(set) var lastDownloadVersion: Int?

    // MARK: - Public API

    func getLatestVersion() async throws -> CatalogVersionMetadata {
        getLatestVersionCallCount += 1

        if let error = shouldThrowError {
            throw error
        }

        guard let version = latestVersion else {
            throw CatalogUpdateError.updateNotAvailable
        }

        return version
    }

    func downloadFullCatalog(
        version: Int? = nil,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws -> Data {
        downloadFullCatalogCallCount += 1
        lastDownloadVersion = version

        if let error = shouldThrowError {
            throw error
        }

        guard let data = catalogData else {
            throw CatalogUpdateError.downloadFailed(
                underlying: NSError(domain: "MockCatalogAPIClient", code: -1,
                                  userInfo: [NSLocalizedDescriptionKey: "No mock data set"])
            )
        }

        // Simulate progress updates
        if !progressUpdates.isEmpty {
            for progress in progressUpdates {
                progressHandler?(progress)
                try await Task.sleep(nanoseconds: UInt64(downloadDelay * 1_000_000_000 / Double(progressUpdates.count)))
            }
        }

        // Final progress
        progressHandler?(1.0)

        return data
    }

    func downloadDeltaCatalog(from: Int, to: Int) async throws -> CatalogDelta {
        throw CatalogUpdateError.updateNotAvailable  // Not implemented
    }

    // MARK: - Test Helpers

    /// Set up mock to return a specific version
    func setMockVersion(_ version: Int, itemCount: Int = 3198, fileSize: Int64 = 3_145_728) {
        latestVersion = CatalogVersionMetadata(
            version: version,
            itemCount: itemCount,
            releaseDate: Date(),
            fileSize: fileSize,
            checksum: "sha256:mockchecksumforversion\(version)",
            minAppVersion: "1.5.0",
            changelog: "Mock changelog for version \(version)"
        )
    }

    /// Set up mock catalog data
    func setMockCatalogData(_ data: Data) {
        catalogData = data
    }

    /// Set up mock catalog from JSON structure
    func setMockCatalogFromJSON(_ json: [String: Any]) throws {
        catalogData = try JSONSerialization.data(withJSONObject: json)
    }

    /// Reset all mock state
    func reset() {
        latestVersion = nil
        catalogData = nil
        shouldThrowError = nil
        downloadDelay = 0.1
        progressUpdates = []
        getLatestVersionCallCount = 0
        downloadFullCatalogCallCount = 0
        lastDownloadVersion = nil
    }

    /// Set up realistic progress simulation
    func enableProgressSimulation(steps: Int = 10) {
        progressUpdates = (1...steps).map { Double($0) / Double(steps) }
    }
}
