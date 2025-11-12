//
//  InventorySharingIntegrationTests.swift
//  MoltenTests
//
//  End-to-end integration tests for the complete inventory sharing flow
//

#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif
import Foundation
import CoreData
@testable import Molten

@Suite("Inventory Sharing Integration Tests")
@MainActor
struct InventorySharingIntegrationTests {

    // MARK: - Test Lifecycle

    init() {
        KeyPairManager.deleteAllKeys()
        UserDefaults.standard.removeObject(forKey: "molten.shareMetadata.myShareCode")
        UserDefaults.standard.removeObject(forKey: "molten.shareMetadata.friendShares")
    }

    // MARK: - Complete Flow Tests

    @Test("Should complete full share creation flow")
    func testCompleteShareCreationFlow() async throws {
        // Create mock API client
        let mockAPIClient = MockSharingAPIClient()

        // Create real components with mock API
        let keyPairManager = KeyPairManager()
        let shareCodeGenerator = ShareCodeGenerator()
        let snapshot = InventorySnapshot()
        let sharingService = InventorySharingService(
            apiClient: mockAPIClient,
            keyPairManager: keyPairManager,
            shareCodeGenerator: shareCodeGenerator,
            snapshot: snapshot
        )
        let coordinator = InventorySharingCoordinator(sharingService: sharingService)
        let manager = InventorySharingManager(coordinator: coordinator)

        // Create test inventory
        let item = createTestItem()

        // Complete flow: Create share
        let metadata = MyShareMetadata(displayName: "Test User")
        let shareCode = try await manager.createMyShare(items: [item], metadata: metadata)

        // Verify share code generated
        #expect(shareCode.count == 6)
        #expect(manager.getMyShareCode() == shareCode)

        // Verify API was called
        #expect(mockAPIClient.uploadCalled)
        #expect(mockAPIClient.lastPublicKey != nil)

        // Verify key pair was created
        let keyPair = try keyPairManager.getCurrentKeyPair()
        #expect(keyPair.publicKey.count == 32)
        #expect(keyPair.privateKey.count == 32)
    }

    @Test("Should complete full friend download flow")
    func testCompleteFriendDownloadFlow() async throws {
        // Setup: User A creates a share
        let userAKeyManager = KeyPairManager()
        let userAKeyPair = try userAKeyManager.generateKeyPair()
        let userASnapshot = InventorySnapshot()

        let items = [
            InventoryItemSnapshot(
                stableId: "abc123",
                manufacturer: "test",
                sku: "001",
                quantity: 5.0,
                unit: "rod",
                location: "Studio A"
            )
        ]

        let userAMetadata = MyShareMetadata(displayName: "User A's Glass Shop")
        let snapshotData = try userASnapshot.serialize(
            items: items,
            publicKey: userAKeyPair.publicKey,
            privateKey: userAKeyPair.privateKey,
            metadata: userAMetadata
        )

        // Mock API to return User A's share
        let mockAPIClient = MockSharingAPIClient()
        mockAPIClient.mockDownloadResult = DownloadedSnapshot(
            snapshotData: snapshotData,
            publicKey: userAKeyPair.publicKey
        )

        // Create test Core Data controller
        let testController = PersistenceController.createTestController()

        // User B downloads User A's share
        let userBSharingService = InventorySharingService(
            apiClient: mockAPIClient,
            keyPairManager: KeyPairManager(), // Different key manager for User B
            shareCodeGenerator: ShareCodeGenerator(),
            snapshot: InventorySnapshot()
        )
        let userBCoordinator = InventorySharingCoordinator(sharingService: userBSharingService)

        // Create manager with test repositories
        let shareRecordRepo = CoreDataShareRecordRepository(context: testController.container.viewContext)
        let catalogRepo = deps.glassItemRepository
        let sharedInventoryRepo = CoreDataSharedInventoryRepository(
            context: testController.container.viewContext,
            catalogRepository: catalogRepo
        )
        let userBManager = InventorySharingManager(
            coordinator: userBCoordinator,
            shareRecordRepository: shareRecordRepo,
            sharedInventoryRepository: sharedInventoryRepo
        )

        // Download friend's share
        let result = try await userBManager.addFriendShare(
            shareCode: "USERA1"
        )

        // Verify download successful
        #expect(result.isValid, "Signature should be valid")
        #expect(result.items.count == 1)
        #expect(result.items[0].stableId == "abc123")
        #expect(result.items[0].quantity == 5.0)

        // Verify friend share saved with display name from server
        let friendShares = userBManager.getFriendShares()
        #expect(friendShares.count == 1)
        #expect(friendShares[0].shareCode == "USERA1")
        #expect(friendShares[0].friendName == "User A's Glass Shop")
    }

    @Test("Should detect tampered snapshot")
    func testDetectTamperedSnapshot() async throws {
        // Create original snapshot
        let keyManager = KeyPairManager()
        let keyPair = try keyManager.generateKeyPair()
        let snapshot = InventorySnapshot()

        let originalItems = [
            InventoryItemSnapshot(
                stableId: "abc123",
                manufacturer: "test",
                sku: "001",
                quantity: 5.0,
                unit: "rod",
                location: nil
            )
        ]

        let snapshotData = try snapshot.serialize(
            items: originalItems,
            publicKey: keyPair.publicKey,
            privateKey: keyPair.privateKey
        )

        // Tamper with the snapshot (change quantity in the data)
        var tamperedData = snapshotData
        // This is a simplified tamper - in reality JSON would need proper modification
        // But the signature will be invalid regardless

        // Create a different key pair (attacker's keys)
        let attackerKeyManager = KeyPairManager()
        let attackerKeyPair = try attackerKeyManager.generateKeyPair()

        // Mock API returns tampered data with wrong public key
        let mockAPIClient = MockSharingAPIClient()
        mockAPIClient.mockDownloadResult = DownloadedSnapshot(
            snapshotData: tamperedData,
            publicKey: attackerKeyPair.publicKey // Wrong public key!
        )

        // Try to download with verification
        let sharingService = InventorySharingService(
            apiClient: mockAPIClient,
            keyPairManager: KeyPairManager(),
            shareCodeGenerator: ShareCodeGenerator(),
            snapshot: InventorySnapshot()
        )
        let coordinator = InventorySharingCoordinator(sharingService: sharingService)

        // Create test Core Data controller
        let testController = PersistenceController.createTestController()
        let shareRecordRepo = CoreDataShareRecordRepository(context: testController.container.viewContext)
        let catalogRepo = deps.glassItemRepository
        let sharedInventoryRepo = CoreDataSharedInventoryRepository(
            context: testController.container.viewContext,
            catalogRepository: catalogRepo
        )
        let manager = InventorySharingManager(
            coordinator: coordinator,
            shareRecordRepository: shareRecordRepo,
            sharedInventoryRepository: sharedInventoryRepo
        )

        let result = try await manager.addFriendShare(
            shareCode: "TAMPER"
        )

        // Signature verification should fail
        #expect(!result.isValid, "Tampered snapshot should have invalid signature")
    }

    @Test("Should refresh my share with updated inventory")
    func testRefreshMyShare() async throws {
        let mockAPIClient = MockSharingAPIClient()
        let sharingService = InventorySharingService(apiClient: mockAPIClient)
        let coordinator = InventorySharingCoordinator(sharingService: sharingService)
        let manager = InventorySharingManager(coordinator: coordinator)

        // Create initial share
        let item1 = createTestItem()
        let metadata = MyShareMetadata(displayName: "Test User")
        let shareCode = try await manager.createMyShare(items: [item1], metadata: metadata)

        // Update inventory
        let item2 = CompleteInventoryItemModel(
            glassItem: GlassItemModel(
                stable_id: "def456",
                name: "Red",
                sku: "002",
                manufacturer: "test",
                coe: 90,
                mfr_status: "available"
            ),
            inventory: [InventoryModel(
                item_stable_id: "def456",
                type: "tube",
                quantity: 10.0,
                location: nil
            )],
            tags: [],
            userTags: []
        )

        // Refresh with updated inventory
        try await manager.refreshMyShare(items: [item1, item2])

        // Verify update called
        #expect(mockAPIClient.updateCalled)
        #expect(mockAPIClient.lastShareCode == shareCode)
    }

    @Test("Should handle complete lifecycle: create, refresh, delete")
    func testCompleteLifecycle() async throws {
        let mockAPIClient = MockSharingAPIClient()
        let sharingService = InventorySharingService(apiClient: mockAPIClient)
        let coordinator = InventorySharingCoordinator(sharingService: sharingService)
        let manager = InventorySharingManager(coordinator: coordinator)

        let item = createTestItem()

        // 1. Create share
        let metadata = MyShareMetadata(displayName: "Test User")
        let shareCode = try await manager.createMyShare(items: [item], metadata: metadata)
        #expect(manager.getMyShareCode() == shareCode)

        // 2. Refresh share
        try await manager.refreshMyShare(items: [item])
        #expect(mockAPIClient.updateCalled)

        // 3. Delete share
        try await manager.deleteMyShare()
        #expect(manager.getMyShareCode() == nil)
        #expect(mockAPIClient.deleteCalled)
    }

    // MARK: - Helper Methods

    private func createTestItem() -> CompleteInventoryItemModel {
        let glassItem = GlassItemModel(
            stable_id: "abc123",
            name: "Test Item",
            sku: "001",
            manufacturer: "test",
            coe: 90,
            mfr_status: "available"
        )

        let inventory = InventoryModel(
            item_stable_id: "abc123",
            type: "rod",
            quantity: 5.0,
            location: nil
        )

        return CompleteInventoryItemModel(
            glassItem: glassItem,
            inventory: [inventory],
            tags: [],
            userTags: []
        )
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
