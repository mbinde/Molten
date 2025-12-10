//
//  ReceiptServiceTests.swift
//  MoltenTests
//
//  Tests for ReceiptService - high-level service for receipt import operations
//  Coordinates key management, API calls, and sync
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

@Suite("ReceiptService Tests")
@MainActor
struct ReceiptServiceTests {

    // MARK: - Test Helpers

    private func createTestService(
        apiClient: MockReceiptAPIClient = MockReceiptAPIClient(),
        keyPairManager: KeyPairManager = KeyPairManager(),
        preferences: ReceiptPreferences? = nil
    ) -> ReceiptService {
        let prefs = preferences ?? createTestPreferences()
        return ReceiptService(
            apiClient: apiClient,
            keyPairManager: keyPairManager,
            preferences: prefs
        )
    }

    private func createTestPreferences() -> ReceiptPreferences {
        let suiteName = "com.molten.tests.receipt.service.\(UUID().uuidString)"
        let localStore = UserDefaults(suiteName: suiteName)!
        // Use NSUbiquitousKeyValueStore.default in tests (no iCloud sync in simulator)
        let prefs = ReceiptPreferences(cloudStore: .default, localStore: localStore)
        // Reset to clear any state from previous tests (shared cloudStore)
        prefs.reset()
        return prefs
    }

    // MARK: - Setup State Tests

    @Test("Should report not set up when no user ID")
    func testNotSetUpWithoutUserId() {
        let preferences = createTestPreferences()
        let service = createTestService(preferences: preferences)

        #expect(service.isSetUp == false)
        #expect(service.userId == nil)
        #expect(service.plusAddress == nil)
    }

    @Test("Should report set up when enabled with user ID")
    func testSetUpWhenEnabled() {
        let preferences = createTestPreferences()
        preferences.userId = "test-user-123"
        preferences.plusAddress = "abc"  // Just the key
        preferences.identifierType = .plusAddress
        preferences.isEnabled = true

        let service = createTestService(preferences: preferences)

        #expect(service.isSetUp == true)
        #expect(service.userId == "test-user-123")
        #expect(service.plusAddress == "abc")  // Returns the key
    }

    @Test("Should expose receipt email from preferences")
    func testReceiptEmail() {
        let preferences = createTestPreferences()
        preferences.userId = "test-user"
        preferences.plusAddress = "test"  // Just the key
        preferences.identifierType = .plusAddress
        preferences.isEnabled = true

        let service = createTestService(preferences: preferences)

        #expect(service.receiptEmail == "receipts+test@moltenglass.app")
    }

    // MARK: - Enable Receipts Tests

    @Test("Should enable receipts and return email address")
    func testEnableReceipts() async throws {
        let mockAPI = MockReceiptAPIClient()
        let preferences = createTestPreferences()
        let service = createTestService(apiClient: mockAPI, preferences: preferences)

        // enableReceipts() generates its own key, no setup needed

        let email = try await service.enableReceipts()

        #expect(!email.isEmpty)
        #expect(preferences.userId == "mock-user-id")
        #expect(preferences.plusAddress == "mock")  // plusKey stored in plusAddress
        #expect(preferences.isEnabled == true)
        #expect(mockAPI.registerCalled == true)
    }

    // MARK: - Disable Receipts Tests

    @Test("Should disable receipts and clear data")
    func testDisableReceipts() {
        let preferences = createTestPreferences()
        preferences.userId = "test-user"
        preferences.plusAddress = "test"  // Just the key
        preferences.identifierType = .plusAddress
        preferences.isEnabled = true
        preferences.pendingReceiptCount = 5

        let service = createTestService(preferences: preferences)

        service.disableReceipts()

        #expect(service.isSetUp == false)
        #expect(preferences.userId == nil)
        #expect(preferences.plusAddress == nil)
        #expect(preferences.isEnabled == false)
        #expect(preferences.pendingReceiptCount == 0)
    }

    // MARK: - Sync Tests

    @Test("Should sync receipts and update pending count")
    func testSyncReceipts() async throws {
        let mockAPI = MockReceiptAPIClient()
        mockAPI.pendingCount = 3

        let preferences = createTestPreferences()
        preferences.userId = "test-user"
        preferences.plusAddress = "test"  // Just the key
        preferences.identifierType = .plusAddress
        preferences.isEnabled = true

        let keyPairManager = KeyPairManager()
        // NOTE: ReceiptService uses production keychain with "com.molten.receipts.key" identifier
        // We must store in production keychain for the service to find it
        // This is safe because tests use a MockReceiptAPIClient that doesn't make real API calls
        _ = try keyPairManager.generateAndStoreKeyPair(identifier: "com.molten.receipts.key")

        let service = createTestService(
            apiClient: mockAPI,
            keyPairManager: keyPairManager,
            preferences: preferences
        )

        let count = try await service.syncReceipts()

        #expect(count == 3)
        #expect(service.pendingReceiptCount == 3)
        #expect(mockAPI.listReceiptsCalled == true)
        #expect(preferences.lastSyncTimestamp != nil)
    }

    @Test("Should throw unauthorized when syncing without user ID")
    func testSyncUnauthorized() async throws {
        let preferences = createTestPreferences()
        // No user ID set

        let service = createTestService(preferences: preferences)

        await #expect(throws: ReceiptAPIError.self) {
            _ = try await service.syncReceipts()
        }
    }

    // MARK: - List Receipts Tests

    @Test("Should list receipts")
    func testListReceipts() async throws {
        let mockAPI = MockReceiptAPIClient()

        let preferences = createTestPreferences()
        preferences.userId = "test-user"
        preferences.plusAddress = "test"  // Just the key
        preferences.identifierType = .plusAddress
        preferences.isEnabled = true

        let keyPairManager = KeyPairManager()
        // NOTE: ReceiptService uses production keychain with "com.molten.receipts.key" identifier
        // We must store in production keychain for the service to find it
        // This is safe because tests use a MockReceiptAPIClient that doesn't make real API calls
        _ = try keyPairManager.generateAndStoreKeyPair(identifier: "com.molten.receipts.key")

        let service = createTestService(
            apiClient: mockAPI,
            keyPairManager: keyPairManager,
            preferences: preferences
        )

        let response = try await service.listReceipts()

        #expect(mockAPI.listReceiptsCalled == true)
        #expect(response.receipts.count == 1)
    }

    // MARK: - Get Receipt Tests

    @Test("Should get receipt detail")
    func testGetReceipt() async throws {
        let mockAPI = MockReceiptAPIClient()

        let preferences = createTestPreferences()
        preferences.userId = "test-user"
        preferences.plusAddress = "test"  // Just the key
        preferences.identifierType = .plusAddress
        preferences.isEnabled = true

        let keyPairManager = KeyPairManager()
        // NOTE: ReceiptService uses production keychain with "com.molten.receipts.key" identifier
        // We must store in production keychain for the service to find it
        // This is safe because tests use a MockReceiptAPIClient that doesn't make real API calls
        _ = try keyPairManager.generateAndStoreKeyPair(identifier: "com.molten.receipts.key")

        let service = createTestService(
            apiClient: mockAPI,
            keyPairManager: keyPairManager,
            preferences: preferences
        )

        let receipt = try await service.getReceipt(receiptId: "test-receipt")

        #expect(mockAPI.getReceiptCalled == true)
        #expect(receipt.id == "mock-receipt-id")
    }

    // MARK: - Acknowledge Receipt Tests

    @Test("Should acknowledge receipt and decrement pending count")
    func testAcknowledgeReceipt() async throws {
        let mockAPI = MockReceiptAPIClient()

        let preferences = createTestPreferences()
        preferences.userId = "test-user"
        preferences.plusAddress = "test"  // Just the key
        preferences.identifierType = .plusAddress
        preferences.isEnabled = true
        preferences.pendingReceiptCount = 5

        let keyPairManager = KeyPairManager()
        // NOTE: ReceiptService uses production keychain with "com.molten.receipts.key" identifier
        // We must store in production keychain for the service to find it
        // This is safe because tests use a MockReceiptAPIClient that doesn't make real API calls
        _ = try keyPairManager.generateAndStoreKeyPair(identifier: "com.molten.receipts.key")

        let service = createTestService(
            apiClient: mockAPI,
            keyPairManager: keyPairManager,
            preferences: preferences
        )

        try await service.acknowledgeReceipt(receiptId: "test-receipt")

        #expect(mockAPI.acknowledgeCalled == true)
        #expect(service.pendingReceiptCount == 4)
    }

    @Test("Should not decrement below zero")
    func testAcknowledgeDoesNotDecrementBelowZero() async throws {
        let mockAPI = MockReceiptAPIClient()

        let preferences = createTestPreferences()
        preferences.userId = "test-user"
        preferences.plusAddress = "test"  // Just the key
        preferences.identifierType = .plusAddress
        preferences.isEnabled = true
        preferences.pendingReceiptCount = 0

        let keyPairManager = KeyPairManager()
        // NOTE: ReceiptService uses production keychain with "com.molten.receipts.key" identifier
        // We must store in production keychain for the service to find it
        // This is safe because tests use a MockReceiptAPIClient that doesn't make real API calls
        _ = try keyPairManager.generateAndStoreKeyPair(identifier: "com.molten.receipts.key")

        let service = createTestService(
            apiClient: mockAPI,
            keyPairManager: keyPairManager,
            preferences: preferences
        )

        try await service.acknowledgeReceipt(receiptId: "test-receipt")

        #expect(service.pendingReceiptCount == 0)
    }
}

// MARK: - Mock Classes

class MockReceiptAPIClient: ReceiptAPIClient {
    var registerCalled = false
    var listReceiptsCalled = false
    var getReceiptCalled = false
    var acknowledgeCalled = false
    var pendingCount = 1

    init() {
        let mockSession = MockReceiptServiceURLSession()
        let mockAttestation = MockReceiptServiceAttestationManager()
        super.init(
            session: mockSession,
            baseURL: URL(string: "https://api.example.com")!,
            attestationManager: mockAttestation
        )
    }

    override func register(publicKey: Data) async throws -> ReceiptRegisterResponse {
        registerCalled = true
        return ReceiptRegisterResponse(
            userId: "mock-user-id",
            plusKey: "mock",
            forwardingEmail: "receipts+mock@example.com"
        )
    }

    override func listReceipts(
        userId: String,
        ownershipSignature: Data,
        limit: Int,
        offset: Int,
        includeAcknowledged: Bool
    ) async throws -> ReceiptListResponse {
        listReceiptsCalled = true
        let receipt = ReceiptSummary(
            id: "mock-receipt-id",
            retailerId: "costco",
            retailerName: "Costco",
            orderNumber: "12345",
            orderDate: Date(),
            totalAmount: 99.99,
            itemCount: 3,
            status: "parsed",
            acknowledged: false,
            receivedAt: Date(),
            parsedAt: Date()
        )
        return ReceiptListResponse(
            receipts: [receipt],
            total: pendingCount,
            offset: 0,
            limit: 50
        )
    }

    override func getReceipt(
        receiptId: String,
        userId: String,
        ownershipSignature: Data
    ) async throws -> ReceiptDetail {
        getReceiptCalled = true
        return ReceiptDetail(
            id: "mock-receipt-id",
            retailerId: "costco",
            retailerName: "Costco",
            senderEmail: "orders@costco.com",
            subject: "Your Order",
            orderNumber: "12345",
            orderDate: Date(),
            totalAmount: 99.99,
            status: "parsed",
            acknowledged: false,
            receivedAt: Date(),
            parsedAt: Date(),
            items: []
        )
    }

    override func acknowledgeReceipt(
        receiptId: String,
        userId: String,
        ownershipSignature: Data
    ) async throws {
        acknowledgeCalled = true
    }
}

// Minimal mocks for MockReceiptAPIClient initialization
private class MockReceiptServiceURLSession: URLSessionProtocol {
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        return (Data(), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }

    func download(for request: URLRequest, delegate: (any URLSessionTaskDelegate)?) async throws -> (URL, URLResponse) {
        throw URLError(.unsupportedURL)
    }
}

private class MockReceiptServiceAttestationManager: AttestationManagerProtocol {
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
