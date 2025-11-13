//
//  DetailedShoppingListModelTests.swift
//  MoltenTests
//
//  Created by Assistant on 2025-11-12.
//  Tests for DetailedShoppingListModel estimated value business logic
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

@Suite("DetailedShoppingListModel Tests")
struct DetailedShoppingListModelTests {

    // MARK: - Test Helpers

    private func createItem(
        stableId: String,
        neededQuantity: Double
    ) -> DetailedShoppingListItemModel {
        let glassItem = GlassItemModel(
            stable_id: stableId,
            name: "Test Item",
            sku: "001",
            manufacturer: "test",
            mfr_notes: "Test",
            coe: 96,
            url: nil,
            mfr_status: "available"
        )

        let shoppingListItem = ShoppingListItemModel(
            item_stable_id: stableId,
            type: "rod",
            currentQuantity: 0.0,
            minimumQuantity: neededQuantity,
            store: "Store A"
        )

        return DetailedShoppingListItemModel(
            shoppingListItem: shoppingListItem,
            glassItem: glassItem,
            tags: [],
            userTags: []
        )
    }

    // MARK: - Estimated Value Tests

    @Test("Should calculate estimated value at $10 per needed unit")
    func testEstimatedValueCalculation() {
        let items = [
            createItem(stableId: "test-001-0", neededQuantity: 5.0),  // $50
            createItem(stableId: "test-002-0", neededQuantity: 3.0),  // $30
            createItem(stableId: "test-003-0", neededQuantity: 2.0)   // $20
        ]

        let shoppingList = DetailedShoppingListModel(
            store: "Store A",
            items: items,
            totalItems: items.count
        )

        // Business rule: $10 per needed unit
        // Total: (5 * $10) + (3 * $10) + (2 * $10) = $100
        #expect(shoppingList.totalValue == 100.0)
    }

    @Test("Should handle empty shopping list")
    func testEmptyShoppingList() {
        let shoppingList = DetailedShoppingListModel(
            store: "Store A",
            items: [],
            totalItems: 0
        )

        #expect(shoppingList.totalValue == 0.0)
    }

    @Test("Should handle single item")
    func testSingleItem() {
        let items = [
            createItem(stableId: "test-001-0", neededQuantity: 7.5)
        ]

        let shoppingList = DetailedShoppingListModel(
            store: "Store A",
            items: items,
            totalItems: items.count
        )

        // $10 * 7.5 = $75
        #expect(shoppingList.totalValue == 75.0)
    }

    @Test("Should handle fractional quantities")
    func testFractionalQuantities() {
        let items = [
            createItem(stableId: "test-001-0", neededQuantity: 0.5),  // $5
            createItem(stableId: "test-002-0", neededQuantity: 1.25)  // $12.50
        ]

        let shoppingList = DetailedShoppingListModel(
            store: "Store A",
            items: items,
            totalItems: items.count
        )

        // Total: $5 + $12.50 = $17.50
        #expect(shoppingList.totalValue == 17.5)
    }

    @Test("Should handle large quantities")
    func testLargeQuantities() {
        let items = [
            createItem(stableId: "test-001-0", neededQuantity: 100.0),  // $1000
            createItem(stableId: "test-002-0", neededQuantity: 50.0)    // $500
        ]

        let shoppingList = DetailedShoppingListModel(
            store: "Store A",
            items: items,
            totalItems: items.count
        )

        // Total: $1000 + $500 = $1500
        #expect(shoppingList.totalValue == 1500.0)
    }
}
