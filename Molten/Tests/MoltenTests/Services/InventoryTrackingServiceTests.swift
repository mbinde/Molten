//
//  InventoryTrackingServiceTests.swift
//  FlameworkerTests
//
//  Tests for inventory tracking service workflow functionality
//  Tests complex orchestration across multiple repositories
//

import Testing
import Foundation
import CryptoKit
@testable import Molten

@Suite("InventoryTrackingService Workflow Tests", .serialized)
@MainActor
struct InventoryTrackingServiceTests {

    // MARK: - Shared Dependencies

    /// ✅ CRITICAL: Store AppDependencies at struct level to keep PersistenceController alive
    /// This prevents Core Data zombie objects that cause crashes.
    /// See CLAUDE.md "Service Creation Anti-Pattern" - same pattern applies to tests!
    private let deps = AppDependencies(persistenceController: .createTestController())


    // MARK: - Complete Item Creation Tests

    @Test("Create complete item with all fields")
    func testCreateCompleteItemWithAllFields() async throws {
        let service = deps.inventoryTrackingService

        // Create test data with all fields
        let stableId = generateStableId(manufacturer: "cim", sku: "123")

        let glassItem = GlassItemModel(
            stable_id: stableId,
            name: "Clear Rod Test",
            sku: "123",
            manufacturer: "cim",
            mfr_notes: "Test notes",
            coe: 104,
            url: "https://example.com",
            mfr_status: "available",
            image_url: "https://example.com/image.jpg",
            image_path: "/path/to/image.jpg"
        )

        let initialInventory = [
            InventoryModel(item_stable_id: stableId, type: "rod", quantity: 10.0),
            InventoryModel(item_stable_id: stableId, type: "sheet", quantity: 5.0)
        ]

        let tags = ["transparent", "test", "high-quality"]

        let completeItem = try await service.createCompleteItem(
            glassItem,
            initialInventory: initialInventory,
            tags: tags
        )

        #expect(completeItem.glassItem.stable_id == generateStableId(manufacturer: "cim", sku: "123"))
        #expect(completeItem.glassItem.name == "Clear Rod Test")
        #expect(completeItem.inventory.count == 2)
        #expect(completeItem.tags.count == 3)
        #expect(completeItem.tags.contains("transparent"))
    }

    @Test("Create complete item with minimal fields")
    func testCreateCompleteItemMinimalFields() async throws {
        let service = deps.inventoryTrackingService

        let glassItem = GlassItemModel(
            stable_id: generateStableId(manufacturer: "cim", sku: "456"),
            name: "Minimal Item",
            sku: "456",
            manufacturer: "cim",
            mfr_notes: nil,
            coe: 96,
            url: nil,
            mfr_status: "available",
            image_url: nil,
            image_path: nil
        )

        // No inventory, no tags
        let completeItem = try await service.createCompleteItem(glassItem)

        #expect(completeItem.glassItem.stable_id == generateStableId(manufacturer: "cim", sku: "456"))
        #expect(completeItem.inventory.isEmpty)
        #expect(completeItem.tags.isEmpty)
    }

    @Test("Create complete item with empty inventory array")
    func testCreateCompleteItemEmptyInventory() async throws {
        let service = deps.inventoryTrackingService

        let glassItem = GlassItemModel(
            stable_id: generateStableId(manufacturer: "ef", sku: "789"),
            name: "Test Item",
            sku: "789",
            manufacturer: "ef",
            coe: 104,
        mfr_status: "available"
        )

        let completeItem = try await service.createCompleteItem(
            glassItem,
            initialInventory: [],
            tags: ["test"]
        )

        #expect(completeItem.inventory.isEmpty)
        #expect(completeItem.tags.count == 1)
    }

    // MARK: - Add Inventory with Locations Tests

    @Test("Add inventory with location distribution")
    func testAddInventoryWithLocations() async throws {
        let service = deps.inventoryTrackingService

        // Create base item
        let stableId = generateStableId(manufacturer: "be", sku: "001")
        let glassItem = GlassItemModel(
            stable_id: stableId,
            name: "Test Glass",
            sku: "001",
            manufacturer: "be",
            coe: 90,
        mfr_status: "available"
        )

        _ = try await service.createCompleteItem(glassItem)

        // Add inventory with locations (create separate records for each location)
        let inv1 = try await service.addInventory(
            quantity: 5.0,
            type: "rod",
            toItem: stableId,
            atLocation: "Shelf A"
        )

        let inv2 = try await service.addInventory(
            quantity: 3.0,
            type: "rod",
            toItem: stableId,
            atLocation: "Shelf B"
        )

        #expect(inv1.quantity == 5.0)
        #expect(inv1.type == "rod")
        #expect(inv1.location == "Shelf A")

        #expect(inv2.quantity == 3.0)
        #expect(inv2.type == "rod")
        #expect(inv2.location == "Shelf B")

        // Verify locations were created
        let summary = try await service.getInventorySummary(for: stableId)
        #expect(summary?.locationDetails["rod"]?.count == 2)
    }

    @Test("Add inventory without locations")
    func testAddInventoryWithoutLocations() async throws {
        let service = deps.inventoryTrackingService

        let stableId = generateStableId(manufacturer: "be", sku: "002")
        let glassItem = GlassItemModel(
            stable_id: stableId,
            name: "Test Glass",
            sku: "002",
            manufacturer: "be",
            coe: 90,
        mfr_status: "available"
        )

        _ = try await service.createCompleteItem(glassItem)

        let inventoryRecord = try await service.addInventory(
            quantity: 10.0,
            type: "sheet",
            toItem: stableId
        )

        #expect(inventoryRecord.quantity == 10.0)
        #expect(inventoryRecord.type == "sheet")
    }

    @Test("Add inventory to non-existent item throws error")
    func testAddInventoryNonExistentItem() async throws {
        let service = deps.inventoryTrackingService

        await #expect(throws: Error.self) {
            _ = try await service.addInventory(
                quantity: 10.0,
                type: "rod",
                toItem: "non-existent-key"
            )
        }
    }

    // MARK: - Cross-Type Operations Tests

    @Test("Add multiple inventory types to same item")
    func testMultipleInventoryTypes() async throws {
        let service = deps.inventoryTrackingService

        let stableId = generateStableId(manufacturer: "cim", sku: "multi")
        let glassItem = GlassItemModel(
            stable_id: stableId,
            name: "Multi-Type Glass",
            sku: "multi",
            manufacturer: "cim",
            coe: 104,
        mfr_status: "available"
        )

        _ = try await service.createCompleteItem(glassItem)

        // Add different types
        _ = try await service.addInventory(quantity: 10.0, type: "rod", toItem: stableId)
        _ = try await service.addInventory(quantity: 5.0, type: "sheet", toItem: stableId)
        _ = try await service.addInventory(quantity: 2.0, type: "frit", toItem: stableId)

        let summary = try await service.getInventorySummary(for: stableId)
        #expect(summary != nil)

        let completeItem = try await service.getCompleteItem(stableId: stableId)
        #expect(completeItem?.inventory.count == 3)
    }

    @Test("Update inventory across multiple types")
    func testUpdateMultipleTypes() async throws {
        let service = deps.inventoryTrackingService

        let stableId = generateStableId(manufacturer: "ef", sku: "update")
        let glassItem = GlassItemModel(
            stable_id: stableId,
            name: "Update Test",
            sku: "update",
            manufacturer: "ef",
            coe: 104,
        mfr_status: "available"
        )

        let initialInventory = [
            InventoryModel(item_stable_id: stableId, type: "rod", quantity: 10.0),
            InventoryModel(item_stable_id: stableId, type: "sheet", quantity: 5.0)
        ]

        _ = try await service.createCompleteItem(glassItem, initialInventory: initialInventory)

        // Add more of each type (creates NEW records, doesn't update existing)
        _ = try await service.addInventory(quantity: 5.0, type: "rod", toItem: stableId)
        _ = try await service.addInventory(quantity: 3.0, type: "sheet", toItem: stableId)

        let completeItem = try await service.getCompleteItem(stableId: stableId)

        // addInventory creates new records, so we now have 4 total (2 initial + 2 added)
        #expect(completeItem?.inventory.count == 4)

        // Verify we have multiple rod and sheet records
        let rodRecords = completeItem?.inventory.filter { $0.type == "rod" } ?? []
        let sheetRecords = completeItem?.inventory.filter { $0.type == "sheet" } ?? []

        #expect(rodRecords.count == 2)
        #expect(sheetRecords.count == 2)

        // Verify total quantities for each type
        let totalRodQuantity = rodRecords.reduce(0.0) { $0 + $1.quantity }
        let totalSheetQuantity = sheetRecords.reduce(0.0) { $0 + $1.quantity }

        #expect(totalRodQuantity == 15.0)
        #expect(totalSheetQuantity == 8.0)
    }

    // MARK: - Get Complete Item Tests

    @Test("Get complete item with all data")
    func testGetCompleteItem() async throws {
        let service = deps.inventoryTrackingService

        let stableId = generateStableId(manufacturer: "be", sku: "complete")
        let glassItem = GlassItemModel(
            stable_id: stableId,
            name: "Complete Item",
            sku: "complete",
            manufacturer: "be",
            coe: 90,
        mfr_status: "available"
        )

        let inventory = [
            InventoryModel(item_stable_id: stableId, type: "rod", quantity: 10.0)
        ]

        _ = try await service.createCompleteItem(glassItem, initialInventory: inventory, tags: ["test"])

        let completeItem = try await service.getCompleteItem(stableId: stableId)

        #expect(completeItem != nil)
        #expect(completeItem?.glassItem.name == "Complete Item")
        #expect(completeItem?.inventory.count == 1)
        #expect(completeItem?.tags.count == 1)
    }

    @Test("Get complete item returns nil for non-existent item")
    func testGetCompleteItemNonExistent() async throws {
        let service = deps.inventoryTrackingService

        let completeItem = try await service.getCompleteItem(stableId: "non-existent")
        #expect(completeItem == nil)
    }

    // MARK: - Update Complete Item Tests

    @Test("Update complete item updates glass item and tags")
    func testUpdateCompleteItem() async throws {
        let service = deps.inventoryTrackingService

        let stableId = generateStableId(manufacturer: "cim", sku: "update")
        let glassItem = GlassItemModel(
            stable_id: stableId,
            name: "Original Name",
            sku: "update",
            manufacturer: "cim",
            coe: 104,
        mfr_status: "available"
        )

        _ = try await service.createCompleteItem(glassItem, tags: ["original"])

        // Update
        let updatedGlassItem = GlassItemModel(
            stable_id: stableId,
            name: "Updated Name",
            sku: "update",
            manufacturer: "cim",
            coe: 104,
        mfr_status: "available"
        )

        let result = try await service.updateCompleteItem(
            stableId: stableId,
            updatedGlassItem: updatedGlassItem,
            updatedTags: ["updated", "new"]
        )

        #expect(result.glassItem.name == "Updated Name")
        #expect(result.tags.count == 2)
        #expect(result.tags.contains("updated"))
    }

    @Test("Update complete item without changing tags")
    func testUpdateCompleteItemKeepTags() async throws {
        let service = deps.inventoryTrackingService

        let stableId = generateStableId(manufacturer: "ef", sku: "keep")
        let glassItem = GlassItemModel(
            stable_id: stableId,
            name: "Original",
            sku: "keep",
            manufacturer: "ef",
            coe: 104,
        mfr_status: "available"
        )

        _ = try await service.createCompleteItem(glassItem, tags: ["keep-me"])

        let updatedGlassItem = GlassItemModel(
            stable_id: stableId,
            name: "Updated",
            sku: "keep",
            manufacturer: "ef",
            coe: 104,
        mfr_status: "available"
        )

        let result = try await service.updateCompleteItem(
            stableId: stableId,
            updatedGlassItem: updatedGlassItem
        )

        #expect(result.glassItem.name == "Updated")
        #expect(result.tags.count == 1)
        #expect(result.tags.contains("keep-me"))
    }

    // MARK: - Inventory Summary Tests

    @Test("Get inventory summary with locations")
    func testGetInventorySummaryWithLocations() async throws {
        let service = deps.inventoryTrackingService

        let stableId = generateStableId(manufacturer: "be", sku: "summary")
        let glassItem = GlassItemModel(
            stable_id: stableId,
            name: "Summary Test",
            sku: "summary",
            manufacturer: "be",
            coe: 90,
        mfr_status: "available"
        )

        _ = try await service.createCompleteItem(glassItem)

        // Add inventory with specific locations
        _ = try await service.addInventory(
            quantity: 5.0,
            type: "rod",
            toItem: stableId,
            atLocation: "Location A"
        )

        _ = try await service.addInventory(
            quantity: 3.0,
            type: "rod",
            toItem: stableId,
            atLocation: "Location B"
        )

        let summary = try await service.getInventorySummary(for: stableId)

        #expect(summary != nil)
        #expect(summary?.summary != nil)
        #expect(summary?.locationDetails["rod"]?.count == 2)
    }

    @Test("Get inventory summary returns nil for non-existent item")
    func testGetInventorySummaryNonExistent() async throws {
        let service = deps.inventoryTrackingService

        let summary = try await service.getInventorySummary(for: "non-existent")
        #expect(summary == nil)
    }

    // MARK: - Search Items Tests

    @Test("Search items by text")
    func testSearchItemsByText() async throws {
        let service = deps.inventoryTrackingService

        // Create test items
        let item1 = GlassItemModel(
            stable_id: generateStableId(manufacturer: "cim", sku: "search1"),
            name: "Blue Glass Rod",
            sku: "search1",
            manufacturer: "cim",
            coe: 104,
        mfr_status: "available"
        )

        let item2 = GlassItemModel(
            stable_id: generateStableId(manufacturer: "ef", sku: "search2"),
            name: "Red Glass Sheet",
            sku: "search2",
            manufacturer: "ef",
            coe: 104,
        mfr_status: "available"
        )

        _ = try await service.createCompleteItem(item1)
        _ = try await service.createCompleteItem(item2)

        let results = try await service.searchItems(text: "Blue")

        #expect(results.count >= 1)
        #expect(results.contains { $0.glassItem.name == "Blue Glass Rod" })
    }

    @Test("Search items with tag filter")
    func testSearchItemsWithTags() async throws {
        let service = deps.inventoryTrackingService

        let item1 = GlassItemModel(
            stable_id: generateStableId(manufacturer: "cim", sku: "tag1"),
            name: "Tagged Item 1",
            sku: "tag1",
            manufacturer: "cim",
            coe: 104,
        mfr_status: "available"
        )

        let item2 = GlassItemModel(
            stable_id: generateStableId(manufacturer: "ef", sku: "tag2"),
            name: "Tagged Item 2",
            sku: "tag2",
            manufacturer: "ef",
            coe: 104,
        mfr_status: "available"
        )

        _ = try await service.createCompleteItem(item1, tags: ["transparent", "test"])
        _ = try await service.createCompleteItem(item2, tags: ["opaque", "test"])

        let results = try await service.searchItems(text: "Tagged", withTags: ["transparent"])

        #expect(results.count == 1)
        #expect(results.first?.glassItem.name == "Tagged Item 1")
    }

    @Test("Search items with inventory filter")
    func testSearchItemsWithInventoryFilter() async throws {
        let service = deps.inventoryTrackingService
        let catalogService = deps.catalogService

        let stableId1 = generateStableId(manufacturer: "cim", sku: "inv1")
        let item1 = GlassItemModel(
            stable_id: stableId1,
            name: "Has Inventory",
            sku: "inv1",
            manufacturer: "cim",
            coe: 104,
        mfr_status: "available"
        )

        let stableId2 = generateStableId(manufacturer: "ef", sku: "inv2")
        let item2 = GlassItemModel(
            stable_id: stableId2,
            name: "No Inventory",
            sku: "inv2",
            manufacturer: "ef",
            coe: 104,
        mfr_status: "available"
        )

        let inventory = [InventoryModel(item_stable_id: stableId1, type: "rod", quantity: 10.0)]
        _ = try await service.createCompleteItem(item1, initialInventory: inventory)
        _ = try await service.createCompleteItem(item2)

        let results = try await service.searchItems(text: "", hasInventory: true)

        #expect(results.contains { $0.glassItem.stable_id == stableId1 })
        #expect(!results.contains { $0.glassItem.stable_id == stableId2 })
    }

    // MARK: - Low Stock Tests

    @Test("Get low stock items below threshold")
    func testGetLowStockItems() async throws {
        let service = deps.inventoryTrackingService

        // Create items with low stock
        let stableId1 = generateStableId(manufacturer: "cim", sku: "low1")
        let item1 = GlassItemModel(
            stable_id: stableId1,
            name: "Low Stock Item",
            sku: "low1",
            manufacturer: "cim",
            coe: 104,
        mfr_status: "available"
        )

        let inventory = [InventoryModel(item_stable_id: stableId1, type: "rod", quantity: 2.0)]
        _ = try await service.createCompleteItem(item1, initialInventory: inventory)

        let lowStockItems = try await service.getLowStockItems(threshold: 5.0)

        #expect(lowStockItems.count >= 1)
        #expect(lowStockItems.contains { $0.glassItem.stable_id == stableId1 })
    }

    @Test("Low stock items are sorted by quantity")
    func testLowStockItemsSorted() async throws {
        let service = deps.inventoryTrackingService

        // Create items with different low stock levels
        let stableId1 = generateStableId(manufacturer: "cim", sku: "low1")
        let item1 = GlassItemModel(
            stable_id: stableId1,
            name: "Very Low",
            sku: "low1",
            manufacturer: "cim",
            coe: 104,
        mfr_status: "available"
        )

        let stableId2 = generateStableId(manufacturer: "ef", sku: "low2")
        let item2 = GlassItemModel(
            stable_id: stableId2,
            name: "Medium Low",
            sku: "low2",
            manufacturer: "ef",
            coe: 104,
        mfr_status: "available"
        )

        let inv1 = [InventoryModel(item_stable_id: stableId1, type: "rod", quantity: 1.0)]
        let inv2 = [InventoryModel(item_stable_id: stableId2, type: "rod", quantity: 3.0)]

        _ = try await service.createCompleteItem(item1, initialInventory: inv1)
        _ = try await service.createCompleteItem(item2, initialInventory: inv2)

        let lowStockItems = try await service.getLowStockItems(threshold: 5.0)

        #expect(lowStockItems.count >= 2)

        // Should be sorted by quantity (ascending)
        if lowStockItems.count >= 2 {
            #expect(lowStockItems[0].currentQuantity <= lowStockItems[1].currentQuantity)
        }
    }

    // MARK: - Validation Tests

    @Test("Validate inventory consistency for valid item")
    func testValidateInventoryConsistency() async throws {
        let service = deps.inventoryTrackingService

        let stableId = generateStableId(manufacturer: "be", sku: "valid")
        let glassItem = GlassItemModel(
            stable_id: stableId,
            name: "Valid Item",
            sku: "valid",
            manufacturer: "be",
            coe: 90,
        mfr_status: "available"
        )

        _ = try await service.createCompleteItem(glassItem)

        // Add inventory with locations to ensure consistency
        let locations: [(location: String, quantity: Double)] = [
            (location: "Shelf A", quantity: 10.0)
        ]

        _ = try await service.addInventory(
            quantity: 10.0,
            type: "rod",
            toItem: stableId
        )

        let validation = try await service.validateInventoryConsistency(for: stableId)

        #expect(validation.isValid == true)
        #expect(validation.errors.isEmpty)
    }

    @Test("Validate inventory consistency for non-existent item")
    func testValidateNonExistentItem() async throws {
        let service = deps.inventoryTrackingService

        let validation = try await service.validateInventoryConsistency(for: "non-existent")

        #expect(validation.isValid == false)
        #expect(validation.errors.contains { $0.contains("not found") })
    }

    // MARK: - Edge Cases

    @Test("Create item with duplicate tags removes duplicates")
    func testCreateItemDuplicateTags() async throws {
        let service = deps.inventoryTrackingService

        let glassItem = GlassItemModel(
            stable_id: generateStableId(manufacturer: "cim", sku: "dup"),
            name: "Duplicate Tags",
            sku: "dup",
            manufacturer: "cim",
            coe: 104,
        mfr_status: "available"
        )

        let completeItem = try await service.createCompleteItem(
            glassItem,
            tags: ["test", "duplicate", "test", "duplicate"]
        )

        // Tags should be deduplicated
        #expect(completeItem.tags.count <= 2)
    }

    @Test("Add zero quantity inventory throws error")
    func testAddZeroQuantityInventory() async throws {
        let service = deps.inventoryTrackingService

        let stableId = generateStableId(manufacturer: "be", sku: "zero")
        let glassItem = GlassItemModel(
            stable_id: stableId,
            name: "Zero Test",
            sku: "zero",
            manufacturer: "be",
            coe: 90,
        mfr_status: "available"
        )

        _ = try await service.createCompleteItem(glassItem)

        await #expect(throws: InventoryServiceError.self) {
            try await service.addInventory(
                quantity: 0.0,
                type: "rod",
                toItem: stableId
            )
        }
    }

    @Test("Search with empty text returns results")
    func testSearchEmptyText() async throws {
        let service = deps.inventoryTrackingService

        let glassItem = GlassItemModel(
            stable_id: generateStableId(manufacturer: "cim", sku: "empty"),
            name: "Empty Search Test",
            sku: "empty",
            manufacturer: "cim",
            coe: 104,
        mfr_status: "available"
        )

        _ = try await service.createCompleteItem(glassItem)

        let results = try await service.searchItems(text: "")

        #expect(results.count >= 1)
    }
}
