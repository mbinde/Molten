//
//  LabelUpdateModelsTests.swift
//  MoltenTests
//
//  Tests for label update models
//

import Foundation
import Testing

@testable import Molten

@Suite("LabelUpdateModels Tests")
@MainActor
struct LabelUpdateModelsTests {

    // MARK: - LabelVersionMetadata Tests

    @Test("LabelVersionMetadata decodes from JSON correctly")
    func testLabelVersionMetadataDecoding() throws {
        let json = """
        {
            "version": 3,
            "releaseDate": "2025-11-02T08:46:18Z",
            "fileSize": 1048576,
            "checksum": "sha256:abc123",
            "changelog": "Added new label layouts",
            "minAppVersion": "1.5.0"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let metadata = try decoder.decode(LabelVersionMetadata.self, from: json)

        #expect(metadata.version == 3)
        #expect(metadata.fileSize == 1048576)
        #expect(metadata.checksum == "sha256:abc123")
        #expect(metadata.minAppVersion == "1.5.0")
        #expect(metadata.changelog == "Added new label layouts")
    }

    @Test("LabelVersionMetadata encodes to JSON correctly")
    func testLabelVersionMetadataEncoding() throws {
        let metadata = LabelVersionMetadata(
            version: 3,
            releaseDate: Date(timeIntervalSince1970: 1699000000),
            fileSize: 1048576,
            checksum: "sha256:abc123",
            changelog: "Added new label layouts",
            minAppVersion: "1.5.0"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(metadata)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["version"] as? Int == 3)
        #expect(json["fileSize"] as? Int == 1048576)
        #expect(json["checksum"] as? String == "sha256:abc123")
        #expect(json["minAppVersion"] as? String == "1.5.0")
    }

    @Test("LabelVersionMetadata checks app compatibility correctly")
    func testAppCompatibility() {
        let metadata = LabelVersionMetadata(
            version: 1,
            releaseDate: Date(),
            fileSize: 1000,
            checksum: "sha256:test",
            changelog: nil,
            minAppVersion: "1.5.0"
        )

        // Compatible versions
        #expect(metadata.isCompatibleWithApp(version: "1.5.0") == true)
        #expect(metadata.isCompatibleWithApp(version: "1.6.0") == true)
        #expect(metadata.isCompatibleWithApp(version: "2.0.0") == true)

        // Incompatible versions
        #expect(metadata.isCompatibleWithApp(version: "1.4.9") == false)
        #expect(metadata.isCompatibleWithApp(version: "1.0.0") == false)
    }

    // MARK: - LabelUpdateInfo Tests

    @Test("LabelUpdateInfo detects initial versioned update")
    func testLabelUpdateInfoInitialVersionedUpdate() {
        // When currentVersion is nil, it's a pre-versioning database
        let initialUpdate = LabelUpdateInfo(
            currentVersion: nil,
            availableVersion: 1,
            releaseDate: Date(),
            changelog: "Initial versioned release",
            fileSize: 1000,
            checksum: "sha256:test"
        )

        #expect(initialUpdate.isInitialVersionedUpdate == true)

        // Regular update from v1 to v2
        let regularUpdate = LabelUpdateInfo(
            currentVersion: 1,
            availableVersion: 2,
            releaseDate: Date(),
            changelog: "Regular update",
            fileSize: 1000,
            checksum: "sha256:test"
        )

        #expect(regularUpdate.isInitialVersionedUpdate == false)
    }

    @Test("LabelUpdateInfo stores correct values")
    func testLabelUpdateInfoValues() {
        let updateInfo = LabelUpdateInfo(
            currentVersion: 1,
            availableVersion: 2,
            releaseDate: Date(),
            changelog: "Test changes",
            fileSize: 1048576,
            checksum: "sha256:test"
        )

        #expect(updateInfo.currentVersion == 1)
        #expect(updateInfo.availableVersion == 2)
        #expect(updateInfo.fileSize == 1048576)
        #expect(updateInfo.changelog == "Test changes")
    }

    // MARK: - LabelUpdateResult Tests

    @Test("LabelUpdateResult stores correct values")
    func testLabelUpdateResult() {
        let result = LabelUpdateResult(
            version: 2,
            layoutCount: 50,
            productCount: 200,
            brandCount: 15,
            appliedAt: Date()
        )

        #expect(result.version == 2)
        #expect(result.layoutCount == 50)
        #expect(result.productCount == 200)
        #expect(result.brandCount == 15)
    }

    // MARK: - LabelUpdateError Tests

    @Test("LabelUpdateError provides correct descriptions")
    func testErrorDescriptions() {
        let networkError = LabelUpdateError.networkPolicyRestricted
        #expect(networkError.errorDescription?.contains("policy") == true)

        let checksumError = LabelUpdateError.checksumMismatch
        #expect(checksumError.errorDescription?.contains("integrity") == true)

        let serverError = LabelUpdateError.serverError(statusCode: 429)
        #expect(serverError.errorDescription?.contains("429") == true)

        let incompatibleError = LabelUpdateError.incompatibleVersion(required: "2.0.0", current: "1.5.0")
        #expect(incompatibleError.errorDescription?.contains("2.0.0") == true)
        #expect(incompatibleError.errorDescription?.contains("1.5.0") == true)

        let invalidDatabaseError = LabelUpdateError.invalidDatabase
        #expect(invalidDatabaseError.errorDescription?.contains("valid") == true)
    }

    @Test("LabelUpdateError updateNotAvailable has description")
    func testUpdateNotAvailableError() {
        let error = LabelUpdateError.updateNotAvailable
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription?.isEmpty == false)
    }

    @Test("LabelUpdateError downloadFailed wraps underlying error")
    func testDownloadFailedError() {
        let underlyingError = NSError(domain: "test", code: 123, userInfo: [NSLocalizedDescriptionKey: "Network timeout"])
        let error = LabelUpdateError.downloadFailed(underlying: underlyingError)
        #expect(error.errorDescription?.contains("download") == true)
    }

    @Test("LabelUpdateError storageError wraps underlying error")
    func testStorageError() {
        let underlyingError = NSError(domain: "test", code: 456, userInfo: [NSLocalizedDescriptionKey: "Disk full"])
        let error = LabelUpdateError.storageError(underlying: underlyingError)
        #expect(error.errorDescription?.contains("Storage") == true)
    }

    @Test("LabelUpdateError databaseSwapFailed wraps underlying error")
    func testDatabaseSwapFailedError() {
        let underlyingError = NSError(domain: "test", code: 789, userInfo: [NSLocalizedDescriptionKey: "File locked"])
        let error = LabelUpdateError.databaseSwapFailed(underlying: underlyingError)
        #expect(error.errorDescription?.contains("install") == true)
    }
}
