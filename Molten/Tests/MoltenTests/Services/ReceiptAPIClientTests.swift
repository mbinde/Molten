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

    // MARK: - Delete Receipt Tests

    @Test("Should delete receipt successfully")
    func testDeleteReceiptSuccess() async throws {
        let mockSession = MockReceiptURLSession()
        mockSession.statusCode = 200

        let client = createTestClient(session: mockSession)
        let signature = Data([0x01, 0x02])

        // Should not throw
        try await client.deleteReceipt(
            receiptId: "receipt-1",
            userId: "test-user",
            ownershipSignature: signature
        )
    }

    @Test("Should throw not found when deleting nonexistent receipt")
    func testDeleteReceiptNotFound() async throws {
        let mockSession = MockReceiptURLSession()
        mockSession.statusCode = 404

        let client = createTestClient(session: mockSession)
        let signature = Data([0x01, 0x02])

        await #expect(throws: ReceiptAPIError.self) {
            try await client.deleteReceipt(
                receiptId: "nonexistent",
                userId: "test-user",
                ownershipSignature: signature
            )
        }
    }

    // MARK: - Get Receipt Email Tests

    @Test("Should get receipt email body successfully")
    func testGetReceiptEmailSuccess() async throws {
        let mockSession = MockReceiptURLSession()
        mockSession.responseData = """
        {
            "email_body": "This is the original email body content"
        }
        """.data(using: .utf8)!
        mockSession.statusCode = 200

        let client = createTestClient(session: mockSession)
        let signature = Data([0x01, 0x02])

        let emailBody = try await client.getReceiptEmail(
            receiptId: "receipt-1",
            userId: "test-user",
            ownershipSignature: signature
        )

        #expect(emailBody == "This is the original email body content")
    }

    @Test("Should throw not found when getting email for nonexistent receipt")
    func testGetReceiptEmailNotFound() async throws {
        let mockSession = MockReceiptURLSession()
        mockSession.statusCode = 404

        let client = createTestClient(session: mockSession)
        let signature = Data([0x01, 0x02])

        await #expect(throws: ReceiptAPIError.self) {
            _ = try await client.getReceiptEmail(
                receiptId: "nonexistent",
                userId: "test-user",
                ownershipSignature: signature
            )
        }
    }

    // MARK: - Add Email Identifier Tests

    @Test("Should add email identifier successfully")
    func testAddEmailIdentifierSuccess() async throws {
        let mockSession = MockReceiptURLSession()
        mockSession.responseData = """
        {
            "type": "email",
            "identifier": "user@example.com",
            "verified": false,
            "message": "Verification email sent"
        }
        """.data(using: .utf8)!
        mockSession.statusCode = 201

        let client = createTestClient(session: mockSession)
        let signature = Data([0x01, 0x02])

        let response = try await client.addEmailIdentifier(
            email: "user@example.com",
            userId: "test-user",
            ownershipSignature: signature
        )

        #expect(response.type == "email")
        #expect(response.identifier == "user@example.com")
        #expect(response.verified == false)
    }

    @Test("Should throw conflict when email already registered")
    func testAddEmailIdentifierConflict() async throws {
        let mockSession = MockReceiptURLSession()
        mockSession.statusCode = 409

        let client = createTestClient(session: mockSession)
        let signature = Data([0x01, 0x02])

        await #expect(throws: ReceiptAPIError.self) {
            _ = try await client.addEmailIdentifier(
                email: "existing@example.com",
                userId: "test-user",
                ownershipSignature: signature
            )
        }
    }

    // MARK: - Check Email Status Tests

    @Test("Should check email status successfully")
    func testCheckEmailStatusSuccess() async throws {
        let mockSession = MockReceiptURLSession()
        mockSession.responseData = """
        {
            "hasEmail": true,
            "verified": true
        }
        """.data(using: .utf8)!
        mockSession.statusCode = 200

        let client = createTestClient(session: mockSession)
        let signature = Data([0x01, 0x02])

        let response = try await client.checkEmailStatus(
            userId: "test-user",
            ownershipSignature: signature
        )

        #expect(response.hasEmail == true)
        #expect(response.verified == true)
    }

    @Test("Should return not verified when email pending")
    func testCheckEmailStatusPending() async throws {
        let mockSession = MockReceiptURLSession()
        mockSession.responseData = """
        {
            "hasEmail": true,
            "verified": false
        }
        """.data(using: .utf8)!
        mockSession.statusCode = 200

        let client = createTestClient(session: mockSession)
        let signature = Data([0x01, 0x02])

        let response = try await client.checkEmailStatus(
            userId: "test-user",
            ownershipSignature: signature
        )

        #expect(response.hasEmail == true)
        #expect(response.verified == false)
    }

    // MARK: - Account Recovery Tests

    @Test("Should request recovery successfully")
    func testRequestRecoverySuccess() async throws {
        let mockSession = MockReceiptURLSession()
        mockSession.responseData = """
        {
            "message": "If the email is registered, a recovery link has been sent."
        }
        """.data(using: .utf8)!
        mockSession.statusCode = 200

        let client = createTestClient(session: mockSession)
        let newPublicKey = Data([0x01, 0x02, 0x03, 0x04])

        let response = try await client.requestRecovery(
            email: "user@example.com",
            newPublicKey: newPublicKey
        )

        #expect(response.message.contains("recovery"))
    }

    @Test("Should throw bad request for unverified email")
    func testRequestRecoveryUnverifiedEmail() async throws {
        let mockSession = MockReceiptURLSession()
        mockSession.responseData = """
        {
            "error": "Email is not verified"
        }
        """.data(using: .utf8)!
        mockSession.statusCode = 400

        let client = createTestClient(session: mockSession)
        let newPublicKey = Data([0x01, 0x02, 0x03, 0x04])

        await #expect(throws: ReceiptAPIError.self) {
            _ = try await client.requestRecovery(
                email: "unverified@example.com",
                newPublicKey: newPublicKey
            )
        }
    }

    @Test("Should check recovery status successfully")
    func testCheckRecoveryStatusSuccess() async throws {
        let mockSession = MockReceiptURLSession()
        mockSession.responseData = """
        {
            "recovered": true,
            "userId": "recovered-user-123"
        }
        """.data(using: .utf8)!
        mockSession.statusCode = 200

        let client = createTestClient(session: mockSession)
        let publicKey = Data([0x01, 0x02, 0x03, 0x04])

        let response = try await client.checkRecoveryStatus(
            email: "user@example.com",
            publicKey: publicKey
        )

        #expect(response.recovered == true)
        #expect(response.userId == "recovered-user-123")
    }

    @Test("Should return not recovered when pending")
    func testCheckRecoveryStatusPending() async throws {
        let mockSession = MockReceiptURLSession()
        mockSession.responseData = """
        {
            "recovered": false,
            "reason": "User has not clicked recovery link"
        }
        """.data(using: .utf8)!
        mockSession.statusCode = 200

        let client = createTestClient(session: mockSession)
        let publicKey = Data([0x01, 0x02, 0x03, 0x04])

        let response = try await client.checkRecoveryStatus(
            email: "user@example.com",
            publicKey: publicKey
        )

        #expect(response.recovered == false)
        #expect(response.reason == "User has not clicked recovery link")
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

    // MARK: - Server Error Tests

    @Test("Should throw server error on 500")
    func testServerError() async throws {
        let mockSession = MockReceiptURLSession()
        mockSession.statusCode = 500

        let client = createTestClient(session: mockSession)
        let signature = Data([0x01, 0x02])

        await #expect(throws: ReceiptAPIError.self) {
            _ = try await client.listReceipts(
                userId: "test-user",
                ownershipSignature: signature
            )
        }
    }

    @Test("Should throw unauthorized on 403")
    func testForbiddenError() async throws {
        let mockSession = MockReceiptURLSession()
        mockSession.statusCode = 403

        let client = createTestClient(session: mockSession)
        let signature = Data([0x01, 0x02])

        await #expect(throws: ReceiptAPIError.self) {
            _ = try await client.getReceipt(
                receiptId: "receipt-1",
                userId: "test-user",
                ownershipSignature: signature
            )
        }
    }
}

// MARK: - ReceiptItem Tests

@Suite("ReceiptItem Tests")
@MainActor
struct ReceiptItemTests {

    @Test("lineHash generates consistent hash for same inputs")
    func testLineHashConsistent() {
        let json: [String: Any] = [
            "id": 1,
            "raw_name": "Test Item",
            "raw_sku": "SKU123",
            "total_price": 20.00
        ]
        let data = try! JSONSerialization.data(withJSONObject: json)
        let item1 = try! JSONDecoder().decode(ReceiptItem.self, from: data)
        let item2 = try! JSONDecoder().decode(ReceiptItem.self, from: data)

        #expect(item1.lineHash == item2.lineHash)
        #expect(!item1.lineHash.isEmpty)
    }

    @Test("lineHash is different for different items")
    func testLineHashDifferent() {
        let json1: [String: Any] = [
            "id": 1,
            "raw_name": "Test Item 1",
            "raw_sku": "SKU123",
            "total_price": 20.00
        ]
        let json2: [String: Any] = [
            "id": 2,
            "raw_name": "Test Item 2",
            "raw_sku": "SKU456",
            "total_price": 30.00
        ]
        let item1 = try! JSONDecoder().decode(ReceiptItem.self, from: JSONSerialization.data(withJSONObject: json1))
        let item2 = try! JSONDecoder().decode(ReceiptItem.self, from: JSONSerialization.data(withJSONObject: json2))

        #expect(item1.lineHash != item2.lineHash)
    }

    @Test("lineHash handles nil SKU")
    func testLineHashNilSku() {
        let json: [String: Any] = [
            "id": 1,
            "raw_name": "Test Item",
            "total_price": 20.00
        ]
        let data = try! JSONSerialization.data(withJSONObject: json)
        let item = try! JSONDecoder().decode(ReceiptItem.self, from: data)

        #expect(!item.lineHash.isEmpty)
        #expect(item.lineHash.count == 32) // SHA256 truncated to 16 bytes = 32 hex chars
    }

    @Test("lineHash handles nil total price")
    func testLineHashNilTotalPrice() {
        let json: [String: Any] = [
            "id": 1,
            "raw_name": "Test Item",
            "raw_sku": "SKU123"
        ]
        let data = try! JSONSerialization.data(withJSONObject: json)
        let item = try! JSONDecoder().decode(ReceiptItem.self, from: data)

        #expect(!item.lineHash.isEmpty)
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
