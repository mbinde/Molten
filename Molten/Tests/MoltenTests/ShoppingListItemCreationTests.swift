//
//  ShoppingListItemCreationTests.swift
//  FlameworkerTests
//
//  Tests for shopping list item creation functionality
//  Tests the business logic and service integration for AddShoppingListItemView
//

import Testing
import Foundation
@testable import Molten

@Suite("Shopping List Item Creation Tests")
@MainActor
struct ShoppingListItemCreationTests {

    @Test("Create shopping list item with minimal fields")
    func testCreateMinimalShoppingListItem() async throws {
        // Configure for testing
        RepositoryFactory.configureForTesting()
        let shoppingListService = RepositoryFactory.createShoppingListService()
        let catalogService = RepositoryFactory.createCatalogService()

        // Create a test glass item first
        let glassItem = try await createTestGlassItem(catalogService: catalogService)

        // Create shopping list item with minimal fields
        let shoppingListItem = ItemShoppingModel(
            item_natural_key: glassItem.natural_key,
            quantity: 5.0,
            store: nil,
            type: nil,
            subtype: nil,
            subsubtype: nil
        )

        let created = try await shoppingListService.shoppingListRepository.createItem(shoppingListItem)

        #expect(created.item_natural_key == glassItem.natural_key)
        #expect(created.quantity == 5.0)
        #expect(created.store == nil)
        #expect(created.type == nil)
        #expect(created.subtype == nil)
    }

    @Test("Create shopping list item with all optional fields")
    func testCreateFullShoppingListItem() async throws {
        RepositoryFactory.configureForTesting()
        let shoppingListService = RepositoryFactory.createShoppingListService()
        let catalogService = RepositoryFactory.createCatalogService()

        let glassItem = try await createTestGlassItem(catalogService: catalogService)

        // Create shopping list item with all fields
        let shoppingListItem = ItemShoppingModel(
            item_natural_key: glassItem.natural_key,
            quantity: 10.0,
            store: "Frantz Art Glass",
            type: "rod",
            subtype: "stringer",
            subsubtype: nil
        )

        let created = try await shoppingListService.shoppingListRepository.createItem(shoppingListItem)

        #expect(created.item_natural_key == glassItem.natural_key)
        #expect(created.quantity == 10.0)
        #expect(created.store == "Frantz Art Glass")
        #expect(created.type == "rod")
        #expect(created.subtype == "stringer")
    }

    @Test("Create shopping list item with type and subtype")
    func testCreateWithTypeAndSubtype() async throws {
        RepositoryFactory.configureForTesting()
        let shoppingListService = RepositoryFactory.createShoppingListService()
        let catalogService = RepositoryFactory.createCatalogService()

        let glassItem = try await createTestGlassItem(catalogService: catalogService)

        // Test with different types
        let rodItem = ItemShoppingModel(
            item_natural_key: glassItem.natural_key,
            quantity: 3.0,
            store: nil,
            type: "rod",
            subtype: "standard",
            subsubtype: nil
        )

        let created = try await shoppingListService.shoppingListRepository.createItem(rodItem)
        #expect(created.type == "rod")
        #expect(created.subtype == "standard")
    }

    @Test("Create multiple shopping list items for same glass item")
    func testCreateMultipleItemsSameGlass() async throws {
        RepositoryFactory.configureForTesting()
        let shoppingListService = RepositoryFactory.createShoppingListService()
        let catalogService = RepositoryFactory.createCatalogService()

        let glassItem = try await createTestGlassItem(catalogService: catalogService)

        // Create items for different stores
        let item1 = ItemShoppingModel(
            item_natural_key: glassItem.natural_key,
            quantity: 5.0,
            store: "Store A",
            type: "rod",
            subtype: nil,
            subsubtype: nil
        )

        let item2 = ItemShoppingModel(
            item_natural_key: glassItem.natural_key,
            quantity: 10.0,
            store: "Store B",
            type: "sheet",
            subtype: nil,
            subsubtype: nil
        )

        let created1 = try await shoppingListService.shoppingListRepository.createItem(item1)
        let created2 = try await shoppingListService.shoppingListRepository.createItem(item2)

        #expect(created1.store == "Store A")
        #expect(created2.store == "Store B")
        #expect(created1.item_natural_key == created2.item_natural_key)
        #expect(created1.id != created2.id)
    }

    @Test("Create shopping list item validates quantity")
    func testQuantityValidation() async throws {
        RepositoryFactory.configureForTesting()
        let catalogService = RepositoryFactory.createCatalogService()

        let glassItem = try await createTestGlassItem(catalogService: catalogService)

        // ItemShoppingModel should accept positive quantities
        let validItem = ItemShoppingModel(
            item_natural_key: glassItem.natural_key,
            quantity: 1.5,
            store: nil,
            type: nil,
            subtype: nil,
            subsubtype: nil
        )

        #expect(validItem.quantity == 1.5)
    }

    @Test("Retrieve shopping list items by store")
    func testRetrieveByStore() async throws {
        RepositoryFactory.configureForTesting()
        let shoppingListService = RepositoryFactory.createShoppingListService()
        let catalogService = RepositoryFactory.createCatalogService()

        let glassItem = try await createTestGlassItem(catalogService: catalogService)

        // Create items for specific store
        let item1 = ItemShoppingModel(
            item_natural_key: glassItem.natural_key,
            quantity: 5.0,
            store: "Test Store",
            type: "rod",
            subtype: nil,
            subsubtype: nil
        )

        _ = try await shoppingListService.shoppingListRepository.createItem(item1)

        // Fetch items for that store
        let items = try await shoppingListService.shoppingListRepository.fetchItems(forStore: "Test Store")

        #expect(items.count > 0)
        #expect(items.allSatisfy { $0.store == "Test Store" })
    }

    @Test("Type and subtype consistency")
    func testTypeSubtypeConsistency() async throws {
        RepositoryFactory.configureForTesting()
        let catalogService = RepositoryFactory.createCatalogService()

        let glassItem = try await createTestGlassItem(catalogService: catalogService)

        // Verify subtypes are appropriate for their types
        let rodSubtypes = GlassItemTypeSystem.getSubtypes(for: "rod")
        #expect(rodSubtypes.contains("standard"))
        #expect(rodSubtypes.contains("cane"))
        #expect(rodSubtypes.contains("pull"))

        // Create item with valid type/subtype combination
        let item = ItemShoppingModel(
            item_natural_key: glassItem.natural_key,
            quantity: 2.0,
            store: nil,
            type: "rod",
            subtype: "standard",
            subsubtype: nil
        )

        #expect(item.type == "rod")
        #expect(item.subtype == "standard")
    }

    // MARK: - Test Helpers

    private func createTestGlassItem(catalogService: CatalogService) async throws -> GlassItemModel {
        // Create a GlassItemModel first
        let glassItem = GlassItemModel(
            natural_key: "test-test-001-0",
            name: "Test Glass Item",
            sku: "TEST-001",
            manufacturer: "test",
            coe: 96,
            mfr_status: "available"
        )

        // Then create it using the catalog service
        let completeItem = try await catalogService.createGlassItem(
            glassItem,
            initialInventory: [],
            tags: ["test"]
        )

        return completeItem.glassItem
    }
}
