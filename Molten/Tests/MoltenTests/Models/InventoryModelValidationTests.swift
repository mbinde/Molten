//
//  InventoryModelValidationTests.swift
//  MoltenTests
//
//  Created by Assistant on 2025-11-12.
//  Tests for InventoryModel quantity validation business logic
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
@Suite("InventoryModel Validation Tests")
struct InventoryModelValidationTests {

    // MARK: - Quantity Validation

    @Test("Should enforce non-negative quantity (positive values pass through)")
    func testPositiveQuantity() {
        let model = InventoryModel(
            item_stable_id: "test-001-0",
            type: "rod",
            quantity: 10.5
        )

        #expect(model.quantity == 10.5)
    }

    @Test("Should enforce non-negative quantity (zero is valid)")
    func testZeroQuantity() {
        let model = InventoryModel(
            item_stable_id: "test-001-0",
            type: "rod",
            quantity: 0.0
        )

        #expect(model.quantity == 0.0)
    }

    @Test("Should enforce non-negative quantity (negative becomes zero)")
    func testNegativeQuantityBecomesZero() {
        let model = InventoryModel(
            item_stable_id: "test-001-0",
            type: "rod",
            quantity: -5.0
        )

        // Business rule: Negative quantities are clamped to zero
        #expect(model.quantity == 0.0)
    }

    @Test("Should enforce non-negative quantity (large negative becomes zero)")
    func testLargeNegativeQuantity() {
        let model = InventoryModel(
            item_stable_id: "test-001-0",
            type: "rod",
            quantity: -999.99
        )

        #expect(model.quantity == 0.0)
    }

    @Test("Should enforce non-negative quantity (fractional values work)")
    func testFractionalQuantity() {
        let model = InventoryModel(
            item_stable_id: "test-001-0",
            type: "rod",
            quantity: 0.5
        )

        #expect(model.quantity == 0.5)
    }

    @Test("Should enforce non-negative quantity (very small negative becomes zero)")
    func testVerySmallNegative() {
        let model = InventoryModel(
            item_stable_id: "test-001-0",
            type: "rod",
            quantity: -0.001
        )

        #expect(model.quantity == 0.0)
    }
}
