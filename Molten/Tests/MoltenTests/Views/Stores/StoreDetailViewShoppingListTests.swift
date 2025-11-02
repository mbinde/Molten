//
//  StoreDetailViewShoppingListTests.swift
//  MoltenTests
//
//  Created by Claude on 11/01/25.
//  Tests for shopping list integration in StoreDetailView
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

@Suite("StoreDetailView Shopping List Integration Tests")
struct StoreDetailViewShoppingListTests {

    // MARK: - Shopping List Detection Tests

    @Test("Should detect shopping list items for store")
    @MainActor
    func testDetectShoppingListItems() async throws {
        // Arrange
        let _ = RepositoryFactory.configureForTesting()
        let shoppingListService = RepositoryFactory.createShoppingListService()

        // Create a store
        let store = StoreModel(
            stable_id: "test-store-1",
            name: "Frantz Art Glass",
            city: "Seattle",
            state: "WA",
            isVerified: true
        )

        // Add shopping list items for this store
        let item1 = ItemShoppingModel(
            item_stable_id: "bullseye-0001-0",
            quantity: 10,
            store: "Frantz Art Glass",
            type: "rod"
        )
        let item2 = ItemShoppingModel(
            item_stable_id: "cim-123-0",
            quantity: 5,
            store: "Frantz Art Glass",
            type: "frit"
        )

        _ = try await shoppingListService.shoppingListRepository.createItem(item1)
        _ = try await shoppingListService.shoppingListRepository.createItem(item2)

        // Act - Fetch items for this store
        let items = try await shoppingListService.shoppingListRepository.fetchItems(forStore: "Frantz Art Glass")

        // Assert
        #expect(items.count == 2)
        #expect(items.contains { $0.item_stable_id == "bullseye-0001-0" })
        #expect(items.contains { $0.item_stable_id == "cim-123-0" })
    }

    @Test("Should return empty array when store has no shopping list items")
    @MainActor
    func testNoShoppingListItems() async throws {
        // Arrange
        let _ = RepositoryFactory.configureForTesting()
        let shoppingListService = RepositoryFactory.createShoppingListService()

        // Act - Fetch items for non-existent store
        let items = try await shoppingListService.shoppingListRepository.fetchItems(forStore: "Nonexistent Store")

        // Assert
        #expect(items.isEmpty)
    }

    @Test("Should only return items for specific store")
    @MainActor
    func testStoreSpecificFiltering() async throws {
        // Arrange
        let _ = RepositoryFactory.configureForTesting()
        let shoppingListService = RepositoryFactory.createShoppingListService()

        // Add items for different stores
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

        // Act - Fetch items for Frantz only
        let frantzItems = try await shoppingListService.shoppingListRepository.fetchItems(forStore: "Frantz Art Glass")

        // Assert
        #expect(frantzItems.count == 1)
        #expect(frantzItems.first?.store == "Frantz Art Glass")
        #expect(frantzItems.first?.item_stable_id == "bullseye-0001-0")
    }

    @Test("Should handle stores with special characters in name")
    @MainActor
    func testStoreNameWithSpecialCharacters() async throws {
        // Arrange
        let _ = RepositoryFactory.configureForTesting()
        let shoppingListService = RepositoryFactory.createShoppingListService()

        let storeName = "Art & Glass Co."
        let item = ItemShoppingModel(
            item_stable_id: "test-item",
            quantity: 1,
            store: storeName
        )

        _ = try await shoppingListService.shoppingListRepository.createItem(item)

        // Act
        let items = try await shoppingListService.shoppingListRepository.fetchItems(forStore: storeName)

        // Assert
        #expect(items.count == 1)
        #expect(items.first?.store == storeName)
    }

    @Test("Should count items correctly for shopping list badge")
    @MainActor
    func testItemCountForBadge() async throws {
        // Arrange
        let _ = RepositoryFactory.configureForTesting()
        let shoppingListService = RepositoryFactory.createShoppingListService()

        let storeName = "Frantz Art Glass"

        // Add 5 items
        for i in 1...5 {
            let item = ItemShoppingModel(
                item_stable_id: "item-\(i)",
                quantity: Double(i),
                store: storeName
            )
            _ = try await shoppingListService.shoppingListRepository.createItem(item)
        }

        // Act
        let items = try await shoppingListService.shoppingListRepository.fetchItems(forStore: storeName)

        // Assert
        #expect(items.count == 5)
    }

    // MARK: - Store Model Tests

    @Test("StoreModel should be identifiable for MapKit")
    func testStoreModelIdentifiable() {
        let store1 = StoreModel(
            stable_id: "store-1",
            name: "Store 1",
            city: "Seattle",
            state: "WA"
        )
        let store2 = StoreModel(
            stable_id: "store-2",
            name: "Store 2",
            city: "Portland",
            state: "OR"
        )

        #expect(store1.id == "store-1")
        #expect(store2.id == "store-2")
        #expect(store1.id != store2.id)
    }

    @Test("StoreModel should validate location data")
    func testStoreLocationValidation() {
        let storeWithLocation = StoreModel(
            stable_id: "store-1",
            name: "Frantz Art Glass",
            latitude: 47.6362,
            longitude: -122.3598
        )

        let storeWithoutLocation = StoreModel(
            stable_id: "store-2",
            name: "Unknown Store"
        )

        #expect(storeWithLocation.hasValidLocation == true)
        #expect(storeWithoutLocation.hasValidLocation == false)
    }

    // MARK: - Edge Cases

    @Test("Should handle case-sensitive store name matching")
    @MainActor
    func testCaseSensitiveStoreNames() async throws {
        // Arrange
        let _ = RepositoryFactory.configureForTesting()
        let shoppingListService = RepositoryFactory.createShoppingListService()

        // Create items with different case variations
        let item1 = ItemShoppingModel(
            item_stable_id: "item-1",
            quantity: 1,
            store: "Frantz Art Glass"
        )
        let item2 = ItemShoppingModel(
            item_stable_id: "item-2",
            quantity: 1,
            store: "frantz art glass"  // lowercase
        )

        _ = try await shoppingListService.shoppingListRepository.createItem(item1)
        _ = try await shoppingListService.shoppingListRepository.createItem(item2)

        // Act - Search with exact case
        let exactMatch = try await shoppingListService.shoppingListRepository.fetchItems(forStore: "Frantz Art Glass")
        let lowerMatch = try await shoppingListService.shoppingListRepository.fetchItems(forStore: "frantz art glass")

        // Assert - Should be case-sensitive (only exact matches)
        #expect(exactMatch.count == 1)
        #expect(lowerMatch.count == 1)
        #expect(exactMatch.first?.item_stable_id == "item-1")
        #expect(lowerMatch.first?.item_stable_id == "item-2")
    }

    @Test("Should handle nil store name in shopping list items")
    @MainActor
    func testNilStoreInShoppingListItem() async throws {
        // Arrange
        let _ = RepositoryFactory.configureForTesting()
        let shoppingListService = RepositoryFactory.createShoppingListService()

        // Create item without store
        let item = ItemShoppingModel(
            item_stable_id: "item-1",
            quantity: 1,
            store: nil
        )

        _ = try await shoppingListService.shoppingListRepository.createItem(item)

        // Act - Try to fetch items for any store
        let items = try await shoppingListService.shoppingListRepository.fetchItems(forStore: "Any Store")

        // Assert - Should not match items with nil store
        #expect(items.isEmpty)
    }
}

#endif
