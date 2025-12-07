//
//  ShoppingListItemCreationTests.swift
//  FlameworkerTests
//
//  Tests for shopping list item creation functionality
//  Tests the business logic and service integration for AddShoppingListItemView
//

import Testing
import Foundation
import CryptoKit
@testable import Molten

@Suite("Shopping List Item Creation Tests", .serialized)
@MainActor
struct ShoppingListItemCreationTests {

    // MARK: - Shared Dependencies

    /// ✅ CRITICAL: Store AppDependencies at struct level to keep PersistenceController alive
    /// This prevents Core Data zombie objects that cause crashes.
    /// See CLAUDE.md "Service Creation Anti-Pattern" - same pattern applies to tests!
    private let deps = AppDependencies(persistenceController: .createTestController())

    @Test("Create shopping list item with minimal fields")
    func testCreateMinimalShoppingListItem() async throws {
        // Configure for testing
        let shoppingListService = deps.shoppingListService
        let catalogService = deps.catalogService

        // Create a test glass item first
        let glassItem = try await createTestGlassItem(catalogService: catalogService)

        // Create shopping list item with minimal fields
        let shoppingListItem = ItemShoppingModel(
            item_stable_id: glassItem.stable_id,
            quantity: 5.0,
            store: nil,
            type: nil,
            subtype: nil,
            subsubtype: nil
        )

        let created = try await shoppingListService.shoppingListRepository.createItem(shoppingListItem)

        #expect(created.item_stable_id == glassItem.stable_id)
        #expect(created.quantity == 5.0)
        #expect(created.store == nil)
        #expect(created.type == nil)
        #expect(created.subtype == nil)
    }

    @Test("Create shopping list item with all optional fields")
    func testCreateFullShoppingListItem() async throws {
        let shoppingListService = deps.shoppingListService
        let catalogService = deps.catalogService

        let glassItem = try await createTestGlassItem(catalogService: catalogService)

        // Create shopping list item with all fields
        let shoppingListItem = ItemShoppingModel(
            item_stable_id: glassItem.stable_id,
            quantity: 10.0,
            store: "Frantz Art Glass",
            type: "rod",
            subtype: "stringer",
            subsubtype: nil
        )

        let created = try await shoppingListService.shoppingListRepository.createItem(shoppingListItem)

        #expect(created.item_stable_id == glassItem.stable_id)
        #expect(created.quantity == 10.0)
        #expect(created.store == "Frantz Art Glass")
        #expect(created.type == "rod")
        #expect(created.subtype == "stringer")
    }

    @Test("Create shopping list item with type and subtype")
    func testCreateWithTypeAndSubtype() async throws {
        let shoppingListService = deps.shoppingListService
        let catalogService = deps.catalogService

        let glassItem = try await createTestGlassItem(catalogService: catalogService)

        // Test with different types
        let rodItem = ItemShoppingModel(
            item_stable_id: glassItem.stable_id,
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
        let shoppingListService = deps.shoppingListService
        let catalogService = deps.catalogService

        let glassItem = try await createTestGlassItem(catalogService: catalogService)

        // Create items for different stores
        let item1 = ItemShoppingModel(
            item_stable_id: glassItem.stable_id,
            quantity: 5.0,
            store: "Store A",
            type: "rod",
            subtype: nil,
            subsubtype: nil
        )

        let item2 = ItemShoppingModel(
            item_stable_id: glassItem.stable_id,
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
        #expect(created1.item_stable_id == created2.item_stable_id)
        #expect(created1.id != created2.id)
    }

    @Test("Create shopping list item validates quantity")
    func testQuantityValidation() async throws {
        let catalogService = deps.catalogService

        let glassItem = try await createTestGlassItem(catalogService: catalogService)

        // ItemShoppingModel should accept positive quantities
        let validItem = ItemShoppingModel(
            item_stable_id: glassItem.stable_id,
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
        let shoppingListService = deps.shoppingListService
        let catalogService = deps.catalogService

        let glassItem = try await createTestGlassItem(catalogService: catalogService)

        // Create items for specific store
        let item1 = ItemShoppingModel(
            item_stable_id: glassItem.stable_id,
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
        let catalogService = deps.catalogService

        let glassItem = try await createTestGlassItem(catalogService: catalogService)

        // Verify subtypes are appropriate for their types
        // Frit has subtypes; rod does not
        let fritSubtypes = GlassItemTypeSystem.getSubtypes(for: "frit")
        #expect(fritSubtypes.contains("coarse"))
        #expect(fritSubtypes.contains("medium"))
        #expect(fritSubtypes.contains("fine"))

        let rodSubtypes = GlassItemTypeSystem.getSubtypes(for: "rod")
        #expect(rodSubtypes.isEmpty)

        // Create item with valid type (rod has no subtypes now)
        let item = ItemShoppingModel(
            item_stable_id: glassItem.stable_id,
            quantity: 2.0,
            store: nil,
            type: "rod",
            subtype: nil,
            subsubtype: nil
        )

        #expect(item.type == "rod")
        #expect(item.subtype == nil)
    }

    // MARK: - Test Helpers

    private func createTestGlassItem(catalogService: CatalogService) async throws -> GlassItemModel {
        // Use real catalog data (catalog is read-only)
        let catalogItems = try await catalogService.getGlassItemsLightweight()
        let glassItem = try catalogItems.first(where: { $0.sku != nil })!
        return glassItem
    }
}
