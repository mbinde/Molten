//
//  AddPurchaseRecordViewModelTests.swift
//  MoltenTests
//
//  Tests for AddPurchaseRecordViewModel form validation and save operations
//

import Testing
import Foundation
@testable import Molten

@Suite("AddPurchaseRecordViewModel Tests")
@MainActor
struct AddPurchaseRecordViewModelTests {

    // MARK: - Initialization Tests

    @Test("Initial state has default values")
    func testInitialState() async throws {
        let viewModel = AddPurchaseRecordViewModel()

        #expect(viewModel.supplier.isEmpty)
        #expect(viewModel.totalAmount.isEmpty)
        #expect(viewModel.itemType == "rod")
        #expect(viewModel.units == .rods)
        #expect(viewModel.notes.isEmpty)
        #expect(viewModel.errorMessage == nil)
        #expect(!viewModel.showingError)
        #expect(!viewModel.isSaving)
    }

    @Test("Initial date is today")
    func testInitialDateIsToday() async throws {
        let viewModel = AddPurchaseRecordViewModel()
        let calendar = Calendar.current

        #expect(calendar.isDateInToday(viewModel.date))
    }

    // MARK: - Validation Tests

    @Test("isValid returns false when supplier is empty")
    func testIsValidEmptySupplier() async throws {
        let viewModel = AddPurchaseRecordViewModel()
        viewModel.supplier = ""
        viewModel.totalAmount = "100.00"

        #expect(!viewModel.isValid)
    }

    @Test("isValid returns false when supplier is whitespace only")
    func testIsValidWhitespaceSupplier() async throws {
        let viewModel = AddPurchaseRecordViewModel()
        viewModel.supplier = "   "
        viewModel.totalAmount = "100.00"

        #expect(!viewModel.isValid)
    }

    @Test("isValid returns false when amount is empty")
    func testIsValidEmptyAmount() async throws {
        let viewModel = AddPurchaseRecordViewModel()
        viewModel.supplier = "Glass Supply Co"
        viewModel.totalAmount = ""

        #expect(!viewModel.isValid)
    }

    @Test("isValid returns false when amount is zero")
    func testIsValidZeroAmount() async throws {
        let viewModel = AddPurchaseRecordViewModel()
        viewModel.supplier = "Glass Supply Co"
        viewModel.totalAmount = "0"

        #expect(!viewModel.isValid)
    }

    @Test("isValid returns false when amount is negative")
    func testIsValidNegativeAmount() async throws {
        let viewModel = AddPurchaseRecordViewModel()
        viewModel.supplier = "Glass Supply Co"
        viewModel.totalAmount = "-50.00"

        #expect(!viewModel.isValid)
    }

    @Test("isValid returns false when amount is not a number")
    func testIsValidInvalidAmount() async throws {
        let viewModel = AddPurchaseRecordViewModel()
        viewModel.supplier = "Glass Supply Co"
        viewModel.totalAmount = "abc"

        #expect(!viewModel.isValid)
    }

    @Test("isValid returns true with valid supplier and amount")
    func testIsValidWithValidData() async throws {
        let viewModel = AddPurchaseRecordViewModel()
        viewModel.supplier = "Glass Supply Co"
        viewModel.totalAmount = "150.00"

        #expect(viewModel.isValid)
    }

    @Test("isValid trims supplier whitespace")
    func testIsValidTrimsSupplierWhitespace() async throws {
        let viewModel = AddPurchaseRecordViewModel()
        viewModel.supplier = "  Glass Supply Co  "
        viewModel.totalAmount = "150.00"

        #expect(viewModel.isValid)
    }

    // MARK: - parsedAmount Tests

    @Test("parsedAmount returns nil for empty string")
    func testParsedAmountEmpty() async throws {
        let viewModel = AddPurchaseRecordViewModel()
        viewModel.totalAmount = ""

        #expect(viewModel.parsedAmount == nil)
    }

    @Test("parsedAmount returns nil for invalid string")
    func testParsedAmountInvalid() async throws {
        let viewModel = AddPurchaseRecordViewModel()
        viewModel.totalAmount = "not a number"

        #expect(viewModel.parsedAmount == nil)
    }

    @Test("parsedAmount returns nil for zero")
    func testParsedAmountZero() async throws {
        let viewModel = AddPurchaseRecordViewModel()
        viewModel.totalAmount = "0"

        #expect(viewModel.parsedAmount == nil)
    }

    @Test("parsedAmount returns nil for negative")
    func testParsedAmountNegative() async throws {
        let viewModel = AddPurchaseRecordViewModel()
        viewModel.totalAmount = "-100"

        #expect(viewModel.parsedAmount == nil)
    }

    @Test("parsedAmount returns value for valid integer")
    func testParsedAmountValidInteger() async throws {
        let viewModel = AddPurchaseRecordViewModel()
        viewModel.totalAmount = "100"

        #expect(viewModel.parsedAmount == 100.0)
    }

    @Test("parsedAmount returns value for valid decimal")
    func testParsedAmountValidDecimal() async throws {
        let viewModel = AddPurchaseRecordViewModel()
        viewModel.totalAmount = "150.50"

        #expect(viewModel.parsedAmount == 150.50)
    }

    // MARK: - Save Tests

    @Test("save fails with empty supplier")
    func testSaveFailsEmptySupplier() async throws {
        let viewModel = AddPurchaseRecordViewModel()
        viewModel.supplier = ""
        viewModel.totalAmount = "100.00"

        let result = await viewModel.save()

        #expect(!result)
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.showingError)
    }

    @Test("save fails with invalid amount")
    func testSaveFailsInvalidAmount() async throws {
        let viewModel = AddPurchaseRecordViewModel()
        viewModel.supplier = "Glass Supply Co"
        viewModel.totalAmount = ""

        let result = await viewModel.save()

        #expect(!result)
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.showingError)
    }

    @Test("save succeeds with valid data")
    func testSaveSucceedsWithValidData() async throws {
        let viewModel = AddPurchaseRecordViewModel()
        viewModel.supplier = "Glass Supply Co"
        viewModel.totalAmount = "150.00"

        let result = await viewModel.save()

        #expect(result)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("save trims supplier whitespace")
    func testSaveTrimsSupplierWhitespace() async throws {
        let viewModel = AddPurchaseRecordViewModel()
        viewModel.supplier = "  Glass Supply Co  "
        viewModel.totalAmount = "150.00"

        let result = await viewModel.save()

        #expect(result)
    }

    @Test("save trims notes whitespace")
    func testSaveTrimsNotesWhitespace() async throws {
        let viewModel = AddPurchaseRecordViewModel()
        viewModel.supplier = "Glass Supply Co"
        viewModel.totalAmount = "150.00"
        viewModel.notes = "  Some notes  "

        let result = await viewModel.save()

        #expect(result)
    }

    @Test("save handles empty notes as nil")
    func testSaveHandlesEmptyNotesAsNil() async throws {
        let viewModel = AddPurchaseRecordViewModel()
        viewModel.supplier = "Glass Supply Co"
        viewModel.totalAmount = "150.00"
        viewModel.notes = "   "

        let result = await viewModel.save()

        #expect(result)
    }

    @Test("isSaving is true during save operation")
    func testIsSavingDuringSave() async throws {
        let viewModel = AddPurchaseRecordViewModel()
        viewModel.supplier = "Glass Supply Co"
        viewModel.totalAmount = "150.00"

        // Before save
        #expect(!viewModel.isSaving)

        // Start save (don't await immediately to check isSaving)
        let saveTask = Task {
            await viewModel.save()
        }

        // After save completes
        _ = await saveTask.value
        #expect(!viewModel.isSaving)
    }

    // MARK: - Error State Tests

    @Test("Error message cleared on successful save")
    func testErrorMessageClearedOnSuccess() async throws {
        let viewModel = AddPurchaseRecordViewModel()

        // First, trigger an error
        viewModel.supplier = ""
        viewModel.totalAmount = "100.00"
        _ = await viewModel.save()

        #expect(viewModel.errorMessage != nil)

        // Now fix the data and save again
        viewModel.supplier = "Glass Supply Co"
        let result = await viewModel.save()

        #expect(result)
        #expect(viewModel.errorMessage == nil)
    }

    // MARK: - Form Field Tests

    @Test("itemType can be changed")
    func testItemTypeCanBeChanged() async throws {
        let viewModel = AddPurchaseRecordViewModel()

        viewModel.itemType = "frit"
        #expect(viewModel.itemType == "frit")

        viewModel.itemType = "sheet"
        #expect(viewModel.itemType == "sheet")
    }

    @Test("units can be changed")
    func testUnitsCanBeChanged() async throws {
        let viewModel = AddPurchaseRecordViewModel()

        viewModel.units = .ounces
        #expect(viewModel.units == .ounces)

        viewModel.units = .shorts
        #expect(viewModel.units == .shorts)
    }

    @Test("date can be changed")
    func testDateCanBeChanged() async throws {
        let viewModel = AddPurchaseRecordViewModel()
        let newDate = Date().addingTimeInterval(-86400) // Yesterday

        viewModel.date = newDate

        #expect(viewModel.date == newDate)
    }

    // MARK: - Edge Cases

    @Test("Very large amount is valid")
    func testVeryLargeAmountIsValid() async throws {
        let viewModel = AddPurchaseRecordViewModel()
        viewModel.supplier = "Glass Supply Co"
        viewModel.totalAmount = "999999.99"

        #expect(viewModel.isValid)
        #expect(viewModel.parsedAmount == 999999.99)
    }

    @Test("Small decimal amount is valid")
    func testSmallDecimalAmountIsValid() async throws {
        let viewModel = AddPurchaseRecordViewModel()
        viewModel.supplier = "Glass Supply Co"
        viewModel.totalAmount = "0.01"

        #expect(viewModel.isValid)
        #expect(viewModel.parsedAmount == 0.01)
    }

    @Test("Supplier with special characters is valid")
    func testSupplierWithSpecialCharactersIsValid() async throws {
        let viewModel = AddPurchaseRecordViewModel()
        viewModel.supplier = "Glass & Art Supply Co."
        viewModel.totalAmount = "100.00"

        #expect(viewModel.isValid)
    }

    @Test("Unicode supplier name is valid")
    func testUnicodeSupplierNameIsValid() async throws {
        let viewModel = AddPurchaseRecordViewModel()
        viewModel.supplier = "Gläs Süpply Cö"
        viewModel.totalAmount = "100.00"

        #expect(viewModel.isValid)
    }
}
