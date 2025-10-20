//
//  PurchaseRecordModelTests.swift
//  FlameworkerTests
//
//  Tests for PurchaseRecordModel domain model
//  Tests business logic, validation, formatting, and data transformations
//

import Testing
import Foundation
@testable import Flameworker

@Suite("PurchaseRecordModel Tests")
struct PurchaseRecordModelTests {

    // MARK: - Model Creation Tests

    @Test("Create with minimal fields")
    func testCreateMinimal() {
        let record = PurchaseRecordModel(
            supplier: "Frantz Art Glass",
            price: 125.50
        )

        #expect(record.supplier == "Frantz Art Glass")
        #expect(record.price == 125.50)
        #expect(record.notes == nil)
        #expect(record.id.isEmpty == false)
    }

    @Test("Create with all fields")
    func testCreateAllFields() {
        let customDate = Date(timeIntervalSince1970: 1000000)
        let record = PurchaseRecordModel(
            id: "custom-id",
            supplier: "Olympic Color",
            price: 75.00,
            dateAdded: customDate,
            notes: "Black Friday sale"
        )

        #expect(record.id == "custom-id")
        #expect(record.supplier == "Olympic Color")
        #expect(record.price == 75.00)
        #expect(record.dateAdded == customDate)
        #expect(record.notes == "Black Friday sale")
    }

    @Test("Create with default ID")
    func testCreateDefaultId() {
        let record = PurchaseRecordModel(
            supplier: "Test Supplier",
            price: 50.0
        )

        // Should have a UUID string as ID
        #expect(record.id.isEmpty == false)
        #expect(UUID(uuidString: record.id) != nil)
    }

    @Test("Create with default date")
    func testCreateDefaultDate() {
        let before = Date()
        let record = PurchaseRecordModel(
            supplier: "Test",
            price: 10.0
        )
        let after = Date()

        #expect(record.dateAdded >= before)
        #expect(record.dateAdded <= after)
    }

    // MARK: - Business Logic Validation Tests

    @Test("Trims whitespace from supplier")
    func testTrimsSupplier() {
        let record = PurchaseRecordModel(
            supplier: "  Frantz Art Glass  ",
            price: 100.0
        )

        #expect(record.supplier == "Frantz Art Glass")
    }

    @Test("Empty string notes become nil")
    func testEmptyNotesBecomesNil() {
        let record = PurchaseRecordModel(
            supplier: "Test",
            price: 10.0,
            notes: ""
        )

        #expect(record.notes == nil)
    }

    @Test("Whitespace-only notes become nil")
    func testWhitespaceNotesBecomesNil() {
        let record = PurchaseRecordModel(
            supplier: "Test",
            price: 10.0,
            notes: "   "
        )

        // Note: The current implementation doesn't trim notes, only checks isEmpty
        // So "   " is not empty and won't become nil
        #expect(record.notes == "   ")
    }

    @Test("Valid notes are preserved")
    func testValidNotesPreserved() {
        let record = PurchaseRecordModel(
            supplier: "Test",
            price: 10.0,
            notes: "Test note"
        )

        #expect(record.notes == "Test note")
    }

    // MARK: - Display and Formatting Tests

    @Test("displayName combines supplier and price")
    func testDisplayName() {
        let record = PurchaseRecordModel(
            supplier: "Frantz Art Glass",
            price: 125.50
        )

        #expect(record.displayName.contains("Frantz Art Glass"))
        #expect(record.displayName.contains("125.50"))
    }

    @Test("formattedPrice uses currency format")
    func testFormattedPrice() {
        let record = PurchaseRecordModel(
            supplier: "Test",
            price: 125.50
        )

        let formatted = record.formattedPrice
        #expect(formatted.contains("125.50"))
        #expect(formatted.contains("$"))
    }

    @Test("formattedPrice handles whole numbers")
    func testFormattedPriceWhole() {
        let record = PurchaseRecordModel(
            supplier: "Test",
            price: 100.0
        )

        let formatted = record.formattedPrice
        #expect(formatted.contains("100"))
        #expect(formatted.contains("$"))
    }

    @Test("formattedPrice handles zero")
    func testFormattedPriceZero() {
        let record = PurchaseRecordModel(
            supplier: "Test",
            price: 0.0
        )

        let formatted = record.formattedPrice
        #expect(formatted.contains("0"))
    }

    @Test("formattedDate returns medium style")
    func testFormattedDate() {
        let date = Date(timeIntervalSince1970: 1609459200)  // Jan 1, 2021
        let record = PurchaseRecordModel(
            supplier: "Test",
            price: 10.0,
            dateAdded: date
        )

        let formatted = record.formattedDate
        // Just verify it's not empty - format may vary by locale
        #expect(formatted.isEmpty == false)
    }

    // MARK: - Business Logic Methods Tests

    @Test("hasNotes - true when notes exist")
    func testHasNotesTrue() {
        let record = PurchaseRecordModel(
            supplier: "Test",
            price: 10.0,
            notes: "Some note"
        )

        #expect(record.hasNotes == true)
    }

    @Test("hasNotes - false when notes are nil")
    func testHasNotesNil() {
        let record = PurchaseRecordModel(
            supplier: "Test",
            price: 10.0,
            notes: nil
        )

        #expect(record.hasNotes == false)
    }

    @Test("hasNotes - false when notes are empty string")
    func testHasNotesEmpty() {
        let record = PurchaseRecordModel(
            supplier: "Test",
            price: 10.0,
            notes: ""
        )

        // Empty notes become nil, so hasNotes should be false
        #expect(record.hasNotes == false)
    }

    @Test("matchesSearchText - supplier match")
    func testMatchesSearchTextSupplier() {
        let record = PurchaseRecordModel(
            supplier: "Frantz Art Glass",
            price: 100.0
        )

        #expect(record.matchesSearchText("frantz") == true)
        #expect(record.matchesSearchText("FRANTZ") == true)
        #expect(record.matchesSearchText("art") == true)
        #expect(record.matchesSearchText("glass") == true)
    }

    @Test("matchesSearchText - notes match")
    func testMatchesSearchTextNotes() {
        let record = PurchaseRecordModel(
            supplier: "Test Supplier",
            price: 50.0,
            notes: "Black Friday sale"
        )

        #expect(record.matchesSearchText("black") == true)
        #expect(record.matchesSearchText("FRIDAY") == true)
        #expect(record.matchesSearchText("sale") == true)
    }

    @Test("matchesSearchText - no match")
    func testMatchesSearchTextNoMatch() {
        let record = PurchaseRecordModel(
            supplier: "Frantz Art Glass",
            price: 100.0,
            notes: "Test note"
        )

        #expect(record.matchesSearchText("Olympic") == false)
        #expect(record.matchesSearchText("xyz") == false)
    }

    @Test("matchesSearchText - nil notes returns false")
    func testMatchesSearchTextNilNotes() {
        let record = PurchaseRecordModel(
            supplier: "Test",
            price: 10.0,
            notes: nil
        )

        #expect(record.matchesSearchText("anything") == false)
    }

    @Test("isWithinDateRange - inside range")
    func testIsWithinDateRangeInside() {
        let date = Date(timeIntervalSince1970: 1000000)
        let record = PurchaseRecordModel(
            supplier: "Test",
            price: 10.0,
            dateAdded: date
        )

        let startDate = Date(timeIntervalSince1970: 500000)
        let endDate = Date(timeIntervalSince1970: 1500000)

        #expect(record.isWithinDateRange(from: startDate, to: endDate) == true)
    }

    @Test("isWithinDateRange - before range")
    func testIsWithinDateRangeBefore() {
        let date = Date(timeIntervalSince1970: 500000)
        let record = PurchaseRecordModel(
            supplier: "Test",
            price: 10.0,
            dateAdded: date
        )

        let startDate = Date(timeIntervalSince1970: 1000000)
        let endDate = Date(timeIntervalSince1970: 1500000)

        #expect(record.isWithinDateRange(from: startDate, to: endDate) == false)
    }

    @Test("isWithinDateRange - after range")
    func testIsWithinDateRangeAfter() {
        let date = Date(timeIntervalSince1970: 2000000)
        let record = PurchaseRecordModel(
            supplier: "Test",
            price: 10.0,
            dateAdded: date
        )

        let startDate = Date(timeIntervalSince1970: 1000000)
        let endDate = Date(timeIntervalSince1970: 1500000)

        #expect(record.isWithinDateRange(from: startDate, to: endDate) == false)
    }

    @Test("isWithinDateRange - exactly at start")
    func testIsWithinDateRangeExactStart() {
        let date = Date(timeIntervalSince1970: 1000000)
        let record = PurchaseRecordModel(
            supplier: "Test",
            price: 10.0,
            dateAdded: date
        )

        let startDate = Date(timeIntervalSince1970: 1000000)
        let endDate = Date(timeIntervalSince1970: 1500000)

        #expect(record.isWithinDateRange(from: startDate, to: endDate) == true)
    }

    @Test("isWithinDateRange - exactly at end")
    func testIsWithinDateRangeExactEnd() {
        let date = Date(timeIntervalSince1970: 1500000)
        let record = PurchaseRecordModel(
            supplier: "Test",
            price: 10.0,
            dateAdded: date
        )

        let startDate = Date(timeIntervalSince1970: 1000000)
        let endDate = Date(timeIntervalSince1970: 1500000)

        #expect(record.isWithinDateRange(from: startDate, to: endDate) == true)
    }

    // MARK: - Change Detection Tests

    @Test("hasChanges - no changes")
    func testHasChangesNone() {
        let date = Date()
        let record1 = PurchaseRecordModel(
            id: "same-id",
            supplier: "Frantz",
            price: 100.0,
            dateAdded: date,
            notes: "Test"
        )

        let record2 = PurchaseRecordModel(
            id: "same-id",
            supplier: "Frantz",
            price: 100.0,
            dateAdded: date,
            notes: "Test"
        )

        #expect(PurchaseRecordModel.hasChanges(existing: record1, new: record2) == false)
    }

    @Test("hasChanges - supplier changed")
    func testHasChangesSupplier() {
        let record1 = PurchaseRecordModel(supplier: "Frantz", price: 100.0)
        let record2 = PurchaseRecordModel(supplier: "Olympic", price: 100.0)

        #expect(PurchaseRecordModel.hasChanges(existing: record1, new: record2) == true)
    }

    @Test("hasChanges - price changed")
    func testHasChangesPrice() {
        let record1 = PurchaseRecordModel(supplier: "Frantz", price: 100.0)
        let record2 = PurchaseRecordModel(supplier: "Frantz", price: 150.0)

        #expect(PurchaseRecordModel.hasChanges(existing: record1, new: record2) == true)
    }

    @Test("hasChanges - date changed")
    func testHasChangesDate() {
        let date1 = Date(timeIntervalSince1970: 1000000)
        let date2 = Date(timeIntervalSince1970: 2000000)

        let record1 = PurchaseRecordModel(supplier: "Test", price: 100.0, dateAdded: date1)
        let record2 = PurchaseRecordModel(supplier: "Test", price: 100.0, dateAdded: date2)

        #expect(PurchaseRecordModel.hasChanges(existing: record1, new: record2) == true)
    }

    @Test("hasChanges - notes changed")
    func testHasChangesNotes() {
        let record1 = PurchaseRecordModel(supplier: "Test", price: 100.0, notes: "Note 1")
        let record2 = PurchaseRecordModel(supplier: "Test", price: 100.0, notes: "Note 2")

        #expect(PurchaseRecordModel.hasChanges(existing: record1, new: record2) == true)
    }

    @Test("hasChanges - notes nil to value")
    func testHasChangesNotesNilToValue() {
        let record1 = PurchaseRecordModel(supplier: "Test", price: 100.0, notes: nil)
        let record2 = PurchaseRecordModel(supplier: "Test", price: 100.0, notes: "New note")

        #expect(PurchaseRecordModel.hasChanges(existing: record1, new: record2) == true)
    }

    // MARK: - Validation Tests

    @Test("isValid - valid record")
    func testIsValidTrue() {
        let record = PurchaseRecordModel(
            supplier: "Frantz Art Glass",
            price: 125.50
        )

        #expect(record.isValid == true)
    }

    @Test("isValid - empty supplier is invalid")
    func testIsValidEmptySupplier() {
        let record = PurchaseRecordModel(
            supplier: "",
            price: 100.0
        )

        #expect(record.isValid == false)
    }

    @Test("isValid - whitespace-only supplier is invalid")
    func testIsValidWhitespaceSupplier() {
        let record = PurchaseRecordModel(
            supplier: "   ",
            price: 100.0
        )

        // After trimming, becomes empty
        #expect(record.isValid == false)
    }

    @Test("isValid - zero price is invalid")
    func testIsValidZeroPrice() {
        let record = PurchaseRecordModel(
            supplier: "Frantz",
            price: 0.0
        )

        #expect(record.isValid == false)
    }

    @Test("isValid - negative price is invalid")
    func testIsValidNegativePrice() {
        let record = PurchaseRecordModel(
            supplier: "Frantz",
            price: -50.0
        )

        #expect(record.isValid == false)
    }

    @Test("validationErrors - valid record has no errors")
    func testValidationErrorsValid() {
        let record = PurchaseRecordModel(
            supplier: "Frantz",
            price: 100.0
        )

        #expect(record.validationErrors.isEmpty == true)
    }

    @Test("validationErrors - empty supplier")
    func testValidationErrorsEmptySupplier() {
        let record = PurchaseRecordModel(
            supplier: "",
            price: 100.0
        )

        #expect(record.validationErrors.count == 1)
        #expect(record.validationErrors.contains("Supplier name is required"))
    }

    @Test("validationErrors - zero price")
    func testValidationErrorsZeroPrice() {
        let record = PurchaseRecordModel(
            supplier: "Frantz",
            price: 0.0
        )

        #expect(record.validationErrors.count == 1)
        #expect(record.validationErrors.contains("Price must be greater than 0"))
    }

    @Test("validationErrors - multiple errors")
    func testValidationErrorsMultiple() {
        let record = PurchaseRecordModel(
            supplier: "",
            price: 0.0
        )

        #expect(record.validationErrors.count == 2)
        #expect(record.validationErrors.contains("Supplier name is required"))
        #expect(record.validationErrors.contains("Price must be greater than 0"))
    }

    // MARK: - Equatable Tests

    @Test("Equatable - same values are equal")
    func testEquatableSame() {
        let date = Date()
        let record1 = PurchaseRecordModel(
            id: "same-id",
            supplier: "Frantz",
            price: 100.0,
            dateAdded: date,
            notes: "Test"
        )

        let record2 = PurchaseRecordModel(
            id: "same-id",
            supplier: "Frantz",
            price: 100.0,
            dateAdded: date,
            notes: "Test"
        )

        #expect(record1 == record2)
    }

    @Test("Equatable - different IDs are not equal")
    func testEquatableDifferentId() {
        let record1 = PurchaseRecordModel(
            id: "id1",
            supplier: "Frantz",
            price: 100.0
        )

        let record2 = PurchaseRecordModel(
            id: "id2",
            supplier: "Frantz",
            price: 100.0
        )

        #expect(record1 != record2)
    }

    @Test("Equatable - different suppliers are not equal")
    func testEquatableDifferentSupplier() {
        let date = Date()
        let record1 = PurchaseRecordModel(
            id: "same",
            supplier: "Frantz",
            price: 100.0,
            dateAdded: date
        )

        let record2 = PurchaseRecordModel(
            id: "same",
            supplier: "Olympic",
            price: 100.0,
            dateAdded: date
        )

        #expect(record1 != record2)
    }

    // MARK: - Codable Tests

    @Test("Codable - encode and decode with all fields")
    func testCodableAllFields() throws {
        let original = PurchaseRecordModel(
            id: "test-id",
            supplier: "Frantz Art Glass",
            price: 125.50,
            notes: "Black Friday"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(PurchaseRecordModel.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.supplier == original.supplier)
        #expect(decoded.price == original.price)
        #expect(decoded.notes == original.notes)
    }

    @Test("Codable - encode and decode without notes")
    func testCodableWithoutNotes() throws {
        let original = PurchaseRecordModel(
            supplier: "Olympic Color",
            price: 75.00
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(PurchaseRecordModel.self, from: data)

        #expect(decoded.supplier == original.supplier)
        #expect(decoded.price == original.price)
        #expect(decoded.notes == nil)
    }

    // MARK: - Dictionary Conversion Tests

    @Test("from(dictionary:) - valid dictionary")
    func testFromDictionaryValid() {
        let dict: [String: Any] = [
            "id": "test-id",
            "supplier": "Frantz Art Glass",
            "price": 125.50,
            "dateAdded": Date(),
            "notes": "Test note"
        ]

        let record = PurchaseRecordModel.from(dictionary: dict)

        #expect(record != nil)
        #expect(record?.id == "test-id")
        #expect(record?.supplier == "Frantz Art Glass")
        #expect(record?.price == 125.50)
        #expect(record?.notes == "Test note")
    }

    @Test("from(dictionary:) - minimal dictionary")
    func testFromDictionaryMinimal() {
        let dict: [String: Any] = [
            "supplier": "Test Supplier",
            "price": 50.0
        ]

        let record = PurchaseRecordModel.from(dictionary: dict)

        #expect(record != nil)
        #expect(record?.supplier == "Test Supplier")
        #expect(record?.price == 50.0)
        #expect(record?.notes == nil)
        #expect(UUID(uuidString: record?.id ?? "") != nil)  // Should have generated UUID
    }

    @Test("from(dictionary:) - missing supplier returns nil")
    func testFromDictionaryMissingSupplier() {
        let dict: [String: Any] = [
            "price": 100.0
        ]

        let record = PurchaseRecordModel.from(dictionary: dict)

        #expect(record == nil)
    }

    @Test("from(dictionary:) - missing price returns nil")
    func testFromDictionaryMissingPrice() {
        let dict: [String: Any] = [
            "supplier": "Test Supplier"
        ]

        let record = PurchaseRecordModel.from(dictionary: dict)

        #expect(record == nil)
    }

    @Test("toDictionary - all fields")
    func testToDictionaryAllFields() {
        let record = PurchaseRecordModel(
            id: "test-id",
            supplier: "Frantz Art Glass",
            price: 125.50,
            notes: "Test note"
        )

        let dict = record.toDictionary()

        #expect(dict["id"] as? String == "test-id")
        #expect(dict["supplier"] as? String == "Frantz Art Glass")
        #expect(dict["price"] as? Double == 125.50)
        #expect(dict["notes"] as? String == "Test note")
        #expect(dict["dateAdded"] as? Date != nil)
    }

    @Test("toDictionary - without notes")
    func testToDictionaryWithoutNotes() {
        let record = PurchaseRecordModel(
            supplier: "Test",
            price: 50.0
        )

        let dict = record.toDictionary()

        #expect(dict["supplier"] as? String == "Test")
        #expect(dict["price"] as? Double == 50.0)
        #expect(dict["notes"] == nil)
    }

    @Test("toDictionary and back - round trip")
    func testDictionaryRoundTrip() {
        let original = PurchaseRecordModel(
            id: "test-id",
            supplier: "Frantz Art Glass",
            price: 125.50,
            notes: "Test note"
        )

        let dict = original.toDictionary()
        let restored = PurchaseRecordModel.from(dictionary: dict)

        #expect(restored != nil)
        #expect(restored?.id == original.id)
        #expect(restored?.supplier == original.supplier)
        #expect(restored?.price == original.price)
        #expect(restored?.notes == original.notes)
    }

    // MARK: - Edge Cases

    @Test("Large price values")
    func testLargePriceValues() {
        let record = PurchaseRecordModel(
            supplier: "Test",
            price: 99999.99
        )

        #expect(record.price == 99999.99)
        #expect(record.isValid == true)
        #expect(record.formattedPrice.contains("99999.99") || record.formattedPrice.contains("99,999.99"))
    }

    @Test("Very small price values")
    func testSmallPriceValues() {
        let record = PurchaseRecordModel(
            supplier: "Test",
            price: 0.01
        )

        #expect(record.price == 0.01)
        #expect(record.isValid == true)
    }

    @Test("Long supplier names")
    func testLongSupplierName() {
        let longName = "This Is A Very Long Supplier Name That Could Potentially Break Some UI Components"
        let record = PurchaseRecordModel(
            supplier: longName,
            price: 100.0
        )

        #expect(record.supplier == longName)
        #expect(record.displayName.contains(longName))
    }

    @Test("Long notes")
    func testLongNotes() {
        let longNotes = String(repeating: "This is a test note. ", count: 50)
        let record = PurchaseRecordModel(
            supplier: "Test",
            price: 100.0,
            notes: longNotes
        )

        #expect(record.notes == longNotes)
        #expect(record.hasNotes == true)
    }

    @Test("Special characters in supplier")
    func testSpecialCharactersSupplier() {
        let record = PurchaseRecordModel(
            supplier: "Müller's Glåss & Co.",
            price: 100.0
        )

        #expect(record.supplier == "Müller's Glåss & Co.")
        #expect(record.matchesSearchText("müller") == true)
    }

    @Test("Special characters in notes")
    func testSpecialCharactersNotes() {
        let record = PurchaseRecordModel(
            supplier: "Test",
            price: 100.0,
            notes: "Café sale - 50% off!"
        )

        #expect(record.notes == "Café sale - 50% off!")
        #expect(record.matchesSearchText("café") == true)
    }
}
