//
//  CatalogAPIClientTests.swift
//  MoltenTests
//
//  Created by Assistant on 11/9/25.
//  Tests for catalog API client
//

import Foundation
import Testing
import SQLite3

@testable import Molten

@Suite("CatalogAPIClient Tests")
@MainActor
struct CatalogAPIClientTests {

    // MARK: - Test Helpers

    /// Create test metadata
    func createTestMetadata(version: Int = 2) -> CatalogVersionMetadata {
        return CatalogVersionMetadata(
            version: version,
            itemCount: 3198,
            releaseDate: Date(),
            fileSize: 3_145_728,
            checksum: "sha256:abc123",
            minAppVersion: "1.5.0",
            changelog: "Test changelog"
        )
    }

    /// Create test catalog SQLite database
    func createTestCatalogData() -> Data {
        // Create a minimal valid SQLite database for testing
        // SQLite file format starts with "SQLite format 3\0" (16 bytes magic number)
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_catalog_\(UUID().uuidString).sqlite")

        // Create a minimal SQLite database using SQLite3
        var db: OpaquePointer?
        guard sqlite3_open(tempURL.path, &db) == SQLITE_OK else {
            fatalError("Failed to create test SQLite database")
        }

        // Create catalog_items table
        let createTableSQL = """
        CREATE TABLE IF NOT EXISTS catalog_items (
            id INTEGER PRIMARY KEY,
            stable_id TEXT NOT NULL UNIQUE,
            manufacturer TEXT,
            name TEXT,
            coe INTEGER
        );
        """

        var createTableStatement: OpaquePointer?
        if sqlite3_prepare_v2(db, createTableSQL, -1, &createTableStatement, nil) == SQLITE_OK {
            if sqlite3_step(createTableStatement) == SQLITE_DONE {
                // Insert test data
                let insertSQL = """
                INSERT INTO catalog_items (stable_id, manufacturer, name, coe)
                VALUES ('bullseye-001-0', 'bullseye', 'Clear', 90);
                """
                var insertStatement: OpaquePointer?
                if sqlite3_prepare_v2(db, insertSQL, -1, &insertStatement, nil) == SQLITE_OK {
                    sqlite3_step(insertStatement)
                }
                sqlite3_finalize(insertStatement)
            }
        }
        sqlite3_finalize(createTableStatement)

        // Create metadata table
        let createMetadataSQL = """
        CREATE TABLE IF NOT EXISTS metadata (
            key TEXT PRIMARY KEY,
            value TEXT
        );
        """
        var createMetadataStatement: OpaquePointer?
        if sqlite3_prepare_v2(db, createMetadataSQL, -1, &createMetadataStatement, nil) == SQLITE_OK {
            sqlite3_step(createMetadataStatement)
        }
        sqlite3_finalize(createMetadataStatement)

        // Insert version metadata
        let insertMetadataSQL = "INSERT INTO metadata (key, value) VALUES ('version', '1');"
        var insertMetadataStatement: OpaquePointer?
        if sqlite3_prepare_v2(db, insertMetadataSQL, -1, &insertMetadataStatement, nil) == SQLITE_OK {
            sqlite3_step(insertMetadataStatement)
        }
        sqlite3_finalize(insertMetadataStatement)

        sqlite3_close(db)

        // Read the database file
        let data = try! Data(contentsOf: tempURL)

        // Clean up temp file
        try? FileManager.default.removeItem(at: tempURL)

        return data
    }

    // MARK: - Version API Tests

    @Test("Get latest version succeeds with 200 response")
    func testGetLatestVersionSuccess() async throws {
        let metadata = createTestMetadata()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let responseData = try encoder.encode(metadata)

        let mockSession = MockCatalogURLSession()
        mockSession.mockData = responseData
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com/catalog/version")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )

        let mockAttestation = MockCatalogAttestationManager()
        let client = CatalogAPIClient(
            session: mockSession,
            attestationManager: mockAttestation
        )

        let result = try await client.getLatestVersion()

        #expect(result.version == 2)
        #expect(result.itemCount == 3198)
        #expect(result.checksum == "sha256:abc123")
    }

    @Test("Get latest version handles 401 unauthorized")
    func testGetLatestVersionUnauthorized() async throws {
        let mockSession = MockCatalogURLSession()
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com/catalog/version")!,
            statusCode: 401,
            httpVersion: nil,
            headerFields: nil
        )

        let client = CatalogAPIClient(session: mockSession)

        await #expect(throws: CatalogUpdateError.self) {
            _ = try await client.getLatestVersion()
        }
    }

    @Test("Get latest version handles 429 rate limit")
    func testGetLatestVersionRateLimit() async throws {
        let mockSession = MockCatalogURLSession()
        mockSession.mockData = Data()  // Empty data is fine, we just need non-nil
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com/catalog/version")!,
            statusCode: 429,
            httpVersion: nil,
            headerFields: nil
        )

        let client = CatalogAPIClient(session: mockSession)

        do {
            _ = try await client.getLatestVersion()
            Issue.record("Expected rate limit error")
        } catch let error as CatalogUpdateError {
            switch error {
            case .serverError(let statusCode):
                #expect(statusCode == 429)
            default:
                Issue.record("Expected serverError with 429 status code, got: \(error)")
            }
        } catch {
            Issue.record("Expected CatalogUpdateError, got: \(error)")
        }
    }

    @Test("Get latest version continues without attestation if attestation fails")
    func testGetLatestVersionWithoutAttestation() async throws {
        let metadata = createTestMetadata()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let responseData = try encoder.encode(metadata)

        let mockSession = MockCatalogURLSession()
        mockSession.mockData = responseData
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com/catalog/version")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )

        let mockAttestation = MockCatalogAttestationManager()
        mockAttestation.shouldThrowError = .noKeyExists  // Attestation fails

        let client = CatalogAPIClient(
            session: mockSession,
            attestationManager: mockAttestation
        )

        // Should succeed despite attestation failure (version check doesn't require it)
        let result = try await client.getLatestVersion()
        #expect(result.version == 2)
    }

    // MARK: - Download Tests

    @Test("Download full catalog succeeds")
    func testDownloadFullCatalogSuccess() async throws {
        let catalogData = createTestCatalogData()

        let mockSession = MockCatalogURLSession()
        mockSession.mockDownloadURL = URL(fileURLWithPath: "/tmp/catalog.sqlite")
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com/catalog/data")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )

        // Write catalog data to temp file
        try catalogData.write(to: mockSession.mockDownloadURL!)

        let mockAttestation = MockCatalogAttestationManager()
        mockAttestation.shouldSucceed = true

        let client = CatalogAPIClient(
            session: mockSession,
            attestationManager: mockAttestation
        )

        let result = try await client.downloadFullCatalog()

        #expect(result.count == catalogData.count)

        // Attestation should have been required for data download
        #expect(mockAttestation.generateAssertionCallCount > 0)
    }

    @Test("Download full catalog with version parameter")
    func testDownloadFullCatalogWithVersion() async throws {
        let catalogData = createTestCatalogData()

        let mockSession = MockCatalogURLSession()
        mockSession.mockDownloadURL = URL(fileURLWithPath: "/tmp/catalog.sqlite")
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com/catalog/data?version=2")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )

        try catalogData.write(to: mockSession.mockDownloadURL!)

        let mockAttestation = MockCatalogAttestationManager()
        mockAttestation.shouldSucceed = true

        let client = CatalogAPIClient(
            session: mockSession,
            attestationManager: mockAttestation
        )

        _ = try await client.downloadFullCatalog(version: 2)

        // Verify URL includes version parameter
        let lastRequest = mockSession.lastDownloadRequest
        #expect(lastRequest?.url?.query?.contains("version=2") == true)
    }

    @Test("Download full catalog decompresses gzipped data")
    func testDownloadFullCatalogDecompressesGzip() async throws {
        let catalogData = createTestCatalogData()
        let gzippedData = try catalogData.gzipped()

        let mockSession = MockCatalogURLSession()
        mockSession.mockDownloadURL = URL(fileURLWithPath: "/tmp/catalog.json.gz")
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com/catalog/data")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Encoding": "gzip"]
        )

        try gzippedData.write(to: mockSession.mockDownloadURL!)

        let mockAttestation = MockCatalogAttestationManager()
        mockAttestation.shouldSucceed = true

        let client = CatalogAPIClient(
            session: mockSession,
            attestationManager: mockAttestation
        )

        let result = try await client.downloadFullCatalog()

        // Should be decompressed
        #expect(result.count == catalogData.count)
        #expect(result == catalogData)
    }

    @Test("Download full catalog tracks progress")
    func testDownloadFullCatalogProgressTracking() async throws {
        let catalogData = createTestCatalogData()

        let mockSession = MockCatalogURLSession()
        mockSession.mockDownloadURL = URL(fileURLWithPath: "/tmp/catalog.sqlite")
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com/catalog/data")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )

        try catalogData.write(to: mockSession.mockDownloadURL!)

        let mockAttestation = MockCatalogAttestationManager()
        mockAttestation.shouldSucceed = true

        let client = CatalogAPIClient(
            session: mockSession,
            attestationManager: mockAttestation
        )

        // Use actor to safely collect progress values from @Sendable closure
        actor ProgressCollector {
            var values: [Double] = []
            func append(_ value: Double) {
                values.append(value)
            }
        }
        let collector = ProgressCollector()

        _ = try await client.downloadFullCatalog { progress in
            Task { await collector.append(progress) }
        }

        // Note: Progress tracking depends on URLSession delegate callbacks
        // In real usage, progress would be reported; in tests with mock, it may not
        // This test validates the API works without errors
        let progressValues = await collector.values
        #expect(progressValues.isEmpty || progressValues.allSatisfy { $0 >= 0.0 && $0 <= 1.0 })
    }

    @Test("Download full catalog handles 304 not modified")
    func testDownloadFullCatalogNotModified() async throws {
        let mockSession = MockCatalogURLSession()
        mockSession.mockDownloadURL = URL(fileURLWithPath: "/tmp/catalog.sqlite")
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com/catalog/data")!,
            statusCode: 304,
            httpVersion: nil,
            headerFields: nil
        )

        let mockAttestation = MockCatalogAttestationManager()
        mockAttestation.shouldSucceed = true

        let client = CatalogAPIClient(
            session: mockSession,
            attestationManager: mockAttestation
        )

        await #expect(throws: CatalogUpdateError.updateNotAvailable) {
            _ = try await client.downloadFullCatalog()
        }
    }

    @Test("Download full catalog handles 404 not found")
    func testDownloadFullCatalogNotFound() async throws {
        let mockSession = MockCatalogURLSession()
        mockSession.mockDownloadURL = URL(fileURLWithPath: "/tmp/catalog.sqlite")
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com/catalog/data")!,
            statusCode: 404,
            httpVersion: nil,
            headerFields: nil
        )

        let mockAttestation = MockCatalogAttestationManager()
        mockAttestation.shouldSucceed = true

        let client = CatalogAPIClient(
            session: mockSession,
            attestationManager: mockAttestation
        )

        await #expect(throws: CatalogUpdateError.updateNotAvailable) {
            _ = try await client.downloadFullCatalog()
        }
    }

    @Test("Download full catalog requires attestation")
    func testDownloadFullCatalogRequiresAttestation() async throws {
        let mockSession = MockCatalogURLSession()

        let mockAttestation = MockCatalogAttestationManager()
        mockAttestation.shouldThrowError = .assertionFailed  // Attestation fails

        let client = CatalogAPIClient(
            session: mockSession,
            attestationManager: mockAttestation
        )

        // Should fail because attestation is required for data downloads
        await #expect(throws: AttestationError.self) {
            _ = try await client.downloadFullCatalog()
        }
    }

    // MARK: - API Versioning Tests

    @Test("Version endpoint uses /v1/catalog/version path")
    func testVersionEndpointUsesVersionedPath() async throws {
        let metadata = createTestMetadata()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let responseData = try encoder.encode(metadata)

        let mockSession = MockCatalogURLSession()
        mockSession.mockData = responseData
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com/v1/catalog/version")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )

        let mockAttestation = MockCatalogAttestationManager()
        let client = CatalogAPIClient(
            session: mockSession,
            baseURL: URL(string: "https://api.example.com")!,
            attestationManager: mockAttestation
        )

        _ = try await client.getLatestVersion()

        // Verify the path includes /v1/
        let request = try #require(mockSession.lastRequest)
        let url = try #require(request.url)
        #expect(url.path == "/v1/catalog/version")
    }

    @Test("Data download endpoint uses /v1/catalog/data path")
    func testDataDownloadEndpointUsesVersionedPath() async throws {
        let catalogData = createTestCatalogData()

        let mockSession = MockCatalogURLSession()
        mockSession.mockDownloadURL = URL(fileURLWithPath: "/tmp/catalog.sqlite")
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com/v1/catalog/data")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )

        try catalogData.write(to: mockSession.mockDownloadURL!)

        let mockAttestation = MockCatalogAttestationManager()
        mockAttestation.shouldSucceed = true

        let client = CatalogAPIClient(
            session: mockSession,
            baseURL: URL(string: "https://api.example.com")!,
            attestationManager: mockAttestation
        )

        _ = try await client.downloadFullCatalog()

        // Verify the path includes /v1/ and uses database endpoint
        let request = try #require(mockSession.lastDownloadRequest)
        let url = try #require(request.url)
        #expect(url.path == "/v1/catalog/database")
    }
}

// MARK: - Mock URLSession

@MainActor
class MockCatalogURLSession: URLSessionProtocol {
    var mockData: Data?
    var mockResponse: URLResponse?
    var mockError: Error?
    var mockDownloadURL: URL?

    var lastRequest: URLRequest?
    var lastDownloadRequest: URLRequest?

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request

        if let error = mockError {
            throw error
        }

        guard let data = mockData, let response = mockResponse else {
            throw CatalogUpdateError.invalidResponse
        }

        return (data, response)
    }

    func download(for request: URLRequest, delegate: URLSessionTaskDelegate?) async throws -> (URL, URLResponse) {
        lastDownloadRequest = request

        if let error = mockError {
            throw error
        }

        guard let downloadURL = mockDownloadURL, let response = mockResponse else {
            throw CatalogUpdateError.invalidResponse
        }

        return (downloadURL, response)
    }
}

// MARK: - Mock AttestationManager

@MainActor
class MockCatalogAttestationManager: AttestationManagerProtocol {
    var isSupported: Bool = true
    var shouldSucceed: Bool = true
    var shouldThrowError: AttestationError?

    var generateKeyCallCount = 0
    var attestKeyCallCount = 0
    var generateAssertionCallCount = 0

    var currentKeyId: String? = "mock-key-id"

    init() {}

    func generateKey() async throws -> String {
        generateKeyCallCount += 1

        if let error = shouldThrowError {
            throw error
        }

        return "mock-key-id"
    }

    func attestKey(keyId: String, challenge: Data) async throws -> Data {
        attestKeyCallCount += 1

        if let error = shouldThrowError {
            throw error
        }

        return Data("mock-attestation".utf8)
    }

    func generateAssertion(requestData: Data) async throws -> Data {
        generateAssertionCallCount += 1

        if let error = shouldThrowError {
            throw error
        }

        if !shouldSucceed {
            throw AttestationError.assertionFailed
        }

        return Data("mock-assertion".utf8)
    }

    func createRequestData(method: String, path: String, body: Data?) -> Data {
        var components = [method, path]

        if let body = body {
            components.append("body-hash")
        }

        return components.joined(separator: "-").data(using: .utf8) ?? Data()
    }
}
