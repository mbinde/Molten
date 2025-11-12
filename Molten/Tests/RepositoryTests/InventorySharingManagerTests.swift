//
//  InventorySharingManagerTests.swift
//  MoltenTests
//
//  Tests for InventorySharingManager - high-level orchestration of inventory sharing
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

@Suite("InventorySharingManager Tests", .serialized)
@MainActor
struct InventorySharingManagerTests {

    // MARK: - Test Lifecycle

    init() {
        KeyPairManager.deleteAllKeys()
        cleanupUserDefaults()
    }

    private func cleanupUserDefaults() {
        UserDefaults.standard.removeObject(forKey: "molten.shareMetadata.myShareCode")
        UserDefaults.standard.removeObject(forKey: "molten.shareMetadata.myShareMetadata")
        UserDefaults.standard.removeObject(forKey: "molten.shareMetadata.friendShares")
    }

    // MARK: - Create My Share Tests

    @Test("Should create share and save code locally")
    func testCreateMyShare() async throws {
        cleanupUserDefaults()

        let mockCoordinator = MockInventorySharingCoordinator()
        let manager = createTestManager(coordinator: mockCoordinator)

        let item = createTestItem()
        let metadata = MyShareMetadata(displayName: "Test User")
        let shareCode = try await manager.createMyShare(items: [item], metadata: metadata)

        #expect(!shareCode.isEmpty)
        #expect(manager.getMyShareCode() == shareCode)
        #expect(mockCoordinator.shareMyInventoryCalled)
    }

    @Test("Should throw error if share already exists")
    func testCreateShareWhenAlreadyExists() async throws {
        cleanupUserDefaults()

        let mockCoordinator = MockInventorySharingCoordinator()
        let manager = createTestManager(coordinator: mockCoordinator)

        let item = createTestItem()
        let metadata = MyShareMetadata(displayName: "Test User")
        _ = try await manager.createMyShare(items: [item], metadata: metadata)

        await #expect(throws: SharingManagerError.self) {
            _ = try await manager.createMyShare(items: [item], metadata: metadata)
        }
    }

    // MARK: - Refresh My Share Tests

    @Test("Should update existing share")
    func testRefreshMyShare() async throws {
        cleanupUserDefaults()

        let mockCoordinator = MockInventorySharingCoordinator()
        let manager = createTestManager(coordinator: mockCoordinator)

        let item = createTestItem()
        let metadata = MyShareMetadata(displayName: "Test User")
        let shareCode = try await manager.createMyShare(items: [item], metadata: metadata)

        try await manager.refreshMyShare(items: [item])

        #expect(mockCoordinator.updateMyShareCalled)
        #expect(mockCoordinator.lastShareCode == shareCode)
    }

    @Test("Should throw error if no share exists when refreshing")
    func testRefreshShareWhenNoneExists() async throws {
        cleanupUserDefaults()

        let manager = InventorySharingManager()

        let item = createTestItem()

        await #expect(throws: SharingManagerError.self) {
            try await manager.refreshMyShare(items: [item])
        }
    }

    // MARK: - Metadata Tests

    @Test("Should save metadata when creating share")
    func testCreateShareWithMetadata() async throws {
        cleanupUserDefaults()

        let mockCoordinator = MockInventorySharingCoordinator()
        let manager = createTestManager(coordinator: mockCoordinator)

        let item = createTestItem()
        let metadata = MyShareMetadata(displayName: "Alice", shareNotes: "My collection")

        let shareCode = try await manager.createMyShare(items: [item], metadata: metadata)

        #expect(!shareCode.isEmpty)
        #expect(manager.getMyShareCode() == shareCode)

        let savedMetadata = manager.getMyShareMetadata()
        #expect(savedMetadata?.displayName == "Alice")
        #expect(savedMetadata?.shareNotes == "My collection")
        #expect(mockCoordinator.lastMetadata?.displayName == "Alice")
    }

    @Test("Should save metadata without notes")
    func testCreateShareWithMetadataWithoutNotes() async throws {
        cleanupUserDefaults()

        let mockCoordinator = MockInventorySharingCoordinator()
        let manager = createTestManager(coordinator: mockCoordinator)

        let item = createTestItem()
        let metadata = MyShareMetadata(displayName: "Alice", shareNotes: nil)

        _ = try await manager.createMyShare(items: [item], metadata: metadata)

        let savedMetadata = manager.getMyShareMetadata()
        #expect(savedMetadata?.displayName == "Alice")
        #expect(savedMetadata?.shareNotes == nil)
    }

    @Test("Should update metadata when refreshing share")
    func testRefreshShareWithUpdatedMetadata() async throws {
        cleanupUserDefaults()

        let mockCoordinator = MockInventorySharingCoordinator()
        let manager = createTestManager(coordinator: mockCoordinator)

        let item = createTestItem()
        let metadata1 = MyShareMetadata(displayName: "Alice", shareNotes: "Old notes")
        _ = try await manager.createMyShare(items: [item], metadata: metadata1)

        let metadata2 = MyShareMetadata(displayName: "Alice Smith", shareNotes: "New notes")
        try await manager.refreshMyShare(items: [item], metadata: metadata2)

        let savedMetadata = manager.getMyShareMetadata()
        #expect(savedMetadata?.displayName == "Alice Smith")
        #expect(savedMetadata?.shareNotes == "New notes")
        #expect(mockCoordinator.lastMetadata?.displayName == "Alice Smith")
    }

    @Test("Should keep existing metadata when refreshing without new metadata")
    func testRefreshShareKeepsExistingMetadata() async throws {
        cleanupUserDefaults()

        let mockCoordinator = MockInventorySharingCoordinator()
        let manager = createTestManager(coordinator: mockCoordinator)

        let item = createTestItem()
        let metadata = MyShareMetadata(displayName: "Alice", shareNotes: "My notes")
        _ = try await manager.createMyShare(items: [item], metadata: metadata)

        try await manager.refreshMyShare(items: [item])

        let savedMetadata = manager.getMyShareMetadata()
        #expect(savedMetadata?.displayName == "Alice")
        #expect(savedMetadata?.shareNotes == "My notes")
    }

    @Test("Should include owner metadata in downloaded friend share")
    func testAddFriendShareIncludesOwnerMetadata() async throws {
        cleanupUserDefaults()

        let mockCoordinator = MockInventorySharingCoordinator()
        mockCoordinator.mockDownloadResult = SnapshotResult(
            items: [
                InventoryItemSnapshot(
                    stableId: "abc123",
                    manufacturer: "test",
                    sku: "001",
                    quantity: 5.0,
                    unit: "rod",
                    location: nil
                )
            ],
            timestamp: Date(),
            version: "1.0",
            isValid: true,
            ownerName: "Bob's Glass Shop",
            ownerShareNotes: "Boro specialist"
        )
        let manager = createTestManager(coordinator: mockCoordinator)

        let result = try await manager.addFriendShare(shareCode: "FRIEND")

        #expect(result.ownerName == "Bob's Glass Shop")
        #expect(result.ownerShareNotes == "Boro specialist")
    }

    // MARK: - Delete My Share Tests

    @Test("Should delete share and remove local code")
    func testDeleteMyShare() async throws {
        cleanupUserDefaults()

        let mockCoordinator = MockInventorySharingCoordinator()
        let manager = createTestManager(coordinator: mockCoordinator)

        let item = createTestItem()
        let metadata = MyShareMetadata(displayName: "Test User")
        _ = try await manager.createMyShare(items: [item], metadata: metadata)

        try await manager.deleteMyShare()

        #expect(manager.getMyShareCode() == nil)
        #expect(mockCoordinator.deleteMyShareCalled)
    }

    @Test("Should throw error if no share exists when deleting")
    func testDeleteShareWhenNoneExists() async throws {
        cleanupUserDefaults()

        let manager = InventorySharingManager()

        await #expect(throws: SharingManagerError.self) {
            try await manager.deleteMyShare()
        }
    }

    // MARK: - Add Friend Share Tests

    @Test("Should download and save friend share with display name from server")
    func testAddFriendShare() async throws {
        cleanupUserDefaults()

        let mockCoordinator = MockInventorySharingCoordinator()
        mockCoordinator.mockDownloadResult = createValidSnapshotResult()
        let manager = createTestManager(coordinator: mockCoordinator)

        let result = try await manager.addFriendShare(shareCode: "FRIEND")

        #expect(result.isValid)
        #expect(mockCoordinator.downloadFriendInventoryCalled)

        let friendShares = manager.getFriendShares()
        #expect(friendShares.count == 1)
        #expect(friendShares[0].shareCode == "FRIEND")
        // Display name should come from server, not user input
        #expect(friendShares[0].friendName == "Bob's Glass Shop")
    }

    @Test("Should save friend share with personal nickname")
    func testAddFriendShareWithNickname() async throws {
        cleanupUserDefaults()

        let mockCoordinator = MockInventorySharingCoordinator()
        mockCoordinator.mockDownloadResult = createValidSnapshotResult()
        let manager = createTestManager(coordinator: mockCoordinator)

        _ = try await manager.addFriendShare(shareCode: "FRIEND", nickname: "Bob from GAS 2025")

        let friendShares = manager.getFriendShares()
        #expect(friendShares.count == 1)
        // Display name comes from server
        #expect(friendShares[0].friendName == "Bob's Glass Shop")
        // Nickname is our personal label
        #expect(friendShares[0].nickname == "Bob from GAS 2025")
    }

    // MARK: - Refresh Friend Share Tests

    @Test("Should refresh friend share and update timestamp")
    func testRefreshFriendShare() async throws {
        cleanupUserDefaults()

        let mockCoordinator = MockInventorySharingCoordinator()
        mockCoordinator.mockDownloadResult = createValidSnapshotResult()
        let manager = createTestManager(coordinator: mockCoordinator)

        _ = try await manager.addFriendShare(shareCode: "FRIEND")

        // Wait a moment so timestamp is different
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms

        let result = try await manager.refreshFriendShare(shareCode: "FRIEND")

        #expect(result.isValid)

        let friendShare = manager.getFriendShares().first
        #expect(friendShare?.lastRefreshed != nil)
    }

    @Test("Should throw error if friend share not found when refreshing")
    func testRefreshFriendShareNotFound() async throws {
        cleanupUserDefaults()

        let manager = InventorySharingManager()

        await #expect(throws: SharingManagerError.self) {
            _ = try await manager.refreshFriendShare(shareCode: "NOTFOUND")
        }
    }

    @Test("Should clean up cached data when share is deleted by owner (404)")
    func testRefreshFriendShareDeletedByOwner() async throws {
        cleanupUserDefaults()

        let mockCoordinator = MockInventorySharingCoordinator()
        mockCoordinator.mockDownloadResult = createSnapshotResult(ownerName: "Bob's Glass Shop")
        let manager = createTestManager(coordinator: mockCoordinator)

        // Add friend share (creates local record and cached data)
        _ = try await manager.addFriendShare(shareCode: "FRIEND")

        let friendSharesBefore = manager.getFriendShares()
        #expect(friendSharesBefore.count == 1)

        // Simulate owner deleting share (mock will return 404)
        mockCoordinator.mockDownloadResult = nil

        // Try to refresh - should throw shareDeletedByOwner error
        await #expect(throws: SharingManagerError.shareDeletedByOwner) {
            _ = try await manager.refreshFriendShare(shareCode: "FRIEND")
        }

        // Verify share record was deactivated (no longer in active list)
        let friendSharesAfter = manager.getFriendShares()
        #expect(friendSharesAfter.isEmpty)
    }

    // MARK: - Remove Friend Share Tests

    @Test("Should remove friend share")
    func testRemoveFriendShare() async throws {
        cleanupUserDefaults()

        let mockCoordinator = MockInventorySharingCoordinator()
        mockCoordinator.mockDownloadResult = createValidSnapshotResult()
        let manager = createTestManager(coordinator: mockCoordinator)

        _ = try await manager.addFriendShare(shareCode: "FRIEND")

        try manager.removeFriendShare(shareCode: "FRIEND")

        let friendShares = manager.getFriendShares()
        #expect(friendShares.isEmpty)
    }

    // MARK: - Helper Methods

    private func createTestManager(coordinator: MockInventorySharingCoordinator) -> InventorySharingManager {
        // Create isolated test controller
        let testController = PersistenceController.createTestController()
        let deps = AppDependencies(forTesting: true)

        let testContext = testController.container.viewContext
        let catalogRepo = deps.glassItemRepository
        let metadataRepo = ShareMetadataRepository()
        let shareRecordRepo = CoreDataShareRecordRepository(context: testContext)
        let sharedInventoryRepo = CoreDataSharedInventoryRepository(
            context: testContext,
            catalogRepository: catalogRepo
        )

        return InventorySharingManager(
            coordinator: coordinator,
            metadataRepository: metadataRepo,
            shareRecordRepository: shareRecordRepo,
            sharedInventoryRepository: sharedInventoryRepo
        )
    }

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

    private func createValidSnapshotResult() -> SnapshotResult {
        return createSnapshotResult()
    }

    private func createSnapshotResult(ownerName: String? = nil, ownerShareNotes: String? = nil) -> SnapshotResult {
        return SnapshotResult(
            items: [
                InventoryItemSnapshot(
                    stableId: "abc123",
                    manufacturer: "test",
                    sku: "001",
                    quantity: 5.0,
                    unit: "rod",
                    location: nil
                )
            ],
            timestamp: Date(),
            version: "1.0",
            isValid: true,
            ownerName: ownerName,
            ownerShareNotes: ownerShareNotes
        )
    }
}

// MARK: - Mock Coordinator

class MockInventorySharingCoordinator: InventorySharingCoordinator {
    var shareMyInventoryCalled = false
    var updateMyShareCalled = false
    var deleteMyShareCalled = false
    var downloadFriendInventoryCalled = false
    var lastShareCode: String?
    var lastMetadata: MyShareMetadata?
    var mockDownloadResult: SnapshotResult?

    override func shareMyInventory(items: [CompleteInventoryItemModel], metadata: MyShareMetadata) async throws -> String {
        shareMyInventoryCalled = true
        lastMetadata = metadata
        return "MOCK12"
    }

    override func updateMyShare(shareCode: String, items: [CompleteInventoryItemModel], metadata: MyShareMetadata) async throws {
        updateMyShareCalled = true
        lastShareCode = shareCode
        lastMetadata = metadata
    }

    override func deleteMyShare(shareCode: String) async throws {
        deleteMyShareCalled = true
        lastShareCode = shareCode
    }

    override func downloadFriendInventory(shareCode: String) async throws -> SnapshotResult {
        downloadFriendInventoryCalled = true
        lastShareCode = shareCode

        guard let result = mockDownloadResult else {
            throw SharingAPIError.notFound
        }

        return result
    }
}
