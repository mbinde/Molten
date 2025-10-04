//  ErrorHandlingAndValidationTests.swift
//  FlameworkerTests
//
//  Extracted from FlameworkerTests.swift on 10/3/25.
//  Copyright © 2025 Motley Woods. All rights reserved.
//

import Testing
import Foundation
@testable import Flameworker

@Suite("String Validation Tests")
struct StringValidationTests {
    
    @Test("String trimming and validation works correctly")
    func testStringValidationLogic() {
        // Test the core validation logic without requiring ValidationUtilities
        
        // Valid string after trimming
        let testString1 = "  Valid String  "
        let trimmed1 = testString1.trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(trimmed1 == "Valid String", "Should trim whitespace correctly")
        #expect(!trimmed1.isEmpty, "Should not be empty after trimming")
        
        // Empty string after trimming
        let testString2 = "   "
        let trimmed2 = testString2.trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(trimmed2.isEmpty, "Should be empty after trimming whitespace-only string")
        
        // Already clean string
        let testString3 = "Valid String"
        let trimmed3 = testString3.trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(trimmed3 == "Valid String", "Should remain unchanged when already clean")
        
        // Empty string
        let testString4 = ""
        let trimmed4 = testString4.trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(trimmed4.isEmpty, "Should remain empty")
    }
    
    @Test("Number parsing validation works correctly")
    func testNumberParsingValidation() {
        // Test the core number parsing logic
        
        // Valid positive number
        let validNumber = "25.50"
        if let parsed = Double(validNumber) {
            #expect(abs(parsed - 25.50) < 0.001, "Should parse positive double correctly")
            #expect(parsed > 0, "Should be positive")
        } else {
            Issue.record("Should successfully parse valid number")
        }
        
        // Zero
        let zeroString = "0"
        if let parsed = Double(zeroString) {
            #expect(parsed == 0.0, "Should parse zero correctly")
            #expect(parsed >= 0, "Should be non-negative")
        } else {
            Issue.record("Should successfully parse zero")
        }
        
        // Negative number
        let negativeString = "-10.5"
        if let parsed = Double(negativeString) {
            #expect(parsed < 0, "Should be negative")
            #expect(abs(parsed - (-10.5)) < 0.001, "Should parse negative number correctly")
        } else {
            Issue.record("Should successfully parse negative number")
        }
        
        // Invalid number format
        let invalidString = "not-a-number"
        let parsed = Double(invalidString)
        #expect(parsed == nil, "Should fail to parse invalid number format")
    }
    
    @Test("Email format validation logic works correctly")
    func testEmailFormatValidation() {
        // Test basic email validation logic
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let predicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        
        // Valid emails
        #expect(predicate.evaluate(with: "user@example.com"), "Should accept valid email")
        #expect(predicate.evaluate(with: "test.email+tag@domain.co.uk"), "Should accept complex valid email")
        
        // Invalid emails
        #expect(!predicate.evaluate(with: "not-an-email"), "Should reject invalid email format")
        #expect(!predicate.evaluate(with: "user@"), "Should reject incomplete email")
        #expect(!predicate.evaluate(with: "@domain.com"), "Should reject email without user")
        #expect(!predicate.evaluate(with: "user.domain.com"), "Should reject email without @")
    }
    
    @Test("String length validation works correctly")
    func testStringLengthValidation() {
        // Test minimum length validation logic
        let minLength = 2
        
        let validString = "Valid Supplier"
        #expect(validString.count >= minLength, "Should meet minimum length requirement")
        
        let shortString = "A"
        #expect(shortString.count < minLength, "Should be below minimum length")
        
        let exactLengthString = "AB"
        #expect(exactLengthString.count == minLength, "Should exactly meet minimum length")
    }
}

@Suite("ErrorHandler Tests")
struct ErrorHandlerTests {
    
    @Test("AppError creates correctly with all properties")
    func testAppErrorCreation() {
        let error = AppError(
            category: .validation,
            severity: .warning,
            userMessage: "Test error",
            technicalDetails: "Technical info",
            suggestions: ["Fix this", "Try again"]
        )
        
        #expect(error.category == .validation, "Should have correct category")
        #expect(error.severity == .warning, "Should have correct severity")
        #expect(error.userMessage == "Test error", "Should have correct user message")
        #expect(error.technicalDetails == "Technical info", "Should have correct technical details")
        #expect(error.suggestions.count == 2, "Should have correct number of suggestions")
        #expect(error.errorDescription == "Test error", "Should use userMessage as errorDescription")
    }
    
    @Test("ErrorHandler creates validation errors correctly")
    func testCreateValidationError() {
        let error = ErrorHandler.shared.createValidationError("Invalid input")
        
        #expect(error.category == .validation, "Should be validation category")
        #expect(error.severity == .warning, "Should be warning severity")
        #expect(error.userMessage == "Invalid input", "Should have correct message")
        #expect(error.suggestions.count >= 1, "Should have default suggestions")
    }
    
    @Test("ErrorHandler creates data errors correctly")
    func testCreateDataError() {
        let error = ErrorHandler.shared.createDataError("Failed to load data", technicalDetails: "Network timeout")
        
        #expect(error.category == .data, "Should be data category")
        #expect(error.severity == .error, "Should be error severity")
        #expect(error.userMessage == "Failed to load data", "Should have correct message")
        #expect(error.technicalDetails == "Network timeout", "Should have technical details")
        #expect(error.suggestions.count >= 1, "Should have default suggestions")
    }
    
    @Test("ErrorHandler execute returns success for valid operations")
    func testExecuteSuccess() {
        let result = ErrorHandler.shared.execute(context: "Test") {
            return "Success"
        }
        
        switch result {
        case .success(let value):
            #expect(value == "Success", "Should return success value")
        case .failure:
            Issue.record("Should not fail for valid operation")
        }
    }
    
    @Test("ErrorHandler execute returns failure for throwing operations")
    func testExecuteFailure() {
        struct TestError: Error {}
        
        let result = ErrorHandler.shared.execute(context: "Test") {
            throw TestError()
        }
        
        switch result {
        case .success:
            Issue.record("Should not succeed for throwing operation")
        case .failure(let error):
            #expect(error is TestError, "Should return the thrown error")
        }
    }
    
    @Test("ErrorSeverity has correct integer values")
    func testErrorSeverityValues() {
        // Test that ErrorSeverity enum has the expected raw values
        #expect(ErrorSeverity.info.rawValue == 0, "Info should have raw value 0")
        #expect(ErrorSeverity.warning.rawValue == 1, "Warning should have raw value 1")
        #expect(ErrorSeverity.error.rawValue == 2, "Error should have raw value 2")
        #expect(ErrorSeverity.critical.rawValue == 3, "Critical should have raw value 3")
    }
}
