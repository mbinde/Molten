//
//  PurchaseRecordModelTests.swift
//  MoltenTests
//
//  Tests for PurchaseRecordModel and PurchaseRecordItemModel
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

@Suite("PurchaseRecordModel Tests")
@MainActor
struct PurchaseRecordModelTests {

    // MARK: - Basic Initialization Tests

    @Test("Should initialize with required fields")
    func testBasicInitialization() {
        let record = PurchaseRecordModel(
            supplier: "Frantz Art Glass",
            datePurchased: Date()
        )

        #expect(record.supplier == "Frantz Art Glass")
        #expect(record.items.isEmpty)
        #expect(record.currency == "USD")
    }

    @Test("Should trim whitespace from supplier")
    func testSupplierTrimming() {
        let record = PurchaseRecordModel(
            supplier: "  Bullseye Glass  "
        )

        #expect(record.supplier == "Bullseye Glass")
    }

    @Test("Should set notes to nil when empty")
    func testEmptyNotesNil() {
        let record = PurchaseRecordModel(
            supplier: "Test",
            notes: ""
        )

        #expect(record.notes == nil)
    }

    // MARK: - Receipt Import Field Tests

    @Test("Should store email receipt ID")
    func testEmailReceiptId() {
        let record = PurchaseRecordModel(
            supplier: "Test Supplier",
            emailReceiptId: "receipt-123"
        )

        #expect(record.emailReceiptId == "receipt-123")
    }

    @Test("Should set empty emailReceiptId to nil")
    func testEmptyEmailReceiptIdNil() {
        let record = PurchaseRecordModel(
            supplier: "Test",
            emailReceiptId: ""
        )

        #expect(record.emailReceiptId == nil)
    }

    @Test("Should store sender email")
    func testSenderEmail() {
        let record = PurchaseRecordModel(
            supplier: "Test Supplier",
            senderEmail: "orders@frantz.com"
        )

        #expect(record.senderEmail == "orders@frantz.com")
    }

    @Test("Should set empty senderEmail to nil")
    func testEmptySenderEmailNil() {
        let record = PurchaseRecordModel(
            supplier: "Test",
            senderEmail: ""
        )

        #expect(record.senderEmail == nil)
    }

    @Test("Should store order number")
    func testOrderNumber() {
        let record = PurchaseRecordModel(
            supplier: "Test Supplier",
            orderNumber: "ORD-12345"
        )

        #expect(record.orderNumber == "ORD-12345")
    }

    @Test("Should set empty orderNumber to nil")
    func testEmptyOrderNumberNil() {
        let record = PurchaseRecordModel(
            supplier: "Test",
            orderNumber: ""
        )

        #expect(record.orderNumber == nil)
    }

    @Test("Should store all receipt fields together")
    func testAllReceiptFields() {
        let record = PurchaseRecordModel(
            supplier: "Frantz Art Glass",
            emailReceiptId: "receipt-xyz",
            senderEmail: "orders@frantz.com",
            orderNumber: "FA-2025-001"
        )

        #expect(record.emailReceiptId == "receipt-xyz")
        #expect(record.senderEmail == "orders@frantz.com")
        #expect(record.orderNumber == "FA-2025-001")
    }

    // MARK: - Total Price Computation Tests

    @Test("Should compute total from subtotal, tax, shipping")
    func testTotalPriceComputation() {
        let record = PurchaseRecordModel(
            supplier: "Test",
            subtotal: Decimal(100),
            tax: Decimal(8),
            shipping: Decimal(12)
        )

        #expect(record.totalPrice == Decimal(120))
    }

    @Test("Should return nil total when no price components")
    func testTotalPriceNil() {
        let record = PurchaseRecordModel(
            supplier: "Test"
        )

        #expect(record.totalPrice == nil)
    }

    @Test("Should handle partial price components")
    func testPartialPriceComponents() {
        let record = PurchaseRecordModel(
            supplier: "Test",
            subtotal: Decimal(50)
        )

        #expect(record.totalPrice == Decimal(50))
    }

    // MARK: - Validation Tests

    @Test("Should be valid with supplier")
    func testValidRecord() {
        let record = PurchaseRecordModel(
            supplier: "Valid Supplier"
        )

        #expect(record.isValid == true)
        #expect(record.validationErrors.isEmpty)
    }

    @Test("Should be invalid without supplier")
    func testInvalidWithoutSupplier() {
        let record = PurchaseRecordModel(
            supplier: ""
        )

        #expect(record.isValid == false)
        #expect(record.validationErrors.contains("Supplier name is required"))
    }

    // MARK: - Business Logic Tests

    @Test("Should match search text in supplier")
    func testMatchesSearchTextSupplier() {
        let record = PurchaseRecordModel(
            supplier: "Frantz Art Glass"
        )

        #expect(record.matchesSearchText("frantz") == true)
        #expect(record.matchesSearchText("art") == true)
        #expect(record.matchesSearchText("bullseye") == false)
    }

    @Test("Should match search text in notes")
    func testMatchesSearchTextNotes() {
        let record = PurchaseRecordModel(
            supplier: "Test",
            notes: "Special order for project"
        )

        #expect(record.matchesSearchText("special") == true)
        #expect(record.matchesSearchText("project") == true)
    }

    @Test("Should check date range correctly")
    func testIsWithinDateRange() {
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now)!
        let lastWeek = Calendar.current.date(byAdding: .day, value: -7, to: now)!

        let record = PurchaseRecordModel(
            supplier: "Test",
            datePurchased: now
        )

        #expect(record.isWithinDateRange(from: yesterday, to: tomorrow) == true)
        #expect(record.isWithinDateRange(from: lastWeek, to: yesterday) == false)
    }

    @Test("Should count items")
    func testItemCount() {
        let items = [
            PurchaseRecordItemModel(item_stable_id: "abc", type: "rod", quantity: 1),
            PurchaseRecordItemModel(item_stable_id: "def", type: "frit", quantity: 2)
        ]

        let record = PurchaseRecordModel(
            supplier: "Test",
            items: items
        )

        #expect(record.itemCount == 2)
    }

    @Test("Should detect price info presence")
    func testHasPriceInfo() {
        let withPrice = PurchaseRecordModel(
            supplier: "Test",
            subtotal: Decimal(100)
        )

        let withoutPrice = PurchaseRecordModel(
            supplier: "Test"
        )

        #expect(withPrice.hasPriceInfo == true)
        #expect(withoutPrice.hasPriceInfo == false)
    }

    // MARK: - fromCheckout Tests

    @Test("Should create record from checkout")
    func testFromCheckout() {
        let items: [(item_stable_id: String, type: String, quantity: Double)] = [
            ("abc123", "rod", 5),
            ("def456", "frit", 2)
        ]

        let record = PurchaseRecordModel.fromCheckout(
            supplier: "Frantz Art Glass",
            items: items,
            subtotal: Decimal(200),
            notes: "Online order"
        )

        #expect(record.supplier == "Frantz Art Glass")
        #expect(record.items.count == 2)
        #expect(record.items[0].item_stable_id == "abc123")
        #expect(record.items[0].orderIndex == 0)
        #expect(record.items[1].orderIndex == 1)
        #expect(record.subtotal == Decimal(200))
        #expect(record.notes == "Online order")
    }
}

// MARK: - PurchaseRecordItemModel Tests

@Suite("PurchaseRecordItemModel Tests")
@MainActor
struct PurchaseRecordItemModelTests {

    // MARK: - Basic Initialization Tests

    @Test("Should initialize with required fields")
    func testBasicInitialization() {
        let item = PurchaseRecordItemModel(
            item_stable_id: "abc123",
            type: "rod",
            quantity: 5
        )

        #expect(item.item_stable_id == "abc123")
        #expect(item.type == "rod")
        #expect(item.quantity == 5)
    }

    @Test("Should trim whitespace from stable_id")
    func testStableIdTrimming() {
        let item = PurchaseRecordItemModel(
            item_stable_id: "  abc123  ",
            type: "rod",
            quantity: 1
        )

        #expect(item.item_stable_id == "abc123")
    }

    @Test("Should set empty subtype to nil")
    func testEmptySubtypeNil() {
        let item = PurchaseRecordItemModel(
            item_stable_id: "abc",
            type: "rod",
            subtype: "",
            quantity: 1
        )

        #expect(item.subtype == nil)
    }

    // MARK: - Receipt Import Field Tests

    @Test("Should store unit price")
    func testUnitPrice() {
        let item = PurchaseRecordItemModel(
            item_stable_id: "abc",
            type: "rod",
            quantity: 5,
            unitPrice: Decimal(10.50)
        )

        #expect(item.unitPrice == Decimal(10.50))
    }

    @Test("Should store currency")
    func testCurrency() {
        let item = PurchaseRecordItemModel(
            item_stable_id: "abc",
            type: "rod",
            quantity: 1,
            currency: "EUR"
        )

        #expect(item.currency == "EUR")
    }

    @Test("Should set empty currency to nil")
    func testEmptyCurrencyNil() {
        let item = PurchaseRecordItemModel(
            item_stable_id: "abc",
            type: "rod",
            quantity: 1,
            currency: ""
        )

        #expect(item.currency == nil)
    }

    @Test("Should store receipt line hash")
    func testReceiptLineHash() {
        let item = PurchaseRecordItemModel(
            item_stable_id: "abc",
            type: "rod",
            quantity: 1,
            receiptLineHash: "a1b2c3d4e5f6"
        )

        #expect(item.receiptLineHash == "a1b2c3d4e5f6")
    }

    @Test("Should set empty receiptLineHash to nil")
    func testEmptyReceiptLineHashNil() {
        let item = PurchaseRecordItemModel(
            item_stable_id: "abc",
            type: "rod",
            quantity: 1,
            receiptLineHash: ""
        )

        #expect(item.receiptLineHash == nil)
    }

    @Test("Should store all receipt item fields together")
    func testAllReceiptItemFields() {
        let item = PurchaseRecordItemModel(
            item_stable_id: "abc123",
            type: "rod",
            subtype: "12mm",
            quantity: 5,
            totalPrice: Decimal(52.50),
            unitPrice: Decimal(10.50),
            currency: "USD",
            receiptLineHash: "hash123"
        )

        #expect(item.unitPrice == Decimal(10.50))
        #expect(item.currency == "USD")
        #expect(item.receiptLineHash == "hash123")
        #expect(item.totalPrice == Decimal(52.50))
    }

    // MARK: - Validation Tests

    @Test("Should be valid with required fields")
    func testValidItem() {
        let item = PurchaseRecordItemModel(
            item_stable_id: "abc",
            type: "rod",
            quantity: 1
        )

        #expect(item.isValid == true)
        #expect(item.validationErrors.isEmpty)
    }

    @Test("Should be invalid without stable_id")
    func testInvalidWithoutStableId() {
        let item = PurchaseRecordItemModel(
            item_stable_id: "",
            type: "rod",
            quantity: 1
        )

        #expect(item.isValid == false)
        #expect(item.validationErrors.contains("Item natural key is required"))
    }

    @Test("Should be invalid without type")
    func testInvalidWithoutType() {
        let item = PurchaseRecordItemModel(
            item_stable_id: "abc",
            type: "",
            quantity: 1
        )

        #expect(item.isValid == false)
        #expect(item.validationErrors.contains("Type is required"))
    }

    @Test("Should be invalid with zero quantity")
    func testInvalidWithZeroQuantity() {
        let item = PurchaseRecordItemModel(
            item_stable_id: "abc",
            type: "rod",
            quantity: 0
        )

        #expect(item.isValid == false)
        #expect(item.validationErrors.contains("Quantity must be greater than 0"))
    }

    // MARK: - Display Tests

    @Test("Should build full type description")
    func testFullTypeDescription() {
        let item = PurchaseRecordItemModel(
            item_stable_id: "abc",
            type: "frit",
            subtype: "coarse",
            subsubtype: "#25",
            quantity: 1
        )

        #expect(item.fullTypeDescription == "frit - coarse - #25")
    }

    @Test("Should format quantity with type")
    func testFormattedQuantity() {
        let item = PurchaseRecordItemModel(
            item_stable_id: "abc",
            type: "rod",
            quantity: 5
        )

        #expect(item.formattedQuantity.contains("5"))
        #expect(item.formattedQuantity.contains("rod"))
    }
}
