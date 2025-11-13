//
//  ShoppingListItemModelTests.swift
//  MoltenTests
//
//  Created by Assistant on 2025-11-12.
//  Tests for ShoppingListItemModel merge business logic
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

@Suite("ShoppingListItemModel Tests")
struct ShoppingListItemModelTests {

    // MARK: - Test Helpers

    private func createItem(
        stableId: String,
        type: String,
        currentQuantity: Double,
        minimumQuantity: Double,
        store: String
    ) -> ShoppingListItemModel {
        return ShoppingListItemModel(
            item_stable_id: stableId,
            type: type,
            currentQuantity: currentQuantity,
            minimumQuantity: minimumQuantity,
            store: store
        )
    }

    // MARK: - Merge Tests

    @Test("Should merge items using max of needed quantities")
    func testMergeUsesMaxNeededQuantity() {
        let item1 = createItem(
            stableId: "test-001-0",
            type: "rod",
            currentQuantity: 5.0,
            minimumQuantity: 10.0,  // needs 5.0
            store: "Store A"
        )

        let item2 = createItem(
            stableId: "test-001-0",
            type: "rod",
            currentQuantity: 5.0,
            minimumQuantity: 13.0,  // needs 8.0
            store: "Store A"
        )

        let merged = item1.merged(with: item2)

        // Business rule: Use max of needed quantities (8.0 > 5.0)
        #expect(merged.neededQuantity == 8.0)
        #expect(merged.minimumQuantity == 13.0)  // currentQuantity + neededQuantity
        #expect(merged.currentQuantity == 5.0)
    }

    @Test("Should preserve item identity when merging")
    func testMergePreservesIdentity() {
        let item1 = createItem(
            stableId: "test-001-0",
            type: "rod",
            currentQuantity: 5.0,
            minimumQuantity: 10.0,
            store: "Store A"
        )

        let item2 = createItem(
            stableId: "test-001-0",
            type: "rod",
            currentQuantity: 5.0,
            minimumQuantity: 15.0,
            store: "Store A"
        )

        let merged = item1.merged(with: item2)

        // Should preserve all identity fields
        #expect(merged.item_stable_id == "test-001-0")
        #expect(merged.type == "rod")
        #expect(merged.store == "Store A")
    }

    @Test("Should handle merging when first item has higher need")
    func testMergeFirstItemHigher() {
        let item1 = createItem(
            stableId: "test-001-0",
            type: "rod",
            currentQuantity: 2.0,
            minimumQuantity: 15.0,  // needs 13.0
            store: "Store A"
        )

        let item2 = createItem(
            stableId: "test-001-0",
            type: "rod",
            currentQuantity: 2.0,
            minimumQuantity: 10.0,  // needs 8.0
            store: "Store A"
        )

        let merged = item1.merged(with: item2)

        // Business rule: Use max (13.0 > 8.0)
        #expect(merged.neededQuantity == 13.0)
        #expect(merged.minimumQuantity == 15.0)
    }

    @Test("Should handle merging when second item has higher need")
    func testMergeSecondItemHigher() {
        let item1 = createItem(
            stableId: "test-001-0",
            type: "rod",
            currentQuantity: 2.0,
            minimumQuantity: 10.0,  // needs 8.0
            store: "Store A"
        )

        let item2 = createItem(
            stableId: "test-001-0",
            type: "rod",
            currentQuantity: 2.0,
            minimumQuantity: 15.0,  // needs 13.0
            store: "Store A"
        )

        let merged = item1.merged(with: item2)

        // Business rule: Use max (13.0 > 8.0)
        #expect(merged.neededQuantity == 13.0)
        #expect(merged.minimumQuantity == 15.0)
    }

    @Test("Should handle merging equal needed quantities")
    func testMergeEqualNeededQuantities() {
        let item1 = createItem(
            stableId: "test-001-0",
            type: "rod",
            currentQuantity: 5.0,
            minimumQuantity: 15.0,  // needs 10.0
            store: "Store A"
        )

        let item2 = createItem(
            stableId: "test-001-0",
            type: "rod",
            currentQuantity: 5.0,
            minimumQuantity: 15.0,  // needs 10.0
            store: "Store A"
        )

        let merged = item1.merged(with: item2)

        // When equal, max returns either value (both 10.0)
        #expect(merged.neededQuantity == 10.0)
        #expect(merged.minimumQuantity == 15.0)
    }

    @Test("Should recalculate priority after merge")
    func testMergeRecalculatesPriority() {
        // Item with low priority (small deficit)
        let item1 = createItem(
            stableId: "test-001-0",
            type: "rod",
            currentQuantity: 9.0,
            minimumQuantity: 10.0,  // needs 1.0 (10% deficit)
            store: "Store A"
        )

        // Item with high priority (large deficit)
        let item2 = createItem(
            stableId: "test-001-0",
            type: "rod",
            currentQuantity: 9.0,
            minimumQuantity: 20.0,  // needs 11.0 (55% deficit)
            store: "Store A"
        )

        let merged = item1.merged(with: item2)

        // After merge, should use max needed quantity (11.0)
        // Priority should reflect the higher need
        #expect(merged.neededQuantity == 11.0)
        #expect(merged.priority == .high)  // 55% deficit
    }
}
