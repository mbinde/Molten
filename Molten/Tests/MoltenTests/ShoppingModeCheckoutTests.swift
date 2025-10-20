//
//  ShoppingModeCheckoutTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/19/25.
//  Tests for shopping mode checkout operations (add to inventory, remove from list)
//

import Testing
import Foundation
@testable import Molten

/// Tests for checkout operations in shopping mode
@Suite("Shopping Mode Checkout Tests")
struct ShoppingModeCheckoutTests {

    // MARK: - Test Lifecycle

    init() {
        // Configure for testing with mocks
        RepositoryFactory.configureForTesting()
    }

    // MARK: - Add to Inventory Tests

    @Test("Can add basket items to inventory")
    func testAddBasketItemsToInventory() async throws {
        let inventoryService = RepositoryFactory.createInventoryTrackingService()

        // Create a test glass item
        let glassItem = GlassItemModel(
            natural_key: "test-checkout-001",
            name: "Test Checkout Item",
            sku: "checkout-001",
            manufacturer: "test",
            coe: 33,
            mfr_status: "available"
        )

        // Create the item with zero initial inventory
        _ = try await inventoryService.createCompleteItem(glassItem, initialInventory: [])

        // Verify starting inventory is zero
        let startInventory = try await inventoryService.inventoryRepository.getTotalQuantity(
            forItem: glassItem.natural_key,
            type: "rod"
        )
        #expect(startInventory == 0.0)

        // Add quantity to inventory (simulating checkout)
        let addedQuantity = 5.0
        _ = try await inventoryService.addInventory(
            quantity: addedQuantity,
            type: "rod",
            toItem: glassItem.natural_key
        )

        // Verify inventory was added
        let endInventory = try await inventoryService.inventoryRepository.getTotalQuantity(
            forItem: glassItem.natural_key,
            type: "rod"
        )
        #expect(endInventory == addedQuantity)
    }

    @Test("Can add multiple basket items to inventory in batch")
    func testAddMultipleItemsToInventory() async throws {
        let inventoryService = RepositoryFactory.createInventoryTrackingService()

        // Create multiple test items
        let items = [
            GlassItemModel(natural_key: "test-multi-001", name: "Item 1", sku: "multi-001", manufacturer: "test", coe: 33, mfr_status: "available"),
            GlassItemModel(natural_key: "test-multi-002", name: "Item 2", sku: "multi-002", manufacturer: "test", coe: 33, mfr_status: "available"),
            GlassItemModel(natural_key: "test-multi-003", name: "Item 3", sku: "multi-003", manufacturer: "test", coe: 33, mfr_status: "available")
        ]

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
                toItem: item.natural_key
            )
        }

        // Verify all items have correct inventory
        for (index, item) in items.enumerated() {
            let quantity = try await inventoryService.inventoryRepository.getTotalQuantity(
                forItem: item.natural_key,
                type: "rod"
            )
            #expect(quantity == quantities[index])
        }
    }

    // MARK: - Remove from Shopping List Tests

    @Test("Can remove item from shopping list")
    func testRemoveItemFromShoppingList() async throws {
        let shoppingListService = RepositoryFactory.createShoppingListService()

        // Create a test glass item
        let inventoryService = RepositoryFactory.createInventoryTrackingService()
        let glassItem = GlassItemModel(
            natural_key: "test-remove-001",
            name: "Remove Test Item",
            sku: "remove-001",
            manufacturer: "test",
            coe: 33,
            mfr_status: "available"
        )
        _ = try await inventoryService.createCompleteItem(glassItem, initialInventory: [])

        // Add item to shopping list
        let shoppingItem = ItemShoppingModel(
            item_natural_key: glassItem.natural_key,
            quantity: 5.0,
            store: "Test Store"
        )
        _ = try await shoppingListService.shoppingListRepository.createItem(shoppingItem)

        // Verify item is in list
        let inList = try await shoppingListService.shoppingListRepository.isItemInList(glassItem.natural_key)
        #expect(inList == true)

        // Remove item from shopping list
        try await shoppingListService.shoppingListRepository.deleteItem(forItem: glassItem.natural_key)

        // Verify item is no longer in list
        let stillInList = try await shoppingListService.shoppingListRepository.isItemInList(glassItem.natural_key)
        #expect(stillInList == false)
    }

    @Test("Can remove multiple items from shopping list")
    func testRemoveMultipleItemsFromShoppingList() async throws {
        let shoppingListService = RepositoryFactory.createShoppingListService()
        let inventoryService = RepositoryFactory.createInventoryTrackingService()

        // Create test items
        let items = [
            GlassItemModel(natural_key: "test-batch-001", name: "Batch 1", sku: "batch-001", manufacturer: "test", coe: 33, mfr_status: "available"),
            GlassItemModel(natural_key: "test-batch-002", name: "Batch 2", sku: "batch-002", manufacturer: "test", coe: 33, mfr_status: "available"),
            GlassItemModel(natural_key: "test-batch-003", name: "Batch 3", sku: "batch-003", manufacturer: "test", coe: 33, mfr_status: "available")
        ]

        // Create items and add to shopping list
        for item in items {
            _ = try await inventoryService.createCompleteItem(item, initialInventory: [])
            let shoppingItem = ItemShoppingModel(
                item_natural_key: item.natural_key,
                quantity: 5.0,
                store: "Test Store"
            )
            _ = try await shoppingListService.shoppingListRepository.createItem(shoppingItem)
        }

        // Verify all items are in list
        for item in items {
            let inList = try await shoppingListService.shoppingListRepository.isItemInList(item.natural_key)
            #expect(inList == true)
        }

        // Remove all items
        for item in items {
            try await shoppingListService.shoppingListRepository.deleteItem(forItem: item.natural_key)
        }

        // Verify all items are removed
        for item in items {
            let stillInList = try await shoppingListService.shoppingListRepository.isItemInList(item.natural_key)
            #expect(stillInList == false)
        }
    }

    // MARK: - Combined Checkout Tests

    @Test("Complete checkout flow: add to inventory and remove from list")
    func testCompleteCheckoutFlow() async throws {
        let inventoryService = RepositoryFactory.createInventoryTrackingService()
        let shoppingListService = RepositoryFactory.createShoppingListService()

        // Create test item
        let glassItem = GlassItemModel(
            natural_key: "test-flow-001",
            name: "Flow Test Item",
            sku: "flow-001",
            manufacturer: "test",
            coe: 33,
            mfr_status: "available"
        )
        _ = try await inventoryService.createCompleteItem(glassItem, initialInventory: [])

        // Add to shopping list
        let shoppingItem = ItemShoppingModel(
            item_natural_key: glassItem.natural_key,
            quantity: 10.0,
            store: "Test Store"
        )
        _ = try await shoppingListService.shoppingListRepository.createItem(shoppingItem)

        // Verify initial state
        let startInventory = try await inventoryService.inventoryRepository.getTotalQuantity(
            forItem: glassItem.natural_key,
            type: "rod"
        )
        #expect(startInventory == 0.0)

        let inList = try await shoppingListService.shoppingListRepository.isItemInList(glassItem.natural_key)
        #expect(inList == true)

        // Simulate checkout: add to inventory
        _ = try await inventoryService.addInventory(
            quantity: shoppingItem.quantity,
            type: "rod",
            toItem: glassItem.natural_key
        )

        // Remove from shopping list
        try await shoppingListService.shoppingListRepository.deleteItem(forItem: glassItem.natural_key)

        // Verify final state
        let endInventory = try await inventoryService.inventoryRepository.getTotalQuantity(
            forItem: glassItem.natural_key,
            type: "rod"
        )
        #expect(endInventory == 10.0)

        let stillInList = try await shoppingListService.shoppingListRepository.isItemInList(glassItem.natural_key)
        #expect(stillInList == false)
    }

    @Test("Checkout with partial quantity (user bought less than needed)")
    func testCheckoutWithPartialQuantity() async throws {
        let inventoryService = RepositoryFactory.createInventoryTrackingService()
        let shoppingListService = RepositoryFactory.createShoppingListService()

        // Create test item
        let glassItem = GlassItemModel(
            natural_key: "test-partial-001",
            name: "Partial Test Item",
            sku: "partial-001",
            manufacturer: "test",
            coe: 33,
            mfr_status: "available"
        )
        _ = try await inventoryService.createCompleteItem(glassItem, initialInventory: [])

        // Add to shopping list (need 10 units)
        let neededQuantity = 10.0
        let shoppingItem = ItemShoppingModel(
            item_natural_key: glassItem.natural_key,
            quantity: neededQuantity,
            store: "Test Store"
        )
        _ = try await shoppingListService.shoppingListRepository.createItem(shoppingItem)

        // User only bought 6 units
        let purchasedQuantity = 6.0
        _ = try await inventoryService.addInventory(
            quantity: purchasedQuantity,
            type: "rod",
            toItem: glassItem.natural_key
        )

        // Remove from shopping list (even though didn't get full amount)
        try await shoppingListService.shoppingListRepository.deleteItem(forItem: glassItem.natural_key)

        // Verify final state
        let endInventory = try await inventoryService.inventoryRepository.getTotalQuantity(
            forItem: glassItem.natural_key,
            type: "rod"
        )
        #expect(endInventory == purchasedQuantity)

        let stillInList = try await shoppingListService.shoppingListRepository.isItemInList(glassItem.natural_key)
        #expect(stillInList == false)
    }

    @Test("Checkout with extra quantity (user bought more than needed)")
    func testCheckoutWithExtraQuantity() async throws {
        let inventoryService = RepositoryFactory.createInventoryTrackingService()
        let shoppingListService = RepositoryFactory.createShoppingListService()

        // Create test item
        let glassItem = GlassItemModel(
            natural_key: "test-extra-001",
            name: "Extra Test Item",
            sku: "extra-001",
            manufacturer: "test",
            coe: 33,
            mfr_status: "available"
        )
        _ = try await inventoryService.createCompleteItem(glassItem, initialInventory: [])

        // Add to shopping list (need 5 units)
        let neededQuantity = 5.0
        let shoppingItem = ItemShoppingModel(
            item_natural_key: glassItem.natural_key,
            quantity: neededQuantity,
            store: "Test Store"
        )
        _ = try await shoppingListService.shoppingListRepository.createItem(shoppingItem)

        // User bought 10 units (more than needed)
        let purchasedQuantity = 10.0
        _ = try await inventoryService.addInventory(
            quantity: purchasedQuantity,
            type: "rod",
            toItem: glassItem.natural_key
        )

        // Remove from shopping list
        try await shoppingListService.shoppingListRepository.deleteItem(forItem: glassItem.natural_key)

        // Verify final state
        let endInventory = try await inventoryService.inventoryRepository.getTotalQuantity(
            forItem: glassItem.natural_key,
            type: "rod"
        )
        #expect(endInventory == purchasedQuantity)

        let stillInList = try await shoppingListService.shoppingListRepository.isItemInList(glassItem.natural_key)
        #expect(stillInList == false)
    }
}
