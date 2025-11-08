//
//  InventorySharingManagerTests.swift
//  MoltenTests
//
//  Tests for InventorySharingManager - high-level orchestration of inventory sharing
//

import Testing
import Foundation
@testable import Molten

@Suite("InventorySharingManager Tests")
@MainActor
struct InventorySharingManagerTests {

    // MARK: - Test Lifecycle

    init() {
        KeyPairManager.deleteAllKeys()
        UserDefaults.standard.removeObject(forKey: "molten.shareMetadata.myShareCode")
        UserDefaults.standard.removeObject(forKey: "molten.shareMetadata.friendShares")
    }

    // MARK: - Create My Share Tests

    @Test("Should create share and save code locally")
    func testCreateMyShare() async throws {
        let mockCoordinator = MockInventorySharingCoordinator()
        let manager = InventorySharingManager(coordinator: mockCoordinator)

        let item = createTestItem()
        let shareCode = try await manager.createMyShare(items: [item])

        #expect(!shareCode.isEmpty)
        #expect(manager.getMyShareCode() == shareCode)
        #expect(mockCoordinator.shareMyInventoryCalled)
    }

    @Test("Should throw error if share already exists")
    func testCreateShareWhenAlreadyExists() async throws {
        let mockCoordinator = MockInventorySharingCoordinator()
        let manager = InventorySharingManager(coordinator: mockCoordinator)

        let item = createTestItem()
        _ = try await manager.createMyShare(items: [item])

        await #expect(throws: SharingManagerError.self) {
            _ = try await manager.createMyShare(items: [item])
        }
    }

    // MARK: - Refresh My Share Tests

    @Test("Should update existing share")
    func testRefreshMyShare() async throws {
        let mockCoordinator = MockInventorySharingCoordinator()
        let manager = InventorySharingManager(coordinator: mockCoordinator)

        let item = createTestItem()
        let shareCode = try await manager.createMyShare(items: [item])

        try await manager.refreshMyShare(items: [item])

        #expect(mockCoordinator.updateMyShareCalled)
        #expect(mockCoordinator.lastShareCode == shareCode)
    }

    @Test("Should throw error if no share exists when refreshing")
    func testRefreshShareWhenNoneExists() async throws {
        let manager = InventorySharingManager()

        let item = createTestItem()

        await #expect(throws: SharingManagerError.self) {
            try await manager.refreshMyShare(items: [item])
        }
    }

    // MARK: - Delete My Share Tests

    @Test("Should delete share and remove local code")
    func testDeleteMyShare() async throws {
        let mockCoordinator = MockInventorySharingCoordinator()
        let manager = InventorySharingManager(coordinator: mockCoordinator)

        let item = createTestItem()
        _ = try await manager.createMyShare(items: [item])

        try await manager.deleteMyShare()

        #expect(manager.getMyShareCode() == nil)
        #expect(mockCoordinator.deleteMyShareCalled)
    }

    @Test("Should throw error if no share exists when deleting")
    func testDeleteShareWhenNoneExists() async throws {
        let manager = InventorySharingManager()

        await #expect(throws: SharingManagerError.self) {
            try await manager.deleteMyShare()
        }
    }

    // MARK: - Add Friend Share Tests

    @Test("Should download and save friend share")
    func testAddFriendShare() async throws {
        let mockCoordinator = MockInventorySharingCoordinator()
        mockCoordinator.mockDownloadResult = createValidSnapshotResult()
        let manager = InventorySharingManager(coordinator: mockCoordinator)

        let result = try await manager.addFriendShare(shareCode: "FRIEND", friendName: "Alice")

        #expect(result.isValid)
        #expect(mockCoordinator.downloadFriendInventoryCalled)

        let friendShares = manager.getFriendShares()
        #expect(friendShares.count == 1)
        #expect(friendShares[0].shareCode == "FRIEND")
        #expect(friendShares[0].friendName == "Alice")
    }

    @Test("Should update friend name if share code already exists")
    func testAddFriendShareUpdateExisting() async throws {
        let mockCoordinator = MockInventorySharingCoordinator()
        mockCoordinator.mockDownloadResult = createValidSnapshotResult()
        let manager = InventorySharingManager(coordinator: mockCoordinator)

        _ = try await manager.addFriendShare(shareCode: "FRIEND", friendName: "Alice")
        _ = try await manager.addFriendShare(shareCode: "FRIEND", friendName: "Alice Updated")

        let friendShares = manager.getFriendShares()
        #expect(friendShares.count == 1)
        #expect(friendShares[0].friendName == "Alice Updated")
    }

    // MARK: - Refresh Friend Share Tests

    @Test("Should refresh friend share and update timestamp")
    func testRefreshFriendShare() async throws {
        // Clean up any previous test state
        UserDefaults.standard.removeObject(forKey: "molten.shareMetadata.myShareCode")
        UserDefaults.standard.removeObject(forKey: "molten.shareMetadata.friendShares")

        let mockCoordinator = MockInventorySharingCoordinator()
        mockCoordinator.mockDownloadResult = createValidSnapshotResult()
        let manager = InventorySharingManager(coordinator: mockCoordinator)

        _ = try await manager.addFriendShare(shareCode: "FRIEND", friendName: "Alice")

        // Wait a moment so timestamp is different
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms

        let result = try await manager.refreshFriendShare(shareCode: "FRIEND")

        #expect(result.isValid)

        let friendShare = manager.getFriendShares().first
        #expect(friendShare?.lastRefreshed != nil)
    }

    @Test("Should throw error if friend share not found when refreshing")
    func testRefreshFriendShareNotFound() async throws {
        let manager = InventorySharingManager()

        await #expect(throws: SharingManagerError.self) {
            _ = try await manager.refreshFriendShare(shareCode: "NOTFOUND")
        }
    }

    // MARK: - Remove Friend Share Tests

    @Test("Should remove friend share")
    func testRemoveFriendShare() async throws {
        let mockCoordinator = MockInventorySharingCoordinator()
        mockCoordinator.mockDownloadResult = createValidSnapshotResult()
        let manager = InventorySharingManager(coordinator: mockCoordinator)

        _ = try await manager.addFriendShare(shareCode: "FRIEND", friendName: "Alice")

        try manager.removeFriendShare(shareCode: "FRIEND")

        let friendShares = manager.getFriendShares()
        #expect(friendShares.isEmpty)
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

    private func createValidSnapshotResult() -> SnapshotResult {
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
            isValid: true
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
    var mockDownloadResult: SnapshotResult?

    override func shareMyInventory(items: [CompleteInventoryItemModel]) async throws -> String {
        shareMyInventoryCalled = true
        return "MOCK12"
    }

    override func updateMyShare(shareCode: String, items: [CompleteInventoryItemModel]) async throws {
        updateMyShareCalled = true
        lastShareCode = shareCode
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
