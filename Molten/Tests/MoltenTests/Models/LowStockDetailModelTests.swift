//
//  LowStockDetailModelTests.swift
//  MoltenTests
//
//  Created by Assistant on 2025-11-12.
//  Tests for LowStockDetailModel sorting business logic
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
@Suite("LowStockDetailModel Sorting Tests")
struct LowStockDetailModelTests {

    // MARK: - Test Helpers

    private func createLowStockItem(
        name: String,
        currentQuantity: Double,
        threshold: Double
    ) -> LowStockDetailModel {
        let glassItem = GlassItemModel(
            stable_id: "test-\(name)",
            name: name,
            sku: "001",
            manufacturer: "test",
            mfr_notes: "Test",
            coe: 96,
            url: nil,
            mfr_status: "available"
        )

        return LowStockDetailModel(
            glassItem: glassItem,
            type: "rod",
            currentQuantity: currentQuantity,
            threshold: threshold,
            tags: []
        )
    }

    // MARK: - Comparable Tests

    @Test("Should sort by currentQuantity ascending (lowest stock first)")
    func testSortByCurrentQuantity() {
        let medium = createLowStockItem(name: "Medium Stock", currentQuantity: 5.0, threshold: 10.0)
        let low = createLowStockItem(name: "Low Stock", currentQuantity: 1.0, threshold: 10.0)
        let high = createLowStockItem(name: "High Stock", currentQuantity: 8.0, threshold: 10.0)

        var items = [medium, high, low]
        items.sort() // Uses Comparable conformance

        #expect(items[0].glassItem.name == "Low Stock")
        #expect(items[1].glassItem.name == "Medium Stock")
        #expect(items[2].glassItem.name == "High Stock")
    }

    @Test("Should handle equal currentQuantity gracefully")
    func testSortWithEqualQuantities() {
        let item1 = createLowStockItem(name: "Item A", currentQuantity: 3.0, threshold: 10.0)
        let item2 = createLowStockItem(name: "Item B", currentQuantity: 3.0, threshold: 10.0)

        // Should not crash with equal values
        let result = item1 < item2 || item1 == item2 || item1 > item2
        #expect(result == true) // One of these must be true
    }

    @Test("Should allow sorting with Swift's sorted method")
    func testSwiftSortedMethod() {
        let items = [
            createLowStockItem(name: "Stock 5", currentQuantity: 5.0, threshold: 10.0),
            createLowStockItem(name: "Stock 2", currentQuantity: 2.0, threshold: 10.0),
            createLowStockItem(name: "Stock 8", currentQuantity: 8.0, threshold: 10.0)
        ]

        let sorted = items.sorted() // Should use Comparable

        #expect(sorted[0].currentQuantity == 2.0)
        #expect(sorted[1].currentQuantity == 5.0)
        #expect(sorted[2].currentQuantity == 8.0)
    }

    @Test("Less than operator should compare currentQuantity")
    func testLessThanOperator() {
        let smaller = createLowStockItem(name: "Smaller", currentQuantity: 2.0, threshold: 10.0)
        let larger = createLowStockItem(name: "Larger", currentQuantity: 7.0, threshold: 10.0)

        // Business rule: lower currentQuantity is "less than" for ascending sort
        #expect(smaller < larger)
        #expect(!(larger < smaller))
    }

    @Test("Should prioritize lowest stock regardless of threshold")
    func testPrioritizeLowestStock() {
        // Item with higher threshold but same stock shouldn't affect sorting
        let item1 = createLowStockItem(name: "Item 1", currentQuantity: 3.0, threshold: 5.0)
        let item2 = createLowStockItem(name: "Item 2", currentQuantity: 3.0, threshold: 20.0)
        let item3 = createLowStockItem(name: "Item 3", currentQuantity: 1.0, threshold: 5.0)

        var items = [item1, item2, item3]
        items.sort()

        // Item 3 should be first (lowest stock), regardless of threshold
        #expect(items[0].glassItem.name == "Item 3")
    }
}
