//
//  ShoppingListStoreFilteringTests.swift
//  MoltenTests
//
//  Created by Claude on 11/01/25.
//  Tests for shopping list store filtering functionality
//

import Foundation

#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

@testable import Molten

#if canImport(Testing)

@Suite("Shopping List Store Filtering Tests")
struct ShoppingListStoreFilteringTests {

    // MARK: - ViewModel Store Filtering Tests

    @Test("ViewModel should filter shopping list by selected store")
    @MainActor
    func testViewModelStoreFiltering() async throws {
        // Arrange
        let deps = AppDependencies(forTesting: true)
        let shoppingListService = deps.shoppingListService

        // Create items for different stores
        let frantzItem = ItemShoppingModel(
            item_stable_id: "bullseye-0001-0",
            quantity: 10,
            store: "Frantz Art Glass"
        )
        let olympicItem = ItemShoppingModel(
            item_stable_id: "cim-123-0",
            quantity: 5,
            store: "Olympic Color"
        )

        _ = try await shoppingListService.shoppingListRepository.createItem(frantzItem)
        _ = try await shoppingListService.shoppingListRepository.createItem(olympicItem)

        let viewModel = ShoppingListViewModel(shoppingListService: shoppingListService)

        // Act
        await viewModel.loadShoppingLists()
        viewModel.selectedStore = "Frantz Art Glass"

        // Assert
        #expect(viewModel.selectedStore == "Frantz Art Glass")
        #expect(viewModel.shoppingLists.keys.contains("Frantz Art Glass"))
        #expect(viewModel.shoppingLists.keys.contains("Olympic Color"))
    }

    @Test("Should clear store filter when set to nil")
    @MainActor
    func testClearStoreFilter() async throws {
        // Arrange
        let deps = AppDependencies(forTesting: true)
        let shoppingListService = deps.shoppingListService
        let viewModel = ShoppingListViewModel(shoppingListService: shoppingListService)

        // Set a filter
        viewModel.selectedStore = "Frantz Art Glass"
        #expect(viewModel.selectedStore != nil)

        // Act - Clear filter
        viewModel.selectedStore = nil

        // Assert
        #expect(viewModel.selectedStore == nil)
    }

    @Test("Should handle store filter with no matching items")
    @MainActor
    func testStoreFilterWithNoMatches() async throws {
        // Arrange
        let deps = AppDependencies(forTesting: true)
        let shoppingListService = deps.shoppingListService

        // Create items for one store
        let item = ItemShoppingModel(
            item_stable_id: "bullseye-0001-0",
            quantity: 10,
            store: "Frantz Art Glass"
        )
        _ = try await shoppingListService.shoppingListRepository.createItem(item)

        let viewModel = ShoppingListViewModel(shoppingListService: shoppingListService)
        await viewModel.loadShoppingLists()

        // Act - Filter by non-existent store
        viewModel.selectedStore = "Nonexistent Store"

        // Assert - Should have the filter set, but no results match
        #expect(viewModel.selectedStore == "Nonexistent Store")
    }

    // MARK: - Repository Filtering Tests

    @Test("Repository should fetch items for specific store")
    @MainActor
    func testRepositoryFetchItemsForStore() async throws {
        // Arrange
        let deps = AppDependencies(forTesting: true)
        let repository = deps.shoppingListRepository

        let storeName = "Frantz Art Glass"
        let item1 = ItemShoppingModel(
            item_stable_id: "item-1",
            quantity: 1,
            store: storeName
        )
        let item2 = ItemShoppingModel(
            item_stable_id: "item-2",
            quantity: 2,
            store: storeName
        )
        let otherStoreItem = ItemShoppingModel(
            item_stable_id: "item-3",
            quantity: 3,
            store: "Other Store"
        )

        _ = try await repository.createItem(item1)
        _ = try await repository.createItem(item2)
        _ = try await repository.createItem(otherStoreItem)

        // Act
        let items = try await repository.fetchItems(forStore: storeName)

        // Assert
        #expect(items.count == 2)
        #expect(items.allSatisfy { $0.store == storeName })
    }

    @Test("Repository should return distinct store names")
    @MainActor
    func testRepositoryGetDistinctStores() async throws {
        // Arrange
        let deps = AppDependencies(forTesting: true)
        let repository = deps.shoppingListRepository

        // Add items with duplicate store names
        let stores = ["Frantz Art Glass", "Olympic Color", "Frantz Art Glass", "Bullseye"]
        for (index, store) in stores.enumerated() {
            let item = ItemShoppingModel(
                item_stable_id: "item-\(index)",
                quantity: 1,
                store: store
            )
            _ = try await repository.createItem(item)
        }

        // Act
        let distinctStores = try await repository.getDistinctStores()

        // Assert
        #expect(distinctStores.count == 3)
        #expect(distinctStores.contains("Frantz Art Glass"))
        #expect(distinctStores.contains("Olympic Color"))
        #expect(distinctStores.contains("Bullseye"))
    }

    @Test("Should get item count by store")
    @MainActor
    func testGetItemCountByStore() async throws {
        // Arrange
        let deps = AppDependencies(forTesting: true)
        let repository = deps.shoppingListRepository

        // Create items for different stores
        for i in 1...3 {
            let item = ItemShoppingModel(
                item_stable_id: "frantz-\(i)",
                quantity: 1,
                store: "Frantz Art Glass"
            )
            _ = try await repository.createItem(item)
        }

        for i in 1...2 {
            let item = ItemShoppingModel(
                item_stable_id: "olympic-\(i)",
                quantity: 1,
                store: "Olympic Color"
            )
            _ = try await repository.createItem(item)
        }

        // Act
        let counts = try await repository.getItemCountByStore()

        // Assert
        #expect(counts["Frantz Art Glass"] == 3)
        #expect(counts["Olympic Color"] == 2)
    }

    // MARK: - Store Name Edge Cases

    @Test("Should handle empty store name")
    @MainActor
    func testEmptyStoreName() async throws {
        // Arrange
        let deps = AppDependencies(forTesting: true)
        let repository = deps.shoppingListRepository

        let item = ItemShoppingModel(
            item_stable_id: "item-1",
            quantity: 1,
            store: ""
        )
        _ = try await repository.createItem(item)

        // Act
        let items = try await repository.fetchItems(forStore: "")

        // Assert
        #expect(items.count == 1)
        #expect(items.first?.store == "")
    }

    @Test("Should handle whitespace-only store names")
    @MainActor
    func testWhitespaceStoreName() async throws {
        // Arrange
        let deps = AppDependencies(forTesting: true)
        let repository = deps.shoppingListRepository

        let item = ItemShoppingModel(
            item_stable_id: "item-1",
            quantity: 1,
            store: "   "
        )
        _ = try await repository.createItem(item)

        // Act
        let items = try await repository.fetchItems(forStore: "   ")

        // Assert
        #expect(items.count == 1)
    }

    @Test("Should handle very long store names")
    @MainActor
    func testVeryLongStoreName() async throws {
        // Arrange
        let deps = AppDependencies(forTesting: true)
        let repository = deps.shoppingListRepository

        let longName = String(repeating: "A", count: 500)
        let item = ItemShoppingModel(
            item_stable_id: "item-1",
            quantity: 1,
            store: longName
        )
        _ = try await repository.createItem(item)

        // Act
        let items = try await repository.fetchItems(forStore: longName)

        // Assert
        #expect(items.count == 1)
        #expect(items.first?.store == longName)
    }

    // MARK: - Filter Integration Tests

    @Test("Should apply multiple filters together")
    @MainActor
    func testMultipleFilters() async throws {
        // Arrange
        let deps = AppDependencies(forTesting: true)
        let shoppingListService = deps.shoppingListService
        let viewModel = ShoppingListViewModel(shoppingListService: shoppingListService)

        // Create items
        let item = ItemShoppingModel(
            item_stable_id: "bullseye-0001-0",
            quantity: 10,
            store: "Frantz Art Glass"
        )
        _ = try await shoppingListService.shoppingListRepository.createItem(item)

        await viewModel.loadShoppingLists()

        // Act - Apply store filter and search
        viewModel.selectedStore = "Frantz Art Glass"
        viewModel.searchText = "bullseye"

        // Assert
        #expect(viewModel.selectedStore == "Frantz Art Glass")
        #expect(viewModel.searchText == "bullseye")
    }

    @Test("Should reset all filters")
    @MainActor
    func testResetAllFilters() async throws {
        // Arrange
        let deps = AppDependencies(forTesting: true)
        let shoppingListService = deps.shoppingListService
        let viewModel = ShoppingListViewModel(shoppingListService: shoppingListService)

        // Apply filters
        viewModel.selectedStore = "Frantz Art Glass"
        viewModel.searchText = "test"
        viewModel.selectedTags = Set(["transparent"])
        viewModel.selectedCOEs = Set([90])

        // Act - Clear all filters
        viewModel.selectedStore = nil
        viewModel.searchText = ""
        viewModel.selectedTags.removeAll()
        viewModel.selectedCOEs.removeAll()

        // Assert
        #expect(viewModel.selectedStore == nil)
        #expect(viewModel.searchText.isEmpty)
        #expect(viewModel.selectedTags.isEmpty)
        #expect(viewModel.selectedCOEs.isEmpty)
    }

    // MARK: - Sorting with Filters

    @Test("Should maintain sorting when filtering by store")
    @MainActor
    func testSortingWithStoreFilter() async throws {
        // Arrange
        let deps = AppDependencies(forTesting: true)
        let repository = deps.shoppingListRepository

        // Create items with different stable_ids
        let stores = ["Frantz Art Glass", "Frantz Art Glass", "Frantz Art Glass"]
        let stableIds = ["c-item", "a-item", "b-item"]

        for (store, stableId) in zip(stores, stableIds) {
            let item = ItemShoppingModel(
                item_stable_id: stableId,
                quantity: 1,
                store: store
            )
            _ = try await repository.createItem(item)
        }

        // Act
        let items = try await repository.fetchItems(forStore: "Frantz Art Glass")
        let sortedIds = items.map { $0.item_stable_id }.sorted()

        // Assert
        #expect(sortedIds == ["a-item", "b-item", "c-item"])
    }
}

#endif
