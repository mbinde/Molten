//
//  ShoppingListServiceIntegrationTests.swift
//  RepositoryTests
//
//  Integration tests for ShoppingListService with actual Core Data persistence
//  Tests coordination between ItemMinimum, Inventory, GlassItem, and Tags repositories
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

@Suite("ShoppingListService Integration Tests", .serialized)
@MainActor
struct ShoppingListServiceIntegrationTests {

    // MARK: - Shared Dependencies

    /// ✅ CRITICAL: Store AppDependencies at struct level to keep PersistenceController alive
    /// This prevents Core Data zombie objects that cause crashes.
    /// See CLAUDE.md "Service Creation Anti-Pattern" - same pattern applies to tests!
    private let deps = AppDependencies(persistenceController: .createTestController())

    // MARK: - Test Setup

    private func createTestEnvironment() async -> (ShoppingListService, CatalogService, InventoryTrackingService, PersistenceController) {
        let testController = PersistenceController.createTestController()

        let shoppingService = deps.shoppingListService
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService

        return (shoppingService, catalogService, inventoryService, testController)
    }

    // MARK: - Shopping List Generation Tests

    @Test("ShoppingListService generates list when inventory below minimum")
    func testGenerateShoppingListBelowMinimum() async throws {
        let (shoppingService, catalogService, inventoryService, _) = await createTestEnvironment()

        // Use real catalog data (catalog is read-only)
        let catalogItems = try await catalogService.getGlassItemsLightweight()
        let glassItem = try catalogItems.first(where: { $0.sku != nil })!
        let stableId = glassItem.stable_id

        // Set minimum threshold
        try await shoppingService.setMinimum(
            forItem: stableId,
            type: "rod",
            quantity: 10.0,
            store: "TestStore"
        )

        // Add current inventory (below minimum)
        try await inventoryService.addInventory(
            quantity: 3.0,
            type: "rod",
            toItem: stableId
        )

        // Generate shopping list
        let shoppingList = try await shoppingService.generateShoppingList(forStore: "TestStore")

        #expect(shoppingList.items.count == 1)
        #expect(shoppingList.items.first?.catalogItem.stable_id == stableId)
        #expect(shoppingList.items.first?.shoppingListItem.neededQuantity == 7.0) // 10 - 3
    }

    @Test("ShoppingListService excludes items at or above minimum")
    func testExcludeItemsAboveMinimum() async throws {
        let (shoppingService, catalogService, inventoryService, _) = await createTestEnvironment()

        // Use real catalog data (catalog is read-only)
        let catalogItems = try await catalogService.getGlassItemsLightweight()
        let glassItem = try catalogItems.filter({ $0.sku != nil })[1] // Use second item
        let stableId = glassItem.stable_id

        // Set minimum threshold
        try await shoppingService.setMinimum(
            forItem: stableId,
            type: "rod",
            quantity: 10.0,
            store: "TestStore"
        )

        // Add current inventory (at minimum)
        try await inventoryService.addInventory(
            quantity: 10.0,
            type: "rod",
            toItem: stableId
        )

        // Generate shopping list
        let shoppingList = try await shoppingService.generateShoppingList(forStore: "TestStore")

        #expect(shoppingList.items.isEmpty)
    }

    @Test("ShoppingListService filters by store correctly")
    func testStoreFiltering() async throws {
        let (shoppingService, catalogService, inventoryService, _) = await createTestEnvironment()

        // Use real catalog data (catalog is read-only)
        let catalogItems = try await catalogService.getGlassItemsLightweight()
        let realItems = Array(catalogItems.filter({ $0.sku != nil }).prefix(2))
        let itemA = realItems[0]
        let itemB = realItems[1]

        // Create items for different stores
        for (item, store) in [(itemA, "Store A"), (itemB, "Store B")] {
            try await shoppingService.setMinimum(
                forItem: item.stable_id,
                type: "rod",
                quantity: 10.0,
                store: store
            )

            try await inventoryService.addInventory(
                quantity: 2.0,
                type: "rod",
                toItem: item.stable_id
            )
        }

        // Generate list for Store A only
        let storeAList = try await shoppingService.generateShoppingList(forStore: "Store A")

        #expect(storeAList.items.count == 1)
        #expect(storeAList.items.first?.catalogItem.stable_id == itemA.stable_id)

        // Generate list for Store B only
        let storeBList = try await shoppingService.generateShoppingList(forStore: "Store B")

        #expect(storeBList.items.count == 1)
        #expect(storeBList.items.first?.catalogItem.stable_id == itemB.stable_id)
    }
}
