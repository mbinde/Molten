//
//  ManufacturerStatisticsModelSortingTests.swift
//  MoltenTests
//
//  Created by Assistant on 2025-11-12.
//  Tests for ManufacturerStatisticsModel sorting business logic
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
@Suite("ManufacturerStatisticsModel Sorting Tests")
struct ManufacturerStatisticsModelSortingTests {

    // MARK: - Test Helpers

    private func createManufacturerStatistics(
        name: String,
        itemCount: Int
    ) -> ManufacturerStatisticsModel {
        return ManufacturerStatisticsModel(
            name: name,
            itemCount: itemCount
        )
    }

    // MARK: - Comparable Tests

    @Test("Should sort by itemCount descending (most items first)")
    func testSortByItemCount() {
        let low = createManufacturerStatistics(name: "Low Count", itemCount: 5)
        let medium = createManufacturerStatistics(name: "Medium Count", itemCount: 15)
        let high = createManufacturerStatistics(name: "High Count", itemCount: 50)

        var manufacturers = [medium, low, high]
        manufacturers.sort() // Uses Comparable conformance

        #expect(manufacturers[0].name == "High Count")
        #expect(manufacturers[1].name == "Medium Count")
        #expect(manufacturers[2].name == "Low Count")
    }

    @Test("Should handle equal itemCount gracefully")
    func testSortWithEqualCounts() {
        let mfr1 = createManufacturerStatistics(name: "Manufacturer A", itemCount: 10)
        let mfr2 = createManufacturerStatistics(name: "Manufacturer B", itemCount: 10)

        // Should not crash with equal values
        let result = mfr1 < mfr2 || mfr1 == mfr2 || mfr1 > mfr2
        #expect(result == true) // One of these must be true
    }

    @Test("Should allow sorting with Swift's sorted method")
    func testSwiftSortedMethod() {
        let manufacturers = [
            createManufacturerStatistics(name: "Count 8", itemCount: 8),
            createManufacturerStatistics(name: "Count 20", itemCount: 20),
            createManufacturerStatistics(name: "Count 3", itemCount: 3)
        ]

        let sorted = manufacturers.sorted() // Should use Comparable

        #expect(sorted[0].itemCount == 20)
        #expect(sorted[1].itemCount == 8)
        #expect(sorted[2].itemCount == 3)
    }

    @Test("Less than operator should compare itemCount")
    func testLessThanOperator() {
        let smaller = createManufacturerStatistics(name: "Smaller", itemCount: 5)
        let larger = createManufacturerStatistics(name: "Larger", itemCount: 30)

        // Business rule: higher itemCount is "less than" for descending sort
        #expect(larger < smaller)
        #expect(!(smaller < larger))
    }

    @Test("Should sort correctly with zero items")
    func testSortWithZeroItems() {
        let hasItems = createManufacturerStatistics(name: "Has Items", itemCount: 10)
        let noItems = createManufacturerStatistics(name: "No Items", itemCount: 0)

        var manufacturers = [noItems, hasItems]
        manufacturers.sort()

        // Manufacturer with items should come first
        #expect(manufacturers[0].name == "Has Items")
        #expect(manufacturers[1].name == "No Items")
    }

    @Test("Should sort by item count only, not by name")
    func testSortByCountNotName() {
        // Names alphabetically reversed from count order
        let zzz = createManufacturerStatistics(name: "ZZZ", itemCount: 100)
        let aaa = createManufacturerStatistics(name: "AAA", itemCount: 5)

        var manufacturers = [aaa, zzz]
        manufacturers.sort()

        // Should sort by itemCount, not by name
        #expect(manufacturers[0].name == "ZZZ")
        #expect(manufacturers[1].name == "AAA")
    }
}
