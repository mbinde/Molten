//
//  StoreStatisticsModelSortingTests.swift
//  MoltenTests
//
//  Created by Assistant on 2025-11-12.
//  Tests for StoreStatisticsModel sorting business logic
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

@Suite("StoreStatisticsModel Sorting Tests")
struct StoreStatisticsModelSortingTests {

    // MARK: - Test Helpers

    private func createStoreStatistics(
        storeName: String,
        minimumCount: Int,
        currentNeedsCount: Int,
        totalNeededQuantity: Double = 10.0
    ) -> StoreStatisticsModel {
        return StoreStatisticsModel(
            storeName: storeName,
            minimumCount: minimumCount,
            currentNeedsCount: currentNeedsCount,
            totalNeededQuantity: totalNeededQuantity
        )
    }

    // MARK: - Comparable Tests

    @Test("Should sort by currentNeedsCount descending (highest needs first)")
    func testSortByCurrentNeedsCount() {
        let low = createStoreStatistics(storeName: "Low Needs", minimumCount: 10, currentNeedsCount: 2)
        let medium = createStoreStatistics(storeName: "Medium Needs", minimumCount: 10, currentNeedsCount: 5)
        let high = createStoreStatistics(storeName: "High Needs", minimumCount: 10, currentNeedsCount: 8)

        var stores = [medium, low, high]
        stores.sort() // Uses Comparable conformance

        let name0 = stores[0].storeName
        let name1 = stores[1].storeName
        let name2 = stores[2].storeName
        #expect(name0 == "High Needs")
        #expect(name1 == "Medium Needs")
        #expect(name2 == "Low Needs")
    }

    @Test("Should handle equal currentNeedsCount gracefully")
    func testSortWithEqualNeeds() {
        let store1 = createStoreStatistics(storeName: "Store A", minimumCount: 10, currentNeedsCount: 5)
        let store2 = createStoreStatistics(storeName: "Store B", minimumCount: 10, currentNeedsCount: 5)

        // Should not crash with equal values
        let result = store1 < store2 || store1 == store2 || store1 > store2
        #expect(result == true) // One of these must be true
    }

    @Test("Should allow sorting with Swift's sorted method")
    func testSwiftSortedMethod() {
        let stores = [
            createStoreStatistics(storeName: "Needs 3", minimumCount: 10, currentNeedsCount: 3),
            createStoreStatistics(storeName: "Needs 7", minimumCount: 10, currentNeedsCount: 7),
            createStoreStatistics(storeName: "Needs 1", minimumCount: 10, currentNeedsCount: 1)
        ]

        let sorted = stores.sorted() // Should use Comparable

        let count0 = sorted[0].currentNeedsCount
        let count1 = sorted[1].currentNeedsCount
        let count2 = sorted[2].currentNeedsCount
        #expect(count0 == 7)
        #expect(count1 == 3)
        #expect(count2 == 1)
    }

    @Test("Less than operator should compare currentNeedsCount")
    func testLessThanOperator() {
        let smaller = createStoreStatistics(storeName: "Smaller", minimumCount: 10, currentNeedsCount: 3)
        let larger = createStoreStatistics(storeName: "Larger", minimumCount: 10, currentNeedsCount: 8)

        // Business rule: higher currentNeedsCount is "less than" for descending sort
        let largerIsLess = larger < smaller
        let smallerIsNotLess = !(smaller < larger)
        #expect(largerIsLess)
        #expect(smallerIsNotLess)
    }

    @Test("Should prioritize by needs regardless of minimumCount")
    func testSortByNeedsIgnoresMinimumCount() {
        // Different minimumCount should not affect needs-based sorting
        let store1 = createStoreStatistics(storeName: "Store 1", minimumCount: 100, currentNeedsCount: 5)
        let store2 = createStoreStatistics(storeName: "Store 2", minimumCount: 1, currentNeedsCount: 8)

        var stores = [store1, store2]
        stores.sort()

        // Should sort by currentNeedsCount, not minimumCount
        #expect(stores[0].storeName == "Store 2")
        #expect(stores[1].storeName == "Store 1")
    }

    @Test("Should sort correctly with zero needs")
    func testSortWithZeroNeeds() {
        let hasNeeds = createStoreStatistics(storeName: "Has Needs", minimumCount: 10, currentNeedsCount: 3)
        let noNeeds = createStoreStatistics(storeName: "No Needs", minimumCount: 10, currentNeedsCount: 0)

        var stores = [noNeeds, hasNeeds]
        stores.sort()

        // Store with needs should come first
        #expect(stores[0].storeName == "Has Needs")
        #expect(stores[1].storeName == "No Needs")
    }
}
