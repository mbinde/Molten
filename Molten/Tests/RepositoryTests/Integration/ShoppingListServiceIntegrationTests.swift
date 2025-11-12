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

    // MARK: - Test Setup

    private func createTestEnvironment() async -> (ShoppingListService, CatalogService, InventoryTrackingService, PersistenceController) {
        let testController = PersistenceController.createTestController()
        let deps = AppDependencies(forTesting: true)

        let shoppingService = deps.shoppingListService
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService

        return (shoppingService, catalogService, inventoryService, testController)
    }

    // MARK: - Shopping List Generation Tests

    @Test("ShoppingListService generates list when inventory below minimum")
    func testGenerateShoppingListBelowMinimum() async throws {
        let (shoppingService, catalogService, inventoryService, _) = await createTestEnvironment()

        // Create glass item
        let glassItem = GlassItemModel(
            stable_id: "shop-test-001",
            name: "Clear Rod",
            sku: "001",
            manufacturer: "Bullseye",
            coe: 90,
            mfr_status: "available"
        )

        try await catalogService.createGlassItem(glassItem)

        // Set minimum threshold
        try await shoppingService.setMinimum(
            forItem: "shop-test-001",
            type: "rod",
            quantity: 10.0,
            store: "TestStore"
        )

        // Add current inventory (below minimum)
        try await inventoryService.addInventory(
            quantity: 3.0,
            type: "rod",
            toItem: "shop-test-001"
        )

        // Generate shopping list
        let shoppingList = try await shoppingService.generateShoppingList(forStore: "TestStore")

        #expect(shoppingList.items.count == 1)
        #expect(shoppingList.items.first?.glassItem.name == "Clear Rod")
        #expect(shoppingList.items.first?.shoppingListItem.neededQuantity == 7.0) // 10 - 3
    }

    @Test("ShoppingListService excludes items at or above minimum")
    func testExcludeItemsAboveMinimum() async throws {
        let (shoppingService, catalogService, inventoryService, _) = await createTestEnvironment()

        // Create glass item
        let glassItem = GlassItemModel(
            stable_id: "shop-test-002",
            name: "Blue Rod",
            sku: "002",
            manufacturer: "Bullseye",
            coe: 90,
            mfr_status: "available"
        )

        try await catalogService.createGlassItem(glassItem)

        // Set minimum threshold
        try await shoppingService.setMinimum(
            forItem: "shop-test-002",
            type: "rod",
            quantity: 10.0,
            store: "TestStore"
        )

        // Add current inventory (at minimum)
        try await inventoryService.addInventory(
            quantity: 10.0,
            type: "rod",
            toItem: "shop-test-002"
        )

        // Generate shopping list
        let shoppingList = try await shoppingService.generateShoppingList(forStore: "TestStore")

        #expect(shoppingList.items.isEmpty)
    }

    @Test("ShoppingListService filters by store correctly")
    func testStoreFiltering() async throws {
        let (shoppingService, catalogService, inventoryService, _) = await createTestEnvironment()

        // Create items for different stores
        for (id, store) in [("item-a", "Store A"), ("item-b", "Store B")] {
            let glassItem = GlassItemModel(
                stable_id: id,
                name: "Item \(id)",
                sku: id,
                manufacturer: "Bullseye",
                coe: 90,
                mfr_status: "available"
            )
            try await catalogService.createGlassItem(glassItem)

            try await shoppingService.setMinimum(
                forItem: id,
                type: "rod",
                quantity: 10.0,
                store: store
            )

            try await inventoryService.addInventory(
                quantity: 2.0,
                type: "rod",
                toItem: id
            )
        }

        // Generate list for Store A only
        let storeAList = try await shoppingService.generateShoppingList(forStore: "Store A")

        #expect(storeAList.items.count == 1)
        #expect(storeAList.items.first?.glassItem.stable_id == "item-a")

        // Generate list for Store B only
        let storeBList = try await shoppingService.generateShoppingList(forStore: "Store B")

        #expect(storeBList.items.count == 1)
        #expect(storeBList.items.first?.glassItem.stable_id == "item-b")
    }
}
