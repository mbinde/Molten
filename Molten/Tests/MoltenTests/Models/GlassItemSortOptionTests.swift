//
//  GlassItemSortOptionTests.swift
//  MoltenTests
//
//  Created by Assistant on 2025-11-12.
//  Tests for GlassItemSortOption sorting business logic
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

@MainActor
@Suite("GlassItemSortOption Tests")
struct GlassItemSortOptionTests {

    // MARK: - Test Helpers

    private func createItem(
        stableId: String,
        name: String,
        manufacturer: String = "test",
        coe: Int32 = 96,
        quantity: Double = 0.0
    ) -> CompleteInventoryItemModel {
        let glassItem = GlassItemModel(
            stable_id: stableId,
            name: name,
            sku: "001",
            manufacturer: manufacturer,
            mfr_notes: "Test",
            coe: coe,
            url: nil,
            mfr_status: "available"
        )

        let inventory: [InventoryModel] = quantity > 0 ? [
            InventoryModel(item_stable_id: stableId, type: "rod", quantity: quantity)
        ] : []

        return CompleteInventoryItemModel(
            glassItem: glassItem,
            inventory: inventory,
            tags: [],
            userTags: []
        )
    }

    // MARK: - Sort by Name

    @Test("Should sort by name (case-insensitive, ascending)")
    func testSortByName() {
        let items = [
            createItem(stableId: "1", name: "Zebra"),
            createItem(stableId: "2", name: "apple"),
            createItem(stableId: "3", name: "Banana")
        ]

        let sorted = GlassItemSortOption.name.sort(items)

        #expect(sorted[0].glassItem.name == "apple")
        #expect(sorted[1].glassItem.name == "Banana")
        #expect(sorted[2].glassItem.name == "Zebra")
    }

    // MARK: - Sort by Manufacturer

    @Test("Should sort by manufacturer, then by name")
    func testSortByManufacturer() {
        let items = [
            createItem(stableId: "1", name: "Rod B", manufacturer: "Zimmerman"),
            createItem(stableId: "2", name: "Rod A", manufacturer: "Bullseye"),
            createItem(stableId: "3", name: "Rod C", manufacturer: "Bullseye")
        ]

        let sorted = GlassItemSortOption.manufacturer.sort(items)

        // First by manufacturer: Bullseye < Zimmerman
        #expect(sorted[0].glassItem.manufacturer == "Bullseye")
        #expect(sorted[1].glassItem.manufacturer == "Bullseye")
        #expect(sorted[2].glassItem.manufacturer == "Zimmerman")

        // Within Bullseye, sorted by name: Rod A < Rod C
        #expect(sorted[0].glassItem.name == "Rod A")
        #expect(sorted[1].glassItem.name == "Rod C")
    }

    // MARK: - Sort by COE

    @Test("Should sort by COE, then by name")
    func testSortByCOE() {
        let items = [
            createItem(stableId: "1", name: "Item B", coe: 96),
            createItem(stableId: "2", name: "Item A", coe: 90),
            createItem(stableId: "3", name: "Item C", coe: 96)
        ]

        let sorted = GlassItemSortOption.coe.sort(items)

        // First by COE: 90 < 96
        #expect(sorted[0].glassItem.coe == 90)
        #expect(sorted[1].glassItem.coe == 96)
        #expect(sorted[2].glassItem.coe == 96)

        // Within COE 96, sorted by name: Item B < Item C
        #expect(sorted[1].glassItem.name == "Item B")
        #expect(sorted[2].glassItem.name == "Item C")
    }

    // MARK: - Sort by Total Quantity

    @Test("Should sort by totalQuantity (descending), then by name")
    func testSortByTotalQuantity() {
        let items = [
            createItem(stableId: "1", name: "Item B", quantity: 5.0),
            createItem(stableId: "2", name: "Item A", quantity: 10.0),
            createItem(stableId: "3", name: "Item C", quantity: 5.0)
        ]

        let sorted = GlassItemSortOption.totalQuantity.sort(items)

        // First by quantity (descending): 10 > 5
        #expect(sorted[0].totalQuantity == 10.0)
        #expect(sorted[1].totalQuantity == 5.0)
        #expect(sorted[2].totalQuantity == 5.0)

        // Within quantity 5.0, sorted by name: Item B < Item C
        #expect(sorted[1].glassItem.name == "Item B")
        #expect(sorted[2].glassItem.name == "Item C")
    }

    // MARK: - Edge Cases

    @Test("Should handle empty array")
    func testSortEmptyArray() {
        let items: [CompleteInventoryItemModel] = []
        let sorted = GlassItemSortOption.name.sort(items)
        #expect(sorted.isEmpty)
    }

    @Test("Should handle single item")
    func testSortSingleItem() {
        let items = [createItem(stableId: "1", name: "Only Item")]
        let sorted = GlassItemSortOption.name.sort(items)
        #expect(sorted.count == 1)
        #expect(sorted[0].glassItem.name == "Only Item")
    }
}
