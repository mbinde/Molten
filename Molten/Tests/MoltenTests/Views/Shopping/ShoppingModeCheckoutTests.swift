//
//  ShoppingModeCheckoutTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/19/25.
//  Tests for shopping mode checkout operations (add to inventory, remove from list)
//

import Testing
import Foundation
import CryptoKit
@testable import Molten

/// Tests for checkout operations in shopping mode
@Suite("Shopping Mode Checkout Tests", .serialized)
@MainActor
struct ShoppingModeCheckoutTests {

    // MARK: - Shared Dependencies

    /// ✅ CRITICAL: Store AppDependencies at struct level to keep PersistenceController alive
    /// This prevents Core Data zombie objects that cause crashes.
    /// See CLAUDE.md "Service Creation Anti-Pattern" - same pattern applies to tests!
    private let deps = AppDependencies(persistenceController: .createTestController())

    // MARK: - Add to Inventory Tests

    @Test("Can add basket items to inventory")
    func testAddBasketItemsToInventory() async throws {
        let inventoryService = deps.inventoryTrackingService
        let catalogService = deps.catalogService

        // Use real catalog data (catalog is read-only)
        let catalogItems = try await catalogService.getGlassItemsLightweight()
        let glassItem = try catalogItems.first(where: { $0.sku != nil })!

        // Create the item with zero initial inventory
        _ = try await inventoryService.createCompleteItem(glassItem, initialInventory: [])

        // Verify starting inventory is zero
        let startInventory = try await inventoryService.inventoryRepository.getTotalQuantity(
            forItem: glassItem.stable_id,
            type: "rod"
        )
        #expect(startInventory == 0.0)

        // Add quantity to inventory (simulating checkout)
        let addedQuantity = 5.0
        _ = try await inventoryService.addInventory(
            quantity: addedQuantity,
            type: "rod",
            toItem: glassItem.stable_id
        )

        // Verify inventory was added
        let endInventory = try await inventoryService.inventoryRepository.getTotalQuantity(
            forItem: glassItem.stable_id,
            type: "rod"
        )
        #expect(endInventory == addedQuantity)
    }

    @Test("Can add multiple basket items to inventory in batch")
    func testAddMultipleItemsToInventory() async throws {
        let inventoryService = deps.inventoryTrackingService
        let catalogService = deps.catalogService

        // Use real catalog data (catalog is read-only)
        let catalogItems = try await catalogService.getGlassItemsLightweight()
        let items = Array(catalogItems.filter({ $0.sku != nil }).prefix(3))

        // Create all items
        for item in items {
            _ = try await inventoryService.createCompleteItem(item, initialInventory: [])
        }

        // Add inventory to each item
        let quantities = [3.0, 5.0, 2.0]
        for (index, item) in items.enumerated() {
            _ = try await inventoryService.addInventory(
                quantity: quantities[index],
                type: "rod",
                toItem: item.stable_id
            )
        }

        // Verify all items have correct inventory
        for (index, item) in items.enumerated() {
            let quantity = try await inventoryService.inventoryRepository.getTotalQuantity(
                forItem: item.stable_id,
                type: "rod"
            )
            #expect(quantity == quantities[index])
        }
    }

    // MARK: - Remove from Shopping List Tests

    @Test("Can remove item from shopping list")
    func testRemoveItemFromShoppingList() async throws {
        let shoppingListService = deps.shoppingListService
        let inventoryService = deps.inventoryTrackingService
        let catalogService = deps.catalogService

        // Use real catalog data (catalog is read-only)
        let catalogItems = try await catalogService.getGlassItemsLightweight()
        let glassItem = try catalogItems.first(where: { $0.sku != nil })!

        _ = try await inventoryService.createCompleteItem(glassItem, initialInventory: [])

        // Add item to shopping list
        let shoppingItem = ItemShoppingModel(
            item_stable_id: glassItem.stable_id,
            quantity: 5.0,
            store: "Test Store"
        )
        _ = try await shoppingListService.shoppingListRepository.createItem(shoppingItem)

        // Verify item is in list
        let inList = try await shoppingListService.shoppingListRepository.isItemInList(glassItem.stable_id)
        #expect(inList == true)

        // Remove item from shopping list
        try await shoppingListService.shoppingListRepository.deleteItem(forItem: glassItem.stable_id)

        // Verify item is no longer in list
        let stillInList = try await shoppingListService.shoppingListRepository.isItemInList(glassItem.stable_id)
        #expect(stillInList == false)
    }

    @Test("Can remove multiple items from shopping list")
    func testRemoveMultipleItemsFromShoppingList() async throws {
        let shoppingListService = deps.shoppingListService
        let inventoryService = deps.inventoryTrackingService
        let catalogService = deps.catalogService

        // Use real catalog data (catalog is read-only)
        let catalogItems = try await catalogService.getGlassItemsLightweight()
        let items = Array(catalogItems.filter({ $0.sku != nil }).prefix(3))

        // Create items and add to shopping list
        for item in items {
            _ = try await inventoryService.createCompleteItem(item, initialInventory: [])
            let shoppingItem = ItemShoppingModel(
                item_stable_id: item.stable_id,
                quantity: 5.0,
                store: "Test Store"
            )
            _ = try await shoppingListService.shoppingListRepository.createItem(shoppingItem)
        }

        // Verify all items are in list
        for item in items {
            let inList = try await shoppingListService.shoppingListRepository.isItemInList(item.stable_id)
            #expect(inList == true)
        }

        // Remove all items
        for item in items {
            try await shoppingListService.shoppingListRepository.deleteItem(forItem: item.stable_id)
        }

        // Verify all items are removed
        for item in items {
            let stillInList = try await shoppingListService.shoppingListRepository.isItemInList(item.stable_id)
            #expect(stillInList == false)
        }
    }

    // MARK: - Combined Checkout Tests

    @Test("Complete checkout flow: add to inventory and remove from list")
    func testCompleteCheckoutFlow() async throws {
        let inventoryService = deps.inventoryTrackingService
        let shoppingListService = deps.shoppingListService
        let catalogService = deps.catalogService

        // Use real catalog data (catalog is read-only)
        let catalogItems = try await catalogService.getGlassItemsLightweight()
        let glassItem = try catalogItems.first(where: { $0.sku != nil })!

        _ = try await inventoryService.createCompleteItem(glassItem, initialInventory: [])

        // Add to shopping list
        let shoppingItem = ItemShoppingModel(
            item_stable_id: glassItem.stable_id,
            quantity: 10.0,
            store: "Test Store"
        )
        _ = try await shoppingListService.shoppingListRepository.createItem(shoppingItem)

        // Verify initial state
        let startInventory = try await inventoryService.inventoryRepository.getTotalQuantity(
            forItem: glassItem.stable_id,
            type: "rod"
        )
        #expect(startInventory == 0.0)

        let inList = try await shoppingListService.shoppingListRepository.isItemInList(glassItem.stable_id)
        #expect(inList == true)

        // Simulate checkout: add to inventory
        _ = try await inventoryService.addInventory(
            quantity: shoppingItem.quantity,
            type: "rod",
            toItem: glassItem.stable_id
        )

        // Remove from shopping list
        try await shoppingListService.shoppingListRepository.deleteItem(forItem: glassItem.stable_id)

        // Verify final state
        let endInventory = try await inventoryService.inventoryRepository.getTotalQuantity(
            forItem: glassItem.stable_id,
            type: "rod"
        )
        #expect(endInventory == 10.0)

        let stillInList = try await shoppingListService.shoppingListRepository.isItemInList(glassItem.stable_id)
        #expect(stillInList == false)
    }

    @Test("Checkout with partial quantity (user bought less than needed)")
    func testCheckoutWithPartialQuantity() async throws {
        let inventoryService = deps.inventoryTrackingService
        let shoppingListService = deps.shoppingListService
        let catalogService = deps.catalogService

        // Use real catalog data (catalog is read-only)
        let catalogItems = try await catalogService.getGlassItemsLightweight()
        let glassItem = try catalogItems.first(where: { $0.sku != nil })!

        _ = try await inventoryService.createCompleteItem(glassItem, initialInventory: [])

        // Add to shopping list (need 10 units)
        let neededQuantity = 10.0
        let shoppingItem = ItemShoppingModel(
            item_stable_id: glassItem.stable_id,
            quantity: neededQuantity,
            store: "Test Store"
        )
        _ = try await shoppingListService.shoppingListRepository.createItem(shoppingItem)

        // User only bought 6 units
        let purchasedQuantity = 6.0
        _ = try await inventoryService.addInventory(
            quantity: purchasedQuantity,
            type: "rod",
            toItem: glassItem.stable_id
        )

        // Remove from shopping list (even though didn't get full amount)
        try await shoppingListService.shoppingListRepository.deleteItem(forItem: glassItem.stable_id)

        // Verify final state
        let endInventory = try await inventoryService.inventoryRepository.getTotalQuantity(
            forItem: glassItem.stable_id,
            type: "rod"
        )
        #expect(endInventory == purchasedQuantity)

        let stillInList = try await shoppingListService.shoppingListRepository.isItemInList(glassItem.stable_id)
        #expect(stillInList == false)
    }

    @Test("Checkout with extra quantity (user bought more than needed)")
    func testCheckoutWithExtraQuantity() async throws {
        let inventoryService = deps.inventoryTrackingService
        let shoppingListService = deps.shoppingListService
        let catalogService = deps.catalogService

        // Use real catalog data (catalog is read-only)
        let catalogItems = try await catalogService.getGlassItemsLightweight()
        let glassItem = try catalogItems.first(where: { $0.sku != nil })!

        _ = try await inventoryService.createCompleteItem(glassItem, initialInventory: [])

        // Add to shopping list (need 5 units)
        let neededQuantity = 5.0
        let shoppingItem = ItemShoppingModel(
            item_stable_id: glassItem.stable_id,
            quantity: neededQuantity,
            store: "Test Store"
        )
        _ = try await shoppingListService.shoppingListRepository.createItem(shoppingItem)

        // User bought 10 units (more than needed)
        let purchasedQuantity = 10.0
        _ = try await inventoryService.addInventory(
            quantity: purchasedQuantity,
            type: "rod",
            toItem: glassItem.stable_id
        )

        // Remove from shopping list
        try await shoppingListService.shoppingListRepository.deleteItem(forItem: glassItem.stable_id)

        // Verify final state
        let endInventory = try await inventoryService.inventoryRepository.getTotalQuantity(
            forItem: glassItem.stable_id,
            type: "rod"
        )
        #expect(endInventory == purchasedQuantity)

        let stillInList = try await shoppingListService.shoppingListRepository.isItemInList(glassItem.stable_id)
        #expect(stillInList == false)
    }
}
