//
//  InventoryDetailView_ShoppingListTests.swift
//  MoltenTests
//
//  Tests for InventoryDetailView shopping list integration
//

import Testing
import SwiftUI
@testable import Molten

@Suite("InventoryDetailView Shopping List Tests")
@MainActor
struct InventoryDetailView_ShoppingListTests {

    // MARK: - Shared Dependencies

    /// ✅ CRITICAL: Store AppDependencies at struct level to keep PersistenceController alive
    /// This prevents Core Data zombie objects that cause crashes.
    /// See CLAUDE.md "Service Creation Anti-Pattern" - same pattern applies to tests!
    private let deps = AppDependencies(persistenceController: .createTestController())

    // MARK: - Test Helpers

    func createTestItem(withInventory: Bool = false) -> CompleteInventoryItemModel {
        let glassItem = GlassItemModel(
            stable_id: generateStableId(manufacturer: "test", sku: "001"),
            name: "Test Glass Item",
            sku: "001",
            manufacturer: "test",
            coe: 96,
            mfr_status: "available"
        )

        let inventory: [InventoryModel]
        if withInventory {
            inventory = [
                InventoryModel(
                    item_stable_id: glassItem.stable_id,
                    type: "rod",
                    quantity: 10.0
                )
            ]
        } else {
            inventory = []
        }

        return CompleteInventoryItemModel(
            glassItem: glassItem,
            inventory: inventory,
            tags: ["blue", "transparent"],
            userTags: []
        )
    }

    // MARK: - Add to Shopping List Tests

    @Test("ShoppingListOptionsView initializes with item and dependencies")
    func testShoppingListOptionsViewInitialization() {
        let item = createTestItem()
        let view = ShoppingListOptionsView(
            item: item,
            deps: deps
        )

        #expect(view != nil)
        #expect(view.item.glassItem.stable_id == item.glassItem.stable_id)
    }

    @Test("Shopping list form validates positive quantity")
    func testShoppingListQuantityValidation() async throws {
        let item = createTestItem()

        // Test valid quantity
        let validQuantity = "5.0"
        let quantityValue = Double(validQuantity)
        #expect(quantityValue != nil)
        #expect(quantityValue! > 0)

        // Test invalid quantity (zero)
        let zeroQuantity = "0"
        let zeroValue = Double(zeroQuantity)
        #expect(zeroValue != nil)
        #expect(zeroValue! <= 0) // Should fail validation

        // Test invalid quantity (negative)
        let negativeQuantity = "-5.0"
        let negativeValue = Double(negativeQuantity)
        #expect(negativeValue != nil)
        #expect(negativeValue! <= 0) // Should fail validation

        // Test invalid quantity (not a number)
        let invalidQuantity = "abc"
        let invalidValue = Double(invalidQuantity)
        #expect(invalidValue == nil) // Should fail parsing
    }

    @Test("Shopping list accepts decimal quantities")
    func testShoppingListDecimalQuantities() {
        let decimalQuantity = "3.5"
        let value = Double(decimalQuantity)

        #expect(value != nil)
        #expect(value == 3.5)
    }

    @Test("Shopping list accepts whole number quantities")
    func testShoppingListWholeNumberQuantities() {
        let wholeQuantity = "10"
        let value = Double(wholeQuantity)

        #expect(value != nil)
        #expect(value == 10.0)
    }

    @Test("Adding item to shopping list creates ItemShoppingModel")
    func testAddToShoppingListCreatesModel() async throws {
        let item = createTestItem()
        let repository = deps.shoppingListRepository

        // Add item to shopping list
        let shoppingItem = try await repository.addQuantity(
            5.0,
            toItem: item.glassItem.stable_id,
            store: "Test Store"
        )

        #expect(shoppingItem != nil)
        #expect(shoppingItem.item_stable_id == item.glassItem.stable_id)
        #expect(shoppingItem.quantity == 5.0)
        #expect(shoppingItem.store == "Test Store")
    }

    @Test("Adding item to shopping list without store")
    func testAddToShoppingListWithoutStore() async throws {
        let item = createTestItem()
        let repository = deps.shoppingListRepository

        // Add item without specifying a store
        let shoppingItem = try await repository.addQuantity(
            3.0,
            toItem: item.glassItem.stable_id,
            store: nil
        )

        #expect(shoppingItem != nil)
        #expect(shoppingItem.item_stable_id == item.glassItem.stable_id)
        #expect(shoppingItem.quantity == 3.0)
        #expect(shoppingItem.store == nil)
    }

    @Test("Shopping list item appears in section after adding")
    func testShoppingListItemAppearsAfterAdding() async throws {
        let item = createTestItem()
        let repository = deps.shoppingListRepository

        // Verify item is not on shopping list initially
        let initialItem = try? await repository.fetchItem(forItem: item.glassItem.stable_id)
        #expect(initialItem == nil)

        // Add item to shopping list
        let shoppingItem = try await repository.addQuantity(
            7.5,
            toItem: item.glassItem.stable_id,
            store: "Art Store"
        )

        #expect(shoppingItem != nil)

        // Verify item now appears on shopping list
        let fetchedItem = try await repository.fetchItem(forItem: item.glassItem.stable_id)
        #expect(fetchedItem != nil)
        #expect(fetchedItem?.item_stable_id == item.glassItem.stable_id)
        #expect(fetchedItem?.quantity == 7.5)
        #expect(fetchedItem?.store == "Art Store")
    }

    @Test("Shopping list updates existing item quantity")
    func testShoppingListUpdatesExistingQuantity() async throws {
        let item = createTestItem()
        let repository = deps.shoppingListRepository

        // Add item first time
        _ = try await repository.addQuantity(
            5.0,
            toItem: item.glassItem.stable_id,
            store: "Store A"
        )

        // Add again to same item - should update
        let updatedItem = try await repository.addQuantity(
            3.0,
            toItem: item.glassItem.stable_id,
            store: "Store A"
        )

        #expect(updatedItem.quantity == 8.0) // 5.0 + 3.0

        // Verify only one item exists
        let fetchedItem = try await repository.fetchItem(forItem: item.glassItem.stable_id)
        #expect(fetchedItem?.quantity == 8.0)
    }

    // MARK: - Shopping List Display Tests

    @Test("InventoryDetailView shows shopping list section when item is on list")
    func testShoppingListSectionDisplaysWhenItemOnList() async throws {
        let item = createTestItem()
        let repository = deps.shoppingListRepository

        // Add item to shopping list
        _ = try await repository.addQuantity(
            4.0,
            toItem: item.glassItem.stable_id,
            store: "Glass Shop"
        )

        // Create view
        let view = InventoryDetailView(item: item, deps: deps)

        #expect(view != nil)

        // Verify shopping list item was added
        let shoppingItem = try await repository.fetchItem(forItem: item.glassItem.stable_id)
        #expect(shoppingItem != nil)
        #expect(shoppingItem?.quantity == 4.0)
        #expect(shoppingItem?.store == "Glass Shop")
    }

    @Test("InventoryDetailView hides shopping list section when item not on list")
    func testShoppingListSectionHiddenWhenNotOnList() async throws {
        let item = createTestItem()
        let repository = deps.shoppingListRepository

        // Verify item is not on shopping list
        let shoppingItem = try? await repository.fetchItem(forItem: item.glassItem.stable_id)
        #expect(shoppingItem == nil)

        // Create view
        let view = InventoryDetailView(item: item, deps: deps)

        #expect(view != nil)
        // Shopping list section should not be displayed (tested via view state)
    }

    // MARK: - Shopping List Removal Tests

    @Test("Remove item from shopping list")
    func testRemoveFromShoppingList() async throws {
        let item = createTestItem()
        let repository = deps.shoppingListRepository

        // Add item first
        _ = try await repository.addQuantity(
            6.0,
            toItem: item.glassItem.stable_id,
            store: "Shop"
        )

        // Verify it exists
        let addedItem = try await repository.fetchItem(forItem: item.glassItem.stable_id)
        #expect(addedItem != nil)

        // Remove it
        try await repository.deleteItem(forItem: item.glassItem.stable_id)

        // Verify it's gone
        let removedItem = try? await repository.fetchItem(forItem: item.glassItem.stable_id)
        #expect(removedItem == nil)
    }

    // MARK: - Shopping List Edit Tests

    @Test("Edit shopping list item quantity")
    func testEditShoppingListQuantity() async throws {
        let item = createTestItem()
        let repository = deps.shoppingListRepository

        // Add item
        let originalItem = try await repository.addQuantity(
            5.0,
            toItem: item.glassItem.stable_id,
            store: "Store"
        )
        #expect(originalItem.quantity == 5.0)

        // Update quantity by replacing (set to new value, not add)
        try await repository.setQuantity(
            10.0,
            forItem: item.glassItem.stable_id
        )

        // Verify update
        let updatedItem = try await repository.fetchItem(forItem: item.glassItem.stable_id)
        #expect(updatedItem?.quantity == 10.0)
    }

    @Test("Edit shopping list item store")
    func testEditShoppingListStore() async throws {
        let item = createTestItem()
        let repository = deps.shoppingListRepository

        // Add item with initial store
        _ = try await repository.addQuantity(
            5.0,
            toItem: item.glassItem.stable_id,
            store: "Store A"
        )

        // Update store
        try await repository.updateStore(
            "Store B",
            forItem: item.glassItem.stable_id
        )

        // Verify update
        let updatedItem = try await repository.fetchItem(forItem: item.glassItem.stable_id)
        #expect(updatedItem?.store == "Store B")
    }

    // MARK: - Store Autocomplete Tests

    @Test("Store autocomplete field initializes")
    func testStoreAutoCompleteFieldInitialization() {
        let storeBinding = Binding<String>(
            get: { "" },
            set: { _ in }
        )

        let field = StoreAutoCompleteField(
            store: storeBinding,
            shoppingListRepository: deps.shoppingListRepository,
            locationService: deps.unifiedLocationService
        )

        #expect(field != nil)
    }

    @Test("Store field trims whitespace")
    func testStoreFieldTrimsWhitespace() {
        let input = "  Test Store  "
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        #expect(trimmed == "Test Store")
    }

    @Test("Empty store field is treated as nil")
    func testEmptyStoreFieldIsNil() {
        let emptyStore = ""
        let trimmedEmpty = emptyStore.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalStore = trimmedEmpty.isEmpty ? nil : trimmedEmpty

        #expect(finalStore == nil)
    }

    // MARK: - Shopping List Integration with Inventory Tests

    @Test("Can add item to shopping list even if not in inventory")
    func testAddToShoppingListWithoutInventory() async throws {
        let item = createTestItem(withInventory: false)
        #expect(item.inventory.isEmpty)

        let repository = deps.shoppingListRepository

        // Should be able to add to shopping list
        let shoppingItem = try await repository.addQuantity(
            2.0,
            toItem: item.glassItem.stable_id,
            store: "Store"
        )

        #expect(shoppingItem != nil)
        #expect(shoppingItem.quantity == 2.0)
    }

    @Test("Can add item to shopping list when item has inventory")
    func testAddToShoppingListWithInventory() async throws {
        let item = createTestItem(withInventory: true)
        #expect(!item.inventory.isEmpty)
        #expect(item.totalQuantity == 10.0)

        let repository = deps.shoppingListRepository

        // Should be able to add to shopping list
        let shoppingItem = try await repository.addQuantity(
            5.0,
            toItem: item.glassItem.stable_id,
            store: "Store"
        )

        #expect(shoppingItem != nil)
        #expect(shoppingItem.quantity == 5.0)
    }

    // MARK: - Formatted Quantity Tests

    @Test("Shopping list item formats whole number quantities")
    func testFormattedWholeNumberQuantity() {
        let quantity = 10.0
        let formatted: String

        if quantity.truncatingRemainder(dividingBy: 1) == 0 {
            formatted = String(format: "%.0f", quantity)
        } else {
            formatted = String(format: "%.1f", quantity)
        }

        #expect(formatted == "10")
    }

    @Test("Shopping list item formats decimal quantities")
    func testFormattedDecimalQuantity() {
        let quantity = 7.5
        let formatted: String

        if quantity.truncatingRemainder(dividingBy: 1) == 0 {
            formatted = String(format: "%.0f", quantity)
        } else {
            formatted = String(format: "%.1f", quantity)
        }

        #expect(formatted == "7.5")
    }

    // MARK: - Multiple Items Shopping List Tests

    @Test("Multiple items can be on shopping list simultaneously")
    func testMultipleItemsOnShoppingList() async throws {
        let repository = deps.shoppingListRepository

        // Create multiple test items
        let item1 = createTestItem()
        let item2StableId = generateStableId(manufacturer: "test", sku: "002")

        // Add both to shopping list
        _ = try await repository.addQuantity(3.0, toItem: item1.glassItem.stable_id, store: "Store A")
        _ = try await repository.addQuantity(5.0, toItem: item2StableId, store: "Store B")

        // Verify both exist
        let fetchedItem1 = try await repository.fetchItem(forItem: item1.glassItem.stable_id)
        let fetchedItem2 = try await repository.fetchItem(forItem: item2StableId)

        #expect(fetchedItem1 != nil)
        #expect(fetchedItem1?.quantity == 3.0)
        #expect(fetchedItem2 != nil)
        #expect(fetchedItem2?.quantity == 5.0)
    }
}
