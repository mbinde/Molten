//
//  BackupAPIClientTests.swift
//  MoltenTests
//
//  Tests for BackupAPIClient - handles server communication for automatic inventory backups
//

#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif
import Foundation
@testable import Molten

@Suite("BackupAPIClient Tests")
@MainActor
struct BackupAPIClientTests {

    // MARK: - Register Backup Key Tests

    @Test("Should register backup key successfully")
    func testRegisterBackupKey() async throws {
        let mockSession = MockBackupURLSession()
        let mockAttestation = MockBackupAttestationManager(isSupported: false)
        let client = BackupAPIClient(
            session: mockSession,
            baseURL: URL(string: "https://api.example.com")!,
            attestationManager: mockAttestation
        )

        let backupKey = "ABC-DEF-GHJ"
        let publicKey = Data(count: 32)

        // Configure mock to succeed with 201
        mockSession.nextResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com/api/v1/backup/register")!,
            statusCode: 201,
            httpVersion: nil,
            headerFields: nil
        )
        mockSession.nextData = Data()

        try await client.registerBackupKey(backupKey, publicKey: publicKey)

        // Verify request was made
        #expect(mockSession.lastRequest != nil)
        #expect(mockSession.lastRequest?.httpMethod == "POST")
        #expect(mockSession.lastRequest?.url?.path == "/api/v1/backup/register")
    }

    @Test("Should include backup key and public key in register request body")
    func testRegisterRequestBody() async throws {
        let mockSession = MockBackupURLSession()
        let mockAttestation = MockBackupAttestationManager(isSupported: false)
        let client = BackupAPIClient(
            session: mockSession,
            baseURL: URL(string: "https://api.example.com")!,
            attestationManager: mockAttestation
        )

        let backupKey = "ABC-DEF-GHJ"
        let publicKey = Data([0x01, 0x02, 0x03])

        mockSession.nextResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com/api/v1/backup/register")!,
            statusCode: 201,
            httpVersion: nil,
            headerFields: nil
        )
        mockSession.nextData = Data()

        try await client.registerBackupKey(backupKey, publicKey: publicKey)

        // Verify request body
        #expect(mockSession.lastRequestBody != nil)
        if let bodyData = mockSession.lastRequestBody {
            let json = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
            #expect(json?["backupKey"] as? String == backupKey)
            #expect(json?["publicKey"] as? String == publicKey.base64EncodedString())
        }
    }

    @Test("Should throw conflict error when key already exists")
    func testRegisterConflict() async throws {
        let mockSession = MockBackupURLSession()
        let mockAttestation = MockBackupAttestationManager(isSupported: false)
        let client = BackupAPIClient(
            session: mockSession,
            baseURL: URL(string: "https://api.example.com")!,
            attestationManager: mockAttestation
        )

        mockSession.nextResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com/api/v1/backup/register")!,
            statusCode: 409,
            httpVersion: nil,
            headerFields: nil
        )
        mockSession.nextData = Data()

        await #expect(throws: BackupAPIError.self) {
            try await client.registerBackupKey("ABC-DEF-GHJ", publicKey: Data(count: 32))
        }
    }

    @Test("Should throw unauthorized error on 401")
    func testRegisterUnauthorized() async throws {
        let mockSession = MockBackupURLSession()
        let mockAttestation = MockBackupAttestationManager(isSupported: false)
        let client = BackupAPIClient(
            session: mockSession,
            baseURL: URL(string: "https://api.example.com")!,
            attestationManager: mockAttestation
        )

        mockSession.nextResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com/api/v1/backup/register")!,
            statusCode: 401,
            httpVersion: nil,
            headerFields: nil
        )
        mockSession.nextData = Data()

        await #expect(throws: BackupAPIError.self) {
            try await client.registerBackupKey("ABC-DEF-GHJ", publicKey: Data(count: 32))
        }
    }

    @Test("Should throw rate limit error on 429")
    func testRegisterRateLimited() async throws {
        let mockSession = MockBackupURLSession()
        let mockAttestation = MockBackupAttestationManager(isSupported: false)
        let client = BackupAPIClient(
            session: mockSession,
            baseURL: URL(string: "https://api.example.com")!,
            attestationManager: mockAttestation
        )

        let resetDate = ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600))
        let responseJSON = ["resetAt": resetDate]
        let responseData = try JSONSerialization.data(withJSONObject: responseJSON)

        mockSession.nextResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com/api/v1/backup/register")!,
            statusCode: 429,
            httpVersion: nil,
            headerFields: nil
        )
        mockSession.nextData = responseData

        await #expect(throws: BackupAPIError.self) {
            try await client.registerBackupKey("ABC-DEF-GHJ", publicKey: Data(count: 32))
        }
    }

    // MARK: - Upload Backup Tests

    @Test("Should upload backup successfully")
    func testUploadBackup() async throws {
        let mockSession = MockBackupURLSession()
        let mockAttestation = MockBackupAttestationManager(isSupported: false)
        let client = BackupAPIClient(
            session: mockSession,
            baseURL: URL(string: "https://api.example.com")!,
            attestationManager: mockAttestation
        )

        let responseJSON: [String: Any] = [
            "message": "Backup created",
            "timestamp": "2025-01-01T00:00:00Z",
            "backupCount": 1
        ]
        let responseData = try JSONSerialization.data(withJSONObject: responseJSON)

        mockSession.nextResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com/api/v1/backup/ABC-DEF-GHJ")!,
            statusCode: 201,
            httpVersion: nil,
            headerFields: nil
        )
        mockSession.nextData = responseData

        let result = try await client.uploadBackup(
            backupKey: "ABC-DEF-GHJ",
            type: "inventory",
            data: "base64data",
            checksum: "checksum123",
            ownershipSignature: Data([0x01, 0x02, 0x03])
        )

        #expect(result.skipped == false)
        #expect(result.timestamp == "2025-01-01T00:00:00Z")
    }

    @Test("Should include ownership signature header in upload request")
    func testUploadIncludesOwnershipSignature() async throws {
        let mockSession = MockBackupURLSession()
        let mockAttestation = MockBackupAttestationManager(isSupported: false)
        let client = BackupAPIClient(
            session: mockSession,
            baseURL: URL(string: "https://api.example.com")!,
            attestationManager: mockAttestation
        )

        let signature = Data([0x01, 0x02, 0x03, 0x04])

        let responseJSON: [String: Any] = ["timestamp": "2025-01-01T00:00:00Z"]
        let responseData = try JSONSerialization.data(withJSONObject: responseJSON)

        mockSession.nextResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com/api/v1/backup/ABC-DEF-GHJ")!,
            statusCode: 201,
            httpVersion: nil,
            headerFields: nil
        )
        mockSession.nextData = responseData

        _ = try await client.uploadBackup(
            backupKey: "ABC-DEF-GHJ",
            type: "inventory",
            data: "base64data",
            checksum: "checksum123",
            ownershipSignature: signature
        )

        let signatureHeader = mockSession.lastRequest?.value(forHTTPHeaderField: "X-Ownership-Signature")
        #expect(signatureHeader == signature.base64EncodedString())
    }

    @Test("Should handle skipped upload response")
    func testUploadSkipped() async throws {
        let mockSession = MockBackupURLSession()
        let mockAttestation = MockBackupAttestationManager(isSupported: false)
        let client = BackupAPIClient(
            session: mockSession,
            baseURL: URL(string: "https://api.example.com")!,
            attestationManager: mockAttestation
        )

        let responseJSON: [String: Any] = [
            "message": "Backup unchanged",
            "skipped": true,
            "latestTimestamp": "2025-01-01T00:00:00Z"
        ]
        let responseData = try JSONSerialization.data(withJSONObject: responseJSON)

        mockSession.nextResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com/api/v1/backup/ABC-DEF-GHJ")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        mockSession.nextData = responseData

        let result = try await client.uploadBackup(
            backupKey: "ABC-DEF-GHJ",
            type: "inventory",
            data: "base64data",
            checksum: "checksum123",
            ownershipSignature: Data()
        )

        #expect(result.skipped == true)
        #expect(result.timestamp == "2025-01-01T00:00:00Z")
    }

    @Test("Should throw not found error on upload 404")
    func testUploadNotFound() async throws {
        let mockSession = MockBackupURLSession()
        let mockAttestation = MockBackupAttestationManager(isSupported: false)
        let client = BackupAPIClient(
            session: mockSession,
            baseURL: URL(string: "https://api.example.com")!,
            attestationManager: mockAttestation
        )

        mockSession.nextResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com/api/v1/backup/ABC-DEF-GHJ")!,
            statusCode: 404,
            httpVersion: nil,
            headerFields: nil
        )
        mockSession.nextData = Data()

        await #expect(throws: BackupAPIError.self) {
            try await client.uploadBackup(
                backupKey: "ABC-DEF-GHJ",
                type: "inventory",
                data: "base64data",
                checksum: "checksum123",
                ownershipSignature: Data()
            )
        }
    }

    // MARK: - Download Backup Tests

    @Test("Should download backup successfully")
    func testDownloadBackup() async throws {
        let mockSession = MockBackupURLSession()
        let mockAttestation = MockBackupAttestationManager(isSupported: false)
        let client = BackupAPIClient(
            session: mockSession,
            baseURL: URL(string: "https://api.example.com")!,
            attestationManager: mockAttestation
        )

        let responseJSON: [String: Any] = [
            "data": "base64encodeddata",
            "checksum": "abc123",
            "timestamp": "2025-01-01T00:00:00Z",
            "backupCount": 5
        ]
        let responseData = try JSONSerialization.data(withJSONObject: responseJSON)

        mockSession.nextResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com/api/v1/backup/ABC-DEF-GHJ?type=inventory")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        mockSession.nextData = responseData

        let result = try await client.downloadBackup(backupKey: "ABC-DEF-GHJ", type: "inventory")

        #expect(result.data == "base64encodeddata")
        #expect(result.checksum == "abc123")
        #expect(result.timestamp == "2025-01-01T00:00:00Z")
        #expect(result.backupCount == 5)
    }

    @Test("Should use GET method for download")
    func testDownloadUsesGET() async throws {
        let mockSession = MockBackupURLSession()
        let mockAttestation = MockBackupAttestationManager(isSupported: false)
        let client = BackupAPIClient(
            session: mockSession,
            baseURL: URL(string: "https://api.example.com")!,
            attestationManager: mockAttestation
        )

        let responseJSON: [String: Any] = [
            "data": "base64data",
            "checksum": "abc",
            "timestamp": "2025-01-01T00:00:00Z"
        ]
        let responseData = try JSONSerialization.data(withJSONObject: responseJSON)

        mockSession.nextResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com/api/v1/backup/ABC-DEF-GHJ?type=inventory")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        mockSession.nextData = responseData

        _ = try await client.downloadBackup(backupKey: "ABC-DEF-GHJ", type: "inventory")

        #expect(mockSession.lastRequest?.httpMethod == "GET")
    }

    @Test("Should include type query parameter in download request")
    func testDownloadIncludesTypeParameter() async throws {
        let mockSession = MockBackupURLSession()
        let mockAttestation = MockBackupAttestationManager(isSupported: false)
        let client = BackupAPIClient(
            session: mockSession,
            baseURL: URL(string: "https://api.example.com")!,
            attestationManager: mockAttestation
        )

        let responseJSON: [String: Any] = [
            "data": "base64data",
            "checksum": "abc",
            "timestamp": "2025-01-01T00:00:00Z"
        ]
        let responseData = try JSONSerialization.data(withJSONObject: responseJSON)

        mockSession.nextResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com/api/v1/backup/ABC-DEF-GHJ?type=inventory")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        mockSession.nextData = responseData

        _ = try await client.downloadBackup(backupKey: "ABC-DEF-GHJ", type: "inventory")

        let url = mockSession.lastRequest?.url
        #expect(url?.query?.contains("type=inventory") == true)
    }

    @Test("Should throw not found error on download 404")
    func testDownloadNotFound() async throws {
        let mockSession = MockBackupURLSession()
        let mockAttestation = MockBackupAttestationManager(isSupported: false)
        let client = BackupAPIClient(
            session: mockSession,
            baseURL: URL(string: "https://api.example.com")!,
            attestationManager: mockAttestation
        )

        mockSession.nextResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com/api/v1/backup/ABC-DEF-GHJ?type=inventory")!,
            statusCode: 404,
            httpVersion: nil,
            headerFields: nil
        )
        mockSession.nextData = Data()

        await #expect(throws: BackupAPIError.self) {
            try await client.downloadBackup(backupKey: "ABC-DEF-GHJ", type: "inventory")
        }
    }

    @Test("Should throw invalid data error on malformed response")
    func testDownloadInvalidData() async throws {
        let mockSession = MockBackupURLSession()
        let mockAttestation = MockBackupAttestationManager(isSupported: false)
        let client = BackupAPIClient(
            session: mockSession,
            baseURL: URL(string: "https://api.example.com")!,
            attestationManager: mockAttestation
        )

        // Missing required fields
        let responseJSON: [String: Any] = ["data": "base64data"]
        let responseData = try JSONSerialization.data(withJSONObject: responseJSON)

        mockSession.nextResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com/api/v1/backup/ABC-DEF-GHJ?type=inventory")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        mockSession.nextData = responseData

        await #expect(throws: BackupAPIError.self) {
            try await client.downloadBackup(backupKey: "ABC-DEF-GHJ", type: "inventory")
        }
    }

    // MARK: - Network Error Tests

    @Test("Should wrap network errors")
    func testNetworkError() async throws {
        let mockSession = MockBackupURLSession()
        let mockAttestation = MockBackupAttestationManager(isSupported: false)
        let client = BackupAPIClient(
            session: mockSession,
            baseURL: URL(string: "https://api.example.com")!,
            attestationManager: mockAttestation
        )

        mockSession.nextError = URLError(.notConnectedToInternet)

        await #expect(throws: BackupAPIError.self) {
            try await client.registerBackupKey("ABC-DEF-GHJ", publicKey: Data(count: 32))
        }
    }

    // MARK: - Attestation Tests

    @Test("Should add attestation header when supported")
    func testAttestationHeader() async throws {
        let mockSession = MockBackupURLSession()
        let mockAttestation = MockBackupAttestationManager(isSupported: true)
        let client = BackupAPIClient(
            session: mockSession,
            baseURL: URL(string: "https://api.example.com")!,
            attestationManager: mockAttestation
        )

        mockSession.nextResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com/api/v1/backup/register")!,
            statusCode: 201,
            httpVersion: nil,
            headerFields: nil
        )
        mockSession.nextData = Data()

        try await client.registerBackupKey("ABC-DEF-GHJ", publicKey: Data(count: 32))

        let attestationHeader = mockSession.lastRequest?.value(forHTTPHeaderField: "X-Apple-Assertion")
        #expect(attestationHeader != nil)
    }

    @Test("Should skip attestation when not supported")
    func testSkipAttestationWhenNotSupported() async throws {
        let mockSession = MockBackupURLSession()
        let mockAttestation = MockBackupAttestationManager(isSupported: false)
        let client = BackupAPIClient(
            session: mockSession,
            baseURL: URL(string: "https://api.example.com")!,
            attestationManager: mockAttestation
        )

        mockSession.nextResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com/api/v1/backup/register")!,
            statusCode: 201,
            httpVersion: nil,
            headerFields: nil
        )
        mockSession.nextData = Data()

        try await client.registerBackupKey("ABC-DEF-GHJ", publicKey: Data(count: 32))

        let attestationHeader = mockSession.lastRequest?.value(forHTTPHeaderField: "X-Apple-Assertion")
        #expect(attestationHeader == nil)
    }
}

// MARK: - Mock Classes

class MockBackupURLSession: URLSessionProtocol {
    var nextData: Data?
    var nextResponse: URLResponse?
    var nextError: Error?
    var lastRequest: URLRequest?
    var lastRequestBody: Data?

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        lastRequestBody = request.httpBody

        if let error = nextError {
            throw error
        }

        guard let response = nextResponse else {
            throw URLError(.badServerResponse)
        }

        return (nextData ?? Data(), response)
    }
}

class MockBackupAttestationManager: AttestationManager {
    private let _isSupported: Bool

    init(isSupported: Bool) {
        self._isSupported = isSupported
        super.init()
    }

    override var isSupported: Bool {
        return _isSupported
    }

    override func generateAssertion(requestData: Data) async throws -> Data {
        return Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08])
    }
}
