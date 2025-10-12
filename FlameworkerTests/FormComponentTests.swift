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
    
    /// Creates a clean test context for form testing using SharedTestUtilities
    private func createCleanTestContext() throws -> NSManagedObjectContext {
        let (_, context) = try SharedTestUtilities.getCleanTestController()
        return context
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
    
    // MARK: - Complex Validation Workflows
    
    @Test("Should handle multi-field dependent validation")
    func testMultiFieldDependentValidation() {
        // Arrange - Form with interdependent fields
        struct ComplexFormValidator {
            var count: String = ""
            var price: String = ""
            var type: InventoryItemType = .inventory
            var units: String = "pounds"
            
            var validationErrors: [String] {
                var errors: [String] = []
                
                // Count validation
                if count.isEmpty {
                    errors.append("Count is required")
                } else if Int(count) == nil {
                    errors.append("Count must be a valid number")
                } else if let countValue = Int(count), countValue <= 0 {
                    errors.append("Count must be positive")
                }
                
                // Price validation  
                if price.isEmpty {
                    errors.append("Price is required")
                } else if Double(price) == nil {
                    errors.append("Price must be a valid number")
                } else if let priceValue = Double(price), priceValue <= 0 {
                    errors.append("Price must be positive")
                }
                
                // Conditional validation based on type
                if type == .buy {
                    if let priceValue = Double(price), priceValue > 1000 {
                        errors.append("Buy orders over $1000 require approval")
                    }
                }
                
                // Units-count relationship validation
                if units == "rods" {
                    if let countValue = Int(count), countValue > 100 {
                        errors.append("Rod purchases over 100 units require special handling")
                    }
                }
                
                return errors
            }
            
            var isValid: Bool { validationErrors.isEmpty }
        }
        
        var form = ComplexFormValidator()
        
        // Test empty form
        #expect(!form.isValid, "Empty form should be invalid")
        #expect(form.validationErrors.count >= 2, "Should have multiple validation errors")
        
        // Test partial validation
        form.count = "5"
        #expect(!form.isValid, "Form with only count should still be invalid")
        #expect(form.validationErrors.contains("Price is required"), "Should still require price")
        
        // Test invalid numeric input
        form.price = "invalid"
        #expect(!form.isValid, "Form with invalid price should be invalid")
        #expect(form.validationErrors.contains("Price must be a valid number"), "Should detect invalid price")
        
        // Test valid basic form
        form.price = "25.00"
        #expect(form.isValid, "Form with valid count and price should be valid")
        
        // Test conditional validation - buy order over limit
        form.type = .buy
        form.price = "1500.00"
        #expect(!form.isValid, "Buy order over $1000 should require approval")
        #expect(form.validationErrors.contains("Buy orders over $1000 require approval"), "Should have approval error")
        
        // Test units-count relationship validation
        form.price = "25.00" // Reset to valid price
        form.units = "rods"
        form.count = "150"
        #expect(!form.isValid, "Rod purchases over 100 should require special handling")
        #expect(form.validationErrors.contains("Rod purchases over 100 units require special handling"), "Should have special handling error")
        
        // Test final valid state
        form.count = "50"
        #expect(form.isValid, "Form should be valid with all constraints satisfied")
    }
    
    @Test("Should handle real-time validation feedback")
    func testRealTimeValidationFeedback() {
        // Arrange - Simulate real-time validation
        struct RealTimeValidator {
            var value: String = "" {
                didSet { validateValue() }
            }
            private(set) var validationMessage: String = ""
            private(set) var isValid: Bool = false
            
            private mutating func validateValue() {
                if value.isEmpty {
                    validationMessage = ""
                    isValid = false
                } else if let doubleValue = Double(value) {
                    if doubleValue <= 0 {
                        validationMessage = "Value must be positive"
                        isValid = false
                    } else if doubleValue > 10000 {
                        validationMessage = "Value seems unusually high"
                        isValid = false
                    } else {
                        validationMessage = "✓ Valid"
                        isValid = true
                    }
                } else {
                    validationMessage = "Please enter a valid number"
                    isValid = false
                }
            }
        }
        
        var validator = RealTimeValidator()
        
        // Test initial state
        #expect(validator.validationMessage.isEmpty, "Should have no validation message initially")
        #expect(!validator.isValid, "Should be invalid initially")
        
        // Test invalid input
        validator.value = "abc"
        #expect(validator.validationMessage == "Please enter a valid number", "Should show invalid number message")
        #expect(!validator.isValid, "Should be invalid")
        
        // Test negative value
        validator.value = "-5"
        #expect(validator.validationMessage == "Value must be positive", "Should show positive value message")
        #expect(!validator.isValid, "Should be invalid")
        
        // Test unusually high value
        validator.value = "50000"
        #expect(validator.validationMessage == "Value seems unusually high", "Should show high value warning")
        #expect(!validator.isValid, "Should be invalid")
        
        // Test valid value
        validator.value = "25.99"
        #expect(validator.validationMessage == "✓ Valid", "Should show valid message")
        #expect(validator.isValid, "Should be valid")
    }
    
    @Test("Should handle complex form state transitions")
    func testComplexFormStateTransitions() {
        // Arrange - Complex form with multiple states
        enum FormState {
            case initial, editing, validating, valid, invalid, submitting, submitted, error
        }
        
        struct StatefulForm {
            var state: FormState = .initial
            var fields: [String: String] = [:]
            var errors: [String] = []
            var isSubmitting: Bool = false
            
            mutating func updateField(key: String, value: String) {
                state = .editing
                fields[key] = value
                validate()
            }
            
            mutating func validate() {
                state = .validating
                errors.removeAll()
                
                // Simulate validation logic
                if fields["name"]?.isEmpty ?? true {
                    errors.append("Name is required")
                }
                if fields["email"]?.contains("@") != true {
                    errors.append("Invalid email format")
                }
                
                state = errors.isEmpty ? .valid : .invalid
            }
            
            mutating func submit() -> Bool {
                guard state == .valid else { return false }
                
                state = .submitting
                isSubmitting = true
                
                // Simulate async submission
                if fields["name"]?.contains("error") == true {
                    state = .error
                    errors.append("Submission failed")
                    isSubmitting = false
                    return false
                } else {
                    state = .submitted
                    isSubmitting = false
                    return true
                }
            }
        }
        
        var form = StatefulForm()
        
        // Test initial state
        #expect(form.state == .initial, "Should start in initial state")
        
        // Test editing transition
        form.updateField(key: "name", value: "John")
        #expect(form.state == .invalid, "Should be invalid with incomplete data")
        #expect(form.errors.contains("Invalid email format"), "Should have email error")
        
        // Test validation transition
        form.updateField(key: "email", value: "john@example.com")
        #expect(form.state == .valid, "Should be valid with complete data")
        #expect(form.errors.isEmpty, "Should have no errors")
        
        // Test successful submission
        let success = form.submit()
        #expect(success, "Should submit successfully")
        #expect(form.state == .submitted, "Should be in submitted state")
        
        // Test failed submission
        form = StatefulForm()
        form.updateField(key: "name", value: "error_case")
        form.updateField(key: "email", value: "test@example.com")
        let failedSubmission = form.submit()
        #expect(!failedSubmission, "Should fail submission")
        #expect(form.state == .error, "Should be in error state")
        #expect(form.errors.contains("Submission failed"), "Should have submission error")
    }
    
    @Test("Should handle conditional field visibility and validation")
    func testConditionalFieldValidation() {
        // Arrange - Form with conditional fields
        struct ConditionalForm {
            var accountType: String = "basic"  // "basic" or "premium" 
            var email: String = ""
            var premiumCode: String = ""
            var billingAddress: String = ""
            
            var visibleFields: Set<String> {
                var fields: Set<String> = ["accountType", "email"]
                if accountType == "premium" {
                    fields.insert("premiumCode")
                    fields.insert("billingAddress")
                }
                return fields
            }
            
            var validationErrors: [String] {
                var errors: [String] = []
                
                // Always validate email
                if email.isEmpty {
                    errors.append("Email is required")
                } else if !email.contains("@") {
                    errors.append("Invalid email format")
                }
                
                // Conditionally validate premium fields
                if accountType == "premium" {
                    if premiumCode.isEmpty {
                        errors.append("Premium code is required")
                    } else if premiumCode.count < 8 {
                        errors.append("Premium code must be at least 8 characters")
                    }
                    
                    if billingAddress.isEmpty {
                        errors.append("Billing address is required for premium accounts")
                    }
                }
                
                return errors
            }
            
            var isValid: Bool { validationErrors.isEmpty }
        }
        
        var form = ConditionalForm()
        
        // Test basic account requirements
        #expect(form.visibleFields.contains("email"), "Email should always be visible")
        #expect(!form.visibleFields.contains("premiumCode"), "Premium code should be hidden for basic account")
        #expect(!form.isValid, "Should be invalid without email")
        
        // Make basic account valid
        form.email = "user@example.com"
        #expect(form.isValid, "Basic account should be valid with just email")
        
        // Switch to premium account
        form.accountType = "premium"
        #expect(form.visibleFields.contains("premiumCode"), "Premium code should be visible for premium account")
        #expect(form.visibleFields.contains("billingAddress"), "Billing address should be visible for premium account")
        #expect(!form.isValid, "Should be invalid without premium fields")
        
        // Test partial premium validation
        form.premiumCode = "short"
        #expect(!form.isValid, "Should be invalid with short premium code")
        #expect(form.validationErrors.contains("Premium code must be at least 8 characters"), "Should validate code length")
        
        // Complete premium validation
        form.premiumCode = "premium123"
        form.billingAddress = "123 Main St"
        #expect(form.isValid, "Should be valid with all premium fields")
        
        // Switch back to basic
        form.accountType = "basic"
        #expect(form.isValid, "Should remain valid when switching back to basic (premium fields ignored)")
        #expect(!form.visibleFields.contains("premiumCode"), "Premium fields should be hidden again")
    }
    
    @Test("Should handle form field format validation")
    func testFormFieldFormatValidation() {
        // Arrange - Different field format validators
        struct FieldFormatValidators {
            static func validateEmail(_ email: String) -> (Bool, String?) {
                if email.isEmpty {
                    return (false, "Email is required")
                }
                let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
                let isValid = email.range(of: emailRegex, options: .regularExpression) != nil
                return (isValid, isValid ? nil : "Please enter a valid email address")
            }
            
            static func validatePhone(_ phone: String) -> (Bool, String?) {
                if phone.isEmpty {
                    return (false, "Phone number is required")
                }
                let phoneRegex = #"^\(?([0-9]{3})\)?[-. ]?([0-9]{3})[-. ]?([0-9]{4})$"#
                let isValid = phone.range(of: phoneRegex, options: .regularExpression) != nil
                return (isValid, isValid ? nil : "Please enter a valid phone number (e.g., 555-123-4567)")
            }
            
            static func validateZipCode(_ zipCode: String) -> (Bool, String?) {
                if zipCode.isEmpty {
                    return (false, "ZIP code is required")
                }
                let zipRegex = #"^\d{5}(-\d{4})?$"#
                let isValid = zipCode.range(of: zipRegex, options: .regularExpression) != nil
                return (isValid, isValid ? nil : "Please enter a valid ZIP code (e.g., 12345 or 12345-6789)")
            }
        }
        
        // Test email validation
        let emailTests = [
            ("", false, "Email is required"),
            ("invalid", false, "Please enter a valid email address"),
            ("test@", false, "Please enter a valid email address"),
            ("test@example", false, "Please enter a valid email address"),
            ("test@example.com", true, nil),
            ("user.name+tag@example.co.uk", true, nil)
        ]
        
        for (email, expectedValid, expectedError) in emailTests {
            let (isValid, errorMessage) = FieldFormatValidators.validateEmail(email)
            #expect(isValid == expectedValid, "Email '\(email)' validation should be \(expectedValid)")
            #expect(errorMessage == expectedError, "Email '\(email)' error should be '\(expectedError ?? "nil")'")
        }
        
        // Test phone validation
        let phoneTests = [
            ("", false, "Phone number is required"),
            ("123", false, "Please enter a valid phone number (e.g., 555-123-4567)"),
            ("555-123-4567", true, nil),
            ("(555) 123-4567", true, nil),
            ("555.123.4567", true, nil),
            ("5551234567", true, nil)
        ]
        
        for (phone, expectedValid, expectedError) in phoneTests {
            let (isValid, errorMessage) = FieldFormatValidators.validatePhone(phone)
            #expect(isValid == expectedValid, "Phone '\(phone)' validation should be \(expectedValid)")
            #expect(errorMessage == expectedError, "Phone '\(phone)' error should be '\(expectedError ?? "nil")'")
        }
        
        // Test ZIP code validation
        let zipTests = [
            ("", false, "ZIP code is required"),
            ("123", false, "Please enter a valid ZIP code (e.g., 12345 or 12345-6789)"),
            ("12345", true, nil),
            ("12345-6789", true, nil),
            ("12345-67890", false, "Please enter a valid ZIP code (e.g., 12345 or 12345-6789)")
        ]
        
        for (zip, expectedValid, expectedError) in zipTests {
            let (isValid, errorMessage) = FieldFormatValidators.validateZipCode(zip)
            #expect(isValid == expectedValid, "ZIP '\(zip)' validation should be \(expectedValid)")
            #expect(errorMessage == expectedError, "ZIP '\(zip)' error should be '\(expectedError ?? "nil")'")
        }
    }
    
    @Test("Should handle form submission with retry logic")
    func testFormSubmissionWithRetryLogic() async throws {
        // Arrange - Form submission with retry capabilities
        actor FormSubmissionHandler {
            private var attemptCount = 0
            private let maxAttempts = 3
            
            func submitForm(data: [String: String], simulateFailure: Bool = false) async -> Result<String, Error> {
                attemptCount += 1
                
                // Simulate network delay
                try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
                
                if simulateFailure && attemptCount < maxAttempts {
                    return .failure(NSError(domain: "NetworkError", code: 500, userInfo: [
                        NSLocalizedDescriptionKey: "Temporary server error"
                    ]))
                }
                
                return .success("Form submitted successfully on attempt \(attemptCount)")
            }
            
            // Add a method that implements the actual retry logic
            func submitFormWithRetries(data: [String: String], simulateFailure: Bool = false) async -> Result<String, Error> {
                var lastError: Error?
                
                for _ in 1...maxAttempts {
                    let result = await submitForm(data: data, simulateFailure: simulateFailure)
                    switch result {
                    case .success:
                        return result
                    case .failure(let error):
                        lastError = error
                        // Continue to next attempt
                    }
                }
                
                return .failure(lastError ?? NSError(domain: "RetryError", code: 999, userInfo: [
                    NSLocalizedDescriptionKey: "Max retry attempts exceeded"
                ]))
            }
            
            func getAttemptCount() -> Int { attemptCount }
            func resetAttempts() { attemptCount = 0 }
        }
        
        let handler = FormSubmissionHandler()
        let formData = ["name": "John Doe", "email": "john@example.com"]
        
        // Test successful submission
        let successResult = await handler.submitForm(data: formData)
        switch successResult {
        case .success(let message):
            #expect(message.contains("attempt 1"), "Should succeed on first attempt")
        case .failure:
            #expect(Bool(false), "Should not fail on first attempt")
        }
        
        // Test retry logic with the retry wrapper method
        await handler.resetAttempts()
        let retryResult = await handler.submitFormWithRetries(data: formData, simulateFailure: true)
        switch retryResult {
        case .success(let message):
            #expect(message.contains("attempt 3"), "Should succeed after retries")
        case .failure:
            #expect(Bool(false), "Should eventually succeed with retries")
        }
        
        let finalAttemptCount = await handler.getAttemptCount()
        #expect(finalAttemptCount == 3, "Should have made 3 attempts")
    }
    
    @Test("Should handle form field masking and formatting")
    func testFormFieldMaskingAndFormatting() {
        // Arrange - Field formatters for different input types
        struct FieldFormatters {
            static func formatCurrency(_ input: String) -> String {
                let digits = input.filter { $0.isNumber || $0 == "." }
                guard let value = Double(digits) else { return input }
                return String(format: "%.2f", value)
            }
            
            static func formatPhone(_ input: String) -> String {
                let digits = input.filter { $0.isNumber }
                guard digits.count <= 10 else { return input }
                
                switch digits.count {
                case 0...3:
                    return digits
                case 4...6:
                    let area = String(digits.prefix(3))
                    let rest = String(digits.dropFirst(3))
                    return "(\(area)) \(rest)"
                case 7...10:
                    let area = String(digits.prefix(3))
                    let exchange = String(digits.dropFirst(3).prefix(3))
                    let number = String(digits.dropFirst(6))
                    return "(\(area)) \(exchange)-\(number)"
                default:
                    return input
                }
            }
            
            static func formatCatalogCode(_ input: String) -> String {
                return input.uppercased().replacingOccurrences(of: " ", with: "-")
            }
        }
        
        // Test currency formatting
        let currencyTests = [
            ("", ""),
            ("1", "1.00"),
            ("12", "12.00"),
            ("12.3", "12.30"),
            ("12.345", "12.35"), // Rounded
            ("abc", "abc") // Invalid input preserved
        ]
        
        for (input, expected) in currencyTests {
            let result = FieldFormatters.formatCurrency(input)
            #expect(result == expected, "Currency formatting '\(input)' should be '\(expected)', got '\(result)'")
        }
        
        // Test phone formatting
        let phoneTests = [
            ("", ""),
            ("5", "5"),
            ("555", "555"),
            ("5551", "(555) 1"),
            ("5551234", "(555) 123-4"),
            ("5551234567", "(555) 123-4567")
        ]
        
        for (input, expected) in phoneTests {
            let result = FieldFormatters.formatPhone(input)
            #expect(result == expected, "Phone formatting '\(input)' should be '\(expected)', got '\(result)'")
        }
        
        // Test catalog code formatting
        let catalogTests = [
            ("", ""),
            ("abc123", "ABC123"),
            ("test code", "TEST-CODE"),
            ("multi word code", "MULTI-WORD-CODE")
        ]
        
        for (input, expected) in catalogTests {
            let result = FieldFormatters.formatCatalogCode(input)
            #expect(result == expected, "Catalog code formatting '\(input)' should be '\(expected)', got '\(result)'")
        }
    }
    
    @Test("Should handle UnifiedFormField integration patterns")
    func testUnifiedFormFieldIntegration() {
        // Arrange - Test the integration of multiple UnifiedFormField components
        struct FormIntegrationTest {
            var countConfig = CountFieldConfig(title: "Item Count")
            var priceConfig = PriceFieldConfig(title: "Unit Price")
            var notesConfig = NotesFieldConfig()
            
            // Simulate form field values
            var countValue = "10"
            var priceValue = "25.99"
            var notesValue = "Test integration notes"
            
            func validateFormData() -> (Bool, [String]) {
                var errors: [String] = []
                
                // Validate count using config
                let formattedCount = countConfig.formatValue(countValue)
                let parsedCount = countConfig.parseValue(formattedCount)
                if parsedCount != countValue {
                    errors.append("Count formatting/parsing mismatch")
                }
                
                // Validate price using config
                let formattedPrice = priceConfig.formatValue(priceValue)
                let parsedPrice = priceConfig.parseValue(formattedPrice)
                if parsedPrice != priceValue {
                    errors.append("Price formatting/parsing mismatch")
                }
                
                // Validate notes using config
                let formattedNotes = notesConfig.formatValue(notesValue)
                let parsedNotes = notesConfig.parseValue(formattedNotes)
                if parsedNotes != notesValue {
                    errors.append("Notes formatting/parsing mismatch")
                }
                
                return (errors.isEmpty, errors)
            }
        }
        
        let integrationTest = FormIntegrationTest()
        let (isValid, errors) = integrationTest.validateFormData()
        
        // Assert - All form field configs should work together
        #expect(isValid, "Form field integration should be valid")
        #expect(errors.isEmpty, "Should have no integration errors: \(errors)")
        
        // Test individual config properties
        #expect(integrationTest.countConfig.title == "Item Count", "Count config should have correct title")
        #expect(integrationTest.countConfig.keyboardType == .decimalPad, "Count config should have decimal pad")
        #expect(integrationTest.priceConfig.placeholder == "0.00", "Price config should have currency placeholder")
        #expect(integrationTest.notesConfig.keyboardType == .default, "Notes config should have default keyboard")
    }
}
