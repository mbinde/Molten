//
//  DetailedLowStockItemModelTests.swift
//  MoltenTests
//
//  Created by Assistant on 2025-11-12.
//  Tests for DetailedLowStockItemModel sorting business logic
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

@Suite("DetailedLowStockItemModel Tests")
struct DetailedLowStockItemModelTests {

    // MARK: - Test Helpers

    private func createItem(name: String, shortfall: Double) -> DetailedLowStockItemModel {
        let glassItem = GlassItemModel(
            stable_id: "test-\(name)-0",
            name: name,
            sku: "001",
            manufacturer: "test",
            mfr_notes: "Test",
            coe: 96,
            url: nil,
            mfr_status: "available"
        )

        let lowStockItem = LowStockItemModel(
            item_stable_id: "test-\(name)-0",
            type: "rod",
            minimumQuantity: 10.0,
            currentQuantity: 10.0 - shortfall,
            shortfall: shortfall,
            store: "Store A"
        )

        return DetailedLowStockItemModel(
            lowStockItem: lowStockItem,
            glassItem: glassItem,
            tags: []
        )
    }

    // MARK: - Comparable Tests

    @Test("Should sort by shortfall descending (highest shortfall first)")
    func testSortByShortfallDescending() {
        let low = createItem(name: "Low", shortfall: 2.0)
        let medium = createItem(name: "Medium", shortfall: 5.0)
        let high = createItem(name: "High", shortfall: 8.0)

        var items = [medium, low, high]
        items.sort()

        // Business rule: Highest shortfall first (most urgent)
        #expect(items[0].glassItem.name == "High")
        #expect(items[1].glassItem.name == "Medium")
        #expect(items[2].glassItem.name == "Low")
    }

    @Test("Should handle equal shortfalls")
    func testEqualShortfalls() {
        let item1 = createItem(name: "Item A", shortfall: 5.0)
        let item2 = createItem(name: "Item B", shortfall: 5.0)

        var items = [item1, item2]
        items.sort()

        // When equal, order doesn't matter (stable sort)
        #expect(items.count == 2)
    }

    @Test("Should use less-than operator correctly")
    func testLessThanOperator() {
        let low = createItem(name: "Low", shortfall: 3.0)
        let high = createItem(name: "High", shortfall: 7.0)

        // Business rule: Higher shortfall = "less than" (sorts first)
        #expect(high < low)
        #expect(!(low < high))
    }

    @Test("Should sort with Swift's sorted() method")
    func testSwiftSortedMethod() {
        let items = [
            createItem(name: "A", shortfall: 4.0),
            createItem(name: "B", shortfall: 9.0),
            createItem(name: "C", shortfall: 1.0)
        ]

        let sorted = items.sorted()

        #expect(sorted[0].lowStockItem.shortfall == 9.0)
        #expect(sorted[1].lowStockItem.shortfall == 4.0)
        #expect(sorted[2].lowStockItem.shortfall == 1.0)
    }

    @Test("Should prioritize by urgency (highest shortfall = highest priority)")
    func testPrioritizeByUrgency() {
        let critical = createItem(name: "Critical", shortfall: 9.5)  // 95% shortfall
        let moderate = createItem(name: "Moderate", shortfall: 5.0)  // 50% shortfall
        let minor = createItem(name: "Minor", shortfall: 1.0)        // 10% shortfall

        var items = [moderate, minor, critical]
        items.sort()

        // Most urgent (critical) should sort first
        #expect(items[0].glassItem.name == "Critical")
        #expect(items[1].glassItem.name == "Moderate")
        #expect(items[2].glassItem.name == "Minor")
    }
}
