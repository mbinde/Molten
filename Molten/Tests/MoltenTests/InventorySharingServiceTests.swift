//
//  InventorySharingServiceTests.swift
//  MoltenTests
//
//  Tests for InventorySharingService - high-level orchestration for inventory sharing
//  Coordinates share code generation, snapshot creation, encryption, and API calls
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

@Suite("InventorySharingService Tests")
@MainActor
struct InventorySharingServiceTests {

    // MARK: - Test Lifecycle

    init() {
        // Clean up any existing test keys
        KeyPairManager.deleteAllKeys()
    }

    // MARK: - Share Creation Tests

    @Test("Should create and upload share with new code")
    func testCreateShare() async throws {
        let mockAPIClient = MockSharingAPIClient()
        let service = InventorySharingService(apiClient: mockAPIClient)

        let items = [
            InventoryItemSnapshot(stableId: "bullseye-001-0", manufacturer: "be", sku: "001", quantity: 5.0, unit: "rod", location: "Studio A")
        ]

        let metadata = MyShareMetadata(displayName: "Test User")
        let shareCode = try await service.createShare(items: items, metadata: metadata)

        #expect(!shareCode.isEmpty)
        #expect(shareCode.count == 6)
        #expect(mockAPIClient.uploadCalled)
    }

    @Test("Should generate unique share codes")
    func testGenerateUniqueShareCodes() async throws {
        let mockAPIClient = MockSharingAPIClient()
        let service = InventorySharingService(apiClient: mockAPIClient)

        let items = [
            InventoryItemSnapshot(stableId: "bullseye-001-0", manufacturer: "be", sku: "001", quantity: 5.0, unit: "rod", location: nil)
        ]

        let metadata = MyShareMetadata(displayName: "Test User")
        let code1 = try await service.createShare(items: items, metadata: metadata)
        let code2 = try await service.createShare(items: items, metadata: metadata)

        // Should generate different codes (very high probability with 31^6 combinations)
        #expect(code1 != code2)
    }

    @Test("Should use KeyPairManager for signing")
    func testUsesKeyPairForSigning() async throws {
        let mockAPIClient = MockSharingAPIClient()
        let service = InventorySharingService(apiClient: mockAPIClient)

        let items = [
            InventoryItemSnapshot(stableId: "bullseye-001-0", manufacturer: "be", sku: "001", quantity: 5.0, unit: "rod", location: nil)
        ]

        let metadata = MyShareMetadata(displayName: "Test User")
        _ = try await service.createShare(items: items, metadata: metadata)

        // Verify public key was included in upload
        #expect(mockAPIClient.lastPublicKey != nil)
        #expect(mockAPIClient.lastPublicKey?.count == 32)
    }

    @Test("Should retry with new code on conflict")
    func testRetryOnConflict() async throws {
        let mockAPIClient = MockSharingAPIClient()
        let service = InventorySharingService(apiClient: mockAPIClient)

        // First upload will conflict, second will succeed
        mockAPIClient.uploadWillConflict = true

        let items = [
            InventoryItemSnapshot(stableId: "bullseye-001-0", manufacturer: "be", sku: "001", quantity: 5.0, unit: "rod", location: nil)
        ]

        let metadata = MyShareMetadata(displayName: "Test User")
        let shareCode = try await service.createShare(items: items, metadata: metadata)

        #expect(!shareCode.isEmpty)
        #expect(mockAPIClient.uploadCallCount >= 2, "Should retry after conflict")
    }

    // MARK: - Download Tests

    @Test("Should download and verify friend's inventory")
    func testDownloadFriendInventory() async throws {
        let mockAPIClient = MockSharingAPIClient()
        let service = InventorySharingService(apiClient: mockAPIClient)

        // Create a valid snapshot for mock to return
        let items = [
            InventoryItemSnapshot(stableId: "bullseye-001-0", manufacturer: "be", sku: "001", quantity: 5.0, unit: "rod", location: "Friend's Studio")
        ]

        let keyManager = KeyPairManager()
        let keyPair = try keyManager.generateKeyPair()
        let snapshot = InventorySnapshot()
        let snapshotData = try snapshot.serialize(items: items, publicKey: keyPair.publicKey, privateKey: keyPair.privateKey)

        mockAPIClient.mockDownloadResult = DownloadedSnapshot(snapshotData: snapshotData, publicKey: keyPair.publicKey)

        let result = try await service.downloadFriendInventory(shareCode: "A7B2X9")

        #expect(result.items.count == 1)
        #expect(result.items[0].stableId == "bullseye-001-0")
        #expect(result.isValid, "Signature should be valid")
    }

    @Test("Should detect invalid signature on download")
    func testDetectInvalidSignature() async throws {
        let mockAPIClient = MockSharingAPIClient()
        let service = InventorySharingService(apiClient: mockAPIClient)

        let items = [
            InventoryItemSnapshot(stableId: "bullseye-001-0", manufacturer: "be", sku: "001", quantity: 5.0, unit: "rod", location: nil)
        ]

        // Create snapshot with one key pair
        let keyManager = KeyPairManager()
        let keyPair1 = try keyManager.generateKeyPair()
        let keyPair2 = try keyManager.generateKeyPair()
        let snapshot = InventorySnapshot()
        let snapshotData = try snapshot.serialize(items: items, publicKey: keyPair1.publicKey, privateKey: keyPair1.privateKey)

        // Mock returns data signed with keyPair1 but claims public key is keyPair2
        mockAPIClient.mockDownloadResult = DownloadedSnapshot(snapshotData: snapshotData, publicKey: keyPair2.publicKey)

        let result = try await service.downloadFriendInventory(shareCode: "A7B2X9")

        #expect(!result.isValid, "Signature should be invalid with wrong public key")
    }

    // MARK: - Update Tests

    @Test("Should update existing share")
    func testUpdateShare() async throws {
        let mockAPIClient = MockSharingAPIClient()
        let service = InventorySharingService(apiClient: mockAPIClient)

        let items = [
            InventoryItemSnapshot(stableId: "bullseye-001-0", manufacturer: "be", sku: "001", quantity: 10.0, unit: "rod", location: "Studio A")
        ]

        let metadata = MyShareMetadata(displayName: "Test User")
        try await service.updateShare(shareCode: "A7B2X9", items: items, metadata: metadata)

        #expect(mockAPIClient.updateCalled)
        #expect(mockAPIClient.lastShareCode == "A7B2X9")
    }

    // MARK: - Delete Tests

    @Test("Should delete share by code")
    func testDeleteShare() async throws {
        let mockAPIClient = MockSharingAPIClient()
        let service = InventorySharingService(apiClient: mockAPIClient)

        try await service.deleteShare(shareCode: "A7B2X9")

        #expect(mockAPIClient.deleteCalled)
        #expect(mockAPIClient.lastShareCode == "A7B2X9")
    }

    // MARK: - Error Handling Tests

    @Test("Should propagate API errors")
    func testPropagateAPIErrors() async throws {
        let mockAPIClient = MockSharingAPIClient()
        let service = InventorySharingService(apiClient: mockAPIClient)

        mockAPIClient.downloadWillFail = true

        await #expect(throws: SharingAPIError.self) {
            _ = try await service.downloadFriendInventory(shareCode: "NOTFND")
        }
    }

    @Test("Should throw error on max conflict retries")
    func testMaxConflictRetries() async throws {
        let mockAPIClient = MockSharingAPIClient()
        let service = InventorySharingService(apiClient: mockAPIClient)

        // Always conflict
        mockAPIClient.alwaysConflict = true

        let items = [
            InventoryItemSnapshot(stableId: "bullseye-001-0", manufacturer: "be", sku: "001", quantity: 5.0, unit: "rod", location: nil)
        ]

        await #expect(throws: SharingAPIError.self) {
            let metadata = MyShareMetadata(displayName: "Test User")
            _ = try await service.createShare(items: items, metadata: metadata)
        }
    }
}

// MARK: - Mock API Client

/// Mock API client for testing
class MockSharingAPIClient: InventorySharingAPIClient {
    var uploadCalled = false
    var uploadCallCount = 0
    var updateCalled = false
    var deleteCalled = false
    var uploadWillConflict = false
    var alwaysConflict = false
    var downloadWillFail = false
    var lastShareCode: String?
    var lastPublicKey: Data?
    var mockDownloadResult: DownloadedSnapshot?

    override func uploadSnapshot(shareCode: String, snapshotData: Data, publicKey: Data) async throws {
        uploadCalled = true
        uploadCallCount += 1
        lastShareCode = shareCode
        lastPublicKey = publicKey

        if alwaysConflict {
            throw SharingAPIError.conflict
        }

        if uploadWillConflict && uploadCallCount == 1 {
            throw SharingAPIError.conflict
        }
    }

    override func downloadSnapshot(shareCode: String) async throws -> DownloadedSnapshot {
        lastShareCode = shareCode

        if downloadWillFail {
            throw SharingAPIError.notFound
        }

        guard let result = mockDownloadResult else {
            throw SharingAPIError.notFound
        }

        return result
    }

    override func updateSnapshot(shareCode: String, snapshotData: Data, publicKey: Data, ownershipSignature: Data) async throws {
        updateCalled = true
        lastShareCode = shareCode
        lastPublicKey = publicKey
    }

    override func deleteShare(shareCode: String, ownershipSignature: Data) async throws {
        deleteCalled = true
        lastShareCode = shareCode
    }
}
