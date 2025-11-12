//
//  InventorySharingCoordinatorTests.swift
//  MoltenTests
//
//  Tests for InventorySharingCoordinator - bridges app inventory with sharing system
//  Converts between CompleteInventoryItemModel and InventoryItemSnapshot
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

@Suite("InventorySharingCoordinator Tests")
@MainActor
struct InventorySharingCoordinatorTests {

    // MARK: - Test Lifecycle

    init() {
        KeyPairManager.deleteAllKeys()
        let deps = AppDependencies(forTesting: true)
    }

    // MARK: - Conversion Tests

    @Test("Should convert CompleteInventoryItemModel to InventoryItemSnapshot")
    func testConvertToSnapshot() async throws {
        let coordinator = InventorySharingCoordinator()

        let glassItem = GlassItemModel(
            stable_id: "abc123",
            name: "Clear",
            sku: "001",
            manufacturer: "be",
            coe: 90,
            mfr_status: "available"
        )

        let inventory = InventoryModel(
            item_stable_id: "abc123",
            type: "rod",
            quantity: 5.0,
            location: "Studio A"
        )

        let inventoryItem = CompleteInventoryItemModel(
            glassItem: glassItem,
            inventory: [inventory],
            tags: [],
            userTags: []
        )

        let snapshot = coordinator.convertToSnapshot(item: inventoryItem)

        #expect(snapshot.stableId == "abc123")
        #expect(snapshot.manufacturer == "be")
        #expect(snapshot.sku == "001")
        #expect(snapshot.quantity == 5.0)
        #expect(snapshot.unit == "rod")
        #expect(snapshot.location == "Studio A")
    }

    @Test("Should convert multiple items to snapshots")
    func testConvertMultipleItems() async throws {
        let coordinator = InventorySharingCoordinator()

        let item1 = CompleteInventoryItemModel(
            glassItem: GlassItemModel(stable_id: "abc123", name: "Clear", sku: "001", manufacturer: "be", coe: 90, mfr_status: "available"),
            inventory: [InventoryModel(item_stable_id: "abc123", type: "rod", quantity: 5.0, location: "Studio A")],
            tags: [],
            userTags: []
        )

        let item2 = CompleteInventoryItemModel(
            glassItem: GlassItemModel(stable_id: "def456", name: "Red", sku: "023", manufacturer: "cim", coe: 104, mfr_status: "available"),
            inventory: [InventoryModel(item_stable_id: "def456", type: "tube", quantity: 3.5, location: "Studio B")],
            tags: [],
            userTags: []
        )

        let snapshots = coordinator.convertToSnapshots(items: [item1, item2])

        #expect(snapshots.count == 2)
        #expect(snapshots[0].stableId == "abc123")
        #expect(snapshots[1].stableId == "def456")
    }

    @Test("Should handle nil location")
    func testHandleNilLocation() async throws {
        let coordinator = InventorySharingCoordinator()

        let item = CompleteInventoryItemModel(
            glassItem: GlassItemModel(stable_id: "abc123", name: "Clear", sku: "001", manufacturer: "be", coe: 90, mfr_status: "available"),
            inventory: [InventoryModel(item_stable_id: "abc123", type: "rod", quantity: 5.0, location: nil)],
            tags: [],
            userTags: []
        )

        let snapshot = coordinator.convertToSnapshot(item: item)

        #expect(snapshot.location == nil)
    }

    // MARK: - Share Creation Tests

    @Test("Should create share from inventory items")
    func testCreateShareFromInventory() async throws {
        let mockService = MockInventorySharingService()
        let coordinator = InventorySharingCoordinator(sharingService: mockService)

        let item = CompleteInventoryItemModel(
            glassItem: GlassItemModel(stable_id: "abc123", name: "Clear", sku: "001", manufacturer: "be", coe: 90, mfr_status: "available"),
            inventory: [InventoryModel(item_stable_id: "abc123", type: "rod", quantity: 5.0, location: "Studio A")],
            tags: [],
            userTags: []
        )

        let metadata = MyShareMetadata(displayName: "Test User")
        let shareCode = try await coordinator.shareMyInventory(items: [item], metadata: metadata)

        #expect(!shareCode.isEmpty)
        #expect(mockService.createShareCalled)
        #expect(mockService.lastItems?.count == 1)
    }

    @Test("Should filter items with zero quantity before sharing")
    func testFilterZeroQuantity() async throws {
        let mockService = MockInventorySharingService()
        let coordinator = InventorySharingCoordinator(sharingService: mockService)

        let item1 = CompleteInventoryItemModel(
            glassItem: GlassItemModel(stable_id: "abc123", name: "Clear", sku: "001", manufacturer: "be", coe: 90, mfr_status: "available"),
            inventory: [InventoryModel(item_stable_id: "abc123", type: "rod", quantity: 5.0, location: nil)],
            tags: [],
            userTags: []
        )

        let item2 = CompleteInventoryItemModel(
            glassItem: GlassItemModel(stable_id: "def456", name: "Red", sku: "023", manufacturer: "cim", coe: 104, mfr_status: "available"),
            inventory: [InventoryModel(item_stable_id: "def456", type: "tube", quantity: 0.0, location: nil)],
            tags: [],
            userTags: []
        )

        let metadata = MyShareMetadata(displayName: "Test User")
        _ = try await coordinator.shareMyInventory(items: [item1, item2], metadata: metadata)

        // Should only share item with quantity > 0
        #expect(mockService.lastItems?.count == 1)
        #expect(mockService.lastItems?[0].stableId == "abc123")
    }

    // MARK: - Download Tests

    @Test("Should download friend's inventory")
    func testDownloadFriendInventory() async throws {
        let mockService = MockInventorySharingService()
        let coordinator = InventorySharingCoordinator(sharingService: mockService)

        // Mock valid snapshot result
        let items = [
            InventoryItemSnapshot(stableId: "bullseye-001-0", manufacturer: "be", sku: "001", quantity: 5.0, unit: "rod", location: "Friend's Studio")
        ]
        mockService.mockDownloadResult = SnapshotResult(
            items: items,
            timestamp: Date(),
            version: "1.0",
            isValid: true
        )

        let result = try await coordinator.downloadFriendInventory(shareCode: "A7B2X9")

        #expect(result.items.count == 1)
        #expect(result.isValid)
        #expect(mockService.downloadCalled)
    }

    @Test("Should warn on invalid signature")
    func testWarnInvalidSignature() async throws {
        let mockService = MockInventorySharingService()
        let coordinator = InventorySharingCoordinator(sharingService: mockService)

        let items = [
            InventoryItemSnapshot(stableId: "bullseye-001-0", manufacturer: "be", sku: "001", quantity: 5.0, unit: "rod", location: nil)
        ]
        mockService.mockDownloadResult = SnapshotResult(
            items: items,
            timestamp: Date(),
            version: "1.0",
            isValid: false  // Invalid signature!
        )

        let result = try await coordinator.downloadFriendInventory(shareCode: "A7B2X9")

        #expect(!result.isValid, "Should detect invalid signature")
        #expect(result.items.count == 1, "Should still return items for inspection")
    }

    // MARK: - Update Tests

    @Test("Should update existing share")
    func testUpdateShare() async throws {
        let mockService = MockInventorySharingService()
        let coordinator = InventorySharingCoordinator(sharingService: mockService)

        let item = CompleteInventoryItemModel(
            glassItem: GlassItemModel(stable_id: "abc123", name: "Clear", sku: "001", manufacturer: "be", coe: 90, mfr_status: "available"),
            inventory: [InventoryModel(item_stable_id: "abc123", type: "rod", quantity: 10.0, location: nil)],
            tags: [],
            userTags: []
        )

        let metadata = MyShareMetadata(displayName: "Test User")
        try await coordinator.updateMyShare(shareCode: "A7B2X9", items: [item], metadata: metadata)

        #expect(mockService.updateCalled)
        #expect(mockService.lastShareCode == "A7B2X9")
    }

    // MARK: - Delete Tests

    @Test("Should delete share")
    func testDeleteShare() async throws {
        let mockService = MockInventorySharingService()
        let coordinator = InventorySharingCoordinator(sharingService: mockService)

        try await coordinator.deleteMyShare(shareCode: "A7B2X9")

        #expect(mockService.deleteCalled)
        #expect(mockService.lastShareCode == "A7B2X9")
    }
}

// MARK: - Mock Service

class MockInventorySharingService: InventorySharingService {
    var createShareCalled = false
    var downloadCalled = false
    var updateCalled = false
    var deleteCalled = false
    var lastItems: [InventoryItemSnapshot]?
    var lastShareCode: String?
    var mockDownloadResult: SnapshotResult?

    override func createShare(items: [InventoryItemSnapshot], metadata: MyShareMetadata) async throws -> String {
        createShareCalled = true
        lastItems = items
        return "MOCK12"
    }

    override func downloadFriendInventory(shareCode: String) async throws -> SnapshotResult {
        downloadCalled = true
        lastShareCode = shareCode

        guard let result = mockDownloadResult else {
            throw SharingAPIError.notFound
        }

        return result
    }

    override func updateShare(shareCode: String, items: [InventoryItemSnapshot], metadata: MyShareMetadata) async throws {
        updateCalled = true
        lastShareCode = shareCode
        lastItems = items
    }

    override func deleteShare(shareCode: String) async throws {
        deleteCalled = true
        lastShareCode = shareCode
    }
}
