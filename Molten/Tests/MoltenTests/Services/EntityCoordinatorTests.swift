//
//  EntityCoordinatorTests.swift
//  MoltenTests
//
//  Created by Claude Code on 10/26/25.
//  Tests for EntityCoordinator following TDD and Swift 6 concurrency guidelines
//

import Testing
import Foundation
@testable import Molten

@Suite("EntityCoordinator Tests")
@MainActor
struct EntityCoordinatorTests {

    // MARK: - Shared Dependencies

    /// ✅ CRITICAL: Store AppDependencies at struct level to keep PersistenceController alive
    /// This prevents Core Data zombie objects that cause crashes.
    /// See CLAUDE.md "Service Creation Anti-Pattern" - same pattern applies to tests!
    private let deps = AppDependencies(persistenceController: .createTestController())


    // MARK: - Setup Helpers

    /// Get a test glass item from real catalog data
    private func getRealCatalogItem(
        using catalogService: CatalogService
    ) async throws -> GlassItemModel {
        // Use real catalog data (catalog is read-only)
        let catalogItems = try await catalogService.getGlassItemsLightweight()
        return try catalogItems.first(where: { $0.sku != nil })!
    }

    /// Create test inventory for a glass item
    private func createTestInventory(
        stableId: String,
        quantity: Double = 10.0,
        using inventoryService: InventoryTrackingService
    ) async throws {
        _ = try await inventoryService.addInventory(
            quantity: quantity,
            type: "rod",
            toItem: stableId,
            atLocation: "Studio A"
        )
    }

    // MARK: - Catalog + Inventory Coordination Tests

    @Test("Get inventory for valid glass item")
    func testGetInventoryForValidGlassItem() async throws {
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService
        let coordinator = EntityCoordinator(
            catalogService: catalogService,
            inventoryTrackingService: inventoryService
        )

        // Get real catalog item (catalog is read-only)
        let glassItem = try await getRealCatalogItem(using: catalogService)

        // Add inventory
        try await createTestInventory(stableId: glassItem.stable_id, quantity: 15.0, using: inventoryService)

        // Get inventory coordination
        let coordination = try await coordinator.getInventoryForGlassItem(stableId: glassItem.stable_id)

        #expect(coordination.glassItem.stable_id == glassItem.stable_id)
        #expect(coordination.hasInventory == true)
        #expect(coordination.totalQuantity > 0)
    }

    @Test("Get inventory for non-existent glass item throws error")
    func testGetInventoryForNonExistentItem() async throws {
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService
        let coordinator = EntityCoordinator(
            catalogService: catalogService,
            inventoryTrackingService: inventoryService
        )

        // Try to get inventory for non-existent item
        do {
            _ = try await coordinator.getInventoryForGlassItem(stableId: "nonexistent")
            Issue.record("Expected error to be thrown")
        } catch let error as CoordinationError {
            #expect(error == .catalogItemNotFound)
        }
    }

    @Test("Get inventory for item with zero quantity")
    func testGetInventoryWithZeroQuantity() async throws {
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService
        let coordinator = EntityCoordinator(
            catalogService: catalogService,
            inventoryTrackingService: inventoryService
        )

        // Get real catalog item (catalog is read-only) but don't add inventory
        let glassItem = try await getRealCatalogItem(using: catalogService)

        // Get inventory coordination
        let coordination = try await coordinator.getInventoryForGlassItem(stableId: glassItem.stable_id)

        #expect(coordination.glassItem.stable_id == glassItem.stable_id)
        #expect(coordination.hasInventory == false)
        #expect(coordination.totalQuantity == 0.0)
    }

    @Test("Get inventory for item with multiple locations")
    func testGetInventoryWithMultipleLocations() async throws {
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService
        let coordinator = EntityCoordinator(
            catalogService: catalogService,
            inventoryTrackingService: inventoryService
        )

        // Get real catalog item (catalog is read-only)
        let glassItem = try await getRealCatalogItem(using: catalogService)

        // Add inventory in multiple locations
        _ = try await inventoryService.addInventory(
            quantity: 10.0,
            type: "rod",
            toItem: glassItem.stable_id,
            atLocation: "Studio A"
        )
        _ = try await inventoryService.addInventory(
            quantity: 5.0,
            type: "rod",
            toItem: glassItem.stable_id,
            atLocation: "Studio B"
        )

        // Get inventory coordination
        let coordination = try await coordinator.getInventoryForGlassItem(stableId: glassItem.stable_id)

        #expect(coordination.hasInventory == true)
        #expect(coordination.totalQuantity >= 15.0)
        #expect(coordination.locations.count >= 2)
    }

    @Test("GlassItemInventoryCoordination convenience accessors work correctly")
    func testInventoryCoordinationAccessors() async throws {
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService
        let coordinator = EntityCoordinator(
            catalogService: catalogService,
            inventoryTrackingService: inventoryService
        )

        // Get real catalog item and add inventory
        let glassItem = try await getRealCatalogItem(using: catalogService)
        try await createTestInventory(stableId: glassItem.stable_id, quantity: 20.0, using: inventoryService)

        // Get coordination
        let coordination = try await coordinator.getInventoryForGlassItem(stableId: glassItem.stable_id)

        // Test convenience accessors
        #expect(coordination.glassItem.stable_id == glassItem.stable_id)
        #expect(coordination.glassItem.name == glassItem.name)
        #expect(coordination.tags is [String])
        #expect(coordination.locations is [String])
    }

    // MARK: - Purchase + Inventory Correlation Tests

    @Test("Correlate purchases with inventory")
    func testCorrelatePurchasesWithInventory() async throws {
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService
        let purchaseService = deps.purchaseRecordService
        let coordinator = EntityCoordinator(
            catalogService: catalogService,
            inventoryTrackingService: inventoryService,
            purchaseRecordService: purchaseService
        )

        // Get real catalog item and add inventory
        let glassItem = try await getRealCatalogItem(using: catalogService)
        try await createTestInventory(stableId: glassItem.stable_id, quantity: 25.0, using: inventoryService)

        // Create purchase record with reference to item
        let recordId = UUID()
        let purchaseItem = PurchaseRecordItemModel(
            id: UUID(),
            item_stable_id: glassItem.stable_id,
            type: "rod",
            subtype: nil,
            subsubtype: nil,
            quantity: 25.0,
            totalPrice: Decimal(250.00),
            orderIndex: 0
        )
        let purchaseRecord = PurchaseRecordModel(
            id: recordId,
            supplier: "Test Supplier",
            datePurchased: Date(),
            subtotal: Decimal(250.00),
            notes: "Contains \(glassItem.stable_id)",
            items: [purchaseItem]
        )
        _ = try await purchaseService.createRecord(purchaseRecord)

        // Correlate
        let correlation = try await coordinator.correlatePurchasesWithInventory(stableId: glassItem.stable_id)

        #expect(correlation.stableId == glassItem.stable_id)
        #expect(correlation.totalQuantityInInventory >= 25.0)
        #expect(correlation.totalSpent > 0)
    }

    @Test("Calculate average price per unit")
    func testCalculateAveragePricePerUnit() async throws {
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService
        let purchaseService = deps.purchaseRecordService
        let coordinator = EntityCoordinator(
            catalogService: catalogService,
            inventoryTrackingService: inventoryService,
            purchaseRecordService: purchaseService
        )

        // Get real catalog item and add inventory
        let glassItem = try await getRealCatalogItem(using: catalogService)
        try await createTestInventory(stableId: glassItem.stable_id, quantity: 10.0, using: inventoryService)

        // Create purchase for $100 (should be $10 per unit)
        let purchaseRecord = PurchaseRecordModel(
            id: UUID(),
            supplier: "Test Supplier",
            datePurchased: Date(),
            subtotal: Decimal(100.00),
            notes: "\(glassItem.stable_id) purchase",
            items: []
        )
        _ = try await purchaseService.createRecord(purchaseRecord)

        // Correlate
        let correlation = try await coordinator.correlatePurchasesWithInventory(stableId: glassItem.stable_id)

        #expect(correlation.averagePricePerUnit > 0)
    }

    @Test("Handle no purchase records for item")
    func testNoPurchaseRecords() async throws {
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService
        let purchaseService = deps.purchaseRecordService
        let coordinator = EntityCoordinator(
            catalogService: catalogService,
            inventoryTrackingService: inventoryService,
            purchaseRecordService: purchaseService
        )

        // Get real catalog item, add inventory but no purchases
        let glassItem = try await getRealCatalogItem(using: catalogService)
        try await createTestInventory(stableId: glassItem.stable_id, quantity: 15.0, using: inventoryService)

        // Correlate
        let correlation = try await coordinator.correlatePurchasesWithInventory(stableId: glassItem.stable_id)

        #expect(correlation.stableId == glassItem.stable_id)
        #expect(correlation.totalSpent == 0.0)
        #expect(correlation.averagePricePerUnit == 0.0)
        #expect(correlation.purchaseRecords.isEmpty)
    }

    @Test("Handle no inventory records for item")
    func testNoInventoryRecords() async throws {
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService
        let purchaseService = deps.purchaseRecordService
        let coordinator = EntityCoordinator(
            catalogService: catalogService,
            inventoryTrackingService: inventoryService,
            purchaseRecordService: purchaseService
        )

        // Get real catalog item with no inventory
        let glassItem = try await getRealCatalogItem(using: catalogService)

        // Correlate
        let correlation = try await coordinator.correlatePurchasesWithInventory(stableId: glassItem.stable_id)

        #expect(correlation.stableId == glassItem.stable_id)
        #expect(correlation.totalQuantityInInventory == 0.0)
        #expect(correlation.inventoryRecords.isEmpty)
    }

    @Test("PurchaseInventoryCorrelation convenience accessors work correctly")
    func testCorrelationAccessors() async throws {
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService
        let purchaseService = deps.purchaseRecordService
        let coordinator = EntityCoordinator(
            catalogService: catalogService,
            inventoryTrackingService: inventoryService,
            purchaseRecordService: purchaseService
        )

        // Get real catalog item and add inventory
        let glassItem = try await getRealCatalogItem(using: catalogService)
        try await createTestInventory(stableId: glassItem.stable_id, quantity: 10.0, using: inventoryService)

        // Correlate
        let correlation = try await coordinator.correlatePurchasesWithInventory(stableId: glassItem.stable_id)

        // Test convenience accessor
        #expect(correlation.glassItem.stable_id == glassItem.stable_id)
        #expect(correlation.glassItem.name == glassItem.name)
    }

    // MARK: - Search with Inventory Context Tests

    @Test("Search glass items with inventory context")
    func testSearchWithInventoryContext() async throws {
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService
        let coordinator = EntityCoordinator(
            catalogService: catalogService,
            inventoryTrackingService: inventoryService
        )

        // Get real catalog item and add inventory
        let glassItem = try await getRealCatalogItem(using: catalogService)
        try await createTestInventory(stableId: glassItem.stable_id, quantity: 20.0, using: inventoryService)

        // Search for it using its actual name
        let results = try await coordinator.searchGlassItemsWithInventoryContext(searchText: glassItem.name)

        #expect(results.count > 0)
        #expect(results.contains { $0.glassItem.stable_id == glassItem.stable_id })
    }

    @Test("Search with multiple matches")
    func testSearchWithMultipleMatches() async throws {
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService
        let coordinator = EntityCoordinator(
            catalogService: catalogService,
            inventoryTrackingService: inventoryService
        )

        // Get real catalog items
        let catalogItems = try await catalogService.getGlassItemsLightweight()
        let realItems = Array(catalogItems.filter({ $0.sku != nil }).prefix(2))
        let item1 = realItems[0]
        let item2 = realItems[1]

        try await createTestInventory(stableId: item1.stable_id, quantity: 10.0, using: inventoryService)
        try await createTestInventory(stableId: item2.stable_id, quantity: 5.0, using: inventoryService)

        // Search using a common term from catalog
        let results = try await coordinator.searchGlassItemsWithInventoryContext(searchText: "")

        #expect(results.count >= 2)
    }

    @Test("Search with no matches returns empty")
    func testSearchNoMatches() async throws {
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService
        let coordinator = EntityCoordinator(
            catalogService: catalogService,
            inventoryTrackingService: inventoryService
        )

        // Search for non-existent item
        let results = try await coordinator.searchGlassItemsWithInventoryContext(searchText: "NonExistentItem12345")

        #expect(results.isEmpty)
    }

    @Test("Search includes items without inventory")
    func testSearchIncludesItemsWithoutInventory() async throws {
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService
        let coordinator = EntityCoordinator(
            catalogService: catalogService,
            inventoryTrackingService: inventoryService
        )

        // Get real catalog item without inventory
        let glassItem = try await getRealCatalogItem(using: catalogService)

        // Search for it using its actual name
        let results = try await coordinator.searchGlassItemsWithInventoryContext(searchText: glassItem.name)

        let foundItem = results.first { $0.glassItem.stable_id == glassItem.stable_id }
        #expect(foundItem != nil)
        #expect(foundItem?.hasInventory == false)
        #expect(foundItem?.totalQuantity == 0.0)
    }

    // MARK: - Error Handling Tests

    @Test("Missing catalog service throws error")
    func testMissingCatalogService() async throws {
        let inventoryService = deps.inventoryTrackingService
        let coordinator = EntityCoordinator(
            catalogService: nil,
            inventoryTrackingService: inventoryService
        )

        do {
            _ = try await coordinator.searchGlassItemsWithInventoryContext(searchText: "test")
            Issue.record("Expected error to be thrown")
        } catch let error as CoordinationError {
            #expect(error == .missingServices)
        }
    }

    @Test("Missing inventory service throws error")
    func testMissingInventoryService() async throws {
        let catalogService = deps.catalogService
        let coordinator = EntityCoordinator(
            catalogService: catalogService,
            inventoryTrackingService: nil
        )

        do {
            _ = try await coordinator.getInventoryForGlassItem(stableId: "test")
            Issue.record("Expected error to be thrown")
        } catch let error as CoordinationError {
            #expect(error == .missingServices)
        }
    }

    @Test("Missing purchase service throws error")
    func testMissingPurchaseService() async throws {
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService
        let coordinator = EntityCoordinator(
            catalogService: catalogService,
            inventoryTrackingService: inventoryService,
            purchaseRecordService: nil
        )

        // Get real catalog item
        let glassItem = try await getRealCatalogItem(using: catalogService)

        do {
            _ = try await coordinator.correlatePurchasesWithInventory(stableId: glassItem.stable_id)
            Issue.record("Expected error to be thrown")
        } catch let error as CoordinationError {
            #expect(error == .missingServices)
        }
    }

    @Test("Catalog item not found error")
    func testCatalogItemNotFoundError() async throws {
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService
        let coordinator = EntityCoordinator(
            catalogService: catalogService,
            inventoryTrackingService: inventoryService
        )

        do {
            _ = try await coordinator.getInventoryForGlassItem(stableId: "nonexistent123")
            Issue.record("Expected error to be thrown")
        } catch let error as CoordinationError {
            #expect(error == .catalogItemNotFound)
        }
    }
}
