//
//  CompleteInventoryItemModelTests.swift
//  MoltenTests
//
//  Created by Assistant on 2025-11-12.
//  Tests for CompleteInventoryItemModel business logic
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

@Suite("CompleteInventoryItemModel Business Logic Tests")
struct CompleteInventoryItemModelTests {

    // MARK: - Test Helpers

    private func createTestItem(inventory: [InventoryModel]) -> CompleteInventoryItemModel {
        let glassItem = GlassItemModel(
            stable_id: "test-001-0",
            name: "Test Glass",
            sku: "001",
            manufacturer: "test",
            mfr_notes: "Test notes",
            coe: 96,
            url: "https://test.com",
            mfr_status: "available"
        )

        return CompleteInventoryItemModel(
            glassItem: glassItem,
            inventory: inventory,
            tags: ["tag1"],
            userTags: ["usertag1"]
        )
    }

    // MARK: - hasInventory Tests

    @Test("Should return false when inventory array is empty")
    func testHasInventoryWhenEmpty() {
        let item = createTestItem(inventory: [])

        #expect(item.hasInventory == false)
    }

    @Test("Should return false when all inventory has zero quantity")
    func testHasInventoryWhenAllZero() {
        let inventory = [
            InventoryModel(
                item_stable_id: "test-001-0",
                type: "rod",
                quantity: 0.0
            ),
            InventoryModel(
                item_stable_id: "test-001-0",
                type: "frit",
                quantity: 0.0
            )
        ]

        let item = createTestItem(inventory: inventory)

        #expect(item.hasInventory == false)
    }

    @Test("Should return true when at least one inventory has positive quantity")
    func testHasInventoryWhenPositive() {
        let inventory = [
            InventoryModel(
                item_stable_id: "test-001-0",
                type: "rod",
                quantity: 0.0
            ),
            InventoryModel(
                item_stable_id: "test-001-0",
                type: "frit",
                quantity: 5.0
            )
        ]

        let item = createTestItem(inventory: inventory)

        #expect(item.hasInventory == true)
    }

    @Test("Should return true when all inventory has positive quantity")
    func testHasInventoryWhenAllPositive() {
        let inventory = [
            InventoryModel(
                item_stable_id: "test-001-0",
                type: "rod",
                quantity: 2.5
            ),
            InventoryModel(
                item_stable_id: "test-001-0",
                type: "frit",
                quantity: 10.0
            )
        ]

        let item = createTestItem(inventory: inventory)

        #expect(item.hasInventory == true)
    }

    // MARK: - Existing Computed Property Tests

    @Test("totalQuantity should sum all inventory quantities")
    func testTotalQuantity() {
        let inventory = [
            InventoryModel(item_stable_id: "test-001-0", type: "rod", quantity: 2.5),
            InventoryModel(item_stable_id: "test-001-0", type: "frit", quantity: 10.0),
            InventoryModel(item_stable_id: "test-001-0", type: "rod", quantity: 3.5)
        ]

        let item = createTestItem(inventory: inventory)

        #expect(item.totalQuantity == 16.0)
    }

    @Test("inventoryByType should group and sum by type")
    func testInventoryByType() {
        let inventory = [
            InventoryModel(item_stable_id: "test-001-0", type: "rod", quantity: 2.5),
            InventoryModel(item_stable_id: "test-001-0", type: "frit", quantity: 10.0),
            InventoryModel(item_stable_id: "test-001-0", type: "rod", quantity: 3.5)
        ]

        let item = createTestItem(inventory: inventory)

        #expect(item.inventoryByType["rod"] == 6.0)
        #expect(item.inventoryByType["frit"] == 10.0)
    }
}
