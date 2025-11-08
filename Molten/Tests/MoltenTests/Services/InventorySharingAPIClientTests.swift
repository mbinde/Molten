//
//  InventorySharingAPIClientTests.swift
//  MoltenTests
//
//  Tests for InventorySharingAPIClient - handles server communication for inventory sharing
//  Uploads and downloads signed inventory snapshots with share codes
//

import Testing
import Foundation
@testable import Molten

@Suite("InventorySharingAPIClient Tests")
@MainActor
struct InventorySharingAPIClientTests {

    // MARK: - Upload Tests

    @Test("Should upload snapshot with share code")
    func testUploadSnapshot() async throws {
        let mockSession = MockURLSession()
        let client = InventorySharingAPIClient(session: mockSession)

        let shareCode = "A7B2X9"
        let snapshotData = Data([0x01, 0x02, 0x03, 0x04])
        let publicKey = Data(count: 32)

        // Configure mock to succeed
        mockSession.nextResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com/share")!,
            statusCode: 201,
            httpVersion: nil,
            headerFields: nil
        )
        mockSession.nextData = Data()

        try await client.uploadSnapshot(
            shareCode: shareCode,
            snapshotData: snapshotData,
            publicKey: publicKey
        )

        // Verify request was made
        #expect(mockSession.lastRequest != nil)
        #expect(mockSession.lastRequest?.httpMethod == "POST")
    }

    @Test("Should include share code in upload request")
    func testUploadIncludesShareCode() async throws {
        let mockSession = MockURLSession()
        let client = InventorySharingAPIClient(session: mockSession)

        let shareCode = "A7B2X9"
        let snapshotData = Data([0x01, 0x02, 0x03])
        let publicKey = Data(count: 32)

        mockSession.nextResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com/share")!,
            statusCode: 201,
            httpVersion: nil,
            headerFields: nil
        )
        mockSession.nextData = Data()

        try await client.uploadSnapshot(
            shareCode: shareCode,
            snapshotData: snapshotData,
            publicKey: publicKey
        )

        // Verify request body contains share code
        let requestBody = mockSession.lastRequestBody
        #expect(requestBody != nil)

        if let bodyData = requestBody {
            let json = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
            #expect(json?["shareCode"] as? String == shareCode)
        }
    }

    @Test("Should throw error on upload failure")
    func testUploadFailure() async throws {
        let mockSession = MockURLSession()
        let client = InventorySharingAPIClient(session: mockSession)

        let shareCode = "A7B2X9"
        let snapshotData = Data([0x01, 0x02, 0x03])
        let publicKey = Data(count: 32)

        // Configure mock to fail
        mockSession.nextResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com/share")!,
            statusCode: 500,
            httpVersion: nil,
            headerFields: nil
        )
        mockSession.nextData = Data()

        await #expect(throws: SharingAPIError.self) {
            try await client.uploadSnapshot(
                shareCode: shareCode,
                snapshotData: snapshotData,
                publicKey: publicKey
            )
        }
    }

    @Test("Should throw error when share code already exists")
    func testUploadConflict() async throws {
        let mockSession = MockURLSession()
        let client = InventorySharingAPIClient(session: mockSession)

        let shareCode = "A7B2X9"
        let snapshotData = Data([0x01, 0x02, 0x03])
        let publicKey = Data(count: 32)

        // Configure mock to return conflict
        mockSession.nextResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com/share")!,
            statusCode: 409,
            httpVersion: nil,
            headerFields: nil
        )
        mockSession.nextData = Data()

        await #expect(throws: SharingAPIError.self) {
            try await client.uploadSnapshot(
                shareCode: shareCode,
                snapshotData: snapshotData,
                publicKey: publicKey
            )
        }
    }

    // MARK: - Download Tests

    @Test("Should download snapshot by share code")
    func testDownloadSnapshot() async throws {
        let mockSession = MockURLSession()
        let client = InventorySharingAPIClient(session: mockSession)

        let shareCode = "A7B2X9"
        let expectedSnapshotData = Data([0x01, 0x02, 0x03, 0x04])
        let expectedPublicKey = Data(count: 32)

        // Configure mock response
        let responseJSON: [String: Any] = [
            "snapshotData": expectedSnapshotData.base64EncodedString(),
            "publicKey": expectedPublicKey.base64EncodedString()
        ]
        let responseData = try JSONSerialization.data(withJSONObject: responseJSON)

        mockSession.nextResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com/share/\(shareCode)")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        mockSession.nextData = responseData

        let result = try await client.downloadSnapshot(shareCode: shareCode)

        #expect(result.snapshotData == expectedSnapshotData)
        #expect(result.publicKey == expectedPublicKey)
    }

    @Test("Should use GET method for download")
    func testDownloadUsesGET() async throws {
        let mockSession = MockURLSession()
        let client = InventorySharingAPIClient(session: mockSession)

        let shareCode = "A7B2X9"

        let responseJSON: [String: Any] = [
            "snapshotData": Data([0x01]).base64EncodedString(),
            "publicKey": Data(count: 32).base64EncodedString()
        ]
        let responseData = try JSONSerialization.data(withJSONObject: responseJSON)

        mockSession.nextResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com/share/\(shareCode)")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        mockSession.nextData = responseData

        _ = try await client.downloadSnapshot(shareCode: shareCode)

        #expect(mockSession.lastRequest?.httpMethod == "GET")
    }

    @Test("Should throw error when share code not found")
    func testDownloadNotFound() async throws {
        let mockSession = MockURLSession()
        let client = InventorySharingAPIClient(session: mockSession)

        let shareCode = "NOTFND"

        mockSession.nextResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com/share/\(shareCode)")!,
            statusCode: 404,
            httpVersion: nil,
            headerFields: nil
        )
        mockSession.nextData = Data()

        await #expect(throws: SharingAPIError.self) {
            _ = try await client.downloadSnapshot(shareCode: shareCode)
        }
    }

    @Test("Should throw error on download network failure")
    func testDownloadNetworkFailure() async throws {
        let mockSession = MockURLSession()
        let client = InventorySharingAPIClient(session: mockSession)

        let shareCode = "A7B2X9"

        mockSession.nextError = URLError(.notConnectedToInternet)

        await #expect(throws: SharingAPIError.self) {
            _ = try await client.downloadSnapshot(shareCode: shareCode)
        }
    }

    // MARK: - Delete Tests

    @Test("Should delete share by code")
    func testDeleteShare() async throws {
        let mockSession = MockURLSession()
        let client = InventorySharingAPIClient(session: mockSession)

        let shareCode = "A7B2X9"

        mockSession.nextResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com/share/\(shareCode)")!,
            statusCode: 204,
            httpVersion: nil,
            headerFields: nil
        )
        mockSession.nextData = Data()

        let ownershipSignature = Data(count: 64) // Mock signature

        try await client.deleteShare(shareCode: shareCode, ownershipSignature: ownershipSignature)

        #expect(mockSession.lastRequest?.httpMethod == "DELETE")
    }

    @Test("Should throw error when deleting non-existent share")
    func testDeleteNotFound() async throws {
        let mockSession = MockURLSession()
        let client = InventorySharingAPIClient(session: mockSession)

        let shareCode = "NOTFND"

        mockSession.nextResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com/share/\(shareCode)")!,
            statusCode: 404,
            httpVersion: nil,
            headerFields: nil
        )
        mockSession.nextData = Data()

        let ownershipSignature = Data(count: 64) // Mock signature

        await #expect(throws: SharingAPIError.self) {
            try await client.deleteShare(shareCode: shareCode, ownershipSignature: ownershipSignature)
        }
    }

    // MARK: - Update Tests

    @Test("Should update existing share")
    func testUpdateShare() async throws {
        let mockSession = MockURLSession()
        let client = InventorySharingAPIClient(session: mockSession)

        let shareCode = "A7B2X9"
        let snapshotData = Data([0x01, 0x02, 0x03, 0x04])
        let publicKey = Data(count: 32)

        mockSession.nextResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com/share/\(shareCode)")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        mockSession.nextData = Data()

        let ownershipSignature = Data(count: 64) // Mock signature

        try await client.updateSnapshot(
            shareCode: shareCode,
            snapshotData: snapshotData,
            publicKey: publicKey,
            ownershipSignature: ownershipSignature
        )

        #expect(mockSession.lastRequest?.httpMethod == "PUT")
    }

    @Test("Should throw error when updating non-existent share")
    func testUpdateNotFound() async throws {
        let mockSession = MockURLSession()
        let client = InventorySharingAPIClient(session: mockSession)

        let shareCode = "NOTFND"
        let snapshotData = Data([0x01, 0x02, 0x03])
        let publicKey = Data(count: 32)

        mockSession.nextResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com/share/\(shareCode)")!,
            statusCode: 404,
            httpVersion: nil,
            headerFields: nil
        )
        mockSession.nextData = Data()

        let ownershipSignature = Data(count: 64) // Mock signature

        await #expect(throws: SharingAPIError.self) {
            try await client.updateSnapshot(
                shareCode: shareCode,
                snapshotData: snapshotData,
                publicKey: publicKey,
                ownershipSignature: ownershipSignature
            )
        }
    }
}

// MARK: - Mock URLSession

/// Mock URLSession for testing
class MockURLSession: URLSessionProtocol {
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
