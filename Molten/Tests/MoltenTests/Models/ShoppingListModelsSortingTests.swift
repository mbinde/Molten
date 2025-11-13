//
//  ShoppingListModelsSortingTests.swift
//  MoltenTests
//
//  Created by Assistant on 2025-11-12.
//  Tests for ShoppingListModels sorting business logic
//

#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

import Foundation
@testable import Molten

@Suite("DetailedShoppingListItemModel Sorting Tests")
struct DetailedShoppingListItemModelSortingTests {

    // MARK: - Test Helpers

    private func createShoppingItem(
        stableId: String,
        name: String,
        neededQuantity: Double
    ) -> DetailedShoppingListItemModel {
        let glassItem = GlassItemModel(
            stable_id: stableId,
            name: name,
            sku: "001",
            manufacturer: "test",
            mfr_notes: "Test notes",
            coe: 96,
            url: nil,
            mfr_status: "available"
        )

        let shoppingListItem = ShoppingListItemModel(
            item_stable_id: stableId,
            type: "rod",
            currentQuantity: 5.0,
            minimumQuantity: 10.0 + neededQuantity, // Min = current + needed
            store: "TestStore"
        )

        return DetailedShoppingListItemModel(
            shoppingListItem: shoppingListItem,
            glassItem: glassItem,
            tags: [],
            userTags: []
        )
    }

    // MARK: - Comparable Tests

    @Test("Should sort by neededQuantity descending (highest need first)")
    func testSortByNeededQuantity() {
        let low = createShoppingItem(stableId: "low", name: "Low Need", neededQuantity: 2.0)
        let medium = createShoppingItem(stableId: "med", name: "Medium Need", neededQuantity: 5.0)
        let high = createShoppingItem(stableId: "high", name: "High Need", neededQuantity: 10.0)

        var items = [medium, low, high]
        items.sort() // Uses Comparable conformance

        #expect(items[0].glassItem.name == "High Need")
        #expect(items[1].glassItem.name == "Medium Need")
        #expect(items[2].glassItem.name == "Low Need")
    }

    @Test("Should handle equal neededQuantity gracefully")
    func testSortWithEqualQuantities() {
        let item1 = createShoppingItem(stableId: "a", name: "Item A", neededQuantity: 5.0)
        let item2 = createShoppingItem(stableId: "b", name: "Item B", neededQuantity: 5.0)

        // Should not crash with equal values
        let result = item1 < item2 || item1 == item2 || item1 > item2
        #expect(result == true) // One of these must be true
    }

    @Test("Should allow sorting with Swift's sorted method")
    func testSwiftSortedMethod() {
        let items = [
            createShoppingItem(stableId: "1", name: "Need 3", neededQuantity: 3.0),
            createShoppingItem(stableId: "2", name: "Need 7", neededQuantity: 7.0),
            createShoppingItem(stableId: "3", name: "Need 1", neededQuantity: 1.0)
        ]

        let sorted = items.sorted() // Should use Comparable

        #expect(sorted[0].shoppingListItem.neededQuantity == 7.0)
        #expect(sorted[1].shoppingListItem.neededQuantity == 3.0)
        #expect(sorted[2].shoppingListItem.neededQuantity == 1.0)
    }

    @Test("Less than operator should compare neededQuantity")
    func testLessThanOperator() {
        let smaller = createShoppingItem(stableId: "s", name: "Smaller", neededQuantity: 3.0)
        let larger = createShoppingItem(stableId: "l", name: "Larger", neededQuantity: 8.0)

        // Business rule: larger neededQuantity is "less than" for descending sort
        #expect(larger < smaller)
        #expect(!(smaller < larger))
    }
}
