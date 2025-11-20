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

    // Helper to get real catalog items (catalog is read-only)
    private func getRealCatalogItems() async throws -> [GlassItemModel] {
        let catalogService = deps.catalogService
        let catalogItems = try await catalogService.getGlassItemsLightweight()
        return Array(catalogItems.filter { $0.sku != nil }.prefix(10))
    }

    // MARK: - Complete Item Creation Tests

    @Test("Create complete item with all fields")
    func testCreateCompleteItemWithAllFields() async throws {
        let service = deps.inventoryTrackingService

        // Use real catalog data (catalog is read-only)
        let catalogItems = try await getRealCatalogItems()
        let glassItem = catalogItems[0]
        let stableId = glassItem.stable_id

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

        #expect(completeItem.glassItem.stable_id == stableId)
        #expect(completeItem.inventory.count == 2)
        #expect(completeItem.tags.count == 3)
        #expect(completeItem.tags.contains("transparent"))
    }

    @Test("Create complete item with minimal fields")
    func testCreateCompleteItemMinimalFields() async throws {
        let service = deps.inventoryTrackingService

        // Use real catalog data (catalog is read-only)
        let catalogItems = try await getRealCatalogItems()
        let glassItem = catalogItems[1]

        // No inventory, no tags
        let completeItem = try await service.createCompleteItem(glassItem)

        #expect(completeItem.glassItem.stable_id == glassItem.stable_id)
        #expect(completeItem.inventory.isEmpty)
        #expect(completeItem.tags.isEmpty)
    }

    @Test("Create complete item with empty inventory array")
    func testCreateCompleteItemEmptyInventory() async throws {
        let service = deps.inventoryTrackingService

        // Use real catalog data (catalog is read-only)
        let catalogItems = try await getRealCatalogItems()
        let glassItem = catalogItems[2]

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

        // Use real catalog data (catalog is read-only)
        let catalogItems = try await getRealCatalogItems()
        let glassItem = catalogItems[3]
        let stableId = glassItem.stable_id

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

        // Use real catalog data (catalog is read-only)
        let catalogItems = try await getRealCatalogItems()
        let glassItem = catalogItems[4]
        let stableId = glassItem.stable_id

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

        // Use real catalog data (catalog is read-only)
        let catalogItems = try await getRealCatalogItems()
        let glassItem = catalogItems[5]
        let stableId = glassItem.stable_id

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

        // Use real catalog data (catalog is read-only)
        let catalogItems = try await getRealCatalogItems()
        let glassItem = catalogItems[6]
        let stableId = glassItem.stable_id

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

        // Use real catalog data (catalog is read-only)
        let catalogItems = try await getRealCatalogItems()
        let glassItem = catalogItems[7]
        let stableId = glassItem.stable_id

        let inventory = [
            InventoryModel(item_stable_id: stableId, type: "rod", quantity: 10.0)
        ]

        _ = try await service.createCompleteItem(glassItem, initialInventory: inventory, tags: ["test"])

        let completeItem = try await service.getCompleteItem(stableId: stableId)

        #expect(completeItem != nil)
        #expect(completeItem?.glassItem.stable_id == stableId)
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

        // Use real catalog data (catalog is read-only)
        let catalogItems = try await getRealCatalogItems()
        let glassItem = catalogItems[8]
        let stableId = glassItem.stable_id

        _ = try await service.createCompleteItem(glassItem, tags: ["original"])

        // Update
        let updatedGlassItem = GlassItemModel(
            stable_id: stableId,
            name: "Updated Name",
            sku: glassItem.sku,
            manufacturer: glassItem.manufacturer,
            coe: glassItem.coe,
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

        // Use real catalog data (catalog is read-only)
        let catalogItems = try await getRealCatalogItems()
        let glassItem = catalogItems[9]
        let stableId = glassItem.stable_id

        _ = try await service.createCompleteItem(glassItem, tags: ["keep-me"])

        let updatedGlassItem = GlassItemModel(
            stable_id: stableId,
            name: "Updated",
            sku: glassItem.sku,
            manufacturer: glassItem.manufacturer,
            coe: glassItem.coe,
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
        let catalogService = deps.catalogService

        // Use real catalog data (catalog is read-only)
        let catalogItems = try await catalogService.getGlassItemsLightweight()
        let glassItem = try catalogItems.first(where: { $0.sku != nil })!
        let stableId = glassItem.stable_id

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
        let catalogService = deps.catalogService

        // Use real catalog data (catalog is read-only)
        let catalogItems = try await catalogService.getGlassItemsLightweight()
        let realItems = Array(catalogItems.filter({ $0.sku != nil }).prefix(2))
        let item1 = realItems[0]
        let item2 = realItems[1]

        _ = try await service.createCompleteItem(item1)
        _ = try await service.createCompleteItem(item2)

        // Search using the first item's name
        let results = try await service.searchItems(text: item1.name)

        #expect(results.count >= 1)
        #expect(results.contains { $0.glassItem.name == item1.name })
    }

    @Test("Search items with tag filter")
    func testSearchItemsWithTags() async throws {
        let service = deps.inventoryTrackingService
        let catalogService = deps.catalogService

        // Use real catalog data (catalog is read-only)
        let catalogItems = try await catalogService.getGlassItemsLightweight()
        let realItems = Array(catalogItems.filter({ $0.sku != nil }).prefix(2))
        let item1 = realItems[0]
        let item2 = realItems[1]

        _ = try await service.createCompleteItem(item1, tags: ["transparent", "test"])
        _ = try await service.createCompleteItem(item2, tags: ["opaque", "test"])

        let results = try await service.searchItems(text: item1.name, withTags: ["transparent"])

        #expect(results.count == 1)
        #expect(results.first?.glassItem.name == item1.name)
    }

    @Test("Search items with inventory filter")
    func testSearchItemsWithInventoryFilter() async throws {
        let service = deps.inventoryTrackingService
        let catalogService = deps.catalogService

        // Use real catalog data (catalog is read-only)
        let catalogItems = try await catalogService.getGlassItemsLightweight()
        let realItems = Array(catalogItems.filter({ $0.sku != nil }).prefix(2))
        let item1 = realItems[0]
        let item2 = realItems[1]

        let inventory = [InventoryModel(item_stable_id: item1.stable_id, type: "rod", quantity: 10.0)]
        _ = try await service.createCompleteItem(item1, initialInventory: inventory)
        _ = try await service.createCompleteItem(item2)

        let results = try await service.searchItems(text: "", hasInventory: true)

        #expect(results.contains { $0.glassItem.stable_id == item1.stable_id })
        #expect(!results.contains { $0.glassItem.stable_id == item2.stable_id })
    }

    // MARK: - Low Stock Tests

    @Test("Get low stock items below threshold")
    func testGetLowStockItems() async throws {
        let service = deps.inventoryTrackingService
        let catalogService = deps.catalogService

        // Use real catalog data (catalog is read-only)
        let catalogItems = try await catalogService.getGlassItemsLightweight()
        let item1 = try catalogItems.first(where: { $0.sku != nil })!

        let inventory = [InventoryModel(item_stable_id: item1.stable_id, type: "rod", quantity: 2.0)]
        _ = try await service.createCompleteItem(item1, initialInventory: inventory)

        let lowStockItems = try await service.getLowStockItems(threshold: 5.0)

        #expect(lowStockItems.count >= 1)
        #expect(lowStockItems.contains { $0.glassItem.stable_id == item1.stable_id })
    }

    @Test("Low stock items are sorted by quantity")
    func testLowStockItemsSorted() async throws {
        let service = deps.inventoryTrackingService
        let catalogService = deps.catalogService

        // Use real catalog data (catalog is read-only)
        let catalogItems = try await catalogService.getGlassItemsLightweight()
        let realItems = Array(catalogItems.filter({ $0.sku != nil }).prefix(2))
        let item1 = realItems[0]
        let item2 = realItems[1]

        let inv1 = [InventoryModel(item_stable_id: item1.stable_id, type: "rod", quantity: 1.0)]
        let inv2 = [InventoryModel(item_stable_id: item2.stable_id, type: "rod", quantity: 3.0)]

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
        let catalogService = deps.catalogService

        // Use real catalog data (catalog is read-only)
        let catalogItems = try await catalogService.getGlassItemsLightweight()
        let glassItem = try catalogItems.first(where: { $0.sku != nil })!
        let stableId = glassItem.stable_id

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
        let catalogService = deps.catalogService

        // Use real catalog data (catalog is read-only)
        let catalogItems = try await catalogService.getGlassItemsLightweight()
        let glassItem = try catalogItems.first(where: { $0.sku != nil })!

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
        let catalogService = deps.catalogService

        // Use real catalog data (catalog is read-only)
        let catalogItems = try await catalogService.getGlassItemsLightweight()
        let glassItem = try catalogItems.first(where: { $0.sku != nil })!
        let stableId = glassItem.stable_id

        _ = try await service.createCompleteItem(glassItem)

        await #expect(throws: InventoryTrackingServiceError.self) {
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
        let catalogService = deps.catalogService

        // Use real catalog data (catalog is read-only)
        let catalogItems = try await catalogService.getGlassItemsLightweight()
        let glassItem = try catalogItems.first(where: { $0.sku != nil })!

        _ = try await service.createCompleteItem(glassItem)

        let results = try await service.searchItems(text: "")

        #expect(results.count >= 1)
    }
}
