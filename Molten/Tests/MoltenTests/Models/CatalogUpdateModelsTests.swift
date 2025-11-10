//
//  CatalogUpdateModelsTests.swift
//  MoltenTests
//
//  Created by Assistant on 11/9/25.
//  Tests for catalog update models
//

import Foundation
import Testing

@testable import Molten

@Suite("CatalogUpdateModels Tests")
@MainActor
struct CatalogUpdateModelsTests {

    // MARK: - CatalogVersionMetadata Tests

    @Test("CatalogVersionMetadata decodes from JSON correctly")
    func testCatalogVersionMetadataDecoding() throws {
        let json = """
        {
            "version": 2,
            "item_count": 3198,
            "release_date": "2025-11-02T08:46:18Z",
            "file_size": 3145728,
            "checksum": "sha256:abc123",
            "min_app_version": "1.5.0",
            "changelog": "Test changelog"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let metadata = try decoder.decode(CatalogVersionMetadata.self, from: json)

        #expect(metadata.version == 2)
        #expect(metadata.itemCount == 3198)
        #expect(metadata.fileSize == 3145728)
        #expect(metadata.checksum == "sha256:abc123")
        #expect(metadata.minAppVersion == "1.5.0")
        #expect(metadata.changelog == "Test changelog")
    }

    @Test("CatalogVersionMetadata encodes to JSON correctly")
    func testCatalogVersionMetadataEncoding() throws {
        let metadata = CatalogVersionMetadata(
            version: 2,
            itemCount: 3198,
            releaseDate: Date(timeIntervalSince1970: 1699000000),
            fileSize: 3145728,
            checksum: "sha256:abc123",
            minAppVersion: "1.5.0",
            changelog: "Test changelog"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(metadata)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["version"] as? Int == 2)
        #expect(json["item_count"] as? Int == 3198)
        #expect(json["file_size"] as? Int == 3145728)
        #expect(json["checksum"] as? String == "sha256:abc123")
        #expect(json["min_app_version"] as? String == "1.5.0")
    }

    @Test("CatalogVersionMetadata formats file size correctly")
    func testFileSizeFormatting() {
        let metadata = CatalogVersionMetadata(
            version: 1,
            itemCount: 100,
            releaseDate: Date(),
            fileSize: 3145728,  // 3 MB
            checksum: "sha256:test",
            minAppVersion: "1.0.0",
            changelog: ""
        )

        let formatted = metadata.fileSizeFormatted
        #expect(formatted.contains("3"))
        #expect(formatted.contains("MB") || formatted.contains("bytes"))
    }

    @Test("CatalogVersionMetadata checks app compatibility correctly")
    func testAppCompatibility() {
        let metadata = CatalogVersionMetadata(
            version: 1,
            itemCount: 100,
            releaseDate: Date(),
            fileSize: 1000,
            checksum: "sha256:test",
            minAppVersion: "1.5.0",
            changelog: ""
        )

        // Compatible versions
        #expect(metadata.isCompatibleWithApp(version: "1.5.0") == true)
        #expect(metadata.isCompatibleWithApp(version: "1.6.0") == true)
        #expect(metadata.isCompatibleWithApp(version: "2.0.0") == true)

        // Incompatible versions
        #expect(metadata.isCompatibleWithApp(version: "1.4.9") == false)
        #expect(metadata.isCompatibleWithApp(version: "1.0.0") == false)
    }

    // MARK: - CatalogUpdateInfo Tests

    @Test("CatalogUpdateInfo calculates properties correctly")
    func testCatalogUpdateInfo() {
        let updateInfo = CatalogUpdateInfo(
            currentVersion: 1,
            availableVersion: 2,
            itemsAdded: 15,
            releaseDate: Date(),
            changelog: "Test changes",
            fileSize: 2097152,  // 2 MB
            checksum: "sha256:test"
        )

        #expect(updateInfo.isNewVersion == true)
        #expect(updateInfo.fileSizeFormatted.contains("2"))

        let sameVersionInfo = CatalogUpdateInfo(
            currentVersion: 2,
            availableVersion: 2,
            itemsAdded: 0,
            releaseDate: Date(),
            changelog: "",
            fileSize: 1000,
            checksum: ""
        )

        #expect(sameVersionInfo.isNewVersion == false)
    }

    // MARK: - CatalogUpdateResult Tests

    @Test("CatalogUpdateResult calculates total changes correctly")
    func testCatalogUpdateResult() {
        let result = CatalogUpdateResult(
            version: 2,
            itemsCreated: 10,
            itemsUpdated: 5,
            itemsRemoved: 2,
            appliedAt: Date()
        )

        #expect(result.totalChanges == 17)  // 10 + 5 + 2
    }

    // MARK: - CatalogDownloadStrategy Tests

    @Test("CatalogDownloadStrategy returns correct download type")
    func testDownloadStrategy() {
        let fullStrategy = CatalogDownloadStrategy.full(version: 2)
        #expect(fullStrategy.downloadType == "full")

        let deltaStrategy = CatalogDownloadStrategy.delta(from: 1, to: 2)
        #expect(deltaStrategy.downloadType == "delta")
    }

    // MARK: - AnyCodable Tests

    @Test("AnyCodable encodes and decodes strings")
    func testAnyCodableString() throws {
        let value = AnyCodable("test string")

        let encoder = JSONEncoder()
        let data = try encoder.encode(value)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AnyCodable.self, from: data)

        #expect(decoded.value as? String == "test string")
    }

    @Test("AnyCodable encodes and decodes integers")
    func testAnyCodableInt() throws {
        let value = AnyCodable(42)

        let encoder = JSONEncoder()
        let data = try encoder.encode(value)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AnyCodable.self, from: data)

        #expect(decoded.value as? Int == 42)
    }

    @Test("AnyCodable encodes and decodes booleans")
    func testAnyCodableBool() throws {
        let value = AnyCodable(true)

        let encoder = JSONEncoder()
        let data = try encoder.encode(value)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AnyCodable.self, from: data)

        #expect(decoded.value as? Bool == true)
    }

    // MARK: - CatalogUpdateError Tests

    @Test("CatalogUpdateError provides correct descriptions")
    func testErrorDescriptions() {
        let networkError = CatalogUpdateError.networkPolicyRestricted
        #expect(networkError.errorDescription?.contains("WiFi") == true)

        let checksumError = CatalogUpdateError.checksumMismatch
        #expect(checksumError.errorDescription?.contains("corrupted") == true)

        let serverError = CatalogUpdateError.serverError(statusCode: 429)
        #expect(serverError.errorDescription?.contains("429") == true)

        let incompatibleError = CatalogUpdateError.incompatibleVersion(required: "2.0.0", current: "1.5.0")
        #expect(incompatibleError.errorDescription?.contains("2.0.0") == true)
        #expect(incompatibleError.errorDescription?.contains("1.5.0") == true)
    }
}
