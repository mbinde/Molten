//
//  ReceiptAPIClientTests.swift
//  MoltenTests
//
//  Tests for ReceiptAPIClient - API client for receipt import operations
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

@Suite("ReceiptAPIClient Tests")
@MainActor
struct ReceiptAPIClientTests {

    // MARK: - Test Helpers

    private func createTestClient(
        session: MockReceiptURLSession = MockReceiptURLSession(),
        attestationManager: AttestationManagerProtocol = MockReceiptAttestationManager()
    ) -> ReceiptAPIClient {
        return ReceiptAPIClient(
            session: session,
            baseURL: URL(string: "https://api.example.com")!,
            attestationManager: attestationManager
        )
    }

    // MARK: - Register Tests

    @Test("Should register with public key and return response")
    func testRegisterSuccess() async throws {
        let mockSession = MockReceiptURLSession()
        mockSession.responseData = """
        {
            "user_id": "test-user-123",
            "plus_key": "abc123",
            "forwarding_email": "receipts+abc123@example.com"
        }
        """.data(using: .utf8)!
        mockSession.statusCode = 201

        let client = createTestClient(session: mockSession)
        let publicKey = Data([0x01, 0x02, 0x03, 0x04])

        let response = try await client.register(publicKey: publicKey)

        #expect(response.userId == "test-user-123")
        #expect(response.plusKey == "abc123")
        #expect(response.forwardingEmail == "receipts+abc123@example.com")
    }

    @Test("Should throw conflict error on 409")
    func testRegisterConflict() async throws {
        let mockSession = MockReceiptURLSession()
        mockSession.statusCode = 409

        let client = createTestClient(session: mockSession)
        let publicKey = Data([0x01, 0x02, 0x03, 0x04])

        await #expect(throws: ReceiptAPIError.self) {
            _ = try await client.register(publicKey: publicKey)
        }
    }

    @Test("Should throw unauthorized error on 401")
    func testRegisterUnauthorized() async throws {
        let mockSession = MockReceiptURLSession()
        mockSession.statusCode = 401

        let client = createTestClient(session: mockSession)
        let publicKey = Data([0x01, 0x02, 0x03, 0x04])

        await #expect(throws: ReceiptAPIError.self) {
            _ = try await client.register(publicKey: publicKey)
        }
    }

    @Test("Should throw rate limit error on 429")
    func testRegisterRateLimited() async throws {
        let mockSession = MockReceiptURLSession()
        mockSession.statusCode = 429
        mockSession.responseData = """
        {
            "error": "rate_limited",
            "resetAt": "2025-01-01T00:00:00Z"
        }
        """.data(using: .utf8)!

        let client = createTestClient(session: mockSession)
        let publicKey = Data([0x01, 0x02, 0x03, 0x04])

        await #expect(throws: ReceiptAPIError.self) {
            _ = try await client.register(publicKey: publicKey)
        }
    }

    // MARK: - List Receipts Tests

    @Test("Should list receipts successfully")
    func testListReceiptsSuccess() async throws {
        let mockSession = MockReceiptURLSession()
        mockSession.responseData = """
        {
            "receipts": [
                {
                    "id": "receipt-1",
                    "retailer_id": "costco",
                    "retailer_name": "Costco",
                    "order_number": "12345",
                    "order_date": "2025-01-15",
                    "total_amount": 99.99,
                    "item_count": 5,
                    "status": "parsed",
                    "acknowledged": false,
                    "received_at": "2025-01-15T10:30:00Z",
                    "parsed_at": "2025-01-15T10:31:00Z"
                }
            ],
            "total": 1,
            "offset": 0,
            "limit": 50
        }
        """.data(using: .utf8)!
        mockSession.statusCode = 200

        let client = createTestClient(session: mockSession)
        let signature = Data([0x01, 0x02])

        let response = try await client.listReceipts(
            userId: "test-user",
            ownershipSignature: signature
        )

        #expect(response.receipts.count == 1)
        #expect(response.receipts[0].id == "receipt-1")
        #expect(response.receipts[0].retailerId == "costco")
        #expect(response.receipts[0].retailerName == "Costco")
        #expect(response.receipts[0].itemCount == 5)
        #expect(response.total == 1)
    }

    @Test("Should handle empty receipts list")
    func testListReceiptsEmpty() async throws {
        let mockSession = MockReceiptURLSession()
        mockSession.responseData = """
        {
            "receipts": [],
            "total": 0,
            "offset": 0,
            "limit": 50
        }
        """.data(using: .utf8)!
        mockSession.statusCode = 200

        let client = createTestClient(session: mockSession)
        let signature = Data([0x01, 0x02])

        let response = try await client.listReceipts(
            userId: "test-user",
            ownershipSignature: signature
        )

        #expect(response.receipts.isEmpty)
        #expect(response.total == 0)
    }

    // MARK: - Get Receipt Detail Tests

    @Test("Should get receipt detail successfully")
    func testGetReceiptSuccess() async throws {
        let mockSession = MockReceiptURLSession()
        mockSession.responseData = """
        {
            "id": "receipt-1",
            "retailer_id": "costco",
            "retailer_name": "Costco",
            "sender_email": "orders@costco.com",
            "subject": "Your Costco Order",
            "order_number": "12345",
            "order_date": "2025-01-15",
            "total_amount": 99.99,
            "status": "parsed",
            "acknowledged": false,
            "received_at": "2025-01-15T10:30:00Z",
            "parsed_at": "2025-01-15T10:31:00Z",
            "items": [
                {
                    "id": 1,
                    "raw_sku": "SKU123",
                    "raw_name": "Test Item",
                    "quantity": 2,
                    "unit_price": 10.00,
                    "total_price": 20.00,
                    "catalog_stable_id": "abc123",
                    "match_confidence": 0.95,
                    "match_method": "sku_exact"
                }
            ]
        }
        """.data(using: .utf8)!
        mockSession.statusCode = 200

        let client = createTestClient(session: mockSession)
        let signature = Data([0x01, 0x02])

        let receipt = try await client.getReceipt(
            receiptId: "receipt-1",
            userId: "test-user",
            ownershipSignature: signature
        )

        #expect(receipt.id == "receipt-1")
        #expect(receipt.retailerId == "costco")
        #expect(receipt.items.count == 1)
        #expect(receipt.items[0].rawName == "Test Item")
        #expect(receipt.items[0].catalogStableId == "abc123")
        #expect(receipt.items[0].matchConfidence == 0.95)
    }

    @Test("Should throw not found error on 404")
    func testGetReceiptNotFound() async throws {
        let mockSession = MockReceiptURLSession()
        mockSession.statusCode = 404

        let client = createTestClient(session: mockSession)
        let signature = Data([0x01, 0x02])

        await #expect(throws: ReceiptAPIError.self) {
            _ = try await client.getReceipt(
                receiptId: "nonexistent",
                userId: "test-user",
                ownershipSignature: signature
            )
        }
    }

    // MARK: - Acknowledge Receipt Tests

    @Test("Should acknowledge receipt successfully")
    func testAcknowledgeReceiptSuccess() async throws {
        let mockSession = MockReceiptURLSession()
        mockSession.statusCode = 200

        let client = createTestClient(session: mockSession)
        let signature = Data([0x01, 0x02])

        // Should not throw
        try await client.acknowledgeReceipt(
            receiptId: "receipt-1",
            userId: "test-user",
            ownershipSignature: signature
        )
    }

    @Test("Should throw not found when acknowledging nonexistent receipt")
    func testAcknowledgeReceiptNotFound() async throws {
        let mockSession = MockReceiptURLSession()
        mockSession.statusCode = 404

        let client = createTestClient(session: mockSession)
        let signature = Data([0x01, 0x02])

        await #expect(throws: ReceiptAPIError.self) {
            try await client.acknowledgeReceipt(
                receiptId: "nonexistent",
                userId: "test-user",
                ownershipSignature: signature
            )
        }
    }

    // MARK: - Network Error Tests

    @Test("Should wrap network errors")
    func testNetworkError() async throws {
        let mockSession = MockReceiptURLSession()
        mockSession.shouldThrowNetworkError = true

        let client = createTestClient(session: mockSession)
        let publicKey = Data([0x01, 0x02, 0x03, 0x04])

        await #expect(throws: ReceiptAPIError.self) {
            _ = try await client.register(publicKey: publicKey)
        }
    }
}

// MARK: - Mock Classes

class MockReceiptURLSession: URLSessionProtocol {
    var responseData = Data()
    var statusCode = 200
    var shouldThrowNetworkError = false

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        if shouldThrowNetworkError {
            throw URLError(.notConnectedToInternet)
        }
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (responseData, response)
    }

    func download(for request: URLRequest, delegate: (any URLSessionTaskDelegate)?) async throws -> (URL, URLResponse) {
        throw URLError(.unsupportedURL)
    }
}

class MockReceiptAttestationManager: AttestationManagerProtocol {
    var isSupported: Bool { false }

    func generateKeyId() async throws -> String {
        throw AttestationError.unsupported
    }

    func attestKey(keyId: String) async throws -> Data {
        throw AttestationError.unsupported
    }

    func generateAssertion(requestData: Data) async throws -> Data {
        throw AttestationError.noKeyExists
    }

    func createRequestData(method: String, path: String, body: Data?) -> Data {
        return Data()
    }
}
