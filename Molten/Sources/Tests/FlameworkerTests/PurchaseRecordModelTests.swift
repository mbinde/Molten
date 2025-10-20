//
//  PurchaseRecordModelTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/19/25.
//  Tests for purchase record domain models
//

import Testing
import Foundation
@testable import Molten

/// Tests for PurchaseRecordModel and PurchaseRecordItemModel
@Suite("Purchase Record Model Tests")
struct PurchaseRecordModelTests {

    // MARK: - PurchaseRecordItemModel Tests

    @Test("Can create purchase record item with required fields")
    func testCreatePurchaseRecordItem() {
        let item = PurchaseRecordItemModel(
            itemNaturalKey: "be-clear-001",
            type: "rod",
            quantity: 5.0
        )

        #expect(item.itemNaturalKey == "be-clear-001")
        #expect(item.type == "rod")
        #expect(item.quantity == 5.0)
        #expect(item.subtype == nil)
        #expect(item.subsubtype == nil)
        #expect(item.totalPrice == nil)
        #expect(item.orderIndex == 0)
    }

    @Test("Can create purchase record item with all fields")
    func testCreatePurchaseRecordItemWithAllFields() {
        let item = PurchaseRecordItemModel(
            id: UUID(),
            itemNaturalKey: "be-frit-001",
            type: "frit",
            subtype: "coarse",
            subsubtype: "opaque",
            quantity: 2.0,
            totalPrice: Decimal(string: "45.50"),
            orderIndex: 1
        )

        #expect(item.itemNaturalKey == "be-frit-001")
        #expect(item.type == "frit")
        #expect(item.subtype == "coarse")
        #expect(item.subsubtype == "opaque")
        #expect(item.quantity == 2.0)
        #expect(item.totalPrice == Decimal(string: "45.50"))
        #expect(item.orderIndex == 1)
    }

    @Test("Full type description formats correctly")
    func testFullTypeDescription() {
        let rodItem = PurchaseRecordItemModel(
            itemNaturalKey: "test-001",
            type: "rod",
            quantity: 1.0
        )
        #expect(rodItem.fullTypeDescription == "rod")

        let fritItem = PurchaseRecordItemModel(
            itemNaturalKey: "test-002",
            type: "frit",
            subtype: "coarse",
            quantity: 1.0
        )
        #expect(fritItem.fullTypeDescription == "frit - coarse")

        let detailedItem = PurchaseRecordItemModel(
            itemNaturalKey: "test-003",
            type: "frit",
            subtype: "coarse",
            subsubtype: "opaque",
            quantity: 1.0
        )
        #expect(detailedItem.fullTypeDescription == "frit - coarse - opaque")
    }

    @Test("Formatted quantity displays correctly")
    func testFormattedQuantity() {
        let item = PurchaseRecordItemModel(
            itemNaturalKey: "test-001",
            type: "rod",
            quantity: 10.5
        )

        #expect(item.formattedQuantity == "10.5 rod")
    }

    @Test("Formatted price displays with currency")
    func testFormattedPrice() {
        let item = PurchaseRecordItemModel(
            itemNaturalKey: "test-001",
            type: "rod",
            quantity: 5.0,
            totalPrice: Decimal(string: "25.99")
        )

        let formatted = item.formattedPrice(currency: "USD")
        #expect(formatted?.contains("25.99") == true)
    }

    @Test("Formatted price returns nil when no price")
    func testFormattedPriceNil() {
        let item = PurchaseRecordItemModel(
            itemNaturalKey: "test-001",
            type: "rod",
            quantity: 5.0
        )

        let formatted = item.formattedPrice(currency: "USD")
        #expect(formatted == nil)
    }

    @Test("Item trims whitespace from natural key")
    func testItemTrimsWhitespace() {
        let item = PurchaseRecordItemModel(
            itemNaturalKey: "  be-clear-001  ",
            type: "rod",
            quantity: 1.0
        )

        #expect(item.itemNaturalKey == "be-clear-001")
    }

    @Test("Item converts empty subtype to nil")
    func testItemEmptySubtypeToNil() {
        let item = PurchaseRecordItemModel(
            itemNaturalKey: "test-001",
            type: "rod",
            subtype: "",
            subsubtype: "",
            quantity: 1.0
        )

        #expect(item.subtype == nil)
        #expect(item.subsubtype == nil)
    }

    @Test("Item validation succeeds with valid data")
    func testItemValidationSuccess() {
        let item = PurchaseRecordItemModel(
            itemNaturalKey: "be-clear-001",
            type: "rod",
            quantity: 5.0
        )

        #expect(item.isValid == true)
        #expect(item.validationErrors.isEmpty)
    }

    @Test("Item validation fails with empty natural key")
    func testItemValidationEmptyNaturalKey() {
        let item = PurchaseRecordItemModel(
            itemNaturalKey: "",
            type: "rod",
            quantity: 5.0
        )

        #expect(item.isValid == false)
        #expect(item.validationErrors.contains("Item natural key is required"))
    }

    @Test("Item validation fails with empty type")
    func testItemValidationEmptyType() {
        let item = PurchaseRecordItemModel(
            itemNaturalKey: "be-clear-001",
            type: "",
            quantity: 5.0
        )

        #expect(item.isValid == false)
        #expect(item.validationErrors.contains("Type is required"))
    }

    @Test("Item validation fails with zero quantity")
    func testItemValidationZeroQuantity() {
        let item = PurchaseRecordItemModel(
            itemNaturalKey: "be-clear-001",
            type: "rod",
            quantity: 0.0
        )

        #expect(item.isValid == false)
        #expect(item.validationErrors.contains("Quantity must be greater than 0"))
    }

    @Test("Item validation fails with negative quantity")
    func testItemValidationNegativeQuantity() {
        let item = PurchaseRecordItemModel(
            itemNaturalKey: "be-clear-001",
            type: "rod",
            quantity: -5.0
        )

        #expect(item.isValid == false)
        #expect(item.validationErrors.contains("Quantity must be greater than 0"))
    }

    // MARK: - PurchaseRecordModel Tests

    @Test("Can create purchase record with required fields")
    func testCreatePurchaseRecord() {
        let record = PurchaseRecordModel(
            supplier: "Test Supplier"
        )

        #expect(record.supplier == "Test Supplier")
        #expect(record.subtotal == nil)
        #expect(record.tax == nil)
        #expect(record.shipping == nil)
        #expect(record.currency == "USD")
        #expect(record.notes == nil)
        #expect(record.items.isEmpty)
    }

    @Test("Can create purchase record with all fields")
    func testCreatePurchaseRecordWithAllFields() {
        let items = [
            PurchaseRecordItemModel(
                itemNaturalKey: "be-clear-001",
                type: "rod",
                quantity: 5.0
            )
        ]

        let record = PurchaseRecordModel(
            id: UUID(),
            supplier: "Test Supplier",
            datePurchased: Date(),
            dateAdded: Date(),
            subtotal: Decimal(string: "100.00"),
            tax: Decimal(string: "8.50"),
            shipping: Decimal(string: "12.00"),
            currency: "USD",
            notes: "Test notes",
            items: items
        )

        #expect(record.supplier == "Test Supplier")
        #expect(record.subtotal == Decimal(string: "100.00"))
        #expect(record.tax == Decimal(string: "8.50"))
        #expect(record.shipping == Decimal(string: "12.00"))
        #expect(record.currency == "USD")
        #expect(record.notes == "Test notes")
        #expect(record.items.count == 1)
    }

    @Test("Total price calculates correctly with all components")
    func testTotalPriceWithAllComponents() {
        let record = PurchaseRecordModel(
            supplier: "Test Supplier",
            subtotal: Decimal(string: "100.00"),
            tax: Decimal(string: "8.50"),
            shipping: Decimal(string: "12.00")
        )

        #expect(record.totalPrice == Decimal(string: "120.50"))
    }

    @Test("Total price calculates with only subtotal")
    func testTotalPriceSubtotalOnly() {
        let record = PurchaseRecordModel(
            supplier: "Test Supplier",
            subtotal: Decimal(string: "100.00")
        )

        #expect(record.totalPrice == Decimal(string: "100.00"))
    }

    @Test("Total price calculates with subtotal and tax")
    func testTotalPriceSubtotalAndTax() {
        let record = PurchaseRecordModel(
            supplier: "Test Supplier",
            subtotal: Decimal(string: "100.00"),
            tax: Decimal(string: "8.50")
        )

        #expect(record.totalPrice == Decimal(string: "108.50"))
    }

    @Test("Total price returns nil when no components present")
    func testTotalPriceNilWhenNoComponents() {
        let record = PurchaseRecordModel(
            supplier: "Test Supplier"
        )

        #expect(record.totalPrice == nil)
    }

    @Test("Display name combines supplier and date")
    func testDisplayName() {
        let record = PurchaseRecordModel(
            supplier: "Test Supplier",
            datePurchased: Date()
        )

        #expect(record.displayName.contains("Test Supplier"))
        #expect(record.displayName.contains("-"))
    }

    @Test("Matches search text in supplier")
    func testMatchesSearchTextInSupplier() {
        let record = PurchaseRecordModel(
            supplier: "Bullseye Glass"
        )

        #expect(record.matchesSearchText("bullseye") == true)
        #expect(record.matchesSearchText("BULLSEYE") == true)
        #expect(record.matchesSearchText("glass") == true)
        #expect(record.matchesSearchText("notfound") == false)
    }

    @Test("Matches search text in notes")
    func testMatchesSearchTextInNotes() {
        let record = PurchaseRecordModel(
            supplier: "Test Supplier",
            notes: "Bought at the show"
        )

        #expect(record.matchesSearchText("show") == true)
        #expect(record.matchesSearchText("SHOW") == true)
        #expect(record.matchesSearchText("notfound") == false)
    }

    @Test("Formatted price displays with currency")
    func testFormattedPriceWithCurrency() {
        let record = PurchaseRecordModel(
            supplier: "Test Supplier",
            subtotal: Decimal(string: "100.00"),
            tax: Decimal(string: "8.50"),
            shipping: Decimal(string: "12.00")
        )

        let formatted = record.formattedPrice
        #expect(formatted?.contains("120.50") == true)
    }

    @Test("Formatted price returns nil when no price")
    func testFormattedPriceNilWhenNoPrice() {
        let record = PurchaseRecordModel(
            supplier: "Test Supplier"
        )

        #expect(record.formattedPrice == nil)
    }

    @Test("Formatted date displays correctly")
    func testFormattedDate() {
        let record = PurchaseRecordModel(
            supplier: "Test Supplier",
            datePurchased: Date()
        )

        // Should contain date components
        let formatted = record.formattedDate
        #expect(!formatted.isEmpty)
    }

    @Test("Has notes returns true when notes present")
    func testHasNotesTrue() {
        let record = PurchaseRecordModel(
            supplier: "Test Supplier",
            notes: "Test notes"
        )

        #expect(record.hasNotes == true)
    }

    @Test("Has notes returns false when notes nil")
    func testHasNotesFalse() {
        let record = PurchaseRecordModel(
            supplier: "Test Supplier"
        )

        #expect(record.hasNotes == false)
    }

    @Test("Is within date range returns correct result")
    func testIsWithinDateRange() {
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        let record = PurchaseRecordModel(
            supplier: "Test Supplier",
            datePurchased: today
        )

        #expect(record.isWithinDateRange(from: yesterday, to: tomorrow) == true)
        #expect(record.isWithinDateRange(from: tomorrow, to: tomorrow) == false)
    }

    @Test("Item count returns correct number")
    func testItemCount() {
        let items = [
            PurchaseRecordItemModel(itemNaturalKey: "item-001", type: "rod", quantity: 1.0),
            PurchaseRecordItemModel(itemNaturalKey: "item-002", type: "rod", quantity: 2.0)
        ]

        let record = PurchaseRecordModel(
            supplier: "Test Supplier",
            items: items
        )

        #expect(record.itemCount == 2)
    }

    @Test("Has price info returns true when any price component present")
    func testHasPriceInfoTrue() {
        let record = PurchaseRecordModel(
            supplier: "Test Supplier",
            subtotal: Decimal(string: "100.00")
        )

        #expect(record.hasPriceInfo == true)
    }

    @Test("Has price info returns false when no price components")
    func testHasPriceInfoFalse() {
        let record = PurchaseRecordModel(
            supplier: "Test Supplier"
        )

        #expect(record.hasPriceInfo == false)
    }

    @Test("Record trims whitespace from supplier")
    func testRecordTrimsWhitespace() {
        let record = PurchaseRecordModel(
            supplier: "  Test Supplier  "
        )

        #expect(record.supplier == "Test Supplier")
    }

    @Test("Record converts empty notes to nil")
    func testRecordEmptyNotesToNil() {
        let record = PurchaseRecordModel(
            supplier: "Test Supplier",
            notes: ""
        )

        #expect(record.notes == nil)
    }

    @Test("Validation succeeds with valid data")
    func testValidationSuccess() {
        let record = PurchaseRecordModel(
            supplier: "Test Supplier"
        )

        #expect(record.isValid == true)
        #expect(record.validationErrors.isEmpty)
    }

    @Test("Validation fails with empty supplier")
    func testValidationEmptySupplier() {
        let record = PurchaseRecordModel(
            supplier: ""
        )

        #expect(record.isValid == false)
        #expect(record.validationErrors.contains("Supplier name is required"))
    }

    @Test("Validation fails with invalid items")
    func testValidationInvalidItems() {
        let invalidItem = PurchaseRecordItemModel(
            itemNaturalKey: "",  // Invalid
            type: "rod",
            quantity: 1.0
        )

        let record = PurchaseRecordModel(
            supplier: "Test Supplier",
            items: [invalidItem]
        )

        #expect(record.isValid == false)
        #expect(record.validationErrors.contains { $0.contains("Item at index 0 is invalid") })
    }

    // MARK: - fromCheckout Helper Tests

    @Test("fromCheckout creates record correctly")
    func testFromCheckout() {
        let items = [
            (itemNaturalKey: "be-clear-001", type: "rod", quantity: 5.0),
            (itemNaturalKey: "ef-blue-002", type: "rod", quantity: 3.0)
        ]

        let record = PurchaseRecordModel.fromCheckout(
            supplier: "Test Supplier",
            items: items,
            subtotal: Decimal(string: "100.00"),
            tax: Decimal(string: "8.50"),
            shipping: Decimal(string: "12.00"),
            notes: "Test purchase"
        )

        #expect(record.supplier == "Test Supplier")
        #expect(record.subtotal == Decimal(string: "100.00"))
        #expect(record.tax == Decimal(string: "8.50"))
        #expect(record.shipping == Decimal(string: "12.00"))
        #expect(record.notes == "Test purchase")
        #expect(record.items.count == 2)
        #expect(record.items[0].itemNaturalKey == "be-clear-001")
        #expect(record.items[0].quantity == 5.0)
        #expect(record.items[0].orderIndex == 0)
        #expect(record.items[1].itemNaturalKey == "ef-blue-002")
        #expect(record.items[1].quantity == 3.0)
        #expect(record.items[1].orderIndex == 1)
    }

    @Test("fromCheckout preserves item order")
    func testFromCheckoutItemOrder() {
        let items = [
            (itemNaturalKey: "item-001", type: "rod", quantity: 1.0),
            (itemNaturalKey: "item-002", type: "rod", quantity: 2.0),
            (itemNaturalKey: "item-003", type: "rod", quantity: 3.0)
        ]

        let record = PurchaseRecordModel.fromCheckout(
            supplier: "Test Supplier",
            items: items
        )

        #expect(record.items[0].orderIndex == 0)
        #expect(record.items[1].orderIndex == 1)
        #expect(record.items[2].orderIndex == 2)
    }
}
