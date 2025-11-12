//
//  ShoppingListServiceTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/16/25.
//  Tests for ShoppingListService integration with ItemMinimum and ItemShopping
//

#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

import Foundation
import CryptoKit
@testable import Molten

@Suite("ShoppingListService Integration Tests")
@MainActor
struct ShoppingListServiceTests {

    // MARK: - Helper Methods

    private func createTestService() -> (service: ShoppingListService, repos: TestRepositories) {
        let itemMinimumRepo = MockItemMinimumRepository()
        let shoppingListRepo = MockShoppingListRepository()
        let inventoryRepo = MockInventoryRepository()
        let glassItemRepo = MockGlassItemRepository()
        let itemTagsRepo = MockItemTagsRepository()
        let userTagsRepo = MockUserTagsRepository()

        let service = ShoppingListService(
            itemMinimumRepository: itemMinimumRepo,
            shoppingListRepository: shoppingListRepo,
            inventoryRepository: inventoryRepo,
            glassItemRepository: glassItemRepo,
            itemTagsRepository: itemTagsRepo,
            userTagsRepository: userTagsRepo
        )

        return (
            service: service,
            repos: TestRepositories(
                itemMinimum: itemMinimumRepo,
                shoppingList: shoppingListRepo,
                inventory: inventoryRepo,
                glassItem: glassItemRepo,
                itemTags: itemTagsRepo
            )
        )
    }

    struct TestRepositories {
        let itemMinimum: MockItemMinimumRepository
        let shoppingList: MockShoppingListRepository
        let inventory: MockInventoryRepository
        let glassItem: MockGlassItemRepository
        let itemTags: MockItemTagsRepository
    }

    // MARK: - Basic Shopping List Generation Tests

    @Test("Generate empty shopping list when no items below minimum and no manual items")
    func testEmptyShoppingList() async throws {
        let deps = AppDependencies(forTesting: true)
        let (service, _) = createTestService()

        let lists = try await service.generateAllShoppingLists()

        #expect(lists.isEmpty)
    }

    @Test("Generate shopping list from ItemMinimum only")
    func testShoppingListFromMinimumOnly() async throws {
        let deps = AppDependencies(forTesting: true)
        let (service, repos) = createTestService()

        // Create a glass item
        let stableId = generateStableId(manufacturer: "test", sku: "001")
        let glassItem = GlassItemModel(
            stable_id: stableId,
            name: "Test Item 1",
            sku: "001",
            manufacturer: "test",
            coe: 96,
            mfr_status: "available"
        )
        try await repos.glassItem.createItem(glassItem)

        // Create inventory with 5 units
        let inventory = InventoryModel(
            item_stable_id: stableId,
            type: "rod",
            quantity: 5.0
        )
        try await repos.inventory.createInventory(inventory)

        // Set minimum to 10 units (5 below)
        try await repos.itemMinimum.setMinimumQuantity(10.0, forItem: stableId, type: "rod", store: "Test Store")

        // Generate shopping list
        let lists = try await service.generateAllShoppingLists()

        #expect(lists.count == 1)
        #expect(lists["Test Store"] != nil)
        #expect(lists["Test Store"]?.items.count == 1)
        #expect(lists["Test Store"]?.items.first?.shoppingListItem.neededQuantity == 5.0)
    }

    @Test("Generate shopping list from ItemShopping only")
    func testShoppingListFromManualOnly() async throws {
        let deps = AppDependencies(forTesting: true)
        let (service, repos) = createTestService()

        // Create a glass item
        let stableId = generateStableId(manufacturer: "test", sku: "002")
        let glassItem = GlassItemModel(
            stable_id: stableId,
            name: "Test Item 2",
            sku: "002",
            manufacturer: "test",
            coe: 96,
            mfr_status: "available"
        )
        try await repos.glassItem.createItem(glassItem)

        // Add manually to shopping list
        let shoppingItem = ItemShoppingModel(
            item_stable_id: stableId,
            quantity: 3.0,
            store: "Manual Store"
        )
        try await repos.shoppingList.createItem(shoppingItem)

        // Generate shopping list
        let lists = try await service.generateAllShoppingLists()

        #expect(lists.count == 1)
        #expect(lists["Manual Store"] != nil)
        #expect(lists["Manual Store"]?.items.count == 1)
        #expect(lists["Manual Store"]?.items.first?.shoppingListItem.neededQuantity == 3.0)
    }

    // MARK: - Combined Shopping List Tests

    @Test("Combine items from both ItemMinimum and ItemShopping")
    func testCombineFromBothSources() async throws {
        let deps = AppDependencies(forTesting: true)
        let (service, repos) = createTestService()

        // Create glass items
        let stableId1 = generateStableId(manufacturer: "test", sku: "001")
        let stableId2 = generateStableId(manufacturer: "test", sku: "002")
        let item1 = GlassItemModel(stable_id: stableId1, name: "Test Item 1", sku: "001", manufacturer: "test", coe: 96, mfr_status: "available")
        let item2 = GlassItemModel(stable_id: stableId2, name: "Test Item 2", sku: "002", manufacturer: "test", coe: 96, mfr_status: "available")
        try await repos.glassItem.createItem(item1)
        try await repos.glassItem.createItem(item2)

        // Item 1: Below minimum (from ItemMinimum)
        let inventory1 = InventoryModel(item_stable_id: stableId1, type: "rod", quantity: 2.0)
        try await repos.inventory.createInventory(inventory1)
        try await repos.itemMinimum.setMinimumQuantity(5.0, forItem: stableId1, type: "rod", store: "Store A")

        // Item 2: Manually added (from ItemShopping)
        let shoppingItem = ItemShoppingModel(item_stable_id: stableId2, quantity: 4.0, store: "Store A")
        try await repos.shoppingList.createItem(shoppingItem)

        // Generate shopping list
        let lists = try await service.generateAllShoppingLists()

        #expect(lists.count == 1)
        #expect(lists["Store A"] != nil)
        #expect(lists["Store A"]?.items.count == 2)

        let items = lists["Store A"]?.items ?? []
        // item_stable_id stores stable_id, not natural_key string
        #expect(items.contains { $0.shoppingListItem.item_stable_id == stableId1 })
        #expect(items.contains { $0.shoppingListItem.item_stable_id == stableId2 })
    }

    @Test("Merge duplicate items with higher needed quantity")
    func testMergeDuplicateItems() async throws {
        let deps = AppDependencies(forTesting: true)
        let (service, repos) = createTestService()

        // Create a glass item
        let stableId = generateStableId(manufacturer: "test", sku: "001")
        let glassItem = GlassItemModel(
            stable_id: stableId,
            name: "Duplicate Item",
            sku: "001",
            manufacturer: "test",
            coe: 96,
            mfr_status: "available"
        )
        try await repos.glassItem.createItem(glassItem)

        // Create inventory with 5 units
        let inventory = InventoryModel(item_stable_id: stableId, type: "rod", quantity: 5.0)
        try await repos.inventory.createInventory(inventory)

        // Set minimum to 8 (need 3 more from ItemMinimum)
        try await repos.itemMinimum.setMinimumQuantity(8.0, forItem: stableId, type: "rod", store: "Same Store")

        // Manually add to shopping list (need 7 from ItemShopping)
        let shoppingItem = ItemShoppingModel(item_stable_id: stableId, quantity: 7.0, store: "Same Store")
        try await repos.shoppingList.createItem(shoppingItem)

        // Generate shopping list
        let lists = try await service.generateAllShoppingLists()

        #expect(lists.count == 1)
        #expect(lists["Same Store"] != nil)
        #expect(lists["Same Store"]?.items.count == 1)

        // Should use the higher needed quantity (7.0 from manual, not 3.0 from minimum)
        let item = lists["Same Store"]?.items.first
        #expect(item?.shoppingListItem.neededQuantity == 7.0)
    }

    @Test("Items from different stores are kept separate")
    func testMultipleStores() async throws {
        let deps = AppDependencies(forTesting: true)
        let (service, repos) = createTestService()

        // Create glass items
        let stableIdA = generateStableId(manufacturer: "test", sku: "001")
        let stableIdB = generateStableId(manufacturer: "test", sku: "002")
        let item1 = GlassItemModel(stable_id: stableIdA, name: "Store A Item", sku: "001", manufacturer: "test", coe: 96, mfr_status: "available")
        let item2 = GlassItemModel(stable_id: stableIdB, name: "Store B Item", sku: "002", manufacturer: "test", coe: 96, mfr_status: "available")
        try await repos.glassItem.createItem(item1)
        try await repos.glassItem.createItem(item2)

        // Item A: Store A (from minimum)
        let inventory1 = InventoryModel(item_stable_id: stableIdA, type: "rod", quantity: 1.0)
        try await repos.inventory.createInventory(inventory1)
        try await repos.itemMinimum.setMinimumQuantity(5.0, forItem: stableIdA, type: "rod", store: "Store A")

        // Item B: Store B (from manual)
        let shoppingItem = ItemShoppingModel(item_stable_id: stableIdB, quantity: 3.0, store: "Store B")
        try await repos.shoppingList.createItem(shoppingItem)

        // Generate shopping list
        let lists = try await service.generateAllShoppingLists()

        #expect(lists.count == 2)
        #expect(lists["Store A"] != nil)
        #expect(lists["Store B"] != nil)
        #expect(lists["Store A"]?.items.count == 1)
        #expect(lists["Store B"]?.items.count == 1)
        #expect(lists["Store A"]?.items.first?.glassItem.stable_id == stableIdA)
        #expect(lists["Store B"]?.items.first?.glassItem.stable_id == stableIdB)
    }

    @Test("Manual items without store go to 'Other' store")
    func testManualItemsWithoutStore() async throws {
        let deps = AppDependencies(forTesting: true)
        let (service, repos) = createTestService()

        // Create a glass item
        let stableId = generateStableId(manufacturer: "test", sku: "001")
        let glassItem = GlassItemModel(
            stable_id: stableId,
            name: "No Store Item",
            sku: "001",
            manufacturer: "test",
            coe: 96,
            mfr_status: "available"
        )
        try await repos.glassItem.createItem(glassItem)

        // Add manually to shopping list with no store
        let shoppingItem = ItemShoppingModel(
            item_stable_id: stableId,
            quantity: 5.0,
            store: nil
        )
        try await repos.shoppingList.createItem(shoppingItem)

        // Generate shopping list
        let lists = try await service.generateAllShoppingLists()

        #expect(lists.count == 1)
        #expect(lists["Other"] != nil)
        #expect(lists["Other"]?.items.count == 1)
    }

    // MARK: - Edge Cases

    @Test("Items with zero inventory and minimum are included")
    func testZeroInventoryWithMinimum() async throws {
        let deps = AppDependencies(forTesting: true)
        let (service, repos) = createTestService()

        // Create a glass item
        let stableId = generateStableId(manufacturer: "test", sku: "001")
        let glassItem = GlassItemModel(
            stable_id: stableId,
            name: "Zero Item",
            sku: "001",
            manufacturer: "test",
            coe: 96,
            mfr_status: "available"
        )
        try await repos.glassItem.createItem(glassItem)

        // No inventory (0 units)
        // Set minimum to 5
        try await repos.itemMinimum.setMinimumQuantity(5.0, forItem: stableId, type: "rod", store: "Test Store")

        // Generate shopping list
        let lists = try await service.generateAllShoppingLists()

        #expect(lists.count == 1)
        #expect(lists["Test Store"] != nil)
        #expect(lists["Test Store"]?.items.count == 1)
        #expect(lists["Test Store"]?.items.first?.shoppingListItem.neededQuantity == 5.0)
    }

    @Test("Items at or above minimum are excluded from shopping list")
    func testItemsAboveMinimumExcluded() async throws {
        let deps = AppDependencies(forTesting: true)
        let (service, repos) = createTestService()

        // Create a glass item
        let stableId = generateStableId(manufacturer: "test", sku: "001")
        let glassItem = GlassItemModel(
            stable_id: stableId,
            name: "Full Item",
            sku: "001",
            manufacturer: "test",
            coe: 96,
            mfr_status: "available"
        )
        try await repos.glassItem.createItem(glassItem)

        // Create inventory with 10 units
        let inventory = InventoryModel(item_stable_id: stableId, type: "rod", quantity: 10.0)
        try await repos.inventory.createInventory(inventory)

        // Set minimum to 5 (already have 10, so no need to buy)
        try await repos.itemMinimum.setMinimumQuantity(5.0, forItem: stableId, type: "rod", store: "Test Store")

        // Generate shopping list
        let lists = try await service.generateAllShoppingLists()

        // Should be empty since item is above minimum
        #expect(lists.isEmpty || lists["Test Store"]?.items.isEmpty == true)
    }

    @Test("Shopping list includes tags from items")
    func testShoppingListIncludesTags() async throws {
        let deps = AppDependencies(forTesting: true)
        let (service, repos) = createTestService()

        // Create a glass item
        let stableId = generateStableId(manufacturer: "test", sku: "001")
        let glassItem = GlassItemModel(
            stable_id: stableId,
            name: "Tagged Item",
            sku: "001",
            manufacturer: "test",
            coe: 96,
            mfr_status: "available"
        )
        try await repos.glassItem.createItem(glassItem)

        // Add tags
        try await repos.itemTags.addTags(["transparent", "rod", "coe96"], toItem: stableId)

        // Add to shopping list manually
        let shoppingItem = ItemShoppingModel(item_stable_id: stableId, quantity: 3.0, store: "Tag Store")
        try await repos.shoppingList.createItem(shoppingItem)

        // Generate shopping list
        let lists = try await service.generateAllShoppingLists()

        #expect(lists["Tag Store"]?.items.first?.tags.count == 3)
        #expect(lists["Tag Store"]?.items.first?.tags.contains("transparent") == true)
        #expect(lists["Tag Store"]?.items.first?.tags.contains("rod") == true)
        #expect(lists["Tag Store"]?.items.first?.tags.contains("coe96") == true)
    }

    // MARK: - DetailedShoppingListItemModel Tests

    @Test("completeItem creates valid CompleteInventoryItemModel")
    func testCompleteItemPropertyCreation() async throws {
        let deps = AppDependencies(forTesting: true)
        let (service, repos) = createTestService()

        // Create a glass item
        let stableId = generateStableId(manufacturer: "test", sku: "001")
        let glassItem = GlassItemModel(
            stable_id: stableId,
            name: "Complete Test Item",
            sku: "001",
            manufacturer: "test",
            coe: 96,
            mfr_status: "available"
        )
        try await repos.glassItem.createItem(glassItem)

        // Add system tags and user tags
        try await repos.itemTags.addTags(["transparent", "rod"], toItem: stableId)

        // Add to shopping list manually
        let shoppingItem = ItemShoppingModel(item_stable_id: stableId, quantity: 5.0, store: "Test Store")
        try await repos.shoppingList.createItem(shoppingItem)

        // Generate shopping list
        let lists = try await service.generateAllShoppingLists()
        let detailedItem = try #require(lists["Test Store"]?.items.first)

        // Test completeItem property
        let completeItem = detailedItem.completeItem

        #expect(completeItem.glassItem.stable_id == stableId)
        #expect(completeItem.glassItem.name == "Complete Test Item")
        #expect(Set(completeItem.tags) == Set(["transparent", "rod"])) // Check set equality for tags
        #expect(completeItem.inventory.isEmpty) // Shopping list items have no inventory data
        #expect(completeItem.locations.isEmpty) // Shopping list items have no location data
        #expect(completeItem.id == stableId) // id is based on stable_id, not natural_key
    }

    @Test("completeItem combines system and user tags")
    func testCompleteItemCombinesTags() async throws {
        let deps = AppDependencies(forTesting: true)
        let (service, repos) = createTestService()

        // Create a glass item
        let stableId = generateStableId(manufacturer: "test", sku: "002")
        let glassItem = GlassItemModel(
            stable_id: stableId,
            name: "Tagged Complete Item",
            sku: "002",
            manufacturer: "test",
            coe: 104,
            mfr_status: "available"
        )
        try await repos.glassItem.createItem(glassItem)

        // Add system tags
        try await repos.itemTags.addTags(["opaque", "frit"], toItem: stableId)

        // Add to shopping list
        let shoppingItem = ItemShoppingModel(item_stable_id: stableId, quantity: 2.0, store: "Test Store")
        try await repos.shoppingList.createItem(shoppingItem)

        // Generate shopping list
        let lists = try await service.generateAllShoppingLists()
        let detailedItem = try #require(lists["Test Store"]?.items.first)

        // Test completeItem has all tags
        let completeItem = detailedItem.completeItem

        #expect(completeItem.tags.contains("opaque"))
        #expect(completeItem.tags.contains("frit"))
        #expect(completeItem.allTags.sorted() == ["frit", "opaque"])
    }

    @Test("completeItem is Hashable and Identifiable")
    func testCompleteItemConformsToProtocols() async throws {
        let deps = AppDependencies(forTesting: true)
        let (service, repos) = createTestService()

        // Create glass items
        let stableId1 = generateStableId(manufacturer: "test", sku: "001")
        let stableId2 = generateStableId(manufacturer: "test", sku: "002")
        let item1 = GlassItemModel(stable_id: stableId1, name: "Protocol Test Item 1", sku: "001", manufacturer: "test", coe: 96, mfr_status: "available")
        let item2 = GlassItemModel(stable_id: stableId2, name: "Protocol Test Item 2", sku: "002", manufacturer: "test", coe: 96, mfr_status: "available")
        try await repos.glassItem.createItem(item1)
        try await repos.glassItem.createItem(item2)

        // Add to shopping list
        try await repos.shoppingList.createItem(ItemShoppingModel(item_stable_id: stableId1, quantity: 1.0, store: "Store"))
        try await repos.shoppingList.createItem(ItemShoppingModel(item_stable_id: stableId2, quantity: 1.0, store: "Store"))

        // Generate shopping list
        let lists = try await service.generateAllShoppingLists()
        let items = try #require(lists["Store"]?.items)

        let complete1 = items[0].completeItem
        let complete2 = items[1].completeItem

        // Test Identifiable (id is based on stable_id, not natural_key)
        #expect(complete1.id == stableId1 || complete1.id == stableId2)
        #expect(complete2.id == stableId1 || complete2.id == stableId2)
        #expect(complete1.id != complete2.id)

        // Test Hashable (can be used in Set)
        let set: Set<CompleteInventoryItemModel> = [complete1, complete2]
        #expect(set.count == 2)
    }
}
