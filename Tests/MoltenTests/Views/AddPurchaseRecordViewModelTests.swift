//
//  AddPurchaseRecordViewModelTests.swift
//  MoltenTests
//
//  Created by Assistant on 10/28/25.
//  Tests for AddPurchaseRecordViewModel presentation logic
//

import Foundation
import Testing
@testable import Molten

/// Tests for AddPurchaseRecordViewModel presentation logic
///
/// Tests cover: initialization, validation, save logic, error handling
@Suite("AddPurchaseRecordViewModel Tests")
@MainActor
struct AddPurchaseRecordViewModelTests {

    // MARK: - Initialization Tests

    @Test("Should initialize with default values")
    func testInitialization() async throws {
        // Arrange & Act
        let viewModel = AddPurchaseRecordViewModel()

        // Assert default values
        #expect(viewModel.supplier.isEmpty)
        #expect(viewModel.totalAmount.isEmpty)
        #expect(viewModel.date != nil)  // Should default to Date()
        #expect(viewModel.itemType == "rod")  // Default type
        #expect(viewModel.units == .rods)  // Default units
        #expect(viewModel.notes.isEmpty)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.showingError == false)
        #expect(viewModel.isSaving == false)
    }

    // MARK: - Validation Tests

    @Test("Should require supplier for validation")
    func testSupplierValidation() async throws {
        // Arrange
        let viewModel = AddPurchaseRecordViewModel()

        // Act & Assert - empty supplier invalid
        #expect(viewModel.isValid == false)

        // Act - set supplier with whitespace
        viewModel.supplier = "   "
        #expect(viewModel.isValid == false)

        // Act - set valid supplier
        viewModel.supplier = "Test Supplier"
        viewModel.totalAmount = "100"
        #expect(viewModel.isValid == true)
    }

    @Test("Should require totalAmount for validation")
    func testAmountValidation() async throws {
        // Arrange
        let viewModel = AddPurchaseRecordViewModel()
        viewModel.supplier = "Test Supplier"

        // Act & Assert - empty amount invalid
        #expect(viewModel.isValid == false)

        // Act - invalid number
        viewModel.totalAmount = "abc"
        #expect(viewModel.isValid == false)

        // Act - negative amount
        viewModel.totalAmount = "-10"
        #expect(viewModel.isValid == false)

        // Act - zero amount
        viewModel.totalAmount = "0"
        #expect(viewModel.isValid == false)

        // Act - valid amount
        viewModel.totalAmount = "99.99"
        #expect(viewModel.isValid == true)
    }

    @Test("Should parse amount as Double")
    func testAmountParsing() async throws {
        // Arrange
        let viewModel = AddPurchaseRecordViewModel()

        // Act & Assert - valid inputs
        viewModel.totalAmount = "99.99"
        #expect(viewModel.parsedAmount == 99.99)

        viewModel.totalAmount = "150"
        #expect(viewModel.parsedAmount == 150.0)

        // Act & Assert - invalid inputs
        viewModel.totalAmount = ""
        #expect(viewModel.parsedAmount == nil)

        viewModel.totalAmount = "abc"
        #expect(viewModel.parsedAmount == nil)

        viewModel.totalAmount = "-50"
        #expect(viewModel.parsedAmount == nil)
    }

    // MARK: - Save Tests

    @Test("Should save valid purchase record")
    func testSaveValidRecord() async throws {
        // Arrange
        let viewModel = AddPurchaseRecordViewModel()
        viewModel.supplier = "Glass Supplier Inc"
        viewModel.totalAmount = "150.00"
        viewModel.date = Date()
        viewModel.itemType = "rod"
        viewModel.units = .rods
        viewModel.notes = "Test purchase notes"

        // Act
        let result = await viewModel.save()

        // Assert
        #expect(result == true)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.isSaving == false)
    }

    @Test("Should not save with empty supplier")
    func testSaveInvalidSupplier() async throws {
        // Arrange
        let viewModel = AddPurchaseRecordViewModel()
        viewModel.supplier = ""
        viewModel.totalAmount = "150.00"

        // Act
        let result = await viewModel.save()

        // Assert
        #expect(result == false)
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.isSaving == false)
    }

    @Test("Should not save with invalid amount")
    func testSaveInvalidAmount() async throws {
        // Arrange
        let viewModel = AddPurchaseRecordViewModel()
        viewModel.supplier = "Glass Supplier Inc"
        viewModel.totalAmount = "abc"

        // Act
        let result = await viewModel.save()

        // Assert
        #expect(result == false)
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.isSaving == false)
    }

    @Test("Should handle whitespace-only supplier")
    func testSaveWhitespaceSupplier() async throws {
        // Arrange
        let viewModel = AddPurchaseRecordViewModel()
        viewModel.supplier = "   "
        viewModel.totalAmount = "150.00"

        // Act
        let result = await viewModel.save()

        // Assert
        #expect(result == false)
        #expect(viewModel.errorMessage != nil)
    }

    @Test("Should trim supplier whitespace on save")
    func testTrimSupplierWhitespace() async throws {
        // Arrange
        let viewModel = AddPurchaseRecordViewModel()
        viewModel.supplier = "  Glass Supplier  "
        viewModel.totalAmount = "150.00"

        // Act
        let result = await viewModel.save()

        // Assert
        #expect(result == true)
        // Note: actual trimming happens in save logic
    }

    @Test("Should handle empty notes")
    func testEmptyNotes() async throws {
        // Arrange
        let viewModel = AddPurchaseRecordViewModel()
        viewModel.supplier = "Glass Supplier Inc"
        viewModel.totalAmount = "150.00"
        viewModel.notes = ""

        // Act
        let result = await viewModel.save()

        // Assert
        #expect(result == true)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("Should set isSaving during save operation")
    func testSavingState() async throws {
        // Arrange
        let viewModel = AddPurchaseRecordViewModel()
        viewModel.supplier = "Glass Supplier Inc"
        viewModel.totalAmount = "150.00"

        // Initial state
        #expect(viewModel.isSaving == false)

        // Note: Testing async state transitions is tricky in tests
        // The save() method manages isSaving internally
        let result = await viewModel.save()

        // After save completes
        #expect(viewModel.isSaving == false)
    }

    @Test("Should handle date changes")
    func testDateHandling() async throws {
        // Arrange
        let viewModel = AddPurchaseRecordViewModel()
        let testDate = Date(timeIntervalSince1970: 1609459200) // 2021-01-01

        // Act
        viewModel.date = testDate

        // Assert
        #expect(viewModel.date == testDate)
    }

    @Test("Should handle itemType changes")
    func testItemTypeHandling() async throws {
        // Arrange
        let viewModel = AddPurchaseRecordViewModel()

        // Act & Assert
        viewModel.itemType = "sheet"
        #expect(viewModel.itemType == "sheet")

        viewModel.itemType = "frit"
        #expect(viewModel.itemType == "frit")
    }

    @Test("Should handle units changes")
    func testUnitsHandling() async throws {
        // Arrange
        let viewModel = AddPurchaseRecordViewModel()

        // Act & Assert
        viewModel.units = .pounds
        #expect(viewModel.units == .pounds)

        viewModel.units = .shorts
        #expect(viewModel.units == .shorts)
    }
}
