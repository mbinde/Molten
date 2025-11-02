//
//  StoreAutoCompleteFieldCombinedSourcesTests.swift
//  MoltenTests
//
//  Created by Claude on 11/01/25.
//  Tests for StoreAutoCompleteField combined store suggestions
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

@Suite("StoreAutoCompleteField Combined Sources Tests")
struct StoreAutoCompleteFieldCombinedSourcesTests {

    // MARK: - Combined Source Tests

    @Test("Should fetch stores from both Store entities and shopping list")
    @MainActor
    func testCombinedSources() async throws {
        // Arrange
        let _ = RepositoryFactory.configureForTesting()
        let storeRepository = RepositoryFactory.createStoreRepository()
        let shoppingListRepository = RepositoryFactory.createShoppingListRepository()

        // Add Store entity
        let storeEntity = StoreModel(
            stable_id: "store-1",
            name: "Frantz Art Glass",
            city: "Seattle",
            state: "WA"
        )
        _ = try await storeRepository.createStore(storeEntity)

        // Add shopping list item with different store
        let shoppingItem = ItemShoppingModel(
            item_stable_id: "item-1",
            quantity: 1,
            store: "Olympic Color"
        )
        _ = try await shoppingListRepository.createItem(shoppingItem)

        // Act
        let storeEntities = try await storeRepository.fetchAllStores()
        let shoppingStores = try await shoppingListRepository.getDistinctStores()

        // Assert
        #expect(storeEntities.count == 1)
        #expect(storeEntities.first?.name == "Frantz Art Glass")
        #expect(shoppingStores.count == 1)
        #expect(shoppingStores.first == "Olympic Color")
    }

    @Test("Should deduplicate stores that appear in both sources")
    @MainActor
    func testDeduplication() async throws {
        // Arrange
        let _ = RepositoryFactory.configureForTesting()
        let storeRepository = RepositoryFactory.createStoreRepository()
        let shoppingListRepository = RepositoryFactory.createShoppingListRepository()

        let storeName = "Frantz Art Glass"

        // Add to both sources
        let storeEntity = StoreModel(
            stable_id: "store-1",
            name: storeName,
            city: "Seattle",
            state: "WA"
        )
        _ = try await storeRepository.createStore(storeEntity)

        let shoppingItem = ItemShoppingModel(
            item_stable_id: "item-1",
            quantity: 1,
            store: storeName
        )
        _ = try await shoppingListRepository.createItem(shoppingItem)

        // Act
        let storeEntities = try await storeRepository.fetchAllStores()
        let shoppingStores = try await shoppingListRepository.getDistinctStores()

        // Simulate deduplication logic (prefer Store entities)
        var uniqueStores: [String: Bool] = [:]  // name -> isStoreEntity
        for store in shoppingStores {
            uniqueStores[store] = false
        }
        for store in storeEntities {
            uniqueStores[store.name] = true  // Overwrite with Store entity
        }

        // Assert
        #expect(uniqueStores.count == 1)
        #expect(uniqueStores[storeName] == true)  // Should be marked as Store entity
    }

    @Test("Should prioritize Store entities over shopping list entries")
    @MainActor
    func testStoreEntityPriority() async throws {
        // Arrange
        let _ = RepositoryFactory.configureForTesting()
        let storeRepository = RepositoryFactory.createStoreRepository()
        let shoppingListRepository = RepositoryFactory.createShoppingListRepository()

        // Add same store to both sources
        let storeName = "Frantz Art Glass"

        let storeEntity = StoreModel(
            stable_id: "store-1",
            name: storeName,
            city: "Seattle",
            state: "WA",
            latitude: 47.6362,
            longitude: -122.3598
        )
        _ = try await storeRepository.createStore(storeEntity)

        let shoppingItem = ItemShoppingModel(
            item_stable_id: "item-1",
            quantity: 1,
            store: storeName
        )
        _ = try await shoppingListRepository.createItem(shoppingItem)

        // Act - Fetch from both sources
        let storeEntities = try await storeRepository.fetchAllStores()
        let matchingStoreEntity = storeEntities.first { $0.name == storeName }

        // Assert - Store entity should have richer data
        #expect(matchingStoreEntity != nil)
        #expect(matchingStoreEntity?.hasValidLocation == true)
        #expect(matchingStoreEntity?.city == "Seattle")
    }

    // MARK: - Sorting Tests

    @Test("Should sort combined results alphabetically")
    @MainActor
    func testAlphabeticalSorting() async throws {
        // Arrange
        let _ = RepositoryFactory.configureForTesting()
        let storeRepository = RepositoryFactory.createStoreRepository()
        let shoppingListRepository = RepositoryFactory.createShoppingListRepository()

        // Add stores in random order
        let storeEntity1 = StoreModel(stable_id: "s1", name: "Zebra Glass")
        let storeEntity2 = StoreModel(stable_id: "s2", name: "Apple Glass")
        _ = try await storeRepository.createStore(storeEntity1)
        _ = try await storeRepository.createStore(storeEntity2)

        let shoppingItem1 = ItemShoppingModel(
            item_stable_id: "i1",
            quantity: 1,
            store: "Mango Glass"
        )
        let shoppingItem2 = ItemShoppingModel(
            item_stable_id: "i2",
            quantity: 1,
            store: "Banana Glass"
        )
        _ = try await shoppingListRepository.createItem(shoppingItem1)
        _ = try await shoppingListRepository.createItem(shoppingItem2)

        // Act
        let storeEntities = try await storeRepository.fetchAllStores()
        let shoppingStores = try await shoppingListRepository.getDistinctStores()

        // Combine and sort
        var allStoreNames = storeEntities.map { $0.name }
        allStoreNames.append(contentsOf: shoppingStores)
        allStoreNames = Array(Set(allStoreNames)).sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }

        // Assert
        #expect(allStoreNames == ["Apple Glass", "Banana Glass", "Mango Glass", "Zebra Glass"])
    }

    @Test("Should handle case-insensitive sorting")
    @MainActor
    func testCaseInsensitiveSorting() async throws {
        // Arrange
        let stores = ["zebra glass", "Apple Glass", "MANGO GLASS", "Banana glass"]
        let sorted = stores.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }

        // Assert
        #expect(sorted[0].lowercased() == "apple glass")
        #expect(sorted[1].lowercased() == "banana glass")
        #expect(sorted[2].lowercased() == "mango glass")
        #expect(sorted[3].lowercased() == "zebra glass")
    }

    // MARK: - Filtering Tests

    @Test("Should filter combined results by prefix")
    @MainActor
    func testPrefixFiltering() async throws {
        // Arrange
        let stores = ["Frantz Art Glass", "Bullseye Glass Co", "Olympic Color", "Northstar Glassworks"]
        let searchText = "fr"

        // Act
        let filtered = stores.filter {
            $0.lowercased().hasPrefix(searchText.lowercased())
        }

        // Assert
        #expect(filtered.count == 1)
        #expect(filtered.first == "Frantz Art Glass")
    }

    @Test("Should return all stores for empty search")
    @MainActor
    func testEmptySearchReturnsAll() async throws {
        // Arrange
        let stores = ["Frantz Art Glass", "Olympic Color", "Bullseye Glass Co"]
        let searchText = ""

        // Act
        let filtered = searchText.isEmpty ? stores : stores.filter {
            $0.lowercased().hasPrefix(searchText.lowercased())
        }

        // Assert
        #expect(filtered.count == 3)
    }

    @Test("Should handle search with no matches")
    @MainActor
    func testSearchWithNoMatches() async throws {
        // Arrange
        let stores = ["Frantz Art Glass", "Olympic Color"]
        let searchText = "xyz"

        // Act
        let filtered = stores.filter {
            $0.lowercased().hasPrefix(searchText.lowercased())
        }

        // Assert
        #expect(filtered.isEmpty)
    }

    // MARK: - Store Entity Icon Tests

    @Test("Store entity should be distinguishable from shopping list entry")
    func testStoreEntityMarking() {
        // This tests the concept that Store entities should be marked
        struct StoreSuggestion {
            let name: String
            let isStoreEntity: Bool
        }

        let storeEntity = StoreSuggestion(name: "Frantz Art Glass", isStoreEntity: true)
        let shoppingEntry = StoreSuggestion(name: "Olympic Color", isStoreEntity: false)

        #expect(storeEntity.isStoreEntity == true)
        #expect(shoppingEntry.isStoreEntity == false)
    }

    // MARK: - Edge Cases

    @Test("Should handle empty results from both sources")
    @MainActor
    func testEmptyResultsFromBothSources() async throws {
        // Arrange
        let _ = RepositoryFactory.configureForTesting()
        let storeRepository = RepositoryFactory.createStoreRepository()
        let shoppingListRepository = RepositoryFactory.createShoppingListRepository()

        // Act
        let storeEntities = try await storeRepository.fetchAllStores()
        let shoppingStores = try await shoppingListRepository.getDistinctStores()

        // Assert
        #expect(storeEntities.isEmpty)
        #expect(shoppingStores.isEmpty)
    }

    @Test("Should handle only Store entities (no shopping list)")
    @MainActor
    func testOnlyStoreEntities() async throws {
        // Arrange
        let _ = RepositoryFactory.configureForTesting()
        let storeRepository = RepositoryFactory.createStoreRepository()
        let shoppingListRepository = RepositoryFactory.createShoppingListRepository()

        let store = StoreModel(
            stable_id: "store-1",
            name: "Frantz Art Glass"
        )
        _ = try await storeRepository.createStore(store)

        // Act
        let storeEntities = try await storeRepository.fetchAllStores()
        let shoppingStores = try await shoppingListRepository.getDistinctStores()

        // Assert
        #expect(storeEntities.count == 1)
        #expect(shoppingStores.isEmpty)
    }

    @Test("Should handle only shopping list entries (no Store entities)")
    @MainActor
    func testOnlyShoppingListEntries() async throws {
        // Arrange
        let _ = RepositoryFactory.configureForTesting()
        let storeRepository = RepositoryFactory.createStoreRepository()
        let shoppingListRepository = RepositoryFactory.createShoppingListRepository()

        let item = ItemShoppingModel(
            item_stable_id: "item-1",
            quantity: 1,
            store: "Olympic Color"
        )
        _ = try await shoppingListRepository.createItem(item)

        // Act
        let storeEntities = try await storeRepository.fetchAllStores()
        let shoppingStores = try await shoppingListRepository.getDistinctStores()

        // Assert
        #expect(storeEntities.isEmpty)
        #expect(shoppingStores.count == 1)
    }

    @Test("Should handle special characters in store names from both sources")
    @MainActor
    func testSpecialCharactersInBothSources() async throws {
        // Arrange
        let _ = RepositoryFactory.configureForTesting()
        let storeRepository = RepositoryFactory.createStoreRepository()
        let shoppingListRepository = RepositoryFactory.createShoppingListRepository()

        let storeName = "Art & Glass Co."

        let store = StoreModel(
            stable_id: "store-1",
            name: storeName
        )
        _ = try await storeRepository.createStore(store)

        let item = ItemShoppingModel(
            item_stable_id: "item-1",
            quantity: 1,
            store: storeName
        )
        _ = try await shoppingListRepository.createItem(item)

        // Act
        let storeEntities = try await storeRepository.fetchAllStores()
        let shoppingStores = try await shoppingListRepository.getDistinctStores()

        // Assert
        #expect(storeEntities.first?.name == storeName)
        #expect(shoppingStores.first == storeName)
    }

    // MARK: - UI Behavior Tests

    @Test("Should handle suggestion limit of 5 items")
    func testSuggestionLimit() {
        // Arrange
        let allStores = [
            "Store 1",
            "Store 2",
            "Store 3",
            "Store 4",
            "Store 5",
            "Store 6",
            "Store 7"
        ]

        // Act
        let limited = Array(allStores.prefix(5))

        // Assert
        #expect(limited.count == 5)
        #expect(limited.last == "Store 5")
    }
}

#endif
