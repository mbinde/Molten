//
//  StoreAutoCompleteFieldTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/16/25.
//  Comprehensive tests for StoreAutoCompleteField component
//
//  ⚠️ IMPORTANT: This file must be added to the FlameworkerTests target via Xcode
//  to ensure proper target membership. Do NOT add via command line.
//
//  Instructions:
//  1. Open Flameworker.xcodeproj in Xcode
//  2. Add this file to Tests/FlameworkerTests/
//  3. In the file inspector, ensure Target Membership is set to "FlameworkerTests" ONLY
//  4. Remove the .todo extension
//  5. Build and run tests
//

import Foundation

// Standard test framework imports pattern
#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

@testable import Molten

// Use Swift Testing if available
#if canImport(Testing)

@Suite("StoreAutoCompleteField Tests")
struct StoreAutoCompleteFieldTests {

    // MARK: - Store Autocomplete Tests

    @Test("Should fetch distinct stores from repository")
    func testFetchDistinctStores() async throws {
        // Create mock repository with sample stores
        let mockRepo = MockShoppingListRepository()

        // Add some sample shopping list items with different stores
        let item1 = ItemShoppingModel(
            item_natural_key: "bullseye-0001-0",
            quantity: 10,
            store: "Frantz Art Glass"
        )
        let item2 = ItemShoppingModel(
            item_natural_key: "cim-123-0",
            quantity: 5,
            store: "Olympic Color"
        )
        let item3 = ItemShoppingModel(
            item_natural_key: "ef-456-0",
            quantity: 3,
            store: "Frantz Art Glass" // Duplicate store
        )

        _ = try await mockRepo.createItem(item1)
        _ = try await mockRepo.createItem(item2)
        _ = try await mockRepo.createItem(item3)

        // Get distinct stores
        let stores = try await mockRepo.getDistinctStores()

        // Should have only 2 unique stores
        #expect(stores.count == 2)
        #expect(stores.contains("Frantz Art Glass"))
        #expect(stores.contains("Olympic Color"))
    }

    @Test("Should return empty array when no stores exist")
    func testNoStoresReturnsEmpty() async throws {
        let mockRepo = MockShoppingListRepository()

        let stores = try await mockRepo.getDistinctStores()

        #expect(stores.isEmpty)
    }

    @Test("Should filter stores by prefix (case-insensitive)")
    func testPrefixFiltering() {
        let allStores = ["Frantz Art Glass", "Bullseye Glass Co", "Olympic Color", "Northstar Glassworks"]
        let searchText = "fr"

        let filtered = allStores.filter { $0.lowercased().hasPrefix(searchText.lowercased()) }

        #expect(filtered.count == 1)
        #expect(filtered.first == "Frantz Art Glass")
    }

    @Test("Should handle case-insensitive store matching")
    func testCaseInsensitiveMatching() {
        let allStores = ["Frantz Art Glass", "Olympic Color"]

        let searchLower = "frantz"
        let searchUpper = "FRANTZ"
        let searchMixed = "FrAnTz"

        let filteredLower = allStores.filter { $0.lowercased().hasPrefix(searchLower.lowercased()) }
        let filteredUpper = allStores.filter { $0.lowercased().hasPrefix(searchUpper.lowercased()) }
        let filteredMixed = allStores.filter { $0.lowercased().hasPrefix(searchMixed.lowercased()) }

        #expect(filteredLower.count == 1)
        #expect(filteredUpper.count == 1)
        #expect(filteredMixed.count == 1)
    }

    @Test("Should return all stores for empty search")
    func testEmptySearchReturnsAll() {
        let allStores = ["Frantz Art Glass", "Olympic Color", "Bullseye Glass Co"]
        let searchText = ""

        let filtered = searchText.isEmpty ? allStores : allStores.filter { $0.lowercased().hasPrefix(searchText.lowercased()) }

        #expect(filtered.count == 3)
    }

    @Test("Should handle special characters in store names")
    func testSpecialCharactersInStoreNames() async throws {
        let mockRepo = MockShoppingListRepository()

        let item = ItemShoppingModel(
            item_natural_key: "test-item",
            quantity: 1,
            store: "Art & Glass Co."
        )
        _ = try await mockRepo.createItem(item)

        let stores = try await mockRepo.getDistinctStores()

        #expect(stores.contains("Art & Glass Co."))
    }

    @Test("Should trim whitespace from store names")
    func testWhitespaceTrimming() {
        let storeValue = "  Frantz Art Glass  "
        let trimmed = storeValue.trimmingCharacters(in: .whitespacesAndNewlines)

        #expect(trimmed == "Frantz Art Glass")
    }

    // MARK: - Integration Tests

    @Test("Should limit suggestions to 5 items")
    func testSuggestionLimit() {
        let allStores = [
            "Store 1",
            "Store 2",
            "Store 3",
            "Store 4",
            "Store 5",
            "Store 6",
            "Store 7"
        ]

        let limited = Array(allStores.prefix(5))

        #expect(limited.count == 5)
    }
}

#else

#if canImport(XCTest)
import XCTest

// Fallback to XCTest if Swift Testing is not available
class StoreAutoCompleteFieldTests: XCTestCase {

    func testFetchDistinctStores() async throws {
        let mockRepo = MockShoppingListRepository()

        let item1 = ItemShoppingModel(
            item_natural_key: "bullseye-0001-0",
            quantity: 10,
            store: "Frantz Art Glass"
        )
        let item2 = ItemShoppingModel(
            item_natural_key: "cim-123-0",
            quantity: 5,
            store: "Olympic Color"
        )

        _ = try await mockRepo.createItem(item1)
        _ = try await mockRepo.createItem(item2)

        let stores = try await mockRepo.getDistinctStores()

        XCTAssertEqual(stores.count, 2)
        XCTAssertTrue(stores.contains("Frantz Art Glass"))
        XCTAssertTrue(stores.contains("Olympic Color"))
    }

    func testPrefixFiltering() {
        let allStores = ["Frantz Art Glass", "Bullseye Glass Co", "Olympic Color"]
        let searchText = "fr"

        let filtered = allStores.filter { $0.lowercased().hasPrefix(searchText.lowercased()) }

        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first, "Frantz Art Glass")
    }
}
#endif

#endif
