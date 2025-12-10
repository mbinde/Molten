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

    @Test("Should clamp negative quantity to zero")
    func testInitClampsNegativeQuantity() {
        let location = StorageLocationModel(
            inventoryId: UUID(),
            quantity: -5.0
        )

        // Quantity is always >= 0; consumption is tracked via InventoryConsumptionRecord
        #expect(location.quantity == 0.0)
    }

    @Test("Should preserve positive quantity")
    func testInitPreservesPositiveQuantity() {
        let location = StorageLocationModel(
            inventoryId: UUID(),
            quantity: 10.5
        )

        #expect(location.quantity == 10.5)
    }

    @Test("Should preserve zero quantity")
    func testInitPreservesZeroQuantity() {
        let location = StorageLocationModel(
            inventoryId: UUID(),
            quantity: 0.0
        )

        #expect(location.quantity == 0.0)
    }

    @Test("Should trim location name in initializer")
    func testInitTrimsLocationName() {
        let location = StorageLocationModel(
            inventoryId: UUID(),
            locationName: "  Shelf A  ",
            quantity: 5.0
        )

        #expect(location.locationName == "Shelf A")
    }

    @Test("Should clamp very negative quantity to zero")
    func testInitClampsVeryNegativeQuantity() {
        let location = StorageLocationModel(
            inventoryId: UUID(),
            quantity: -999999.99
        )

        // Quantity is always >= 0; consumption is tracked via InventoryConsumptionRecord
        #expect(location.quantity == 0.0)
    }

    @Test("Should preserve large positive quantity")
    func testInitLargePositiveQuantity() {
        let location = StorageLocationModel(
            inventoryId: UUID(),
            quantity: 999999.99
        )

        #expect(location.quantity == 999999.99)
    }

    // MARK: - New Field Tests

    @Test("Should set dateAdded and dateModified")
    func testInitSetsDateFields() {
        let now = Date()
        let location = StorageLocationModel(
            inventoryId: UUID(),
            quantity: 5.0,
            dateAdded: now,
            dateModified: now
        )

        #expect(location.dateAdded == now)
        #expect(location.dateModified == now)
    }

    @Test("Should default isTransfer to false")
    func testInitDefaultsIsTransferToFalse() {
        let location = StorageLocationModel(
            inventoryId: UUID(),
            quantity: 5.0
        )

        #expect(location.isTransfer == false)
    }

    @Test("Should set isTransfer when specified")
    func testInitSetsIsTransfer() {
        let location = StorageLocationModel(
            inventoryId: UUID(),
            quantity: 5.0,
            isTransfer: true
        )

        #expect(location.isTransfer == true)
    }

    @Test("Should set containerCount for weight-based types")
    func testInitSetsContainerCount() {
        let location = StorageLocationModel(
            inventoryId: UUID(),
            quantity: 250.0,
            containerCount: 3.0
        )

        #expect(location.containerCount == 3.0)
    }

    @Test("Should allow nil containerCount")
    func testInitAllowsNilContainerCount() {
        let location = StorageLocationModel(
            inventoryId: UUID(),
            quantity: 5.0
        )

        #expect(location.containerCount == nil)
    }

    @Test("Should set storageLocationId for location definition reference")
    func testInitSetsStorageLocationId() {
        let definitionId = UUID()
        let location = StorageLocationModel(
            inventoryId: UUID(),
            storageLocationId: definitionId,
            quantity: 5.0
        )

        #expect(location.storageLocationId == definitionId)
    }

    @Test("Should allow nil storageLocationId for unassigned inventory")
    func testInitAllowsNilStorageLocationId() {
        let location = StorageLocationModel(
            inventoryId: UUID(),
            quantity: 5.0
        )

        #expect(location.storageLocationId == nil)
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

    // MARK: - Receipt Import Field Tests

    @Test("Should set purchaseRecordItemId for linked inventory")
    func testInitSetsPurchaseRecordItemId() {
        let purchaseItemId = UUID()
        let location = StorageLocationModel(
            inventoryId: UUID(),
            quantity: 5.0,
            purchaseRecordItemId: purchaseItemId
        )

        #expect(location.purchaseRecordItemId == purchaseItemId)
    }

    @Test("Should allow nil purchaseRecordItemId for unlinked inventory")
    func testInitAllowsNilPurchaseRecordItemId() {
        let location = StorageLocationModel(
            inventoryId: UUID(),
            quantity: 5.0,
            purchaseRecordItemId: nil
        )

        #expect(location.purchaseRecordItemId == nil)
    }

    @Test("Should set unitPrice for priced inventory")
    func testInitSetsUnitPrice() {
        let location = StorageLocationModel(
            inventoryId: UUID(),
            quantity: 5.0,
            unitPrice: Decimal(12.50)
        )

        #expect(location.unitPrice == Decimal(12.50))
    }

    @Test("Should allow nil unitPrice for unpriced inventory")
    func testInitAllowsNilUnitPrice() {
        let location = StorageLocationModel(
            inventoryId: UUID(),
            quantity: 5.0,
            unitPrice: nil
        )

        #expect(location.unitPrice == nil)
    }

    @Test("Should set currency for priced inventory")
    func testInitSetsCurrency() {
        let location = StorageLocationModel(
            inventoryId: UUID(),
            quantity: 5.0,
            currency: "USD"
        )

        #expect(location.currency == "USD")
    }

    @Test("Should allow nil currency")
    func testInitAllowsNilCurrency() {
        let location = StorageLocationModel(
            inventoryId: UUID(),
            quantity: 5.0,
            currency: nil
        )

        #expect(location.currency == nil)
    }

    @Test("Should set all receipt import fields together")
    func testInitSetsAllReceiptImportFields() {
        let purchaseItemId = UUID()
        let location = StorageLocationModel(
            inventoryId: UUID(),
            quantity: 10.0,
            purchaseRecordItemId: purchaseItemId,
            unitPrice: Decimal(25.99),
            currency: "USD"
        )

        #expect(location.purchaseRecordItemId == purchaseItemId)
        #expect(location.unitPrice == Decimal(25.99))
        #expect(location.currency == "USD")
    }

    @Test("Should preserve receipt import fields with other fields")
    func testReceiptImportFieldsWithOtherFields() {
        let purchaseItemId = UUID()
        let inventoryId = UUID()
        let storageDefId = UUID()
        let now = Date()

        let location = StorageLocationModel(
            id: UUID(),
            inventoryId: inventoryId,
            storageLocationId: storageDefId,
            locationName: "Shelf A",
            quantity: 15.0,
            containerCount: 3.0,
            dateAdded: now,
            dateModified: now,
            isTransfer: false,
            workspaceId: nil,
            purchaseRecordItemId: purchaseItemId,
            unitPrice: Decimal(8.75),
            currency: "EUR"
        )

        #expect(location.inventoryId == inventoryId)
        #expect(location.storageLocationId == storageDefId)
        #expect(location.locationName == "Shelf A")
        #expect(location.quantity == 15.0)
        #expect(location.containerCount == 3.0)
        #expect(location.purchaseRecordItemId == purchaseItemId)
        #expect(location.unitPrice == Decimal(8.75))
        #expect(location.currency == "EUR")
    }
}
