//
//  StorageLocationModelTests.swift
//  MoltenTests
//
//  Created by Assistant on 2025-11-12.
//  Tests for StorageLocationModel validation and normalization business logic
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
@Suite("StorageLocationModel Tests")
struct StorageLocationModelTests {

    // MARK: - isValidLocationName Tests

    @Test("Should validate non-empty location names within length limit")
    func testValidLocationNames() {
        #expect(StorageLocationModel.isValidLocationName("Shelf A") == true)
        #expect(StorageLocationModel.isValidLocationName("Warehouse 1") == true)
        #expect(StorageLocationModel.isValidLocationName("B") == true)  // Single char valid
    }

    @Test("Should reject empty location names")
    func testInvalidEmptyLocationName() {
        #expect(StorageLocationModel.isValidLocationName("") == false)
    }

    @Test("Should reject whitespace-only location names")
    func testInvalidWhitespaceOnlyLocationName() {
        #expect(StorageLocationModel.isValidLocationName("   ") == false)
        #expect(StorageLocationModel.isValidLocationName("\t\n") == false)
    }

    @Test("Should trim whitespace before validation")
    func testTrimsWhitespaceBeforeValidation() {
        #expect(StorageLocationModel.isValidLocationName("  Shelf A  ") == true)
        #expect(StorageLocationModel.isValidLocationName("\tWarehouse\n") == true)
    }

    @Test("Should accept location names up to 50 characters")
    func testMaxLengthLocationName() {
        let exactly50 = String(repeating: "A", count: 50)
        #expect(StorageLocationModel.isValidLocationName(exactly50) == true)
    }

    @Test("Should reject location names over 50 characters")
    func testTooLongLocationName() {
        let tooLong = String(repeating: "A", count: 51)
        #expect(StorageLocationModel.isValidLocationName(tooLong) == false)

        let wayTooLong = String(repeating: "A", count: 100)
        #expect(StorageLocationModel.isValidLocationName(wayTooLong) == false)
    }

    @Test("Should trim whitespace before checking length")
    func testTrimsWhitespaceBeforeLengthCheck() {
        // 50 chars + whitespace should trim to 50 and be valid
        let exactly50 = String(repeating: "A", count: 50)
        #expect(StorageLocationModel.isValidLocationName("  \(exactly50)  ") == true)

        // 51 chars + whitespace should trim to 51 and be invalid
        let tooLong = String(repeating: "A", count: 51)
        #expect(StorageLocationModel.isValidLocationName("  \(tooLong)  ") == false)
    }

    // MARK: - cleanLocationName Tests

    @Test("Should trim leading whitespace")
    func testCleanLeadingWhitespace() {
        #expect(StorageLocationModel.cleanLocationName("  Shelf A") == "Shelf A")
        #expect(StorageLocationModel.cleanLocationName("\tShelf A") == "Shelf A")
    }

    @Test("Should trim trailing whitespace")
    func testCleanTrailingWhitespace() {
        #expect(StorageLocationModel.cleanLocationName("Shelf A  ") == "Shelf A")
        #expect(StorageLocationModel.cleanLocationName("Shelf A\n") == "Shelf A")
    }

    @Test("Should trim both leading and trailing whitespace")
    func testCleanBothSides() {
        #expect(StorageLocationModel.cleanLocationName("  Shelf A  ") == "Shelf A")
        #expect(StorageLocationModel.cleanLocationName("\t\nShelf A\n\t") == "Shelf A")
    }

    @Test("Should preserve interior whitespace")
    func testPreserveInteriorWhitespace() {
        #expect(StorageLocationModel.cleanLocationName("  Shelf   A  ") == "Shelf   A")
    }

    @Test("Should handle location with no whitespace")
    func testNoWhitespace() {
        #expect(StorageLocationModel.cleanLocationName("ShelfA") == "ShelfA")
    }

    @Test("Should handle empty string")
    func testCleanEmptyString() {
        #expect(StorageLocationModel.cleanLocationName("") == "")
    }

    @Test("Should handle whitespace-only string")
    func testCleanWhitespaceOnly() {
        #expect(StorageLocationModel.cleanLocationName("   ") == "")
        #expect(StorageLocationModel.cleanLocationName("\t\n") == "")
    }

    // MARK: - cleanLocation Tests (alias)

    @Test("cleanLocation should behave identically to cleanLocationName")
    func testCleanLocationAlias() {
        let testCases = [
            "  Shelf A  ",
            "Warehouse 1",
            "",
            "   ",
            "\tShelf\n"
        ]

        for testCase in testCases {
            #expect(
                StorageLocationModel.cleanLocation(testCase) ==
                StorageLocationModel.cleanLocationName(testCase)
            )
        }
    }

    // MARK: - init Validation Tests

    @Test("Should ensure non-negative quantity in initializer")
    func testInitEnsuresNonNegativeQuantity() {
        let location = StorageLocationModel(
            inventory_id: UUID(),
            location: "Shelf A",
            quantity: -5.0
        )

        // Business rule: Negative quantity becomes 0.0
        #expect(location.quantity == 0.0)
    }

    @Test("Should preserve positive quantity")
    func testInitPreservesPositiveQuantity() {
        let location = StorageLocationModel(
            inventory_id: UUID(),
            location: "Shelf A",
            quantity: 10.5
        )

        #expect(location.quantity == 10.5)
    }

    @Test("Should preserve zero quantity")
    func testInitPreservesZeroQuantity() {
        let location = StorageLocationModel(
            inventory_id: UUID(),
            location: "Shelf A",
            quantity: 0.0
        )

        #expect(location.quantity == 0.0)
    }

    @Test("Should trim location name in initializer")
    func testInitTrimsLocationName() {
        let location = StorageLocationModel(
            inventory_id: UUID(),
            location: "  Shelf A  ",
            quantity: 5.0
        )

        #expect(location.location == "Shelf A")
    }

    @Test("Should handle edge case: very negative quantity")
    func testInitVeryNegativeQuantity() {
        let location = StorageLocationModel(
            inventory_id: UUID(),
            location: "Shelf A",
            quantity: -999999.99
        )

        #expect(location.quantity == 0.0)
    }

    @Test("Should preserve large positive quantity")
    func testInitLargePositiveQuantity() {
        let location = StorageLocationModel(
            inventory_id: UUID(),
            location: "Shelf A",
            quantity: 999999.99
        )

        #expect(location.quantity == 999999.99)
    }

    // MARK: - Integration Tests

    @Test("Should validate and clean together correctly")
    func testValidationAndCleaningIntegration() {
        let rawLocation = "  Shelf A  "
        let cleaned = StorageLocationModel.cleanLocationName(rawLocation)
        let isValid = StorageLocationModel.isValidLocationName(rawLocation)

        #expect(cleaned == "Shelf A")
        #expect(isValid == true)
    }

    @Test("Should reject invalid location even after cleaning")
    func testInvalidAfterCleaning() {
        let whitespaceOnly = "   "
        let cleaned = StorageLocationModel.cleanLocationName(whitespaceOnly)
        let isValid = StorageLocationModel.isValidLocationName(whitespaceOnly)

        #expect(cleaned == "")
        #expect(isValid == false)
    }
}
