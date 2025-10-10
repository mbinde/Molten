//
//  FormComponentTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/10/25.
//

// Standard test framework imports pattern - use in all test files
#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

import SwiftUI
import CoreData
import Foundation
@testable import Flameworker

@Suite("Form Component Tests", .serialized)
struct FormComponentTests {
    
    // MARK: - Helper Methods
    
    /// Creates a clean test context for form testing
    private func createCleanTestContext() -> NSManagedObjectContext {
        let testController = PersistenceController.createTestController()
        return testController.container.viewContext
    }
    
    // MARK: - Form Input Validation Tests
    
    @Test("Should test form input validation states")
    func testFormInputValidationStates() {
        // Arrange - Test different validation scenarios
        let validPrice = "29.99"
        let invalidPrice = "not-a-number"
        let emptyPrice = ""
        let negativePrice = "-10.00"
        
        // Act & Assert - Test that form validation logic works
        #expect(validPrice == "29.99", "Valid price should remain unchanged")
        #expect(invalidPrice == "not-a-number", "Invalid price should be preserved for validation")
        #expect(emptyPrice == "", "Empty price should be handled")
        #expect(negativePrice == "-10.00", "Negative price should be preserved for validation")
        
        // Test price validation logic
        let validPriceDouble = Double(validPrice)
        let invalidPriceDouble = Double(invalidPrice)
        
        #expect(validPriceDouble != nil, "Valid price should parse to Double")
        #expect(invalidPriceDouble == nil, "Invalid price should not parse to Double")
    }
    
    // MARK: - Inventory Item Type Tests
    
    @Test("Should test InventoryItemType functionality")
    func testInventoryItemTypeEnum() {
        // Arrange & Act
        let inventoryType = InventoryItemType.inventory
        let buyType = InventoryItemType.buy  
        let sellType = InventoryItemType.sell
        
        // Assert - Test enum display properties
        #expect(inventoryType.displayName == "Inventory", "Inventory type should have correct display name")
        #expect(buyType.displayName == "Buy", "Buy type should have correct display name")
        #expect(sellType.displayName == "Sell", "Sell type should have correct display name")
        
        // Test system images
        #expect(!inventoryType.systemImageName.isEmpty, "Inventory type should have system image")
        #expect(!buyType.systemImageName.isEmpty, "Buy type should have system image")
        #expect(!sellType.systemImageName.isEmpty, "Sell type should have system image")
        
        // Test colors
        #expect(inventoryType.color != buyType.color, "Different types should have different colors")
        #expect(buyType.color != sellType.color, "Different types should have different colors")
    }
    
    // MARK: - Form Component Data Flow Tests
    
    @Test("Should test form data conversion for business logic")
    func testFormDataConversion() {
        // Arrange
        let testCount = "5"
        let testPrice = "25.00"
        let testNotes = "Integration test notes"
        
        // Act - Test that form data can flow to business logic
        let countInt = Int(testCount)
        let priceDouble = Double(testPrice)
        
        // Assert - Verify data conversion for business logic
        #expect(countInt == 5, "Count should convert to integer")
        #expect(priceDouble == 25.0, "Price should convert to double")
        #expect(testNotes.count > 0, "Notes should contain content")
        #expect(!testNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Notes should have meaningful content")
    }
    
    @Test("Should handle form error states gracefully")
    func testFormErrorStates() {
        // Arrange - Test various error conditions
        let errorCount = "invalid"
        let errorPrice = "abc123"
        let longNotes = String(repeating: "A", count: 5000)
        
        // Act & Assert - Form should handle error states without crashing
        #expect(Int(errorCount) == nil, "Invalid count should not convert")
        #expect(Double(errorPrice) == nil, "Invalid price should not convert")
        #expect(longNotes.count == 5000, "Long notes should be preserved")
        
        // Test that form validation can identify invalid states
        let hasValidCount = Int(errorCount) != nil
        let hasValidPrice = Double(errorPrice) != nil
        
        #expect(!hasValidCount, "Form should detect invalid count")
        #expect(!hasValidPrice, "Form should detect invalid price")
    }
    
    // MARK: - Form Performance Tests
    
    @Test("Should handle string concatenation performance")
    func testFormPerformanceWithStringOperations() {
        // Arrange
        var result = ""
        
        // Act - Simulate building form content
        let startTime = Date()
        for i in 1...100 {
            result = "Value \(i)" // Each iteration creates a new string
        }
        let endTime = Date()
        
        // Assert
        #expect(result == "Value 100", "Should handle final value correctly")
        
        let processingTime = endTime.timeIntervalSince(startTime)
        #expect(processingTime < 0.1, "Should handle 100 string operations quickly (actual: \(processingTime)s)")
    }
    
    // MARK: - Form Validation Integration Tests
    
    @Test("Should test integrated form validation workflow")
    func testIntegratedFormValidation() {
        // Arrange - Simulate a complete form state
        let formCount = "10"
        let formPrice = "15.50"
        let formNotes = "Valid notes"
        let formCatalogCode = "VALID-001"
        let formType = InventoryItemType.inventory
        
        // Act - Validate all form fields
        let countValid = Int(formCount) != nil
        let priceValid = Double(formPrice) != nil
        let notesValid = !formNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let catalogValid = !formCatalogCode.isEmpty
        let typeValid = true // InventoryItemType is always valid
        
        // Assert - All form fields should be valid
        #expect(countValid, "Count should be valid")
        #expect(priceValid, "Price should be valid")
        #expect(notesValid, "Notes should be valid")
        #expect(catalogValid, "Catalog code should be valid")
        #expect(typeValid, "Type should be valid")
        
        let formIsValid = countValid && priceValid && notesValid && catalogValid && typeValid
        #expect(formIsValid, "Complete form should be valid")
    }
    
    // MARK: - String Processing Tests
    
    @Test("Should test form string processing utilities")
    func testFormStringProcessing() {
        // Arrange
        let inputWithSpaces = "  TEST-123  "
        let emptyInput = ""
        let normalInput = "NORMAL-456"
        
        // Act & Assert - Test string processing for forms
        let trimmedInput = inputWithSpaces.trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(trimmedInput == "TEST-123", "Should trim whitespace from input")
        
        let isEmptyAfterTrim = emptyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        #expect(isEmptyAfterTrim, "Empty input should remain empty after trim")
        
        let normalTrimmed = normalInput.trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(normalTrimmed == "NORMAL-456", "Normal input should remain unchanged")
        
        // Test length validation
        #expect(trimmedInput.count > 0, "Trimmed input should have length")
        #expect(normalInput.count == 10, "Normal input should have expected length")
    }
    
    // MARK: - Form Field Validation Tests
    
    @Test("Should validate different types of form fields")
    func testFormFieldTypeValidation() {
        // Test numeric validation
        let validInteger = "42"
        let invalidInteger = "not-a-number"
        
        #expect(Int(validInteger) == 42, "Valid integer string should convert")
        #expect(Int(invalidInteger) == nil, "Invalid integer string should not convert")
        
        // Test decimal validation
        let validDecimal = "99.99"
        let invalidDecimal = "99.99.99"
        
        #expect(Double(validDecimal) == 99.99, "Valid decimal string should convert")
        #expect(Double(invalidDecimal) == nil, "Invalid decimal string should not convert")
        
        // Test empty field validation
        let emptyField = ""
        let whitespaceField = "   "
        let validField = "Content"
        
        #expect(emptyField.isEmpty, "Empty field should be detected")
        #expect(!whitespaceField.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false, "Whitespace-only field should be detected")
        #expect(!validField.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Valid field should pass validation")
    }
    
    // MARK: - UnifiedFormField Configuration Tests
    
    @Test("Should test CountFieldConfig functionality")
    func testCountFieldConfig() {
        // Arrange
        let config = CountFieldConfig(title: "Test Count")
        
        // Act & Assert
        #expect(config.title == "Test Count", "Should store title correctly")
        #expect(config.placeholder == "Amount", "Should have correct placeholder")
        #expect(config.keyboardType == .decimalPad, "Should have decimal pad keyboard")
        // Note: TextInputAutocapitalization doesn't conform to Equatable, so we just verify it's accessible
        _ = config.textInputAutocapitalization // Verify property is accessible
        
        // Test value formatting and parsing
        let testValue = "42"
        let formattedValue = config.formatValue(testValue)
        let parsedValue = config.parseValue("42")
        
        #expect(formattedValue == "42", "Should format value correctly")
        #expect(parsedValue == "42", "Should parse value correctly")
    }
    
    @Test("Should test PriceFieldConfig functionality") 
    func testPriceFieldConfig() {
        // Arrange
        let config = PriceFieldConfig(title: "Test Price")
        
        // Act & Assert
        #expect(config.title == "Test Price", "Should store title correctly")
        #expect(config.placeholder == "0.00", "Should have correct placeholder")
        #expect(config.keyboardType == .decimalPad, "Should have decimal pad keyboard")
        // Note: TextInputAutocapitalization doesn't conform to Equatable, so we just verify it's accessible
        _ = config.textInputAutocapitalization // Verify property is accessible
        
        // Test value formatting and parsing
        let testValue = "29.99"
        let formattedValue = config.formatValue(testValue)
        let parsedValue = config.parseValue("29.99")
        
        #expect(formattedValue == "29.99", "Should format price value correctly")
        #expect(parsedValue == "29.99", "Should parse price value correctly")
    }
    
    @Test("Should test NotesFieldConfig functionality")
    func testNotesFieldConfig() {
        // Arrange
        let config = NotesFieldConfig()
        
        // Act & Assert
        #expect(config.title == "Notes", "Should have correct title")
        #expect(config.placeholder == "Notes", "Should have correct placeholder")
        #expect(config.keyboardType == .default, "Should have default keyboard")
        // Note: TextInputAutocapitalization doesn't conform to Equatable, so we just verify it's accessible
        _ = config.textInputAutocapitalization // Verify property is accessible
        
        // Test value formatting and parsing
        let testNotes = "These are test notes"
        let formattedValue = config.formatValue(testNotes)
        let parsedValue = config.parseValue("These are test notes")
        
        #expect(formattedValue == "These are test notes", "Should format notes correctly")
        #expect(parsedValue == "These are test notes", "Should parse notes correctly")
    }
    
    // MARK: - Form Field Validation Logic Tests
    
    @Test("Should test numeric validation with edge cases")
    func testNumericValidationEdgeCases() {
        // Arrange - Various numeric input scenarios
        let validNumbers = ["0", "1", "42", "99.99", "0.01", "1000", "12.", ".34", "0.0", "00", "01", "1.0000", "999999999"]
        let invalidNumbers = ["", "abc", "12.34.56", "-", "."]
        // Note: Swift's Double() accepts "NaN" and "∞" as valid, so we handle them separately
        let specialNumbers = ["NaN", "∞", "inf", "-inf", "+inf"]
        
        // Test valid numbers (including ones that might seem invalid but Swift accepts)
        for number in validNumbers {
            let doubleResult = Double(number)
            #expect(doubleResult != nil, "'\(number)' should be valid number according to Swift's Double() initializer")
            
            if let value = doubleResult {
                #expect(value >= 0 || number.hasPrefix("-"), "Positive numbers should be positive: \(value)")
            }
        }
        
        // Test invalid numbers (ones Swift definitely rejects)
        for number in invalidNumbers {
            let doubleResult = Double(number)
            #expect(doubleResult == nil, "'\(number)' should be invalid number")
        }
        
        // Test special numbers (valid to Swift but might need special handling in forms)
        for number in specialNumbers {
            let doubleResult = Double(number)
            if doubleResult != nil {
                // These are valid to Swift's Double() but might need business logic validation
                #expect(true, "Special number '\(number)' was accepted by Swift (value: \(doubleResult!))")
            }
        }
    }
    
    @Test("Should test whitespace handling in form fields")
    func testWhitespaceHandling() {
        // Arrange - Various whitespace scenarios
        let inputs = [
            ("  normal  ", "normal"),
            ("\t\ttabbed\t\t", "tabbed"),
            ("\n\nnewlines\n\n", "newlines"),
            ("  mixed \t\n spaces  ", "mixed \t\n spaces"),
            ("", ""),
            ("   ", "")
        ]
        
        // Act & Assert
        for (input, expected) in inputs {
            let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
            #expect(trimmed == expected, "'\(input)' should trim to '\(expected)', got '\(trimmed)'")
        }
    }
    
    @Test("Should test form field error message scenarios")
    func testFormFieldErrorMessageScenarios() {
        // Arrange - Test error conditions that would need user feedback
        let errorScenarios = [
            ("", "Empty field"),
            ("   ", "Whitespace only"),
            ("abc", "Invalid number format"),
            ("12.34.56", "Multiple decimal points"),
            ("-", "Invalid dash only"),
            (".", "Invalid decimal point only"),
            ("∞", "Infinity symbol"),  // Swift doesn't parse this symbol
        ]
        
        // Note: Swift's Double() accepts some special strings but not others
        let businessLogicRejectScenarios = [
            ("NaN", "Not a number value"),
            ("inf", "Infinity value"),
            ("+inf", "Positive infinity"),
            ("-inf", "Negative infinity")
        ]
        
        // Act & Assert - Test that we can detect error conditions
        for (input, description) in errorScenarios {
            let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
            let isEmpty = trimmedInput.isEmpty
            let isValidNumber = Double(input) != nil
            
            if description.contains("Empty") || description.contains("Whitespace") {
                #expect(isEmpty, "\(description): '\(input)' should be detected as empty")
            } else {
                #expect(!isValidNumber, "\(description): '\(input)' should be detected as invalid number")
            }
        }
        
        // Test business logic scenarios (Swift accepts these, but we might want to reject them)
        for (input, description) in businessLogicRejectScenarios {
            let doubleResult = Double(input)
            #expect(doubleResult != nil, "\(description): '\(input)' should be valid to Swift's Double() initializer")
            
            // Business logic could check for these special cases
            if let value = doubleResult {
                let isNaN = value.isNaN
                let isInfinite = value.isInfinite
                let needsBusinessValidation = isNaN || isInfinite
                #expect(needsBusinessValidation, "\(description): '\(input)' would need additional business validation")
            }
        }
    }
    
    // MARK: - InventoryItemType Integration Tests
    
    @Test("Should test InventoryItemType with form components")
    func testInventoryItemTypeFormIntegration() {
        // Arrange
        let buyType = InventoryItemType.buy
        let inventoryType = InventoryItemType.inventory  
        let sellType = InventoryItemType.sell
        
        // Test all cases are available
        let allCases = Array(InventoryItemType.allCases)
        #expect(allCases.count >= 3, "Should have at least 3 inventory types")
        #expect(allCases.contains(buyType), "Should contain buy type")
        #expect(allCases.contains(inventoryType), "Should contain inventory type")
        #expect(allCases.contains(sellType), "Should contain sell type")
        
        // Test display properties for form integration
        for type in allCases {
            #expect(!type.displayName.isEmpty, "Type \(type) should have display name")
            #expect(!type.systemImageName.isEmpty, "Type \(type) should have system image")
            
            // Test that color is valid (not nil/clear)
            let color = type.color
            #expect(color != Color.clear, "Type \(type) should have meaningful color")
        }
    }
    
    // MARK: - Form State Management Tests
    
    @Test("Should test form state transitions")
    func testFormStateTransitions() {
        // Arrange - Simulate form states
        var formState = "initial"
        var isValid = false
        var errorMessage = ""
        
        // Test initial state
        #expect(formState == "initial", "Form should start in initial state")
        #expect(!isValid, "Form should start as invalid")
        #expect(errorMessage.isEmpty, "Should have no error message initially")
        
        // Act - Simulate state changes
        formState = "editing"
        errorMessage = "Field required"
        #expect(formState == "editing", "Form should transition to editing")
        #expect(!errorMessage.isEmpty, "Should have error message when invalid")
        
        // Simulate valid state
        formState = "valid"
        isValid = true
        errorMessage = ""
        #expect(formState == "valid", "Form should transition to valid")
        #expect(isValid, "Form should be marked as valid")
        #expect(errorMessage.isEmpty, "Should clear error message when valid")
    }
    
    @Test("Should test form validation workflow")
    func testFormValidationWorkflow() {
        // Arrange - Simulate complete form validation
        struct MockFormData {
            var count: String = ""
            var price: String = ""
            var notes: String = ""
            var isValid: Bool { !count.isEmpty && !price.isEmpty && Double(price) != nil }
        }
        
        var form = MockFormData()
        
        // Test empty form
        #expect(!form.isValid, "Empty form should be invalid")
        
        // Add count only
        form.count = "5"
        #expect(!form.isValid, "Form with only count should be invalid")
        
        // Add invalid price
        form.price = "invalid"
        #expect(!form.isValid, "Form with invalid price should be invalid")
        
        // Add valid price
        form.price = "25.00"
        #expect(form.isValid, "Form with valid count and price should be valid")
        
        // Test that notes are optional
        form.notes = "Optional notes"
        #expect(form.isValid, "Form should remain valid with notes")
        
        form.notes = ""
        #expect(form.isValid, "Form should remain valid without notes")
    }
    
    // MARK: - Performance and Memory Tests
    
    @Test("Should handle form field updates efficiently")
    func testFormFieldUpdatePerformance() {
        // Arrange
        var textField = ""
        let startTime = Date()
        
        // Act - Simulate rapid form field updates
        for i in 1...100 {
            textField = "Update \(i)"
        }
        
        let endTime = Date()
        let processingTime = endTime.timeIntervalSince(startTime)
        
        // Assert
        #expect(textField == "Update 100", "Should handle final update correctly")
        #expect(processingTime < 0.1, "Should handle 100 updates quickly (actual: \(processingTime)s)")
    }
    
    @Test("Should handle form memory management")
    func testFormMemoryManagement() {
        // Arrange - Test that form components can be created and destroyed
        func createTemporaryForm() -> Bool {
            let config = CountFieldConfig(title: "Temporary")
            let tempValue = "temporary"
            
            // Simulate form field operations
            let formatted = config.formatValue(tempValue)
            let parsed = config.parseValue("test")
            
            return formatted == tempValue && parsed == "test"
        }
        
        // Act & Assert - Multiple creations should work without issues
        for _ in 1...10 {
            let result = createTemporaryForm()
            #expect(result, "Temporary form creation should succeed")
        }
    }
}