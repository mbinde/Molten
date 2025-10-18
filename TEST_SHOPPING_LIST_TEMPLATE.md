# Shopping List Item Creation Tests Template

## Instructions

To add these tests to your project:

1. In Xcode, right-click on the `FlameworkerTests` group
2. Select "New File..."
3. Choose "Swift File"
4. Name it `ShoppingListItemCreationTests.swift`
5. **IMPORTANT**: Make sure only `FlameworkerTests` target is checked (not `Flameworker`)
6. Copy and paste the code below into the new file

## Test File Code

```swift
//
//  ShoppingListItemCreationTests.swift
//  FlameworkerTests
//
//  Tests for shopping list item creation functionality
//  Tests the business logic and service integration for AddShoppingListItemView
//

import Testing
import Foundation
@testable import Flameworker

@Suite("Shopping List Item Creation Tests")
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
        let items = try await shoppingListService.shoppingListRepository.getItems(forStore: "Test Store")

        #expect(items.count > 0)
        #expect(items.allSatisfy { $0.store == "Test Store" })
    }

    @Test("Type and subtype consistency")
    func testTypeSubtypeConsistency() async throws {
        RepositoryFactory.configureForTesting()
        let catalogService = RepositoryFactory.createCatalogService()

        let glassItem = try await createTestGlassItem(catalogService: catalogService)

        // Verify subtypes are appropriate for their types
        let availableSubtypes = GlassItemTypeSystem.getSubtypes(for: "rod")
        #expect(availableSubtypes.contains("stringer"))
        #expect(availableSubtypes.contains("standard"))

        // Create item with valid type/subtype combination
        let item = ItemShoppingModel(
            item_natural_key: glassItem.natural_key,
            quantity: 2.0,
            store: nil,
            type: "rod",
            subtype: "stringer",
            subsubtype: nil
        )

        #expect(item.type == "rod")
        #expect(item.subtype == "stringer")
    }

    // MARK: - Test Helpers

    private func createTestGlassItem(catalogService: CatalogService) async throws -> GlassItemModel {
        // Create a complete test glass item
        let glassItem = try await catalogService.inventoryTrackingService.createCompleteItem(
            name: "Test Glass Item",
            manufacturer: "test",
            sku: "TEST-001",
            coe: 96,
            tags: ["test"],
            initialInventory: nil
        )

        return glassItem.glassItem
    }
}
```

## Test Coverage

These tests cover:

1. **Minimal field creation** - Creating shopping list items with only required fields (item, quantity)
2. **Full field creation** - Creating items with all optional fields (store, type, subtype)
3. **Type/subtype validation** - Verifying type system integration works correctly
4. **Multiple items** - Creating multiple shopping list items for the same glass item
5. **Quantity validation** - Testing quantity handling
6. **Store filtering** - Testing retrieval by store
7. **Type system consistency** - Verifying type/subtype relationships

## Running Tests

Run these specific tests with:

```bash
xcodebuild test -project Flameworker.xcodeproj -scheme Flameworker -testPlan UnitTestsOnly -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:FlameworkerTests/ShoppingListItemCreationTests
```

Or run all unit tests:

```bash
xcodebuild test -project Flameworker.xcodeproj -scheme Flameworker -testPlan UnitTestsOnly -destination 'platform=iOS Simulator,name=iPhone 17'
```
